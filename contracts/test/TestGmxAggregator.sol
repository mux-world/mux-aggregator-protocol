// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../aggregators/gmx/GmxAdapter.sol";

import "../aggregators/gmx/libs/LibGmx.sol";

contract TestGmxAdapter is GmxAdapter {
    constructor(address weth) GmxAdapter(weth) {}

    function getMarginValue() external view returns (uint256 marginValue) {
        IGmxVault.Position memory position = _getGmxPosition();
        (marginValue, ) = _getMarginValue(
            position,
            0,
            LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong)
        );
    }

    function getMarginValue2() external view returns (uint256, bool) {
        IGmxVault.Position memory position = _getGmxPosition();
        return
            _getMarginValue(position, 0, LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong));
    }

    function getPrice(bool max) external view returns (uint256) {
        return LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, max);
    }

    function isImMarginSafe() external view returns (bool) {
        IGmxVault.Position memory position = _getGmxPosition();
        return
            _isMarginSafe(
                position,
                0,
                0,
                LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong),
                _assetConfigs.initialMarginRate
            );
    }

    function isMmMarginSafe() external view returns (bool) {
        IGmxVault.Position memory position = _getGmxPosition();
        return
            _isMarginSafe(
                position,
                0,
                0,
                LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong),
                _assetConfigs.maintenanceMarginRate
            );
    }

    function getGmxPosition() external view returns (IGmxVault.Position memory) {
        return IGmxVault(_projectConfigs.vault).positions(_gmxPositionKey);
    }

    function calcInflightBorrow() external view returns (uint256) {
        return _calcInflightBorrow();
    }

    function getGmxConfigs() external view returns (ProjectConfigs memory) {
        return _projectConfigs;
    }

    function getMuxConfigs() external view returns (TokenConfigs memory) {
        return _assetConfigs;
    }

    function updateConfigs() external {
        _updateConfigs();
    }

    function hasPendingOrder(bytes32 key) external view returns (bool) {
        return _hasPendingOrder(key);
    }

    function cancelOrder(bytes32 key) external returns (bool success) {
        return _cancelOrder(key);
    }

    function removePendingOrder(bytes32 key) external {
        _removePendingOrder(key);
    }

    function cleanOrders() external {
        _cleanOrders();
    }

    function decodeOrderHistory(bytes32 key) external pure returns (LibGmx.OrderHistory memory) {
        return LibGmx.decodeOrderHistoryKey(key);
    }

    function getGmxPositionKey(
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external pure returns (bytes32 a, bytes32 b) {
        return (
            keccak256(abi.encodePacked(account, collateralToken, assetToken, isLong)),
            keccak256(abi.encode(account, collateralToken, assetToken, isLong))
        );
    }

    function setDebtState(uint256 cumulativeDebt, uint256 cumulativeFee, uint256 debtEntryFunding) external {
        _account.cumulativeDebt = cumulativeDebt;
        _account.cumulativeFee = cumulativeFee;
        _account.debtEntryFunding = debtEntryFunding;
    }

    function getProjectConfigs() external view returns (ProjectConfigs memory) {
        return _projectConfigs;
    }

    function getTokenConfigs() external view returns (TokenConfigs memory) {
        return _assetConfigs;
    }

    function encodeTpslKey(bytes32 tpOrderKey, bytes32 slOrderKey) external view returns (bytes32) {
        return LibGmx.encodeTpslIndex(tpOrderKey, slOrderKey);
    }
}
