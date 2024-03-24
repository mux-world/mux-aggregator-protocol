// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../../interfaces/IPriceHub.sol";

import "./libraries/LibGmxV2.sol";
import "./libraries/LibUtils.sol";
import "./Storage.sol";

abstract contract Getter is Storage {
    using LibUtils for IGmxV2Adatper.GmxAdapterStoreV2;
    using LibGmxV2 for IGmxV2Adatper.GmxAdapterStoreV2;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    function positionKey() external view returns (bytes32) {
        return _store.positionKey;
    }

    function muxAccountState() external view returns (AccountState memory) {
        return _store.account;
    }

    function getPendingOrders() external view returns (PendingOrder[] memory pendingOrders) {
        uint256 count = _store.pendingOrderIndexes.length();
        if (count == 0) {
            return pendingOrders;
        }
        pendingOrders = new PendingOrder[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = _store.pendingOrderIndexes.at(i);
            OrderRecord memory record = _store.pendingOrders[key];
            pendingOrders[i] = PendingOrder({
                key: key,
                debtCollateralAmount: record.debtCollateralAmount,
                timestamp: record.timestamp,
                blockNumber: record.blockNumber,
                isIncreasing: record.isIncreasing
            });
        }
    }

    // 1e18
    function getMarginRate(Prices memory prices) external view returns (uint256) {
        return _store.getMarginRate(prices); // 1e18
    }

    function isLiquidateable(Prices memory prices) external view returns (bool) {
        uint256 sizeInUsd = IReaderLite(_store.projectConfigs.reader).getPositionSizeInUsd(
            _store.projectConfigs.dataStore,
            _store.positionKey
        );
        if (sizeInUsd == 0) {
            return false;
        }
        return _store.getMarginRate(prices) < uint256(_store.marketConfigs.maintenanceMarginRate) * 1e13;
    }
}
