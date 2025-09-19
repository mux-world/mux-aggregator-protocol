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
        uint24 newLeverage;
    }

    /// @dev Useful values for increase leverage callback
    struct UpdateLeverageValues {
        uint256 newLeverage;
        uint256 newCollateralAmount;
        uint256 liqPrice;
        uint256 govFeeCollateral;
    }
}
