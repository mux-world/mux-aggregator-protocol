// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IPairsStorage.sol";

/**
 * @dev Interface for GNSPairsStorage facet (inherits types and also contains functions, events, and custom errors)
 */
interface IPairsStorageUtils is IPairsStorage {
    /**
     * @dev Initializes liquidation params for all existing groups
     * @param _groupLiquidationParams liquidation params for each group (index corresponds to group index)
     */
    function initializeGroupLiquidationParams(
        IPairsStorage.GroupLiquidationParams[] memory _groupLiquidationParams
    ) external;

    /**
     * @dev Copies all existing fee groups to new mapping, multiplies existing groups min/max lev by 1e3, initializes new global trade fee params
     * @param _tradeFeeParams global trade fee params
     */
    function initializeNewFees(IPairsStorage.GlobalTradeFeeParams memory _tradeFeeParams) external;

    /**
     * @dev Initializes referral fee change (adds 50% of referral share to gov and otc, now gov+otc+trigger+gToken = 100%, referral fee charged first)
     * @dev Only useful for v9.4.4 -> v9.4.5 transition
     */
    function initializeReferralFeeChange() external;

    /**
     * @dev Adds new trading pairs
     * @param _pairs pairs to add
     */
    function addPairs(Pair[] calldata _pairs) external;

    /**
     * @dev Updates trading pairs
     * @param _pairIndices indices of pairs
     * @param _pairs new pairs values
     */
    function updatePairs(uint256[] calldata _pairIndices, Pair[] calldata _pairs) external;

    /**
     * @dev Adds new pair groups
     * @param _groups groups to add
     */
    function addGroups(Group[] calldata _groups) external;

    /**
     * @dev Updates pair groups
     * @param _ids indices of groups
     * @param _groups new groups values
     */
    function updateGroups(uint256[] calldata _ids, Group[] calldata _groups) external;

    /**
     * @dev Adds new pair fees groups
     * @param _fees fees to add
     */
    function addFees(FeeGroup[] calldata _fees) external;

    /**
     * @dev Updates pair fees groups
     * @param _ids indices of fees
     * @param _fees new fees values
     */
    function updateFees(uint256[] calldata _ids, FeeGroup[] calldata _fees) external;

    /**
     * @dev Updates pair custom max leverages (if unset group default is used); useful to delist a pair if new value is below the pair's group minLeverage
     * @param _indices indices of pairs
     * @param _values new custom max leverages (1e3 precision)
     */
    function setPairCustomMaxLeverages(uint256[] calldata _indices, uint256[] calldata _values) external;

    /**
     * @dev Updates group liquidation params (will only apply for trades opened after the change)
     * @param _groupIndex index of group
     * @param _params new liquidation params
     */
    function setGroupLiquidationParams(
        uint256 _groupIndex,
        IPairsStorage.GroupLiquidationParams memory _params
    ) external;

    /**
     * @dev Updates global trade fee params
     * @param _feeParams new fee params
     */
    function setGlobalTradeFeeParams(IPairsStorage.GlobalTradeFeeParams memory _feeParams) external;

    /**
     * @dev Returns data needed by price aggregator when doing a new price request
     * @param _pairIndex index of pair
     * @return from pair from (eg. BTC)
     * @return to pair to (eg. USD)
     */
    function pairJob(uint256 _pairIndex) external view returns (string memory from, string memory to);

    /**
     * @dev Returns whether a pair is listed
     * @param _from pair from (eg. BTC)
     * @param _to pair to (eg. USD)
     */
    function isPairListed(string calldata _from, string calldata _to) external view returns (bool);

    /**
     * @dev Returns whether a pair index is listed
     * @param _pairIndex index of pair to check
     */
    function isPairIndexListed(uint256 _pairIndex) external view returns (bool);

    /**
     * @dev Returns a pair's details
     * @param _index index of pair
     */
    function pairs(uint256 _index) external view returns (Pair memory);

    /**
     * @dev Returns number of listed pairs
     */
    function pairsCount() external view returns (uint256);

    /**
     * @dev Returns the sum of trader's custom spread + global pair's spread % (1e10 precision)
     * @param _trader trader address
     * @param _pairIndex index of pair
     */
    function pairSpreadP(address _trader, uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns array of each traders' custom spread + global pair's spread % (1e10 precision)
     * @param _trader array of traders
     * @param _pairIndex array of pairs indices
     */
    function pairSpreadPArray(
        address[] calldata _trader,
        uint256[] calldata _pairIndex
    ) external view returns (uint256[] memory);

    /**
     * @dev Returns a pair's min leverage (1e3 precision)
     * @param _pairIndex index of pair
     */
    function pairMinLeverage(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns a pair's total position size fee % (1e10 precision)
     * @param _pairIndex index of pair
     */
    function pairTotalPositionSizeFeeP(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns a pair's total liquidation collateral fee % (1e10 precision)
     * @param _pairIndex index of pair
     */
    function pairTotalLiqCollateralFeeP(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns a pair's oracle position size fee % (1e10 precision)
     * @param _pairIndex index of pair
     */
    function pairOraclePositionSizeFeeP(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns a pair's min position size in USD (1e18 precision)
     * @param _pairIndex index of pair
     */
    function pairMinPositionSizeUsd(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns global trade fee params
     */
    function getGlobalTradeFeeParams() external view returns (IPairsStorage.GlobalTradeFeeParams memory);

    /**
     * @dev Returns a pair's minimum trading fee in USD (1e18 precision)
     * @param _pairIndex index of pair
     */
    function pairMinFeeUsd(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns a group details
     * @param _index index of group
     */
    function groups(uint256 _index) external view returns (Group memory);

    /**
     * @dev Returns number of listed groups
     */
    function groupsCount() external view returns (uint256);

    /**
     * @dev Returns a fee group details
     * @param _index index of fee group
     */
    function fees(uint256 _index) external view returns (FeeGroup memory);

    /**
     * @dev Returns number of listed fee groups
     */
    function feesCount() external view returns (uint256);

    /**
     * @dev Returns a pair's active max leverage; custom if set, otherwise group default (1e3 precision)
     * @param _pairIndex index of pair
     */
    function pairMaxLeverage(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns a pair's custom max leverage; 0 if not set (1e3 precision)
     * @param _pairIndex index of pair
     */
    function pairCustomMaxLeverage(uint256 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns all listed pairs custom max leverages (1e3 precision)
     */
    function getAllPairsRestrictedMaxLeverage() external view returns (uint256[] memory);

    /**
     * @dev Returns a group's liquidation params
     */
    function getGroupLiquidationParams(
        uint256 _groupIndex
    ) external view returns (IPairsStorage.GroupLiquidationParams memory);

    /**
     * @dev Returns a pair's group liquidation params
     */
    function getPairLiquidationParams(
        uint256 _pairIndex
    ) external view returns (IPairsStorage.GroupLiquidationParams memory);

    /**
     * @dev Emitted when a new pair is listed
     * @param index index of pair
     * @param from pair from (eg. BTC)
     * @param to pair to (eg. USD)
     */
    event PairAdded(uint256 index, string from, string to);

    /**
     * @dev Emitted when a pair is updated
     * @param index index of pair
     */
    event PairUpdated(uint256 index);

    /**
     * @dev Emitted when a pair's custom max leverage is updated
     * @param index index of pair
     * @param maxLeverage new max leverage (1e3 precision)
     */
    event PairCustomMaxLeverageUpdated(uint256 indexed index, uint256 maxLeverage);

    /**
     * @dev Emitted when a new group is added
     * @param index index of group
     * @param name name of group
     */
    event GroupAdded(uint256 index, string name);

    /**
     * @dev Emitted when a group is updated
     * @param index index of group
     */
    event GroupUpdated(uint256 index);

    /**
     * @dev Emitted when a new fee group is added
     * @param index index of fee group
     * @param feeGroup fee group
     */
    event FeeAdded(uint256 index, FeeGroup feeGroup);

    /**
     * @dev Emitted when a fee group is updated
     * @param index index of fee group
     * @param feeGroup updated fee group
     */
    event FeeUpdated(uint256 index, FeeGroup feeGroup);

    /**
     * @dev Emitted when a group liquidation params are updated
     * @param index index of group
     * @param params new group liquidation params
     */
    event GroupLiquidationParamsUpdated(uint256 index, IPairsStorage.GroupLiquidationParams params);

    /**
     * @dev Emitted when global trade fee params are updated
     * @param feeParams new fee params
     */
    event GlobalTradeFeeParamsUpdated(IPairsStorage.GlobalTradeFeeParams feeParams);

    error PairNotListed();
    error GroupNotListed();
    error FeeNotListed();
    error WrongLeverages();
    error WrongFees();
    error PairAlreadyListed();
    error MaxLiqSpreadPTooHigh();
    error WrongLiqParamsThresholds();
    error WrongLiqParamsLeverages();
    error StartLiqThresholdTooHigh();
    error EndLiqThresholdTooLow();
    error StartLeverageTooLow();
    error EndLeverageTooHigh();
}
