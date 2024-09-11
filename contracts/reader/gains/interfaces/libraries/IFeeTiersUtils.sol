// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IFeeTiers.sol";

/**
 * @custom:version 8
 * @dev Interface for GNSFeeTiers facet (inherits types and also contains functions, events, and custom errors)
 */
interface IFeeTiersUtils is IFeeTiers {
    /**
     *
     * @param _groupIndices group indices (pairs storage fee index) to initialize
     * @param _groupVolumeMultipliers corresponding group volume multipliers (1e3)
     * @param _feeTiersIndices fee tiers indices to initialize
     * @param _feeTiers fee tiers values to initialize (feeMultiplier, pointsThreshold)
     */
    function initializeFeeTiers(
        uint256[] calldata _groupIndices,
        uint256[] calldata _groupVolumeMultipliers,
        uint256[] calldata _feeTiersIndices,
        IFeeTiersUtils.FeeTier[] calldata _feeTiers
    ) external;

    /**
     * @dev Updates groups volume multipliers
     * @param _groupIndices indices of groups to update
     * @param _groupVolumeMultipliers corresponding new volume multipliers (1e3)
     */
    function setGroupVolumeMultipliers(
        uint256[] calldata _groupIndices,
        uint256[] calldata _groupVolumeMultipliers
    ) external;

    /**
     * @dev Updates fee tiers
     * @param _feeTiersIndices indices of fee tiers to update
     * @param _feeTiers new fee tiers values (feeMultiplier, pointsThreshold)
     */
    function setFeeTiers(uint256[] calldata _feeTiersIndices, IFeeTiersUtils.FeeTier[] calldata _feeTiers) external;

    /**
     * @dev Increases daily points from a new trade, re-calculate trailing points, and cache daily fee tier for a trader.
     * @param _trader trader address
     * @param _volumeUsd trading volume in USD (1e18)
     * @param _pairIndex pair index
     */
    function updateTraderPoints(address _trader, uint256 _volumeUsd, uint256 _pairIndex) external;

    /**
     * @dev Returns fee amount after applying the trader's active fee tier multiplier
     * @param _trader address of trader
     * @param _normalFeeAmountCollateral base fee amount (collateral precision)
     */
    function calculateFeeAmount(address _trader, uint256 _normalFeeAmountCollateral) external view returns (uint256);

    /**
     * Returns the current number of active fee tiers
     */
    function getFeeTiersCount() external view returns (uint256);

    /**
     * @dev Returns a fee tier's details (feeMultiplier, pointsThreshold)
     * @param _feeTierIndex fee tier index
     */
    function getFeeTier(uint256 _feeTierIndex) external view returns (IFeeTiersUtils.FeeTier memory);

    /**
     * @dev Returns a group's volume multiplier
     * @param _groupIndex group index (pairs storage fee index)
     */
    function getGroupVolumeMultiplier(uint256 _groupIndex) external view returns (uint256);

    /**
     * @dev Returns a trader's info (lastDayUpdated, trailingPoints)
     * @param _trader trader address
     */
    function getFeeTiersTraderInfo(address _trader) external view returns (IFeeTiersUtils.TraderInfo memory);

    /**
     * @dev Returns a trader's daily fee tier info (feeMultiplierCache, points)
     * @param _trader trader address
     * @param _day day
     */
    function getFeeTiersTraderDailyInfo(
        address _trader,
        uint32 _day
    ) external view returns (IFeeTiersUtils.TraderDailyInfo memory);

    /**
     * @dev Emitted when group volume multipliers are updated
     * @param groupIndices indices of updated groups
     * @param groupVolumeMultipliers new corresponding volume multipliers (1e3)
     */
    event GroupVolumeMultipliersUpdated(uint256[] groupIndices, uint256[] groupVolumeMultipliers);

    /**
     * @dev Emitted when fee tiers are updated
     * @param feeTiersIndices indices of updated fee tiers
     * @param feeTiers new corresponding fee tiers values (feeMultiplier, pointsThreshold)
     */
    event FeeTiersUpdated(uint256[] feeTiersIndices, IFeeTiersUtils.FeeTier[] feeTiers);

    /**
     * @dev Emitted when a trader's daily points are updated
     * @param trader trader address
     * @param day day
     * @param points points added (1e18 precision)
     */
    event TraderDailyPointsIncreased(address indexed trader, uint32 indexed day, uint224 points);

    /**
     * @dev Emitted when a trader info is updated for the first time
     * @param trader address of trader
     * @param day day
     */
    event TraderInfoFirstUpdate(address indexed trader, uint32 day);

    /**
     * @dev Emitted when a trader's trailing points are updated
     * @param trader trader address
     * @param fromDay from day
     * @param toDay to day
     * @param expiredPoints expired points amount (1e18 precision)
     */
    event TraderTrailingPointsExpired(address indexed trader, uint32 fromDay, uint32 toDay, uint224 expiredPoints);

    /**
     * @dev Emitted when a trader's info is updated
     * @param trader address of trader
     * @param traderInfo new trader info value (lastDayUpdated, trailingPoints)
     */
    event TraderInfoUpdated(address indexed trader, IFeeTiersUtils.TraderInfo traderInfo);

    /**
     * @dev Emitted when a trader's cached fee multiplier is updated (this is the one used in fee calculations)
     * @param trader address of trader
     * @param day day
     * @param feeMultiplier new fee multiplier (1e3 precision)
     */
    event TraderFeeMultiplierCached(address indexed trader, uint32 indexed day, uint32 feeMultiplier);

    error WrongFeeTier();
}
