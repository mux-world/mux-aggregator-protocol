// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../../interfaces/IGmxRouter.sol";
import "../../interfaces/ILiquidityPool.sol";
import "../../interfaces/IProxyFactory.sol";
import "../../components/ImplementationGuard.sol";

import "./libs/LibGmx.sol";
import "./libs/LibOracle.sol";
import "./libs/LibUtils.sol";

import "./Type.sol";
import "./Storage.sol";
import "./Config.sol";
import "./Debt.sol";
import "./Position.sol";

contract GmxAdapter is Storage, Debt, Position, Config, ReentrancyGuardUpgradeable, ImplementationGuard {
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.Bytes32ToBytes32Map;

    // mux flags
    uint8 constant POSITION_MARKET_ORDER = 0x40;
    uint8 constant POSITION_TPSL_ORDER = 0x08;

    address internal immutable _WETH;

    event Withdraw(
        uint256 cumulativeDebt,
        uint256 cumulativeFee,
        bool isLiquidation,
        uint256 balance,
        uint256 userWithdrawal,
        uint256 paidDebt,
        uint256 paidFee
    );

    constructor(address weth) ImplementationGuard() {
        _WETH = weth;
    }

    receive() external payable {}

    modifier onlyTraderOrFactory() {
        require(msg.sender == _account.account || msg.sender == _factory, "OnlyTraderOrFactory");
        _;
    }

    modifier onlyKeeperOrFactory() {
        require(IProxyFactory(_factory).isKeeper(msg.sender) || msg.sender == _factory, "onlyKeeper");
        _;
    }

    function initialize(
        uint256 projectId,
        address liquidityPool,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external initializer onlyDelegateCall {
        require(liquidityPool != address(0), "InvalidLiquidityPool");
        require(projectId == PROJECT_ID, "InvalidProject");

        _factory = msg.sender;
        _liquidityPool = liquidityPool;
        _gmxPositionKey = keccak256(abi.encodePacked(address(this), collateralToken, assetToken, isLong));
        _account.account = account;
        _account.collateralToken = collateralToken;
        _account.indexToken = assetToken;
        _account.isLong = isLong;
        _account.collateralDecimals = IERC20MetadataUpgradeable(collateralToken).decimals();
        _updateConfigs();
    }

    function debtStates()
        external
        view
        returns (uint256 cumulativeDebt, uint256 cumulativeFee, uint256 debtEntryFunding)
    {
        cumulativeDebt = _account.cumulativeDebt;
        cumulativeFee = _account.cumulativeFee;
        debtEntryFunding = _account.debtEntryFunding;
    }

    function muxAccountState() external view returns (AccountState memory) {
        return _account;
    }

    function getPendingGmxOrderKeys() external view returns (bytes32[] memory) {
        return _getPendingOrders();
    }

    function getTpslOrderKeys(bytes32 orderKey) external view returns (bytes32, bytes32) {
        return _getTpslOrderIndexes(orderKey);
    }

    /// @notice Place a openning request on GMX.
    /// - market order => positionRouter
    /// - limit order => orderbook
    /// token: swapInToken(swapInAmount) => _account.collateralToken => _account.indexToken.
    function openPosition(
        address swapInToken,
        uint256 swapInAmount, // tokenIn.decimals
        uint256 minSwapOut, // collateral.decimals
        uint256 borrow, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint96 tpPriceUsd,
        uint96 slPriceUsd,
        uint8 flags // MARKET, TRIGGER
    ) external payable onlyTraderOrFactory nonReentrant {
        require(!_account.isLiquidating, "TradeForbidden");

        _updateConfigs();
        _tryApprovePlugins();
        _cleanOrders();

        bytes32 orderKey;
        orderKey = _openPosition(
            swapInToken,
            swapInAmount, // tokenIn.decimals
            minSwapOut, // collateral.decimals
            borrow, // collateral.decimals
            sizeUsd, // 1e18
            priceUsd, // 1e18
            flags // MARKET, TRIGGER
        );

        if (flags & POSITION_TPSL_ORDER > 0) {
            bytes32 tpOrderKey;
            bytes32 slOrderKey;
            if (tpPriceUsd > 0) {
                tpOrderKey = _closePosition(0, sizeUsd, tpPriceUsd, 0);
            }
            if (slPriceUsd > 0) {
                slOrderKey = _closePosition(0, sizeUsd, slPriceUsd, 0);
            }
            _openTpslOrderIndexes.set(orderKey, LibGmx.encodeTpslIndex(tpOrderKey, slOrderKey));
        }
    }

    function _openPosition(
        address swapInToken,
        uint256 swapInAmount, // tokenIn.decimals
        uint256 minSwapOut, // collateral.decimals
        uint256 borrow, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) internal returns (bytes32 orderKey) {
        require(!_account.isLiquidating, "TradeForbidden");

        _updateConfigs();
        _tryApprovePlugins();
        _cleanOrders();

        OpenPositionContext memory context = OpenPositionContext({
            sizeUsd: sizeUsd * GMX_DECIMAL_MULTIPLIER,
            priceUsd: priceUsd * GMX_DECIMAL_MULTIPLIER,
            isMarket: _isMarketOrder(flags),
            borrow: borrow,
            fee: 0,
            amountIn: 0,
            amountOut: 0,
            gmxOrderIndex: 0,
            executionFee: 0
        });
        if (swapInToken == _WETH) {
            IWETH(_WETH).deposit{ value: swapInAmount }();
        }
        if (swapInToken != _account.collateralToken) {
            context.amountOut = LibGmx.swap(
                _projectConfigs,
                swapInToken,
                _account.collateralToken,
                swapInAmount,
                minSwapOut
            );
        } else {
            context.amountOut = swapInAmount;
        }
        uint256 borrowed;
        (borrowed, context.fee) = _borrowCollateral(borrow);
        context.amountIn = context.amountOut + borrowed;
        IERC20Upgradeable(_account.collateralToken).approve(_projectConfigs.router, context.amountIn);

        return _openPosition(context);
    }

    /// @notice Place a closing request on GMX.
    function closePosition(
        uint256 collateralUsd, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint96 tpPriceUsd, // 1e18
        uint96 slPriceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) external payable onlyTraderOrFactory nonReentrant {
        require(!_account.isLiquidating, "TradeForbidden");
        _updateConfigs();
        _cleanOrders();

        if (flags & POSITION_TPSL_ORDER > 0) {
            if (_account.isLong) {
                require(tpPriceUsd >= slPriceUsd, "WrongPrice");
            } else {
                require(tpPriceUsd <= slPriceUsd, "WrongPrice");
            }
            bytes32 tpOrderKey = _closePosition(
                collateralUsd, // collateral.decimals
                sizeUsd, // 1e18
                tpPriceUsd, // 1e18
                0 // MARKET, TRIGGER
            );
            _closeTpslOrderIndexes.add(tpOrderKey);
            bytes32 slOrderKey = _closePosition(
                collateralUsd, // collateral.decimals
                sizeUsd, // 1e18
                slPriceUsd, // 1e18
                0 // MARKET, TRIGGER
            );
            _closeTpslOrderIndexes.add(slOrderKey);
        } else {
            _closePosition(
                collateralUsd, // collateral.decimals
                sizeUsd, // 1e18
                priceUsd, // 1e18
                flags // MARKET, TRIGGER
            );
        }
    }

    function updateOrder(
        bytes32 orderKey,
        uint256 collateralDelta,
        uint256 sizeDelta,
        uint256 triggerPrice,
        bool triggerAboveThreshold
    ) external onlyTraderOrFactory nonReentrant {
        _updateConfigs();
        _cleanOrders();

        LibGmx.OrderHistory memory history = LibGmx.decodeOrderHistoryKey(orderKey);
        if (history.receiver == LibGmx.OrderReceiver.OB_INC) {
            IGmxOrderBook(_projectConfigs.orderBook).updateIncreaseOrder(
                history.index,
                sizeDelta,
                triggerPrice,
                triggerAboveThreshold
            );
        } else if (history.receiver == LibGmx.OrderReceiver.OB_DEC) {
            IGmxOrderBook(_projectConfigs.orderBook).updateDecreaseOrder(
                history.index,
                collateralDelta,
                sizeDelta,
                triggerPrice,
                triggerAboveThreshold
            );
        } else {
            revert("InvalidOrderType");
        }
    }

    function _closePosition(
        uint256 collateralUsd, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) internal returns (bytes32) {
        require(!_account.isLiquidating, "TradeForbidden");
        _updateConfigs();
        _cleanOrders();

        ClosePositionContext memory context = ClosePositionContext({
            collateralUsd: collateralUsd * GMX_DECIMAL_MULTIPLIER,
            sizeUsd: sizeUsd * GMX_DECIMAL_MULTIPLIER,
            priceUsd: priceUsd * GMX_DECIMAL_MULTIPLIER,
            isMarket: _isMarketOrder(flags),
            gmxOrderIndex: 0,
            executionFee: 0
        });
        return _closePosition(context);
    }

    function liquidatePosition(uint256 liquidatePrice) external payable onlyKeeperOrFactory nonReentrant {
        _updateConfigs();
        _cleanOrders();

        IGmxVault.Position memory position = _getGmxPosition();
        require(position.sizeUsd > 0, "NoPositionToLiquidate");
        _checkLiquidatePrice(liquidatePrice);
        _liquidatePosition(position, liquidatePrice);
        _account.isLiquidating = true;
    }

    function withdraw() external nonReentrant {
        _updateConfigs();
        _cleanOrders();

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            if (_account.collateralToken == _WETH) {
                IWETH(_WETH).deposit{ value: ethBalance }();
            } else {
                LibUtils.trySendNativeToken(_WETH, _account.account, ethBalance);
            }
        }
        IGmxVault.Position memory position = _getGmxPosition();
        uint256 balance = IERC20Upgradeable(_account.collateralToken).balanceOf(address(this));
        uint256 userAmount;
        uint256 paidDebt;
        uint256 paidFee;
        bool isLiquidation = _account.isLiquidating;
        // partially close
        if (position.sizeUsd != 0) {
            require(
                _isMarginSafe(
                    position,
                    0,
                    0,
                    LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong),
                    _assetConfigs.initialMarginRate
                ),
                "ImMarginUnsafe"
            );
            userAmount = balance;
            paidDebt = 0;
            paidFee = 0;
            _transferToUser(userAmount);
            (uint256 fundingFee, uint256 newFunding) = _getMuxFundingFee();
            _account.cumulativeFee += fundingFee;
            _account.debtEntryFunding = newFunding;
        } else {
            // safe
            uint256 inflightBorrow = _calcInflightBorrow(); // collateral
            (userAmount, paidDebt, paidFee) = _repayCollateral(balance, inflightBorrow);
            if (userAmount > 0) {
                _transferToUser(userAmount);
            }
            _account.isLiquidating = false;
            // clean tpsl orders
            _cleanTpslOrders();
        }
        emit Withdraw(
            _account.cumulativeDebt,
            _account.cumulativeFee,
            isLiquidation,
            balance,
            userAmount,
            paidDebt,
            paidFee
        );
    }

    function cancelOrders(bytes32[] memory keys) external nonReentrant {
        require(
            msg.sender == _account.account || msg.sender == _factory || IProxyFactory(_factory).isKeeper(msg.sender),
            "OnlyTraderOrFactoryOrKeeper"
        );
        _cleanOrders();
        _cancelOrders(keys);
    }

    function cancelTimeoutOrders(bytes32[] memory keys) external nonReentrant onlyKeeperOrFactory {
        _cleanOrders();
        _cancelTimeoutOrders(keys);
    }

    function _tryApprovePlugins() internal {
        IGmxRouter(_projectConfigs.router).approvePlugin(_projectConfigs.orderBook);
        IGmxRouter(_projectConfigs.router).approvePlugin(_projectConfigs.positionRouter);
    }

    function _transferToUser(uint256 amount) internal {
        if (_account.collateralToken == _WETH) {
            IWETH(_WETH).withdraw(amount);
            LibUtils.trySendNativeToken(_WETH, _account.account, amount);
        } else {
            IERC20Upgradeable(_account.collateralToken).safeTransfer(_account.account, amount);
        }
    }

    function _checkLiquidatePrice(uint256 liquidatePrice) internal view {
        require(liquidatePrice != 0, "ZeroLiquidationPrice"); // broker price = 0
        if (_assetConfigs.referrenceOracle == address(0)) {
            return;
        }
        uint96 oraclePrice = LibOracle.readChainlink(_assetConfigs.referrenceOracle);
        require(oraclePrice != 0, "ZeroOralcePrice"); // broker price = 0

        uint256 bias = liquidatePrice >= oraclePrice ? liquidatePrice - oraclePrice : oraclePrice - liquidatePrice;
        bias = (bias * LibUtils.RATE_DENOMINATOR) / oraclePrice;
        require(bias <= _assetConfigs.referenceDeviation, "LiquidatePriceNotMet");
    }

    function _isMarketOrder(uint8 flags) internal pure returns (bool) {
        return (flags & POSITION_MARKET_ORDER) != 0;
    }

    function _cancelOrders(bytes32[] memory keys) internal {
        uint256 canceledBorrow = 0;
        for (uint256 i = 0; i < keys.length; i++) {
            bytes32 orderKey = keys[i];
            LibGmx.OrderHistory memory history = LibGmx.decodeOrderHistoryKey(orderKey);
            canceledBorrow += history.borrow;
            // must cancel order && tpsl
            require(_cancelOrder(orderKey), "CancelFailed");
            _cancelTpslOrders(orderKey);
        }
        _repayCanceledBorrow(canceledBorrow);
    }

    function _cancelTimeoutOrders(bytes32[] memory keys) internal {
        uint256 _now = block.timestamp;
        uint256 marketTimeout = _projectConfigs.marketOrderTimeoutSeconds;
        uint256 limitTimeout = _projectConfigs.limitOrderTimeoutSeconds;
        uint256 canceledBorrow = 0;
        for (uint256 i = 0; i < keys.length; i++) {
            bytes32 orderKey = keys[i];
            LibGmx.OrderHistory memory history = LibGmx.decodeOrderHistoryKey(orderKey);
            uint256 elapsed = _now - history.timestamp;
            if (
                ((history.receiver == LibGmx.OrderReceiver.PR_INC || history.receiver == LibGmx.OrderReceiver.PR_DEC) &&
                    elapsed >= marketTimeout) ||
                ((history.receiver == LibGmx.OrderReceiver.OB_INC || history.receiver == LibGmx.OrderReceiver.OB_DEC) &&
                    elapsed >= limitTimeout)
            ) {
                if (_cancelOrder(orderKey)) {
                    canceledBorrow += history.borrow;
                    _cancelTpslOrders(orderKey);
                }
            }
        }
        _repayCanceledBorrow(canceledBorrow);
    }

    function _cleanTpslOrders() internal {
        // open tpsl orders
        uint256 openLength = _openTpslOrderIndexes.length();
        bytes32[] memory openKeys = new bytes32[](openLength);
        for (uint256 i = 0; i < openLength; i++) {
            (openKeys[i], ) = _openTpslOrderIndexes.at(i);
        }
        for (uint256 i = 0; i < openLength; i++) {
            // clean all tpsl orders paired with orders that already filled
            if (!_pendingOrders.contains(openKeys[i])) {
                _cancelTpslOrders(openKeys[i]);
            }
        }
        // close tpsl orders
        uint256 closeLength = _closeTpslOrderIndexes.length();
        bytes32[] memory closeKeys = new bytes32[](closeLength);
        for (uint256 i = 0; i < closeLength; i++) {
            closeKeys[i] = _closeTpslOrderIndexes.at(i);
        }
        for (uint256 i = 0; i < closeLength; i++) {
            // clean all tpsl orders paired with orders that already filled
            _cancelOrder(closeKeys[i]);
        }
    }

    function _cleanOrders() internal {
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            bytes32 orderKey = pendingKeys[i];
            (bool notExist, ) = LibGmx.getOrder(_projectConfigs, orderKey);
            if (notExist) {
                _removePendingOrder(orderKey);
            }
        }
    }

    function _repayCanceledBorrow(uint256 borrow) internal {
        if (borrow == 0) {
            return;
        }
        uint256 ethBalance = address(this).balance;
        if (_account.collateralToken == _WETH && ethBalance > 0) {
            IWETH(_WETH).deposit{ value: ethBalance }();
        }
        uint256 balance = IERC20Upgradeable(_account.collateralToken).balanceOf(address(this));
        if (_account.collateralToken == _WETH) {
            balance += address(this).balance;
        }
        (uint256 toUser, , ) = _partialRepayCollateral(borrow, balance);
        _transferToUser(toUser);
    }
}
