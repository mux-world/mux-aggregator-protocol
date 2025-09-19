// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IPriceImpact.sol";
import "../types/ITradingStorage.sol";

/**
 * @dev Interface for GNSPriceImpact facet (inherits types and also contains functions, events, and custom errors)
 */
interface IPriceImpactUtils is IPriceImpact {
    /**
     * @dev Initializes price impact facet
     * @param _windowsDuration windows duration (seconds)
     * @param _windowsCount windows count
     */
    function initializePriceImpact(uint48 _windowsDuration, uint48 _windowsCount) external;

    /**
     * @dev Initializes negative pnl cumulative volume multiplier
     * @param _negPnlCumulVolMultiplier new value (1e10)
     */
    function initializeNegPnlCumulVolMultiplier(uint40 _negPnlCumulVolMultiplier) external;

    /**
     * @dev Initializes pair factors
     * @param _pairIndices pair indices to initialize
     * @param _protectionCloseFactors protection close factors (1e10)
     * @param _protectionCloseFactorBlocks protection close factor blocks
     * @param _cumulativeFactors cumulative factors (1e10)
     */
    function initializePairFactors(
        uint16[] calldata _pairIndices,
        uint40[] calldata _protectionCloseFactors,
        uint32[] calldata _protectionCloseFactorBlocks,
        uint40[] calldata _cumulativeFactors
    ) external;

    /**
     * @dev Updates price impact windows count
     * @param _newWindowsCount new windows count
     */
    function setPriceImpactWindowsCount(uint48 _newWindowsCount) external;

    /**
     * @dev Updates price impact windows duration
     * @param _newWindowsDuration new windows duration (seconds)
     */
    function setPriceImpactWindowsDuration(uint48 _newWindowsDuration) external;

    /**
     * @dev Updates negative pnl cumulative volume multiplier
     * @param _negPnlCumulVolMultiplier new value (1e10)
     */
    function setNegPnlCumulVolMultiplier(uint40 _negPnlCumulVolMultiplier) external;

    /**
     * @dev Whitelists/unwhitelists traders from protection close factor
     * @param _traders traders addresses
     * @param _whitelisted values
     */
    function setProtectionCloseFactorWhitelist(address[] calldata _traders, bool[] calldata _whitelisted) external;

    /**
     * @dev Updates traders price impact settings for pairs
     * @param _traders traders addresses
     * @param _pairIndices pair indices
     * @param _cumulVolPriceImpactMultipliers cumulative volume price impact multipliers (1e3)
     * @param _fixedSpreadPs fixed spreads (1e3 %)
     */
    function setUserPriceImpact(
        address[] calldata _traders,
        uint16[] calldata _pairIndices,
        uint16[] calldata _cumulVolPriceImpactMultipliers,
        uint16[] calldata _fixedSpreadPs
    ) external;

    /**
     * @dev Updates pairs 1% depths above and below
     * @param _indices indices of pairs
     * @param _depthsAboveUsd depths above the price in USD
     * @param _depthsBelowUsd depths below the price in USD
     */
    function setPairDepths(
        uint256[] calldata _indices,
        uint128[] calldata _depthsAboveUsd,
        uint128[] calldata _depthsBelowUsd
    ) external;

    /**
     * @dev Sets protection close factors for pairs
     * @param _pairIndices pair indices to update
     * @param _protectionCloseFactors new protection close factors (1e10)
     */
    function setProtectionCloseFactors(
        uint16[] calldata _pairIndices,
        uint40[] calldata _protectionCloseFactors
    ) external;

    /**
     * @dev Sets protection close factor blocks duration for pairs
     * @param _pairIndices pair indices to update
     * @param _protectionCloseFactorBlocks new protection close factor blocks
     */
    function setProtectionCloseFactorBlocks(
        uint16[] calldata _pairIndices,
        uint32[] calldata _protectionCloseFactorBlocks
    ) external;

    /**
     * @dev Sets cumulative factors for pairs
     * @param _pairIndices pair indices to update
     * @param _cumulativeFactors new cumulative factors (1e10)
     */
    function setCumulativeFactors(uint16[] calldata _pairIndices, uint40[] calldata _cumulativeFactors) external;

    /**
     * @dev Sets whether pairs are exempt from price impact on open
     * @param _pairIndices pair indices to update
     * @param _exemptOnOpen new values
     */
    function setExemptOnOpen(uint16[] calldata _pairIndices, bool[] calldata _exemptOnOpen) external;

    /**
     * @dev Sets whether pairs are exempt from price impact on close once protection close factor has expired
     * @param _pairIndices pair indices to update
     * @param _exemptAfterProtectionCloseFactor new values
     */
    function setExemptAfterProtectionCloseFactor(
        uint16[] calldata _pairIndices,
        bool[] calldata _exemptAfterProtectionCloseFactor
    ) external;

    /**
     * @dev Adds open interest to current window
     * @param _trader trader address
     * @param _index trade index
     * @param _oiDeltaCollateral open interest to add (collateral precision)
     * @param _open whether it corresponds to opening or closing a trade
     * @param _isPnlPositive whether it corresponds to a positive pnl trade (only relevant when _open = false)
     */
    function addPriceImpactOpenInterest(
        address _trader,
        uint32 _index,
        uint256 _oiDeltaCollateral,
        bool _open,
        bool _isPnlPositive
    ) external;

    /**
     * @dev Returns active open interest used in price impact calculation for a pair and side (long/short)
     * @param _pairIndex index of pair
     * @param _long true for long, false for short
     */
    function getPriceImpactOi(uint256 _pairIndex, bool _long) external view returns (uint256 activeOi);

    /**
     * @dev Returns price impact % (1e10 precision) and price after impact (1e10 precision) for a trade
     * @param _trader trader address (to check if whitelisted from protection close factor)
     * @param _marketPrice market price (1e10 precision)
     * @param _pairIndex index of pair
     * @param _long true for long, false for short
     * @param _tradeOpenInterestUsd open interest of trade in USD (1e18 precision)
     * @param _isPnlPositive true if positive pnl, false if negative pnl (only relevant when _open = false)
     * @param _open true on open, false on close
     * @param _lastPosIncreaseBlock block when trade position size was last increased (only relevant when _open = false)
     * @param _contractsVersion trade contracts version
     */
    function getTradePriceImpact(
        address _trader,
        uint256 _marketPrice,
        uint256 _pairIndex,
        bool _long,
        uint256 _tradeOpenInterestUsd,
        bool _isPnlPositive,
        bool _open,
        uint256 _lastPosIncreaseBlock,
        ITradingStorage.ContractsVersion _contractsVersion
    ) external view returns (uint256 priceImpactP, uint256 priceAfterImpact);

    /**
     * @dev Returns a pair's depths above and below the price
     * @param _pairIndex index of pair
     */
    function getPairDepth(uint256 _pairIndex) external view returns (PairDepth memory);

    /**
     * @dev Returns current price impact windows settings
     */
    function getOiWindowsSettings() external view returns (OiWindowsSettings memory);

    /**
     * @dev Returns OI window details (long/short OI)
     * @param _windowsDuration windows duration (seconds)
     * @param _pairIndex index of pair
     * @param _windowId id of window
     */
    function getOiWindow(
        uint48 _windowsDuration,
        uint256 _pairIndex,
        uint256 _windowId
    ) external view returns (PairOi memory);

    /**
     * @dev Returns multiple OI windows details (long/short OI)
     * @param _windowsDuration windows duration (seconds)
     * @param _pairIndex index of pair
     * @param _windowIds ids of windows
     */
    function getOiWindows(
        uint48 _windowsDuration,
        uint256 _pairIndex,
        uint256[] calldata _windowIds
    ) external view returns (PairOi[] memory);

    /**
     * @dev Returns depths above and below the price for multiple pairs
     * @param _indices indices of pairs
     */
    function getPairDepths(uint256[] calldata _indices) external view returns (PairDepth[] memory);

    /**
     * @dev Returns factors for a set of pairs (1e10)
     * @param _indices indices of pairs
     */
    function getPairFactors(uint256[] calldata _indices) external view returns (IPriceImpact.PairFactors[] memory);

    /**
     * @dev Returns negative pnl cumulative volume multiplier
     */
    function getNegPnlCumulVolMultiplier() external view returns (uint48);

    /**
     * @dev Returns whether a trader is whitelisted from protection close factor
     */
    function getProtectionCloseFactorWhitelist(address _trader) external view returns (bool);

    /**
     * @dev Returns a trader's price impact settings on a particular pair
     */
    function getUserPriceImpact(
        address _trader,
        uint256 _pairIndex
    ) external view returns (IPriceImpact.UserPriceImpact memory);

    /**
     * @dev Triggered when OiWindowsSettings is initialized (once)
     * @param windowsDuration duration of each window (seconds)
     * @param windowsCount number of windows
     */
    event OiWindowsSettingsInitialized(uint48 indexed windowsDuration, uint48 indexed windowsCount);

    /**
     * @dev Triggered when OiWindowsSettings.windowsCount is updated
     * @param windowsCount new number of windows
     */
    event PriceImpactWindowsCountUpdated(uint48 indexed windowsCount);

    /**
     * @dev Triggered when OiWindowsSettings.windowsDuration is updated
     * @param windowsDuration new duration of each window (seconds)
     */
    event PriceImpactWindowsDurationUpdated(uint48 indexed windowsDuration);

    /**
     * @dev Triggered when negPnlCumulVolMultiplier is updated
     * @param negPnlCumulVolMultiplier new value (1e10)
     */
    event NegPnlCumulVolMultiplierUpdated(uint40 indexed negPnlCumulVolMultiplier);

    /**
     * @dev Triggered when a trader is whitelisted/unwhitelisted from protection close factor
     * @param trader trader address
     * @param whitelisted true if whitelisted, false if unwhitelisted
     */
    event ProtectionCloseFactorWhitelistUpdated(address trader, bool whitelisted);

    /**
     * @dev Triggered when a trader's price impact data is updated
     * @param trader trader address
     * @param pairIndex pair index
     * @param cumulVolPriceImpactMultiplier cumulative volume price impact multiplier (1e3)
     * @param fixedSpreadP fixed spread (1e3 %)
     */
    event UserPriceImpactUpdated(
        address indexed trader,
        uint16 indexed pairIndex,
        uint16 cumulVolPriceImpactMultiplier,
        uint16 fixedSpreadP
    );

    /**
     * @dev Triggered when a pair's protection close factor is updated
     * @param pairIndex index of the pair
     * @param protectionCloseFactor new protection close factor (1e10)
     */
    event ProtectionCloseFactorUpdated(uint256 indexed pairIndex, uint40 protectionCloseFactor);

    /**
     * @dev Triggered when a pair's protection close factor duration is updated
     * @param pairIndex index of the pair
     * @param protectionCloseFactorBlocks new protection close factor blocks
     */
    event ProtectionCloseFactorBlocksUpdated(uint256 indexed pairIndex, uint32 protectionCloseFactorBlocks);

    /**
     * @dev Triggered when a pair's cumulative factor is updated
     * @param pairIndex index of the pair
     * @param cumulativeFactor new cumulative factor (1e10)
     */
    event CumulativeFactorUpdated(uint256 indexed pairIndex, uint40 cumulativeFactor);

    /**
     * @dev Triggered when a pair's exemptOnOpen value is updated
     * @param pairIndex index of the pair
     * @param exemptOnOpen whether the pair is exempt of price impact on open
     */
    event ExemptOnOpenUpdated(uint256 indexed pairIndex, bool exemptOnOpen);

    /**
     * @dev Triggered when a pair's exemptAfterProtectionCloseFactor value is updated
     * @param pairIndex index of the pair
     * @param exemptAfterProtectionCloseFactor whether the pair is exempt of price impact on close once protection close factor has expired
     */
    event ExemptAfterProtectionCloseFactorUpdated(uint256 indexed pairIndex, bool exemptAfterProtectionCloseFactor);

    /**
     * @dev Triggered when OI is added to a window.
     * @param oiWindowUpdate OI window update details (windowsDuration, pairIndex, windowId, etc.)
     */
    event PriceImpactOpenInterestAdded(IPriceImpact.OiWindowUpdate oiWindowUpdate);

    /**
     * @dev Triggered when multiple pairs' OI are transferred to a new window (when updating windows duration).
     * @param pairsCount number of pairs
     * @param prevCurrentWindowId previous current window ID corresponding to previous window duration
     * @param prevEarliestWindowId previous earliest window ID corresponding to previous window duration
     * @param newCurrentWindowId new current window ID corresponding to new window duration
     */
    event PriceImpactOiTransferredPairs(
        uint256 pairsCount,
        uint256 prevCurrentWindowId,
        uint256 prevEarliestWindowId,
        uint256 newCurrentWindowId
    );

    /**
     * @dev Triggered when a pair's OI is transferred to a new window.
     * @param pairIndex index of the pair
     * @param totalPairOi total USD long/short OI of the pair (1e18 precision)
     */
    event PriceImpactOiTransferredPair(uint256 indexed pairIndex, IPriceImpact.PairOi totalPairOi);

    /**
     * @dev Triggered when a pair's depth is updated.
     * @param pairIndex index of the pair
     * @param valueAboveUsd new USD depth above the price
     * @param valueBelowUsd new USD depth below the price
     */
    event OnePercentDepthUpdated(uint256 indexed pairIndex, uint128 valueAboveUsd, uint128 valueBelowUsd);

    error WrongWindowsDuration();
    error WrongWindowsCount();
}
