// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 *
 * @dev Interface for leverage updates types
 */
interface IUpdateLeverage {
    /// @dev Update leverage input values
    struct UpdateLeverageInput {
        address user;
        uint32 index;
        uint24 newLeverage; // 1e3
    }

    /// @dev Useful values for increase leverage callback
    struct UpdateLeverageValues {
        uint256 newLeverage; // 1e3
        uint256 newCollateralAmount; // collateral precision
        uint256 existingLiqPrice; // 1e10
        uint256 newLiqPrice; // 1e10
        uint256 govFeeCollateral; // collateral precision
        uint256 newEffectiveLeverage; // 1e3
        uint256 totalTradeAvailableCollateralInDiamond; // collateral precision
        uint256 availableCollateralInDiamond; // collateral precision
    }
}
