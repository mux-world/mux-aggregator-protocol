// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IGmxV2Adatper.sol";

interface IEventEmitter {
    event PlacePositionOrder(
        address indexed proxy,
        address indexed proxyOwner,
        IGmxV2Adatper.OrderCreateParams createParams,
        IGmxV2Adatper.PositionResult result
    );
    event PlaceLiquidateOrder(address indexed proxy, address indexed proxyOwner, IGmxV2Adatper.PositionResult result);
    event BorrowCollateral(address indexed proxy, address indexed proxyOwner, IGmxV2Adatper.DebtResult result);
    event RepayCollateral(address indexed proxy, address indexed proxyOwner, IGmxV2Adatper.DebtResult result);
    event UpdateOrder(
        address indexed proxy,
        address indexed proxyOwner,
        bytes32 indexed key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice
    );
    event CancelOrder(address indexed proxy, address indexed proxyOwner, bytes32 key);
    event UpdateDebt(
        address indexed proxy,
        address indexed proxyOwner,
        bytes32 indexed key,
        uint256 oldDebtCollateralAmount,
        uint256 oldInflightDebtCollateralAmount,
        uint256 oldPendingFeeCollateralAmount,
        uint256 oldDebtEntryFunding,
        uint256 newDebtCollateralAmount,
        uint256 newInflightDebtCollateralAmount,
        uint256 newPendingFeeCollateralAmount,
        uint256 newDebtEntryFunding
    );

    function onPlacePositionOrder(
        address proxyOwner,
        IGmxV2Adatper.OrderCreateParams calldata createParams,
        IGmxV2Adatper.PositionResult calldata result
    ) external;

    function onPlaceLiquidateOrder(address proxyOwner, IGmxV2Adatper.PositionResult calldata result) external;

    function onBorrowCollateral(address proxyOwner, IGmxV2Adatper.DebtResult calldata result) external;

    function onRepayCollateral(address proxyOwner, IGmxV2Adatper.DebtResult calldata result) external;

    function onUpdateOrder(
        address proxyOwner,
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice
    ) external;

    function onCancelOrder(address proxyOwner, bytes32 key) external;

    function onUpdateDebt(
        address proxyOwner,
        bytes32 key,
        uint256 oldDebtCollateralAmount, // collateral decimals
        uint256 oldInflightDebtCollateralAmount, // collateral decimals
        uint256 oldPendingFeeCollateralAmount, // collateral decimals
        uint256 oldDebtEntryFunding,
        uint256 newDebtCollateralAmount, // collateral decimals
        uint256 newInflightDebtCollateralAmount, // collateral decimals
        uint256 newPendingFeeCollateralAmount, // collateral decimals
        uint256 newDebtEntryFunding
    ) external;
}
