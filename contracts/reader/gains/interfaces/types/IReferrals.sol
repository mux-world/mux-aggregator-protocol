// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSReferrals facet
 */
interface IReferrals {
    struct ReferralsStorage {
        mapping(address => AllyDetails) allyDetails;
        mapping(address => ReferrerDetails) referrerDetails;
        mapping(address => address) referrerByTrader;
        uint256 allyFeeP; // % (of referrer fees going to allies, eg. 10)
        uint256 startReferrerFeeP; // % (of referrer fee when 0 volume referred, eg. 75)
        uint256 openFeeP; /// @custom:deprecated
        uint256 targetVolumeUsd; // USD (to reach maximum referral system fee, eg. 1e8)
        mapping(address => ReferralSettingsOverrides) referralSettingsOverrides;
        uint256[42] __gap;
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

    struct ReferralSettingsOverrides {
        uint24 referralFeeOverrideP; // % of total trading fee (1e3), 0 means it uses globalTradeFeeParams value
        uint24 allyFeeOverrideP; // % of total trading fee (1e3), 0 means it uses default allyFeeP value
        uint208 __placeholder;
    }
}
