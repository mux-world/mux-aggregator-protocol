// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IUpdateLeverage.sol";
import "../types/ITradingStorage.sol";
import "../types/ITradingCallbacks.sol";

/**
 * @dev Interface for leverage updates
 */
interface IUpdateLeverageUtils is IUpdateLeverage {
    /**
     * @param orderId request order id
     * @param trader address of trader
     * @param pairIndex index of pair
     * @param index index of trade
     * @param isIncrease true if increase leverage, false if decrease
     * @param newLeverage new leverage value (1e3)
     */
    event LeverageUpdateInitiated(
        ITradingStorage.Id orderId,
        address indexed trader,
        uint256 indexed pairIndex,
        uint256 indexed index,
        bool isIncrease,
        uint256 newLeverage
    );

    /**
     * @param orderId request order id
     * @param isIncrease true if leverage increased, false if decreased
     * @param cancelReason cancel reason (executed if none)
     * @param collateralIndex collateral index
     * @param trader address of trader
     * @param pairIndex index of pair
     * @param index index of trade
     * @param oraclePrice current oracle price (1e10)
     * @param collateralDelta collateral delta (collateral precision)
     * @param values useful values (new collateral, new leverage, liq price, gov fee collateral)
     */
    event LeverageUpdateExecuted(
        ITradingStorage.Id orderId,
        bool isIncrease,
        ITradingCallbacks.CancelReason cancelReason,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint256 pairIndex,
        uint256 indexed index,
        uint256 oraclePrice,
        uint256 collateralDelta,
        IUpdateLeverage.UpdateLeverageValues values
    );
}
