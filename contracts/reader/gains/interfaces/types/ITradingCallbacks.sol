// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/ITradingStorage.sol";
import "../libraries/ITradingCommonUtils.sol";

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
        WRONG_TRADE,
        NOT_HIT,
        LIQ_REACHED,
        COUNTER_TRADE_CANCELED
    }

    struct AggregatorAnswer {
        ITradingStorage.Id orderId;
        uint64 open;
        uint64 high;
        uint64 low;
        uint64 current;
    }

    // Useful to avoid stack too deep errors
    struct Values {
        int256 profitP;
        uint256 executionPrice;
        uint256 executionPriceRaw;
        uint256 liqPrice;
        uint256 amountSentToTrader;
        uint256 collateralPriceUsd;
        bool exactExecution;
        uint32 limitIndex;
        ITradingCommonUtils.TradePriceImpact priceImpact;
        CancelReason cancelReason;
        uint256 collateralToReturn;
        uint120 newCollateralAmount;
        uint256 newEffectiveLeverage;
        uint256 pnlWithdrawnCollateral;
        uint256 openingFeeCollateral;
    }

    struct PnlWithdrawalValues {
        ITradingStorage.Trade trade;
        uint64 currentPairPrice;
        uint256 positionSizeCollateral;
        ITradingCommonUtils.TradePriceImpact priceImpact;
        int256 pnlPercent;
        int256 withdrawablePositivePnlCollateral;
        uint256 pnlInputCollateral;
        uint256 pnlWithdrawnCollateral;
        uint256 withdrawablePositivePnlCollateralUint;
        uint256 finalGovFeeCollateral;
    }
}
