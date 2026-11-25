// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./ITradingStorage.sol";
import "./ITradingCallbacks.sol";
import "../IChainlinkFeed.sol";
import "../ILiquidityPool.sol";

/**
 * @dev Contains the types for the GNSPriceAggregator facet
 */
interface IPriceAggregator {
    struct PriceAggregatorStorage {
        IChainlinkFeed linkUsdPriceFeed;
        uint24 twapInterval; // seconds
        uint8 minAnswers;
        uint24 maxMarketDeviationP; // 1e3 %
        uint24 maxLookbackDeviationP; // 1e3 %
        uint16 __placeholder;
        bytes32[2] jobIds;
        address[] oracles;
        mapping(uint8 => LiquidityPoolInfo) collateralGnsLiquidityPools;
        mapping(uint8 => IChainlinkFeed) collateralUsdPriceFeed;
        mapping(bytes32 => Order) orders;
        mapping(address => mapping(uint32 => uint256[])) orderAnswersLegacy; /// @custom:deprecated
        // Chainlink Client state start
        LinkTokenInterface linkErc677;
        uint8 limitJobCount; // max value 255
        uint88 limitJobIndex; // max value 3e26 runs
        uint256 requestCount;
        mapping(bytes32 => address) pendingRequests;
        // Chainlink Client state end
        bytes32 paramUpdateJobId; /// @custom:deprecated
        mapping(address => mapping(uint32 => OrderAnswer[])) orderAnswers;
        mapping(uint16 => OrderAnswer[]) signedOrderAnswersTemporary;
        mapping(uint16 => ITradingCallbacks.AggregatorAnswer) signedMediansTemporary;
        uint16[] signedPairIndicesTemporary;
        uint256[34] __gap;
    }

    struct LiquidityPoolInfo {
        ILiquidityPool pool;
        bool isGnsToken0InLp;
        PoolType poolType;
        uint80 __placeholder;
    }

    struct Order {
        address user;
        uint32 index;
        ITradingStorage.PendingOrderType orderType;
        uint16 pairIndex;
        bool isLookback;
        uint32 __placeholder;
    }

    struct OrderAnswer {
        /// @custom:dev max price = type(uint56.max) / 1e10 = 7,205,759
        uint56 open;
        uint56 high;
        uint56 low;
        uint56 current;
        uint32 ts;
    }

    struct LiquidityPoolInput {
        ILiquidityPool pool;
        PoolType poolType;
    }

    struct GetPriceInput {
        uint8 collateralIndex;
        uint16 pairIndex;
        ITradingStorage.PendingOrder pendingOrder;
        uint256 positionSizeCollateral; // collateral precision
        uint256 fromBlock;
        bool isCounterTrade;
    }

    struct SignedPairPrices {
        uint8 signerId; // index in oracles array of price aggregator facet
        uint32 expiryTs;
        bool isLookback;
        uint32 fromBlock;
        bytes signature;
        uint16[] pairIndices;
        OrderAnswer[] prices;
    }

    enum PoolType {
        UNISWAP_V3,
        ALGEBRA_v1_9,
        CONSTANT_VALUE
    }
}
