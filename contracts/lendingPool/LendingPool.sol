// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "../interfaces/IProxyFactory.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IPriceHub.sol";
import "../interfaces/ILiquidityPool.sol";

contract LendingPool is ILendingPool, Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    LendingPoolStore internal _store;

    function initialize(address liquidityPool, address priceHub, address swapRouter) external initializer {
        __Ownable_init();
        _store.liquidityPool = liquidityPool;
        _store.priceHub = priceHub;
        _store.swapRouter = swapRouter;
    }

    modifier onlyBorrower() {
        require(_store.borrowers[msg.sender], "UnauthorizedCaller");

        _;
    }

    modifier onlyMaintainer() {
        require(_store.maintainers[msg.sender], "UnauthorizedCaller");
        _;
    }

    // ================================= ADMIN =================================
    function setMaintainer(address maintainer, bool enabled) external onlyOwner {
        _store.maintainers[maintainer] = enabled;
        emit SetMaintainer(maintainer, enabled);
    }

    function setBorrower(address borrower, bool enabled) external onlyOwner {
        _store.borrowers[borrower] = enabled;
        emit SetBorrower(borrower, enabled);
    }

    function setSwapRouter(address swapRouter) external onlyOwner {
        _store.swapRouter = swapRouter;
        emit SetSwapRouter(swapRouter);
    }

    function enable(address token, uint256 features) external onlyMaintainer {
        uint256 flags = _store.borrowStates[token].flags;
        _store.borrowStates[token].flags = flags | features;
        emit SetFlags(token, features, 0, _store.borrowStates[token].flags);
    }

    function disable(address token, uint256 features) external onlyMaintainer {
        uint256 flags = _store.borrowStates[token].flags;
        _store.borrowStates[token].flags = flags & (~features);
        emit SetFlags(token, 0, features, _store.borrowStates[token].flags);
    }

    // ================================= READ =================================
    function isMaintainer(address maintainer) external view returns (bool) {
        return _store.maintainers[maintainer];
    }

    function claimFee(address[] memory tokens) external onlyMaintainer {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            BorrowState storage state = _store.borrowStates[token];
            uint256 feeAmount = state.borrowFeeAmount;
            state.borrowFeeAmount = 0;
            IERC20Upgradeable(token).safeTransfer(msg.sender, feeAmount);
            emit ClaimFee(token, msg.sender, feeAmount);
        }
    }

    function getFlagsOf(address token) external view returns (uint256) {
        return _store.borrowStates[token].flags;
    }

    function getStatusOf(
        address token
    )
        external
        view
        returns (bool isEnabled, bool isBorrowable, bool isRepayable, bool isDepositable, bool isWithdrawable)
    {
        BorrowState memory state = _store.borrowStates[token];
        return (
            _testFlag(state.flags, STATE_IS_ENABLED),
            _testFlag(state.flags, STATE_IS_BORROWABLE),
            _testFlag(state.flags, STATE_IS_REPAYABLE),
            _testFlag(state.flags, STATE_IS_DEPOSITABLE),
            _testFlag(state.flags, STATE_IS_WITHDRAWABLE)
        );
    }

    function getAvailableLiquidity(address token) external view returns (uint256) {
        return _store.borrowStates[token].supplyAmount;
    }

    function getBadDebtOf(address token) external view returns (uint256) {
        return _store.borrowStates[token].badDebtAmount;
    }

    function getBorrowStates(address token) external view returns (BorrowState memory states) {
        return _store.borrowStates[token];
    }

    function getAssetAddress(uint8 assetId) external view returns (address) {
        return ILiquidityPool(_store.liquidityPool).getAssetAddress(assetId);
    }

    function getAssetInfo(uint8 assetId) external view returns (ILiquidityPool.Asset memory) {
        return ILiquidityPool(_store.liquidityPool).getAssetInfo(assetId);
    }

    function getTotalDebtUsd() external view returns (uint256) {
        return _store.totalBorrowUsd > _store.totalRepayUsd ? _store.totalBorrowUsd - _store.totalRepayUsd : 0;
    }

    function getDebtUsdOf(address borrower) external view returns (uint256) {
        uint256 totalBorrowUsd = _store.borrowUsds[borrower];
        uint256 totalRepayUsd = _store.repayUsds[borrower];
        return totalBorrowUsd > totalRepayUsd ? totalBorrowUsd - totalRepayUsd : 0;
    }

    function getDebtStates() external view returns (uint256, uint256) {
        return (_store.totalBorrowUsd, _store.totalRepayUsd);
    }

    function getDebtStatesOf(address borrower) external view returns (uint256, uint256) {
        return (_store.borrowUsds[borrower], _store.repayUsds[borrower]);
    }

    // ================================= WRITE =================================

    function deposit(address token, uint256 depositAmount) external {
        require(depositAmount > 0, "InvalidAmount");
        BorrowState storage state = _store.borrowStates[token];
        require(_testFlag(state.flags, STATE_IS_ENABLED | STATE_IS_DEPOSITABLE), "Forbidden");
        state.supplyAmount += depositAmount;
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), depositAmount);

        emit Deposit(token, depositAmount);
    }

    function withdraw(address token, uint256 withdrawAmount) external onlyOwner {
        require(withdrawAmount > 0, "InvalidAmount");
        require(_store.borrowStates[token].supplyAmount >= withdrawAmount, "InsufficientSupply");
        BorrowState storage state = _store.borrowStates[token];
        require(_testFlag(state.flags, STATE_IS_ENABLED | STATE_IS_WITHDRAWABLE), "Forbidden");
        state.supplyAmount -= withdrawAmount;
        IERC20Upgradeable(token).safeTransfer(msg.sender, withdrawAmount);

        emit Withdraw(token, withdrawAmount);
    }

    function borrowToken(
        uint256 projectId,
        address borrower,
        address token,
        uint256 borrowAmount,
        uint256 borrowFee
    ) external onlyBorrower returns (uint256) {
        return _borrowToken(borrower, token, borrowAmount, borrowFee);
    }

    // new repay
    function repayToken(
        uint256 projectId,
        address repayer,
        address token,
        uint256 repayAmount,
        uint256 borrowFee,
        uint256 badDebt
    ) external onlyBorrower returns (uint256) {
        return _repayToken(repayer, token, repayAmount, borrowFee, badDebt);
    }

    function swap(
        bytes memory swapPath,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external onlyMaintainer returns (uint256 amountOut) {
        require(_store.swapRouter != address(0), "_store.swapRouterUnset");
        // exact input swap to convert exact amount of tokens into usdc
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: swapPath,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut
        });

        BorrowState storage stateIn = _store.borrowStates[tokenIn];
        BorrowState storage stateOut = _store.borrowStates[tokenOut];

        require(amountIn <= stateIn.supplyAmount, "InsufficientSupply");
        stateIn.supplyAmount -= amountIn;
        IERC20Upgradeable(tokenIn).approve(_store.swapRouter, amountIn);
        uint256 outBalance = IERC20Upgradeable(tokenOut).balanceOf(address(this));
        amountOut = ISwapRouter(_store.swapRouter).exactInput(params);
        uint256 outBalanceDiff = IERC20Upgradeable(tokenOut).balanceOf(address(this)) - outBalance;
        require(outBalanceDiff >= amountOut, "InsufficientAmountOut");
        stateOut.supplyAmount += amountOut;
    }

    // ================================= Compatibility =================================

    // new borrow
    function borrowAsset(
        address borrower,
        uint8 assetId,
        uint256 borrowAmount, // token.decimals
        uint256 borrowFee // token.decimals
    ) external onlyBorrower returns (uint256) {
        address token = ILiquidityPool(_store.liquidityPool).getAssetAddress(assetId);
        require(token != address(0), "UnrecognizedToken");
        return _borrowToken(borrower, token, borrowAmount, borrowFee);
    }

    // compatible with gmx v1 + LiquidityPool. will be removed in the future
    // NOTE: LiquidityManager SHOULD transfer rawRepayAmount + rawFee collateral to LiquidityPool
    function repayAsset(
        address repayer,
        uint8 assetId,
        uint256 repayAmount, // token.decimals
        uint256 borrowFee, // token.decimals
        uint256 badDebt // debt amount that cannot be recovered
    ) external onlyBorrower {
        address token = ILiquidityPool(_store.liquidityPool).getAssetAddress(assetId);
        require(token != address(0), "UnrecognizedToken");

        ILiquidityPool.Asset memory asset = ILiquidityPool(_store.liquidityPool).getAssetInfo(assetId);
        uint256 repayToLendingPool = repayAmount;
        if (asset.credit > 0) {
            uint256 credit = asset.credit / (10 ** (18 - asset.decimals));
            uint256 repayToLiquidityPool = MathUpgradeable.min(repayAmount, credit);
            if (repayToLiquidityPool > 0) {
                ILiquidityPool(_store.liquidityPool).repayAsset(repayer, assetId, repayToLiquidityPool, 0, 0);
            }
            repayToLendingPool = repayAmount - repayToLiquidityPool;
        }
        if (repayToLendingPool > 0) {
            _repayToken(repayer, token, repayToLendingPool, borrowFee, badDebt);
        }
    }

    // ================================= Priavte =================================
    function _testFlag(uint256 flag, uint256 testBits) internal pure returns (bool) {
        return flag & testBits == testBits;
    }

    function _borrowToken(
        address borrower,
        address token,
        uint256 borrowAmount,
        uint256 borrowFee
    ) internal returns (uint256) {
        BorrowState storage state = _store.borrowStates[token];
        require(_testFlag(state.flags, STATE_IS_ENABLED | STATE_IS_BORROWABLE), "Forbidden");
        require(borrowAmount <= state.supplyAmount, "InsufficientSupply");
        state.supplyAmount -= borrowAmount;
        state.borrowFeeAmount += borrowFee;
        state.totalAmountOut += borrowAmount;
        uint256 transferOutAmount = borrowAmount - borrowFee;
        IERC20Upgradeable(token).safeTransfer(borrower, transferOutAmount);
        _updateBorrowHistory(borrower, token, borrowAmount);
        emit BorrowToken(borrower, token, borrowAmount, borrowFee);

        return transferOutAmount;
    }

    function _repayToken(
        address repayer,
        address token,
        uint256 repayAmount,
        uint256 borrowFee,
        uint256 badDebt
    ) internal returns (uint256) {
        BorrowState storage state = _store.borrowStates[token];
        require(_testFlag(state.flags, STATE_IS_ENABLED | STATE_IS_REPAYABLE), "Forbidden");
        state.supplyAmount += repayAmount;
        state.borrowFeeAmount += borrowFee;
        state.totalAmountIn += repayAmount;
        state.badDebtAmount += badDebt;
        uint256 transferInAmount = repayAmount + borrowFee;
        uint256 balance = IERC20Upgradeable(token).balanceOf(address(this));
        require(balance - state.borrowFeeAmount >= state.supplyAmount, "InsufficientTransferredIn");
        _updateRepayHistory(repayer, token, repayAmount);
        emit RepayToken(repayer, token, repayAmount, borrowFee, badDebt);

        return transferInAmount;
    }

    function _updateBorrowHistory(address borrower, address token, uint256 amount) internal {
        uint256 price = IPriceHub(_store.priceHub).getPriceByToken(token);
        uint256 valueUsd = _norm(token, (amount * price) / 1e18);
        _store.borrowUsds[borrower] += valueUsd;
        _store.totalBorrowUsd += valueUsd;
    }

    function _updateRepayHistory(address repayer, address token, uint256 amount) internal {
        uint256 price = IPriceHub(_store.priceHub).getPriceByToken(token);
        uint256 valueUsd = _norm(token, (amount * price) / 1e18);
        _store.repayUsds[repayer] += valueUsd;
        _store.totalRepayUsd += valueUsd;
    }

    function _norm(address token, uint256 value) internal view returns (uint256) {
        uint8 decimals = IERC20MetadataUpgradeable(token).decimals();
        return value * (10 ** (18 - decimals));
    }
}
