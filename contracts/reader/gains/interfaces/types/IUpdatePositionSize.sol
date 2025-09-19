// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 *
 * @dev Interface for position size updates types
 */
interface IUpdatePositionSize {
    /// @dev Request decrease position input values
    struct DecreasePositionSizeInput {
        address user;
        uint32 index;
        uint120 collateralDelta;
        uint24 leverageDelta;
        uint64 expectedPrice;
    }

    /// @dev Request increase position input values
    struct IncreasePositionSizeInput {
        address user;
        uint32 index;
        uint120 collateralDelta;
        uint24 leverageDelta;
        uint64 expectedPrice;
        uint16 maxSlippageP;
    }

    /// @dev Useful values for decrease position size callback
    struct DecreasePositionSizeValues {
        uint256 positionSizeCollateralDelta;
        uint256 existingPositionSizeCollateral;
        uint256 existingLiqPrice;
        uint256 priceAfterImpact;
        int256 existingPnlCollateral;
        uint256 borrowingFeeCollateral;
        uint256 closingFeeCollateral;
        int256 availableCollateralInDiamond;
        int256 collateralSentToTrader;
        uint120 newCollateralAmount;
        uint24 newLeverage;
    }

    /// @dev Useful values for increase position size callback
    struct IncreasePositionSizeValues {
        uint256 positionSizeCollateralDelta;
        uint256 existingPositionSizeCollateral;
        uint256 newPositionSizeCollateral;
        uint256 newCollateralAmount;
        uint256 newLeverage;
        uint256 priceAfterImpact;
        int256 existingPnlCollateral;
        uint256 oldPosSizePlusPnlCollateral;
        uint256 newOpenPrice;
        uint256 borrowingFeeCollateral;
        uint256 openingFeesCollateral;
        uint256 existingLiqPrice;
        uint256 newLiqPrice;
    }
}
