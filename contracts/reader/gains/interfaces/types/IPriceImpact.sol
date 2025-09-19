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
        uint256[42] __gap;
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
    }

    // Deprecated
    struct TradePriceImpactInfo {
        uint128 lastWindowOiUsd;
        uint128 __placeholder;
    }
}
