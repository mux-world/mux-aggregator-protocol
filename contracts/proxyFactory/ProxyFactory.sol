// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import "../interfaces/IProxyFactory.sol";
import "../interfaces/IAggregator.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IReferralManager.sol";
import { IMux3OrderBook, OrderData as Mux3OrderData } from "../interfaces/IMux3OrderBook.sol";
import "../interfaces/IMuxOrderBook.sol";

import "./Storage.sol";
import "./ProxyBeacon.sol";
import "./DebtManager.sol";
import "./ProxyConfig.sol";

contract ProxyFactory is Storage, ProxyBeacon, DebtManager, ProxyConfig, OwnableUpgradeable, IProxyFactory {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

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

    function getProxyProjectId(address proxy_) public view returns (uint256) {
        return _proxyProjectIds[proxy_];
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

    function getLiquiditySource(uint256 projectId) external view returns (uint256 sourceId, address source) {
        (sourceId, source) = _getLiquiditySource(projectId);
    }

    function getProxyAddress(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) public view returns (address proxy) {
        bytes32 proxyId = _makeProxyId(projectId, account, collateralToken, assetToken, isLong);
        proxy = _tradingProxies[proxyId];
        if (proxy != address(0)) {
            return proxy;
        }
        proxy = _getBeaconProxyAddress(projectId, _liquidityPool, account, collateralToken, assetToken, isLong);
    }

    // =========================== management interfaces ===========================
    function setReferralManager(address referralManager) external onlyOwner {
        _referralManager = referralManager;
    }

    function setMuxOrderBook(address muxOrderBook) external onlyOwner {
        _muxOrderBook = muxOrderBook;
    }

    function setMux3OrderBook(address mux3OrderBook) external onlyOwner {
        _mux3OrderBook = mux3OrderBook;
    }

    // SOURCE_ID_LIQUIDITY_POOL = 1;
    // SOURCE_ID_LENDING_POOL = 2;
    function setLiquiditySource(uint256 projectId, uint256 sourceId, address source) external onlyOwner {
        require(sourceId == SOURCE_ID_LIQUIDITY_POOL || sourceId == SOURCE_ID_LENDING_POOL, "BadSourceId");
        require(source != address(0), "BadSource");
        _liquiditySourceId[projectId] = sourceId;
        _liquiditySource[projectId] = source;

        emit SetLiquiditySource(projectId, sourceId, source);
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

    function setDelegator(address delegator, bool enable) external onlyOwner {
        _delegators[delegator] = enable;
        emit SetDelegator(delegator, enable);
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
    function muxFunctionCall(bytes memory muxCallData, uint256 value) external payable {
        bytes32 subAccountId = _decodeSubAccountId(muxCallData);
        // account owner or delegator
        address account = _getSubAccountOwner(subAccountId);
        _verifyCaller(account);
        bytes4 sig = _decodeFunctionSig(muxCallData);

        require(
            sig == IMuxOrderBook.placePositionOrder3.selector ||
                sig == IMuxOrderBook.depositCollateral.selector ||
                sig == IMuxOrderBook.placeWithdrawalOrder.selector,
            "Forbidden"
        );
        _muxOrderBook.functionCallWithValue(muxCallData, value);
    }

    function muxCancelOrder(uint64 orderId) external payable {
        (bytes32[3] memory order, bool isOrderExist) = IMuxOrderBook(_muxOrderBook).getOrder(orderId);
        require(isOrderExist, "orderNotExist");
        address orderOwner = _getSubAccountOwner(order[0]);
        _verifyCaller(orderOwner);
        IMuxOrderBook(_muxOrderBook).cancelOrder(orderId);
    }

    /**
     * @notice A trader should set initial leverage at least once before open-position
     * @param collateralToken The token to deposit, 0x0 or 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE for native token
     * @param collateralAmount The amount of collateral to deposit, following collateral token decimals
     * @param positionOrderCallData The call data for placePositionOrder.
     *                              The data should include the referral code but function selector
     * @param initialLeverage The initial leverage to set
     * @param gas The amount of gas to deposit, must included in sent value
     */
    function mux3PositionCall(
        address collateralToken,
        uint256 collateralAmount,
        bytes memory positionOrderCallData,
        uint256 initialLeverage, // 0 = ignore
        uint256 gas // 0 = ignore
    ) external payable {
        // *      example for collateral = USDC:
        // *        multicall([
        // *          wrapNative(gas),
        // *          depositGas(gas),
        // *          transferToken(collateral),
        // *          placePositionOrder(positionOrderParams),
        // *        ])
        // *      example for collateral = ETH:
        // *        multicall([
        // *          wrapNative(gas),
        // *          depositGas(gas),
        // *          wrapNative(collateral),
        // *          placePositionOrder(positionOrderParams),
        // *        ])
        bytes32 positionId = _decodeBytes32(positionOrderCallData, 0);
        address accountOwner = _getSubAccountOwner(positionId);
        _verifyCaller(accountOwner);
        if (gas > 0) {
            IMux3OrderBook(_mux3OrderBook).wrapNative{ value: gas }(gas);
            IMux3OrderBook(_mux3OrderBook).depositGas(accountOwner, gas);
        }
        if (collateralAmount > 0) {
            if (
                collateralToken == address(0x0) ||
                collateralToken == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
            ) {
                IMux3OrderBook(_mux3OrderBook).wrapNative{ value: collateralAmount }(collateralAmount);
            } else {
                IMux3OrderBook(_mux3OrderBook).transferTokenFrom(accountOwner, collateralToken, collateralAmount);
            }
        }
        if (initialLeverage > 0) {
            bytes32 marketId = _decodeBytes32(positionOrderCallData, 1);
            IMux3OrderBook(_mux3OrderBook).setInitialLeverage(positionId, marketId, initialLeverage);
        }
        _mux3OrderBook.functionCall(
            abi.encodePacked(IMux3OrderBook.placePositionOrder.selector, positionOrderCallData)
        );
    }

    function mux3CancelOrder(uint64 orderId) external payable {
        (Mux3OrderData memory orderData, bool exists) = IMux3OrderBook(_mux3OrderBook).getOrder(orderId);
        require(exists, "No such orderId");
        address orderOwner = orderData.account;
        _verifyCaller(orderOwner);
        IMux3OrderBook(_mux3OrderBook).cancelOrder(orderId);
    }

    function proxyFunctionCall(ProxyCallParams calldata params) external payable {
        proxyFunctionCall2(msg.sender, params);
    }

    function proxyFunctionCall2(address account, ProxyCallParams calldata params) public payable {
        _verifyCaller(account);
        address proxy = _mustGetProxy(
            params.projectId,
            account,
            params.collateralToken,
            params.assetToken,
            params.isLong
        );
        if (params.referralCode != bytes32(0) && _referralManager != address(0)) {
            IReferralManager(_referralManager).setReferrerCodeFor(proxy, params.referralCode);
        }
        proxy.functionCallWithValue(params.proxyCallData, params.value);
    }

    // =========================================================================
    function multicall(bytes[] calldata proxyCalls) external payable returns (bytes[] memory results) {
        results = new bytes[](proxyCalls.length);
        for (uint256 i = 0; i < proxyCalls.length; i++) {
            (bool success, bytes memory returnData) = address(this).delegatecall(proxyCalls[i]);
            AddressUpgradeable.verifyCallResult(success, returnData, "multicallFailed");
            results[i] = returnData;
        }
    }

    function transferToken(
        uint256 projectId,
        address collateralToken,
        address assetToken,
        bool isLong,
        address token,
        uint256 amount
    ) external payable {
        transferToken2(projectId, msg.sender, collateralToken, assetToken, isLong, token, amount);
    }

    function transferToken2(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong,
        address token,
        uint256 amount
    ) public payable {
        _verifyCaller(account);
        address proxy = _mustGetProxy(projectId, account, collateralToken, assetToken, isLong);
        IERC20Upgradeable(token).safeTransferFrom(account, proxy, amount);
    }

    function wrapAndTransferNative(
        uint256 projectId,
        address collateralToken,
        address assetToken,
        bool isLong,
        uint256 amount
    ) external payable {
        wrapAndTransferNative2(projectId, msg.sender, collateralToken, assetToken, isLong, amount);
    }

    function wrapAndTransferNative2(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong,
        uint256 amount
    ) public payable {
        _verifyCaller(account);
        require(msg.value >= amount, "InsufficientValue");
        address proxy = _mustGetProxy(projectId, account, collateralToken, assetToken, isLong);
        IWETH(_weth).deposit{ value: amount }();
        IERC20Upgradeable(_weth).safeTransfer(proxy, amount);
    }

    function _verifyCaller(address account) internal view {
        address caller = msg.sender;
        require(caller == account || _delegators[caller], "AccountNotMatch");
    }

    function _createProxy(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) internal returns (address) {
        uint8 collateralId = getAssetId(projectId, collateralToken);
        _verifyAssetId(collateralToken, collateralId);
        return
            _createBeaconProxy(projectId, _liquidityPool, account, assetToken, collateralToken, collateralId, isLong);
    }

    function _mustGetProxy(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) internal returns (address proxy) {
        bytes32 proxyId = _makeProxyId(projectId, account, collateralToken, assetToken, isLong);
        proxy = _tradingProxies[proxyId];
        if (proxy == address(0)) {
            proxy = _createProxy(projectId, account, collateralToken, assetToken, isLong);
        }
    }

    function _verifyAssetId(address assetToken, uint8 assetId) internal view {
        if (assetId == VIRTUAL_ASSET_ID) {
            return;
        }
        address token = ILiquidityPool(_liquidityPool).getAssetAddress(assetId);
        require(assetToken == token, "BadAssetId");
    }

    function _decodeSubAccountId(bytes memory muxCallData) internal pure returns (bytes32 subAccountId) {
        require(muxCallData.length >= 36, "BadMuxCallData");
        assembly {
            subAccountId := mload(add(muxCallData, 0x24))
        }
    }

    function _getSubAccountOwner(bytes32 subAccountId) internal pure returns (address account) {
        account = address(uint160(uint256(subAccountId) >> 96));
    }

    function _decodeBytes32(bytes memory callData, uint256 index) internal pure returns (bytes32 data) {
        require(callData.length >= 32 * (index + 1), "BadCallData");
        uint256 offset = 0x20 + index * 32;
        assembly {
            data := mload(add(callData, offset))
        }
    }

    function _decodeFunctionSig(bytes memory muxCallData) internal pure returns (bytes4 sig) {
        require(muxCallData.length >= 0x20, "BadMuxCallData");
        bytes32 data;
        assembly {
            data := mload(add(muxCallData, 0x20))
        }
        sig = bytes4(data);
    }
}
