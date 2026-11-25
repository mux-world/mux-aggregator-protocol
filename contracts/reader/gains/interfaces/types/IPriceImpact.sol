// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSPriceImpact facet
 */
interface IPriceImpact {
    struct PriceImpactStorage {
        OiWindowsSettings oiWindowsSettings;
        mapping(uint48 => mapping(uint256 => mapping(uint256 => PairOi))) windows; // duration => pairIndex => windowId => Oi
        mapping(uint256 => PairDepth) pairDepths; // pairIndex => depth (USD)
        mapping(address => mapping(uint32 => TradePriceImpactInfo)) tradePriceImpactInfos; // deprecated
        mapping(uint256 => PairFactors) pairFactors;
        uint40 negPnlCumulVolMultiplier;
        uint216 __placeholder;
        mapping(address => bool) protectionCloseFactorWhitelist;
        mapping(address => mapping(uint256 => UserPriceImpact)) userPriceImpact; // address => pair => UserPriceImpact
        mapping(uint8 => mapping(uint16 => uint256)) pairSkewDepths; // collateral index => pairIndex => depth (tokens, 1e18)
        mapping(uint8 => mapping(uint16 => PairOiCollateral)) pairOiAfterV10Collateral; // collateral index => pairIndex => open interest (collateral precision)
        mapping(uint8 => mapping(uint16 => PairOiToken)) pairOiAfterV10Token; // collateral index => pairIndex => open interest (1e18)
        mapping(uint256 => PairDepthBands) pairDepthBands; // pairIndex => depth bands
        DepthBandsMapping depthBandsMapping; // global mapping from band indices to band percentage offsets
        uint256[36] __gap;
    }

    struct OiWindowsSettings {
        uint48 startTs;
        uint48 windowsDuration;
        uint48 windowsCount;
    }

    struct PairOi {
        uint128 oiLongUsd; // 1e18 USD
        uint128 oiShortUsd; // 1e18 USD
    }

    struct PairOiCollateral {
        uint128 oiLongCollateral; // collateral precision
        uint128 oiShortCollateral; // collateral precision
    }

    struct PairOiToken {
        uint128 oiLongToken; // 1e18
        uint128 oiShortToken; // 1e18
    }

    struct OiWindowUpdate {
        address trader;
        uint32 index;
        uint48 windowsDuration;
        uint256 pairIndex;
        uint256 windowId;
        bool long;
        bool open;
        bool isPnlPositive;
        uint128 openInterestUsd; // 1e18 USD
    }

    struct PairDepth {
        uint128 onePercentDepthAboveUsd; // USD
        uint128 onePercentDepthBelowUsd; // USD
    }

    struct PairFactors {
        uint40 protectionCloseFactor; // 1e10; max 109.95x
        uint32 protectionCloseFactorBlocks;
        uint40 cumulativeFactor; // 1e10; max 109.95x
        bool exemptOnOpen;
        bool exemptAfterProtectionCloseFactor;
        uint128 __placeholder;
    }

    struct UserPriceImpact {
        uint16 cumulVolPriceImpactMultiplier; // 1e3
        uint16 fixedSpreadP; // 1e3 %
        uint224 __placeholder;
    }

    struct PriceImpactValues {
        PairFactors pairFactors;
        bool protectionCloseFactorWhitelist;
        UserPriceImpact userPriceImpact;
        bool protectionCloseFactorActive;
        uint256 depth; // USD
        bool tradePositiveSkew;
        int256 tradeSkewMultiplier;
        int256 priceImpactDivider;
    }

    /**
     * @dev Each slot encodes cumulative liquidity percentages for specific bands.
     * Percentages are in basis points (eg. 10,000 = 100% => percentages with 2 decimals).
     * Max value: 65535/1e2 = 655.35%
     */
    struct PairDepthBands {
        uint256 aboveSlot1; // totalDepthUsd (uint32, no decimals) + 14 x uint16 band cumulative liquidity percentages
        uint256 aboveSlot2; // 16 x uint16 band cumulative liquidity percentages
        uint256 belowSlot1; // totalDepthUsd (uint32, no decimals) + 14 x uint16 band cumulative liquidity percentages
        uint256 belowSlot2; // 16 x uint16 band cumulative liquidity percentages
    }

    /**
     * @dev Each slot encodes cumulative offset percentages from mid price for specific bands.
     * Same encoding as PairDepthBands, but totalDepthUsd is zeroed.
     * Percentages are in parts per million (eg. 1,000,000 = 100% => percentages with 4 decimals).
     * Max value: 65535/1e4 = 6.5535%
     */
    struct DepthBandsMapping {
        uint256 slot1; // first 32 bits empty, 14 x uint16 band offset percentages
        uint256 slot2; // 16 x uint16 band offset percentages
    }

    // Working struct for convenience
    struct DepthBandParameters {
        uint256 pairSlot1;
        uint256 pairSlot2;
        uint256 mappingSlot1;
        uint256 mappingSlot2;
    }

    // Deprecated
    struct TradePriceImpactInfo {
        uint128 lastWindowOiUsd;
        uint128 __placeholder;
    }
}
