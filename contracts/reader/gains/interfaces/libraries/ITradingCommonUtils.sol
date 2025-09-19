// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/ITradingStorage.sol";

/**
 * @dev Interface for TradingCommonUtils library
 */
interface ITradingCommonUtils {
    struct TradePriceImpactInput {
        ITradingStorage.Trade trade;
        uint256 oraclePrice;
        uint256 spreadP;
        uint256 positionSizeCollateral;
    }

    /**
     * @dev Emitted when gov fee is charged
     * @param trader address of the trader
     * @param collateralIndex index of the collateral
     * @param amountCollateral amount charged (collateral precision)
     */
    event GovFeeCharged(address indexed trader, uint8 indexed collateralIndex, uint256 amountCollateral);

    /**
     * @dev Emitted when referral fee is charged
     * @param trader address of the trader
     * @param collateralIndex index of the collateral
     * @param amountCollateral amount charged (collateral precision)
     */
    event ReferralFeeCharged(address indexed trader, uint8 indexed collateralIndex, uint256 amountCollateral);

    /**
     * @dev Emitted when GNS otc fee is charged
     * @param trader address of the trader
     * @param collateralIndex index of the collateral
     * @param amountCollateral amount charged (collateral precision)
     */
    event GnsOtcFeeCharged(address indexed trader, uint8 indexed collateralIndex, uint256 amountCollateral);

    /**
     * @dev Emitted when trigger fee is charged
     * @param trader address of the trader
     * @param collateralIndex index of the collateral
     * @param amountCollateral amount charged (collateral precision)
     */
    event TriggerFeeCharged(address indexed trader, uint8 indexed collateralIndex, uint256 amountCollateral);

    /**
     * @dev Emitted when gToken fee is charged
     * @param trader address of the trader
     * @param collateralIndex index of the collateral
     * @param amountCollateral amount charged (collateral precision)
     */
    event GTokenFeeCharged(address indexed trader, uint8 indexed collateralIndex, uint256 amountCollateral);
}
