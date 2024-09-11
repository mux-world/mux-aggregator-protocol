// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @custom:version 8
 * @dev Contains the types for the GNSReferrals facet
 */
interface IReferrals {
    struct ReferralsStorage {
        mapping(address => AllyDetails) allyDetails;
        mapping(address => ReferrerDetails) referrerDetails;
        mapping(address => address) referrerByTrader;
        uint256 allyFeeP; // % (of referrer fees going to allies, eg. 10)
        uint256 startReferrerFeeP; // % (of referrer fee when 0 volume referred, eg. 75)
        uint256 openFeeP; // % (of opening fee used for referral system, eg. 33)
        uint256 targetVolumeUsd; // USD (to reach maximum referral system fee, eg. 1e8)
        uint256[43] __gap;
    }

    struct AllyDetails {
        address[] referrersReferred;
        uint256 volumeReferredUsd; // 1e18
        uint256 pendingRewardsGns; // 1e18
        uint256 totalRewardsGns; // 1e18
        uint256 totalRewardsValueUsd; // 1e18
        bool active;
    }

    struct ReferrerDetails {
        address ally;
        address[] tradersReferred;
        uint256 volumeReferredUsd; // 1e18
        uint256 pendingRewardsGns; // 1e18
        uint256 totalRewardsGns; // 1e18
        uint256 totalRewardsValueUsd; // 1e18
        bool active;
    }
}
