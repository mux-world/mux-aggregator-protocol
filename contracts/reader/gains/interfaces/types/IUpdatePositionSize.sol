// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../libraries/ITradingCommonUtils.sol";

/**
 *
 * @dev Interface for position size updates types
 */
interface IUpdatePositionSize {
    /// @dev Request decrease position input values
    struct DecreasePositionSizeInput {
        address user;
        uint32 index;
        uint120 collateralDelta; // collateral precision
        uint24 leverageDelta; // 1e3
        uint64 expectedPrice; // 1e10
    }

    /// @dev Request increase position input values
    struct IncreasePositionSizeInput {
        address user;
        uint32 index;
        uint120 collateralDelta; // collateral precision
        uint24 leverageDelta; // 1e3
        uint64 expectedPrice; // 1e10
        uint16 maxSlippageP; // 1e3 (%)
    }

    /// @dev Useful values for decrease position size callback
    struct DecreasePositionSizeValues {
        bool isLeverageUpdate;
        uint256 positionSizeCollateralDelta; // collateral precision
        uint256 existingPositionSizeCollateral; // collateral precision
        uint256 existingLiqPrice; // 1e10
        uint256 newLiqPrice; // 1e10
        ITradingCommonUtils.TradePriceImpact priceImpact;
        int256 existingPnlPercent; // 1e10 (%)
        int256 partialRawPnlCollateral; // collateral precision
        int256 partialNetPnlCollateral; // collateral precision
        int256 pnlToRealizeCollateral; // collateral precision
        uint256 closingFeeCollateral; // collateral precision
        uint256 totalAvailableCollateralInDiamond; // collateral precision
        int256 availableCollateralInDiamond; // collateral precision
        int256 collateralSentToTrader; // collateral precision
        uint120 newCollateralAmount; // collateral precision
        uint24 newLeverage; // 1e3
    }

    /// @dev Useful values for increase position size callback
    struct IncreasePositionSizeValues {
        uint256 positionSizeCollateralDelta; // collateral precision
        uint256 existingPositionSizeCollateral; // collateral precision
        uint256 newPositionSizeCollateral; // collateral precision
        uint256 newCollateralAmount; // collateral precision
        uint256 newLeverage; // 1e3
        ITradingCommonUtils.TradePriceImpact priceImpact;
        int256 existingPnlCollateral; // collateral precision
        uint256 oldPosSizePlusPnlCollateral; // collateral precision
        uint256 newOpenPrice; // 1e10
        uint256 openingFeesCollateral; // collateral precision
        uint256 existingLiqPrice; // 1e10
        uint256 newLiqPrice; // 1e10
        bool isCounterTradeValidated;
        uint256 exceedingPositionSizeCollateral; // collateral precision
        uint256 counterTradeCollateralToReturn; // collateral precision
        uint256 newEffectiveLeverage; // 1e3
    }
}
