// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import "../interfaces/IAggregator.sol";
import "../interfaces/IReferralManager.sol";
import "../interfaces/IMuxOrderBook.sol";

import "./Storage.sol";
import "./ProxyBeacon.sol";
import "./DebtManager.sol";
import "./ProxyConfig.sol";

contract ProxyFactory is Storage, ProxyBeacon, DebtManager, ProxyConfig, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct OpenPositionArgs {
        uint256 projectId;
        address collateralToken;
        address assetToken;
        bool isLong;
        address tokenIn;
        uint256 amountIn; // tokenIn.decimals
        uint256 minOut; // collateral.decimals
        uint256 borrow; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }
    struct ClosePositionArgs {
        uint256 projectId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }

    struct OpenPositionArgsV2 {
        uint256 projectId;
        address collateralToken;
        address assetToken;
        bool isLong;
        address tokenIn;
        uint256 amountIn; // tokenIn.decimals
        uint256 minOut; // collateral.decimals
        uint256 borrow; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint96 tpPriceUsd; // 1e18
        uint96 slPriceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }
    struct ClosePositionArgsV2 {
        uint256 projectId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint96 tpPriceUsd; // 1e18
        uint96 slPriceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }

    struct PositionOrderExtra {
        // tp/sl strategy
        uint96 tpPrice; // take-profit price. decimals = 18. only valid when flags.POSITION_TPSL_STRATEGY.
        uint96 slPrice; // stop-loss price. decimals = 18. only valid when flags.POSITION_TPSL_STRATEGY.
        uint8 tpslProfitTokenId; // only valid when flags.POSITION_TPSL_STRATEGY.
        uint32 tpslDeadline; // only valid when flags.POSITION_TPSL_STRATEGY.
    }

    struct MuxOrderParams {
        bytes32 subAccountId;
        uint96 collateralAmount; // erc20.decimals
        uint96 size; // 1e18
        uint96 price; // 1e18
        uint8 profitTokenId;
        uint8 flags;
        uint32 deadline; // 1e0
        bytes32 referralCode;
        IMuxOrderBook.PositionOrderExtra extra;
    }

    struct OrderParams {
        bytes32 orderKey;
        uint256 collateralDelta;
        uint256 sizeDelta;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
    }

    event SetMaintainer(address maintainer, bool enable);
    event SetKeeper(address keeper, bool enable);
    event SetGmxReferralCode(bytes32 gmxReferralCode);
    event SetBorrowConfig(
        uint256 projectId,
        address assetToken,
        uint8 prevAssetId,
        uint8 newAssetId,
        uint256 prevLimit,
        uint256 newLimit
    );
    event MuxCall(address target, uint256 value, bytes data);

    function initialize(address weth_, address liquidityPool) external initializer {
        __Ownable_init();
        _weth = weth_;
        _liquidityPool = liquidityPool;
    }

    function weth() external view returns (address) {
        return _weth;
    }

    function isKeeper(address keeper) public view returns (bool) {
        return _keepers[keeper];
    }

    function getConfigVersions(
        uint256 projectId,
        address assetToken
    ) external view returns (uint32 projectConfigVersion, uint32 assetConfigVersion) {
        return _getLatestVersions(projectId, assetToken);
    }

    function getProjectConfig(uint256 projectId) external view returns (uint256[] memory) {
        return _projectConfigs[projectId].values;
    }

    function getProjectAssetConfig(uint256 projectId, address assetToken) external view returns (uint256[] memory) {
        return _projectAssetConfigs[projectId][assetToken].values;
    }

    function getProxy(bytes32 accountKey) public view returns (address) {
        return _tradingProxies[accountKey];
    }

    function getProxiesOf(address account) public view returns (address[] memory) {
        return _ownedProxies[account];
    }

    function getBorrowStates(
        uint256 projectId,
        address assetToken
    ) external view returns (uint256 totalBorrow, uint256 borrowLimit, uint256 badDebt) {
        DebtData storage debtData = _debtData[projectId][assetToken];
        totalBorrow = debtData.totalDebt;
        borrowLimit = debtData.limit;
        badDebt = debtData.badDebt;
    }

    function getAssetId(uint256 projectId, address assetToken) public view returns (uint8) {
        DebtData storage debtData = _debtData[projectId][assetToken];
        require(debtData.hasValue, "AssetNotAvailable");
        return debtData.assetId;
    }

    // =========================== management interfaces ===========================
    function setReferralManager(address referralManager) external onlyOwner {
        _referralManager = referralManager;
    }

    function setMuxOrderBook(address muxOrderBook) external onlyOwner {
        _muxOrderBook = muxOrderBook;
    }

    function setBorrowConfig(uint256 projectId, address assetToken, uint8 newAssetId, uint256 newLimit) external {
        require(_maintainers[msg.sender] || msg.sender == owner(), "OnlyMaintainerOrAbove");
        DebtData storage debtData = _debtData[projectId][assetToken];
        _verifyAssetId(assetToken, newAssetId);
        emit SetBorrowConfig(projectId, assetToken, debtData.assetId, newAssetId, debtData.limit, newLimit);
        debtData.assetId = newAssetId;
        debtData.limit = newLimit;
        debtData.hasValue = true;
    }

    function setProjectConfig(uint256 projectId, uint256[] memory values) external {
        require(_maintainers[msg.sender] || msg.sender == owner(), "OnlyMaintainerOrAbove");
        _setProjectConfig(projectId, values);
    }

    function setMaintainer(address maintainer, bool enable) external onlyOwner {
        _maintainers[maintainer] = enable;
        emit SetMaintainer(maintainer, enable);
    }

    function setKeeper(address keeper, bool enable) external onlyOwner {
        _keepers[keeper] = enable;
        emit SetKeeper(keeper, enable);
    }

    function setProjectAssetConfig(uint256 projectId, address assetToken, uint256[] memory values) external onlyOwner {
        _setProjectAssetConfig(projectId, assetToken, values);
    }

    function upgradeTo(uint256 projectId, address newImplementation_) external onlyOwner {
        _upgradeTo(projectId, newImplementation_);
    }

    // =========================== proxy interfaces ===========================
    // ======================== method called by proxy ========================
    function borrowAsset(
        uint256 projectId,
        address assetToken,
        uint256 toBorrow,
        uint256 fee
    ) external returns (uint256 amountOut) {
        require(_isCreatedProxy(msg.sender), "CallNotProxy");
        amountOut = _borrowAsset(projectId, msg.sender, assetToken, toBorrow, fee);
    }

    function repayAsset(uint256 projectId, address assetToken, uint256 toRepay, uint256 fee, uint256 badDebt) external {
        require(_isCreatedProxy(msg.sender), "CallNotProxy");
        _repayAsset(projectId, msg.sender, assetToken, toRepay, fee, badDebt);
    }

    // ======================== method called by user ========================
    function createProxy(
        uint256 projectId,
        address collateralToken,
        address assetToken,
        bool isLong
    ) public returns (address) {
        uint8 collateralId = getAssetId(projectId, collateralToken);
        _verifyAssetId(collateralToken, collateralId);
        return
            _createBeaconProxy(
                projectId,
                _liquidityPool,
                msg.sender,
                assetToken,
                collateralToken,
                collateralId,
                isLong
            );
    }

    function openPosition(OpenPositionArgs calldata args) external payable {
        bytes32 proxyId = _makeProxyId(args.projectId, msg.sender, args.collateralToken, args.assetToken, args.isLong);
        address proxy = _tradingProxies[proxyId];
        if (proxy == address(0)) {
            proxy = createProxy(args.projectId, args.collateralToken, args.assetToken, args.isLong);
        }
        if (args.tokenIn != _weth) {
            IERC20Upgradeable(args.tokenIn).safeTransferFrom(msg.sender, proxy, args.amountIn);
        } else {
            require(msg.value >= args.amountIn, "InsufficientAmountIn");
        }
        if (args.referralCode != bytes32(0) && _referralManager != address(0)) {
            IReferralManager(_referralManager).setReferrerCodeFor(proxy, args.referralCode);
        }
        IAggregator(proxy).openPosition{ value: msg.value }(
            args.tokenIn,
            args.amountIn,
            args.minOut,
            args.borrow,
            args.sizeUsd,
            args.priceUsd,
            0,
            0,
            args.flags
        );
    }

    function openPositionV2(OpenPositionArgsV2 calldata args) external payable {
        _openPosition(args, msg.value);
    }

    function openPositionV3(
        OpenPositionArgsV2 calldata args,
        MuxOrderParams calldata muxParams,
        uint256 muxValue
    ) external payable {
        require(msg.value >= muxValue, "InsufficientValue");
        _openPosition(args, msg.value - muxValue);
        if (muxParams.subAccountId != bytes32(0)) {
            require(msg.sender == _getSubAccountOwner(muxParams.subAccountId), "SubAccountNotMatch");
            IMuxOrderBook(_muxOrderBook).placePositionOrder3{ value: muxValue }(
                muxParams.subAccountId,
                muxParams.collateralAmount,
                muxParams.size,
                muxParams.price,
                muxParams.profitTokenId,
                muxParams.flags,
                muxParams.deadline,
                muxParams.referralCode,
                muxParams.extra
            );
        }
    }

    function _openPosition(OpenPositionArgsV2 calldata args, uint256 value) internal {
        bytes32 proxyId = _makeProxyId(args.projectId, msg.sender, args.collateralToken, args.assetToken, args.isLong);
        address proxy = _tradingProxies[proxyId];
        if (proxy == address(0)) {
            proxy = createProxy(args.projectId, args.collateralToken, args.assetToken, args.isLong);
        }
        if (args.tokenIn != _weth) {
            IERC20Upgradeable(args.tokenIn).safeTransferFrom(msg.sender, proxy, args.amountIn);
        } else {
            require(value >= args.amountIn, "InsufficientAmountIn");
        }
        if (args.referralCode != bytes32(0) && _referralManager != address(0)) {
            IReferralManager(_referralManager).setReferrerCodeFor(proxy, args.referralCode);
        }
        IAggregator(proxy).openPosition{ value: value }(
            args.tokenIn,
            args.amountIn,
            args.minOut,
            args.borrow,
            args.sizeUsd,
            args.priceUsd,
            args.tpPriceUsd,
            args.slPriceUsd,
            args.flags
        );
    }

    function closePosition(ClosePositionArgs calldata args) external payable {
        address proxy = _mustGetProxy(args.projectId, msg.sender, args.collateralToken, args.assetToken, args.isLong);
        if (args.referralCode != bytes32(0) && _referralManager != address(0)) {
            IReferralManager(_referralManager).setReferrerCodeFor(proxy, args.referralCode);
        }
        IAggregator(proxy).closePosition{ value: msg.value }(
            args.collateralUsd,
            args.sizeUsd,
            args.priceUsd,
            0,
            0,
            args.flags
        );
    }

    function closePositionV2(ClosePositionArgsV2 calldata args) external payable {
        address proxy = _mustGetProxy(args.projectId, msg.sender, args.collateralToken, args.assetToken, args.isLong);
        if (args.referralCode != bytes32(0) && _referralManager != address(0)) {
            IReferralManager(_referralManager).setReferrerCodeFor(proxy, args.referralCode);
        }
        IAggregator(proxy).closePosition{ value: msg.value }(
            args.collateralUsd,
            args.sizeUsd,
            args.priceUsd,
            args.tpPriceUsd,
            args.slPriceUsd,
            args.flags
        );
    }

    function cancelOrders(
        uint256 projectId,
        address collateralToken,
        address assetToken,
        bool isLong,
        bytes32[] calldata keys
    ) external {
        IAggregator(_mustGetProxy(projectId, msg.sender, collateralToken, assetToken, isLong)).cancelOrders(keys);
    }

    function updateOrder(
        uint256 projectId,
        address collateralToken,
        address assetToken,
        bool isLong,
        OrderParams[] memory orderParams
    ) external {
        for (uint256 i = 0; i < orderParams.length; i++) {
            IAggregator(_mustGetProxy(projectId, msg.sender, collateralToken, assetToken, isLong)).updateOrder(
                orderParams[i].orderKey,
                orderParams[i].collateralDelta,
                orderParams[i].sizeDelta,
                orderParams[i].triggerPrice,
                orderParams[i].triggerAboveThreshold
            );
        }
    }

    // ======================== method called by keeper ========================
    function cancelTimeoutOrders(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong,
        bytes32[] calldata keys
    ) external {
        IAggregator(_mustGetProxy(projectId, account, collateralToken, assetToken, isLong)).cancelTimeoutOrders(keys);
    }

    function liquidatePosition(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong,
        uint256 liquidatePrice
    ) external payable {
        require(isKeeper(msg.sender), "OnlyKeeper");
        IAggregator(_mustGetProxy(projectId, account, collateralToken, assetToken, isLong)).liquidatePosition{
            value: msg.value
        }(liquidatePrice);
    }

    function withdraw(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external {
        IAggregator(_mustGetProxy(projectId, account, collateralToken, assetToken, isLong)).withdraw();
    }

    function getProxyAddress(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external view returns (address) {
        return _getBeaconProxyAddress(projectId, _liquidityPool, account, collateralToken, assetToken, isLong);
    }

    function _mustGetProxy(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) internal view returns (address proxy) {
        bytes32 proxyId = _makeProxyId(projectId, account, collateralToken, assetToken, isLong);
        proxy = _tradingProxies[proxyId];
        require(proxy != address(0), "ProxyNotExist");
    }

    function _verifyAssetId(address assetToken, uint8 assetId) internal view {
        if (assetId == VIRTUAL_ASSET_ID) {
            return;
        }
        address token = ILiquidityPool(_liquidityPool).getAssetAddress(assetId);
        require(assetToken == token, "BadAssetId");
    }

    function _getSubAccountOwner(bytes32 subAccountId) internal pure returns (address account) {
        account = address(uint160(uint256(subAccountId) >> 96));
    }
}
