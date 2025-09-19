// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/ITradingStorage.sol";

/**
 * @dev Contains the types for the GNSTradingCallbacks facet
 */
interface ITradingCallbacks {
    struct TradingCallbacksStorage {
        uint8 vaultClosingFeeP;
        uint248 __placeholder;
        mapping(uint8 => uint256) pendingGovFees; // collateralIndex => pending gov fee (collateral)
        uint256[48] __gap;
    }

    enum CancelReason {
        NONE,
        PAUSED, // deprecated
        MARKET_CLOSED, // deprecated
        SLIPPAGE,
        TP_REACHED,
        SL_REACHED,
        EXPOSURE_LIMITS,
        PRICE_IMPACT,
        MAX_LEVERAGE,
        NO_TRADE,
        WRONG_TRADE, // deprecated
        NOT_HIT,
        LIQ_REACHED
    }

    struct AggregatorAnswer {
        ITradingStorage.Id orderId;
        uint256 spreadP;
        uint64 price;
        uint64 open;
        uint64 high;
        uint64 low;
    }

    // Useful to avoid stack too deep errors
    struct Values {
        int256 profitP;
        uint256 executionPrice;
        uint256 liqPrice;
        uint256 amountSentToTrader;
        uint256 collateralPriceUsd;
        bool exactExecution;
        uint256 collateralLeftInStorage;
        uint256 oraclePrice;
        uint32 limitIndex;
        uint256 priceImpactP;
    }
}
