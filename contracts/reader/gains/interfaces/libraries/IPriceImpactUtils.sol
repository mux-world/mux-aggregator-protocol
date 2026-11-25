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
     * @dev Initializes depth bands mapping for price impact calculation
     * @param _slot1 slot 1
     * @param _slot2 slot 2
     */
    function initializeDepthBandsMapping(uint256 _slot1, uint256 _slot2) external;

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
     * @dev Sets encoded depth bands for price impact calculation per trading pair.
     * See `PairDepthBands` struct for layout.
     * @param _indices Array of pair indices.
     * @param _depthBands Array of PairDepthBands structs with above/below slot encoding.
     */
    function setPairDepthBands(
        uint256[] calldata _indices,
        IPriceImpact.PairDepthBands[] calldata _depthBands
    ) external;

    /**
     * @dev Sets the global depth band offset mapping.
     * See `DepthBandsMapping` struct for layout.
     * @param _slot1 Encoded offsets for bands 0–13 (first 32 bits unused).
     * @param _slot2 Encoded offsets for bands 14–29.
     */
    function setDepthBandsMapping(uint256 _slot1, uint256 _slot2) external;

    /**
     * @dev Updates pairs 1% depths above and below (for skew price impact)
     * @dev Has to be manually updated from time to time based on desired speed of arbitrage (not too often to not cause imbalances)
     * @param _collateralIndices indices of collaterals
     * @param _pairIndices indices of pairs
     * @param _depths depths in tokens (1e18, 0 = no price impact)
     */
    function setPairSkewDepths(
        uint8[] calldata _collateralIndices,
        uint16[] calldata _pairIndices,
        uint256[] calldata _depths
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
     * @dev Updates pair stored open interest after v10
     * @param _collateralIndex index of collateral
     * @param _pairIndex index of pair
     * @param _oiDeltaCollateral open interest delta in collateral tokens (collateral precision)
     * @param _oiDeltaToken open interest delta in tokens (1e18)
     * @param _open whether it corresponds to opening or closing a trade
     * @param _long true for long, false for short
     */
    function updatePairOiAfterV10(
        uint8 _collateralIndex,
        uint16 _pairIndex,
        uint256 _oiDeltaCollateral,
        uint256 _oiDeltaToken,
        bool _open,
        bool _long
    ) external;

    /**
     * @dev Returns active open interest used in price impact calculation for a pair and side (long/short)
     * @param _pairIndex index of pair
     * @param _long true for long, false for short
     */
    function getPriceImpactOi(uint256 _pairIndex, bool _long) external view returns (uint256 activeOi);

    /**
     * @dev Returns cumulative volume price impact % (1e10 precision) for a trade
     * @param _trader trader address (to check if whitelisted from protection close factor)
     * @param _pairIndex index of pair
     * @param _long true for long, false for short
     * @param _tradeOpenInterestUsd open interest of trade in USD (1e18 precision)
     * @param _isPnlPositive true if positive pnl, false if negative pnl (only relevant when _open = false)
     * @param _open true on open, false on close
     * @param _lastPosIncreaseBlock block when trade position size was last increased (only relevant when _open = false)
     */
    function getTradeCumulVolPriceImpactP(
        address _trader,
        uint16 _pairIndex,
        bool _long,
        uint256 _tradeOpenInterestUsd,
        bool _isPnlPositive,
        bool _open,
        uint256 _lastPosIncreaseBlock
    ) external view returns (int256 priceImpactP);

    /**
     * @dev Returns skew price impact % (1e10 precision) for a trade
     * @param _collateralIndex index of collateral
     * @param _pairIndex index of pair
     * @param _long true for long, false for short
     * @param _positionSizeToken open interest of trade in tokens (1e18)
     * @param _open true on open, false on close
     */
    function getTradeSkewPriceImpactP(
        uint8 _collateralIndex,
        uint16 _pairIndex,
        bool _long,
        uint256 _positionSizeToken,
        bool _open
    ) external view returns (int256 priceImpactP);

    /**
     * @dev Returns the encoded depth bands for a specific pair.
     * See `PairDepthBands` struct for layout.
     * @param _pairIndex Pair index.
     * @return Encoded PairDepthBands struct (above and below).
     */
    function getPairDepthBands(uint256 _pairIndex) external view returns (IPriceImpact.PairDepthBands memory);

    /**
     * @dev Returns encoded depth bands for multiple trading pairs.
     * See `PairDepthBands` struct for layout.
     * @param _indices Array of pair indices.
     * @return Array of PairDepthBands structs.
     */
    function getPairDepthBandsArray(
        uint256[] calldata _indices
    ) external view returns (IPriceImpact.PairDepthBands[] memory);

    /**
     * @dev Returns the decoded depth bands for a specific pair.
     * @param _pairIndex Pair index.
     * @return totalDepthAboveUsd total depth above in USD (1e18).
     * @return totalDepthBelowUsd total depth below in USD (1e18).
     * @return bandsAbove above bands liquidity percentages bps (1e2 %).
     * @return bandsBelow below bands liquidity percentages bps (1e2 %).
     */
    function getPairDepthBandsDecoded(
        uint256 _pairIndex
    )
        external
        view
        returns (
            uint256 totalDepthAboveUsd,
            uint256 totalDepthBelowUsd,
            uint16[] memory bandsAbove,
            uint16[] memory bandsBelow
        );

    /**
     * @dev Returns the decoded depth bands for multiple pairs.
     * @param _indices Array of pair indices.
     * @return totalDepthAboveUsd Array of total depth above in USD (1e18).
     * @return totalDepthBelowUsd Array of total depth below in USD (1e18).
     * @return bandsAbove Array of above bands liquidity percentages bps (1e2 %).
     * @return bandsBelow Array of below bands liquidity percentages bps (1e2 %).
     */
    function getPairDepthBandsDecodedArray(
        uint256[] calldata _indices
    )
        external
        view
        returns (
            uint256[] memory totalDepthAboveUsd,
            uint256[] memory totalDepthBelowUsd,
            uint16[][] memory bandsAbove,
            uint16[][] memory bandsBelow
        );

    /**
     * @dev Returns the global depth band offset mapping.
     * See `DepthBandsMapping` struct for layout.
     * @return slot1 Encoded offsets for bands 0–13 (first 32 bits unused).
     * @return slot2 Encoded offsets for bands 14–29.
     */
    function getDepthBandsMapping() external view returns (uint256 slot1, uint256 slot2);

    /**
     * @dev Returns the decoded global depth band offset mapping.
     * @return bands Array of offsets in parts per million (1e4 %).
     */
    function getDepthBandsMappingDecoded() external view returns (uint16[] memory bands);

    /**
     * @dev Returns a pair's depths above and below the price (for skew price impact)
     * @param _collateralIndex index of collateral
     * @param _pairIndex index of pair
     */
    function getPairSkewDepth(uint8 _collateralIndex, uint16 _pairIndex) external view returns (uint256);

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
     * @dev Returns depths above and below the price for multiple pairs for skew price impact (tokens, 1e18)
     * @param _collateralIndices indices of collaterals
     * @param _pairIndices indices of pairs
     */
    function getPairSkewDepths(
        uint8[] calldata _collateralIndices,
        uint16[] calldata _pairIndices
    ) external view returns (uint256[] memory);

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
     * @param _trader trader address
     */
    function getProtectionCloseFactorWhitelist(address _trader) external view returns (bool);

    /**
     * @dev Returns a trader's price impact settings on a particular pair
     * @param _trader trader address
     * @param _pairIndex pair index
     */
    function getUserPriceImpact(
        address _trader,
        uint256 _pairIndex
    ) external view returns (IPriceImpact.UserPriceImpact memory);

    /**
     * @dev Returns a pair's open interest in collateral tokens after v10 (collateral precision)
     * @param _collateralIndex collateral index
     * @param _pairIndex pair index
     */
    function getPairOiAfterV10Collateral(
        uint8 _collateralIndex,
        uint16 _pairIndex
    ) external view returns (IPriceImpact.PairOiCollateral memory);

    /**
     * @dev Returns multiple pairs' open interests in collateral tokens after v10 (collateral precision)
     * @param _collateralIndex collateral indices
     * @param _pairIndex pair indices
     */
    function getPairOisAfterV10Collateral(
        uint8[] memory _collateralIndex,
        uint16[] memory _pairIndex
    ) external view returns (IPriceImpact.PairOiCollateral[] memory);

    /**
     * @dev Returns a pair's open interest in tokens after v10 (1e18)
     * @param _collateralIndex collateral index
     * @param _pairIndex pair index
     */
    function getPairOiAfterV10Token(
        uint8 _collateralIndex,
        uint16 _pairIndex
    ) external view returns (IPriceImpact.PairOiToken memory);

    /**
     * @dev Returns multiple pairs' open interests in tokens after v10 (collateral precision)
     * @param _collateralIndex collateral indices
     * @param _pairIndex pair indices
     */
    function getPairOisAfterV10Token(
        uint8[] memory _collateralIndex,
        uint16[] memory _pairIndex
    ) external view returns (IPriceImpact.PairOiToken[] memory);

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
     * @dev Triggered when a pair's OI after v10 is updated.
     * @param collateralIndex index of collateral
     * @param pairIndex index of pair
     * @param oiDeltaCollateral open interest delta in collateral tokens (collateral precision)
     * @param oiDeltaToken open interest delta in tokens (1e18)
     * @param open whether it corresponds to opening or closing a trade
     * @param long true for long, false for short
     * @param newOiCollateral new OI collateral after v10 (collateral precision)
     * @param newOiToken new OI token after v10 (1e18)
     */
    event PairOiAfterV10Updated(
        uint8 indexed collateralIndex,
        uint16 indexed pairIndex,
        uint256 oiDeltaCollateral,
        uint256 oiDeltaToken,
        bool open,
        bool long,
        IPriceImpact.PairOiCollateral newOiCollateral,
        IPriceImpact.PairOiToken newOiToken
    );

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
     * @dev Triggered when a pair's 1% depth is updated (for cumulative volume price impact).
     * @param pairIndex index of the pair
     * @param valueAboveUsd new USD depth above the price
     * @param valueBelowUsd new USD depth below the price
     */
    event OnePercentDepthUpdated(uint256 indexed pairIndex, uint128 valueAboveUsd, uint128 valueBelowUsd);

    /**
     * @dev Triggered when a pair's 1% depth is updated (for skew price impact).
     * @param pairIndex index of the pair
     * @param newValue new depth above/below the price (1e18, token)
     */
    event OnePercentSkewDepthUpdated(uint8 indexed collateralIndex, uint16 indexed pairIndex, uint256 newValue);

    /**
     * @dev Triggered when a pair's depth bands are updated.
     * @param pairIndex index of the pair
     * @param aboveSlot1 first slot for above bands (totalDepthUsd + 14 bands)
     * @param aboveSlot2 second slot for above bands (16 bands)
     * @param belowSlot1 first slot for below bands (totalDepthUsd + 14 bands)
     * @param belowSlot2 second slot for below bands (16 bands)
     */
    event PairDepthBandsUpdated(
        uint256 indexed pairIndex,
        uint256 aboveSlot1,
        uint256 aboveSlot2,
        uint256 belowSlot1,
        uint256 belowSlot2
    );

    /**
     * @dev Emitted when depth bands mapping is updated
     * @param slot1 Slot 1 data containing the first 14 bands offsets
     * @param slot2 Slot 2 data containing the last 16 bands offsets
     */
    event DepthBandsMappingUpdated(uint256 slot1, uint256 slot2);

    error WrongWindowsDuration();
    error WrongWindowsCount();
    error WrongDepthBandsOrder();
    error DepthBandsAboveMax();
    error DepthBandsIncomplete();
}
