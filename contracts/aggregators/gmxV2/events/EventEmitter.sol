// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../../../interfaces/IProxyFactory.sol";
import "../interfaces/IEventEmitter.sol";

contract EventEmitter is Initializable, IEventEmitter {
    address public proxyFactory;

    modifier onlyProxy() {
        require(IProxyFactory(proxyFactory).getProxyProjectId(msg.sender) == PROJECT_ID, "OnlyProxy");
        _;
    }

    function initialize(address proxyFactory_) external initializer {
        proxyFactory = proxyFactory_;
    }

    function onPlacePositionOrder(
        address proxyOwner,
        IGmxV2Adatper.OrderCreateParams calldata createParams,
        IGmxV2Adatper.PositionResult calldata result
    ) external {
        emit PlacePositionOrder(
            msg.sender, // proxy
            proxyOwner,
            createParams,
            result
        );
    }

    function onPlaceLiquidateOrder(address proxyOwner, IGmxV2Adatper.PositionResult calldata result) external {
        emit PlaceLiquidateOrder(
            msg.sender, // proxy
            proxyOwner,
            result
        );
    }

    function onBorrowCollateral(address proxyOwner, IGmxV2Adatper.DebtResult calldata result) external {
        emit BorrowCollateral(
            msg.sender, // proxy
            proxyOwner,
            result
        );
    }

    function onRepayCollateral(address proxyOwner, IGmxV2Adatper.DebtResult calldata result) external {
        emit RepayCollateral(
            msg.sender, // proxy
            proxyOwner,
            result
        );
    }

    function onUpdateOrder(
        address proxyOwner,
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice
    ) external {
        emit UpdateOrder(
            msg.sender, // proxy
            proxyOwner,
            key,
            sizeDeltaUsd,
            acceptablePrice,
            triggerPrice
        );
    }

    function onCancelOrder(address proxyOwner, bytes32 key) external {
        emit CancelOrder(
            msg.sender, // proxy
            proxyOwner,
            key
        );
    }

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
    ) external {
        emit UpdateDebt(
            msg.sender, // proxy
            proxyOwner,
            key,
            oldDebtCollateralAmount,
            oldInflightDebtCollateralAmount,
            oldPendingFeeCollateralAmount,
            oldDebtEntryFunding,
            newDebtCollateralAmount,
            newInflightDebtCollateralAmount,
            newPendingFeeCollateralAmount,
            newDebtEntryFunding
        );
    }
}
