// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../aggregators/gmxV2/GmxV2Adapter.sol";

import "../aggregators/gmxV2/libraries/LibUtils.sol";

contract TestGmxV2Adapter is GmxV2Adapter {
    using LibUtils for GmxAdapterStoreV2;

    function debugSetDebtStates(
        uint256 debtCollateralAmount, // collateral decimals
        uint256 inflightDebtCollateralAmount, // collateral decimals
        uint256 pendingFeeCollateralAmount, // collateral decimals
        uint256 entryFunding
    ) external {
        _store.account.debtCollateralAmount = debtCollateralAmount;
        _store.account.inflightDebtCollateralAmount = inflightDebtCollateralAmount;
        _store.account.pendingFeeCollateralAmount = pendingFeeCollateralAmount;
        _store.account.debtEntryFunding = entryFunding;
    }

    function makeTestOrder(
        bytes32 key,
        uint256 collateralAmount,
        uint256 debtCollateralAmount,
        bool isIncreasing
    ) external {
        _store.appendOrder(key, collateralAmount, debtCollateralAmount, isIncreasing);
    }

    function makeEmptyOrderParams()
        external
        pure
        returns (IOrder.Props memory order, IEvent.EventLogData memory events)
    {}
}
