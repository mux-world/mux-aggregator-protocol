// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./IPairsStorage.sol";

/**
 * @dev Contains the types for the GNSTradingStorage facet
 */
interface ITradingStorage {
    struct TradingStorage {
        TradingActivated tradingActivated; // 8 bits
        uint8 lastCollateralIndex; // 8 bits
        uint8 gnsCollateralIndex; // 8 bits
        uint232 __placeholder; // 232 bits
        mapping(uint8 => Collateral) collaterals;
        mapping(uint8 => address) gTokens;
        mapping(address => uint8) collateralIndex;
        mapping(address => mapping(uint32 => Trade)) trades;
        mapping(address => mapping(uint32 => TradeInfo)) tradeInfos;
        mapping(address => mapping(uint32 => mapping(PendingOrderType => uint256))) tradePendingOrderBlock;
        mapping(address => mapping(uint32 => PendingOrder)) pendingOrders;
        mapping(address => mapping(CounterType => Counter)) userCounters;
        address[] traders;
        mapping(address => bool) traderStored;
        mapping(address => mapping(uint32 => IPairsStorage.GroupLiquidationParams)) tradeLiquidationParams;
        uint256[38] __gap;
    }

    enum PendingOrderType {
        MARKET_OPEN,
        MARKET_CLOSE,
        LIMIT_OPEN,
        STOP_OPEN,
        TP_CLOSE,
        SL_CLOSE,
        LIQ_CLOSE,
        UPDATE_LEVERAGE,
        MARKET_PARTIAL_OPEN,
        MARKET_PARTIAL_CLOSE,
        PARAM_UPDATE, // deprecated
        PNL_WITHDRAWAL,
        MANUAL_HOLDING_FEES_REALIZATION,
        MANUAL_NEGATIVE_PNL_REALIZATION
    }

    enum CounterType {
        TRADE,
        PENDING_ORDER
    }

    enum TradeType {
        TRADE,
        LIMIT,
        STOP
    }

    enum TradingActivated {
        ACTIVATED,
        CLOSE_ONLY,
        PAUSED
    }

    enum ContractsVersion {
        BEFORE_V9_2,
        V9_2,
        V10
    }

    struct Collateral {
        // slot 1
        address collateral; // 160 bits
        bool isActive; // 8 bits
        uint88 __placeholder; // 88 bits
        // slot 2
        uint128 precision;
        uint128 precisionDelta;
    }

    struct Id {
        address user; // 160 bits
        uint32 index; // max: 4,294,967,295
    }

    struct Trade {
        // slot 1
        address user; // 160 bits
        uint32 index; // max: 4,294,967,295
        uint16 pairIndex; // max: 65,535
        uint24 leverage; // 1e3; max: 16,777.215
        bool long; // 8 bits
        bool isOpen; // 8 bits
        uint8 collateralIndex; // max: 255
        // slot 2
        TradeType tradeType; // 8 bits
        uint120 collateralAmount; // collateral precision; max: 3.402e+38
        uint64 openPrice; // 1e10; max: 1.8e19
        uint64 tp; // 1e10; max: 1.8e19
        // slot 3
        uint64 sl; // 1e10; max: 1.8e19
        bool isCounterTrade;
        /// @dev Warning this position size  in token amount is calculated using position size collateral / entry price, without taking into account skew price impact
        /// At the moment it is only used to calculate skew price impact, once we refactor formulas to use it for pnl for example we'll need to re-calculate it based on real entry price
        /// And once we refactor to USD position sizes we'll have to convert it from collateral to USD
        uint160 positionSizeToken; // 1e18, assuming 1e-9 collateral price, 1e-9 pair price => max value is 1.46 trillion USD (1e12)
        uint24 __placeholder;
    }

    struct TradeInfo {
        uint32 createdBlock; // for lookbacks
        uint32 tpLastUpdatedBlock; // for lookbacks
        uint32 slLastUpdatedBlock; // for lookbacks
        uint16 maxSlippageP; // 1e3 (%)
        uint48 lastOiUpdateTs; // deprecated
        uint48 collateralPriceUsd; // 1e8 collateral price at trade open
        ContractsVersion contractsVersion;
        uint32 lastPosIncreaseBlock; // for protection close factor
        uint8 __placeholder;
    }

    struct PendingOrder {
        // slots 1-3
        Trade trade;
        // slot 4
        address user; // 160 bits
        uint32 index; // max: 4,294,967,295
        bool isOpen; // 8 bits
        PendingOrderType orderType; // 8 bits
        uint32 createdBlock; // max: 4,294,967,295
        uint16 maxSlippageP; // 1e3 (%), max: 65.535%
    }

    struct Counter {
        uint32 currentIndex;
        uint32 openCount;
        uint192 __placeholder;
    }

    struct UpdateTradePositionValues {
        uint32 blockNumber;
        uint64 newSl;
        uint160 newPositionSizeToken;
    }
}
