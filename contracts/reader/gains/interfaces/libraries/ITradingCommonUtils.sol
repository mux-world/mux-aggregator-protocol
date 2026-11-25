// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/ITradingStorage.sol";

/**
 * @dev Interface for TradingCommonUtils library
 */
interface ITradingCommonUtils {
    struct TradePriceImpactInput {
        ITradingStorage.Trade trade;
        uint256 oraclePrice; // 1e10
        uint256 positionSizeCollateral; // collateral precision
        uint64 currentPairPrice; // 1e10
        bool useCumulativeVolPriceImpact;
    }

    struct TradePriceImpact {
        uint256 positionSizeToken; // 1e18
        int256 fixedSpreadP; // 1e10 (%)
        int256 cumulVolPriceImpactP; // 1e10 (%)
        int256 skewPriceImpactP; // 1e10 (%)
        int256 totalPriceImpactP; // 1e10 (%)
        uint64 priceAfterImpact; // 1e10
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

    /**
     * @dev Emitted when a trade's fees are processed
     * @param collateralIndex index of the collateral
     * @param trader address of the trader
     * @param positionSizeCollateral position size (collateral precision)
     * @param orderType type of the order
     * @param totalFeesCollateral amount of fees charged (collateral precision)
     */
    event FeesProcessed(
        uint8 indexed collateralIndex,
        address indexed trader,
        uint256 positionSizeCollateral,
        ITradingStorage.PendingOrderType orderType,
        uint256 totalFeesCollateral
    );

    /**
     * @dev Emitted when a trade's value is transferred
     * @param collateralIndex index of the collateral
     * @param trader address of the trader
     * @param index index of the trade
     * @param collateralSentToTrader amount of collateral sent to the trader (collateral precision)
     * @param availableCollateralInDiamond amount of available collateral in the diamond (collateral precision)
     */
    event TradeValueTransferred(
        uint8 indexed collateralIndex,
        address indexed trader,
        uint32 indexed index,
        int256 collateralSentToTrader,
        int256 availableCollateralInDiamond
    );
}
