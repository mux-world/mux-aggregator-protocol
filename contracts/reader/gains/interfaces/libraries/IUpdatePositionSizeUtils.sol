// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IUpdatePositionSize.sol";
import "../types/ITradingStorage.sol";
import "../types/ITradingCallbacks.sol";

/**
 * @dev Interface for position size updates
 */
interface IUpdatePositionSizeUtils is IUpdatePositionSize {
    /**
     * @param orderId request order id
     * @param trader address of the trader
     * @param pairIndex index of the pair
     * @param index index of user trades
     * @param isIncrease true if increase position size, false if decrease
     * @param collateralDelta collateral delta (collateral precision)
     * @param leverageDelta leverage delta (1e3)
     */
    event PositionSizeUpdateInitiated(
        ITradingStorage.Id orderId,
        address indexed trader,
        uint256 indexed pairIndex,
        uint256 indexed index,
        bool isIncrease,
        uint256 collateralDelta,
        uint256 leverageDelta
    );

    /**
     * @param orderId request order id
     * @param cancelReason cancel reason if canceled or none if executed
     * @param collateralIndex collateral index
     * @param trader address of trader
     * @param pairIndex index of pair
     * @param index index of trade
     * @param long true for long, false for short
     * @param oraclePrice oracle price (1e10)
     * @param collateralPriceUsd collateral price in USD (1e8)
     * @param collateralDelta collateral delta (collateral precision)
     * @param leverageDelta leverage delta (1e3)
     * @param values important values (new open price, new leverage, new collateral, etc.)
     */
    event PositionSizeIncreaseExecuted(
        ITradingStorage.Id orderId,
        ITradingCallbacks.CancelReason cancelReason,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint256 pairIndex,
        uint256 indexed index,
        bool long,
        uint256 oraclePrice,
        uint256 collateralPriceUsd,
        uint256 collateralDelta,
        uint256 leverageDelta,
        IUpdatePositionSize.IncreasePositionSizeValues values
    );

    /**
     * @param orderId request order id
     * @param cancelReason cancel reason if canceled or none if executed
     * @param collateralIndex collateral index
     * @param trader address of trader
     * @param pairIndex index of pair
     * @param index index of trade
     * @param long true for long, false for short
     * @param oraclePrice oracle price (1e10)
     * @param collateralPriceUsd collateral price in USD (1e8)
     * @param collateralDelta collateral delta (collateral precision)
     * @param leverageDelta leverage delta (1e3)
     * @param values important values (pnl, new leverage, new collateral, etc.)
     */
    event PositionSizeDecreaseExecuted(
        ITradingStorage.Id orderId,
        ITradingCallbacks.CancelReason cancelReason,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint256 pairIndex,
        uint256 indexed index,
        bool long,
        uint256 oraclePrice,
        uint256 collateralPriceUsd,
        uint256 collateralDelta,
        uint256 leverageDelta,
        IUpdatePositionSize.DecreasePositionSizeValues values
    );

    error InvalidIncreasePositionSizeInput();
    error InvalidDecreasePositionSizeInput();
    error NewPositionSizeSmaller();
}
