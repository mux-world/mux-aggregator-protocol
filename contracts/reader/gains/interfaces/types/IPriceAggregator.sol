// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import "./ITradingStorage.sol";
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
        mapping(address => mapping(uint32 => OrderAnswer[])) orderAnswers;
        // Chainlink Client (slots 9, 10, 11)
        LinkTokenInterface linkErc677;
        uint8 limitJobCount; // max value 255
        uint88 limitJobIndex; // max value 3e26 runs
        uint256 requestCount;
        mapping(bytes32 => address) pendingRequests;
        uint256[39] __gap;
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
        uint64 open;
        uint64 high;
        uint64 low;
        uint64 ts;
    }

    struct LiquidityPoolInput {
        ILiquidityPool pool;
        PoolType poolType;
    }

    enum PoolType {
        UNISWAP_V3,
        ALGEBRA_v1_9,
        CONSTANT_VALUE
    }
}
