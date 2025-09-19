// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSFeeTiers facet
 */
interface IFeeTiers {
    struct FeeTiersStorage {
        FeeTier[8] feeTiers;
        mapping(uint256 => uint256) groupVolumeMultipliers; // groupIndex (pairs storage) => multiplier (1e3)
        mapping(address => TraderInfo) traderInfos; // trader => TraderInfo
        mapping(address => mapping(uint32 => TraderDailyInfo)) traderDailyInfos; // trader => day => TraderDailyInfo
        mapping(address => TraderEnrollment) traderEnrollments; // trader => TraderEnrollment
        mapping(address => uint224) unclaimedPoints; // trader => points (1e18)
        uint256[37] __gap;
    }

    enum TraderEnrollmentStatus {
        ENROLLED,
        EXCLUDED
    }

    enum CreditType {
        IMMEDIATE,
        CLAIMABLE
    }

    struct FeeTier {
        uint32 feeMultiplier; // 1e3
        uint32 pointsThreshold;
    }

    struct TraderInfo {
        uint32 lastDayUpdated;
        uint224 trailingPoints; // 1e18
    }

    struct TraderDailyInfo {
        uint32 feeMultiplierCache; // 1e3
        uint224 points; // 1e18
    }

    struct TraderEnrollment {
        TraderEnrollmentStatus status;
        uint248 __placeholder;
    }
}
