// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Chainlink} from "@chainlink/contracts/src/v0.8/Chainlink.sol";

import "../types/IPriceAggregator.sol";
import "../types/ITradingStorage.sol";
import "../types/ITradingCallbacks.sol";

/**
 * @dev Interface for GNSPriceAggregator facet (inherits types and also contains functions, events, and custom errors)
 */
interface IPriceAggregatorUtils is IPriceAggregator {
    /**
     * @dev Initializes price aggregator facet
     * @param _linkToken LINK token address
     * @param _linkUsdPriceFeed LINK/USD price feed address
     * @param _twapInterval TWAP interval (seconds)
     * @param _minAnswers answers count at which a trade is executed with median
     * @param _oracles chainlink oracle addresses
     * @param _jobIds chainlink job ids (market/lookback)
     * @param _collateralIndices collateral indices
     * @param _gnsCollateralLiquidityPools corresponding GNS/collateral liquidity pool values
     * @param _collateralUsdPriceFeeds corresponding collateral/USD chainlink price feeds
     */
    function initializePriceAggregator(
        address _linkToken,
        IChainlinkFeed _linkUsdPriceFeed,
        uint24 _twapInterval,
        uint8 _minAnswers,
        address[] memory _oracles,
        bytes32[2] memory _jobIds,
        uint8[] calldata _collateralIndices,
        LiquidityPoolInput[] memory _gnsCollateralLiquidityPools,
        IChainlinkFeed[] memory _collateralUsdPriceFeeds
    ) external;

    /**
     * @dev Initializes lookback job count
     * @param _limitJobCount lookback job count
     */
    function initializeLimitJobCount(uint8 _limitJobCount) external;

    /**
     * @dev Initializes max deviation percentages
     * @param _maxMarketDeviationP max market order deviation percentage (1e3, %)
     * @param _maxLookbackDeviationP max lookback order deviation percentage (1e3, %)
     */
    function initializeMaxDeviationsP(uint24 _maxMarketDeviationP, uint24 _maxLookbackDeviationP) external;

    /**
     * @dev Updates LINK/USD chainlink price feed
     * @param _value new value
     */
    function updateLinkUsdPriceFeed(IChainlinkFeed _value) external;

    /**
     * @dev Updates collateral/USD chainlink price feed
     * @param _collateralIndex collateral index
     * @param _value new value
     */
    function updateCollateralUsdPriceFeed(uint8 _collateralIndex, IChainlinkFeed _value) external;

    /**
     * @dev Updates collateral/GNS liquidity pool
     * @param _collateralIndex collateral index
     * @param _liquidityPoolInput new values
     */
    function updateCollateralGnsLiquidityPool(
        uint8 _collateralIndex,
        LiquidityPoolInput calldata _liquidityPoolInput
    ) external;

    /**
     * @dev Updates TWAP interval
     * @param _twapInterval new value (seconds)
     */
    function updateTwapInterval(uint24 _twapInterval) external;

    /**
     * @dev Updates minimum answers count
     * @param _value new value
     */
    function updateMinAnswers(uint8 _value) external;

    /**
     * @dev Adds an oracle
     * @param _a new value
     */
    function addOracle(address _a) external;

    /**
     * @dev Replaces an oracle
     * @param _index oracle index
     * @param _a new value
     */
    function replaceOracle(uint256 _index, address _a) external;

    /**
     * @dev Removes an oracle
     * @param _index oracle index
     */
    function removeOracle(uint256 _index) external;

    /**
     * @dev Updates market job id
     * @param _jobId new value
     */
    function setMarketJobId(bytes32 _jobId) external;

    /**
     * @dev Updates lookback job id
     * @param _jobId new value
     */
    function setLimitJobId(bytes32 _jobId) external;

    /**
     * @dev Updates lookback job count
     * @param _limitJobCount new value
     */
    function setLimitJobCount(uint8 _limitJobCount) external;

    /**
     * @dev Updates max market order deviation percentage
     * @param _maxMarketDeviationP new value (1e3, %)
     */
    function setMaxMarketDeviationP(uint24 _maxMarketDeviationP) external;

    /**
     * @dev Updates max lookback order deviation percentage
     * @param _maxLookbackDeviationP new value (1e3, %)
     */
    function setMaxLookbackDeviationP(uint24 _maxLookbackDeviationP) external;

    /**
     * @dev Stores pending order, requests price from oracles, and returns pending order id
     * @param _input price request input (see IPriceAggregator)
     */
    function getPrice(IPriceAggregator.GetPriceInput memory _input) external returns (ITradingStorage.Id memory);

    /**
     * @dev Fulfills price request, called by chainlink oracles
     * @param _requestId request id
     * @param _priceData price data
     */
    function fulfill(bytes32 _requestId, uint256 _priceData) external;

    /**
     * @dev Claims back LINK tokens, called by gov fund
     */
    function claimBackLink() external;

    /**
     * @dev Validates signed pair prices, stores them temporarily as well as the corresponding median price for each pair after filtering outliers and the list of corresponding pair indices (for cleanup)
     * @param _signedPairPrices signed pair market prices (one entry per oracle)
     * @param _isLookback whether the prices are for a lookback order
     */
    function validateSignedPairPrices(
        IPriceAggregator.SignedPairPrices[] calldata _signedPairPrices,
        bool _isLookback
    ) external;

    /**
     * @dev Cleans up all temporary storage related to signed pair prices
     */
    function cleanUpSignedPairPrices() external;

    /**
     * @dev Returns LINK fee for price request
     * @param _collateralIndex collateral index
     * @param _trader trader address
     * @param _pairIndex pair index
     * @param _positionSizeCollateral position size in collateral tokens (collateral precision)
     * @param _isCounterTrade whether corresponding trade is counter trade
     */
    function getLinkFee(
        uint8 _collateralIndex,
        address _trader,
        uint16 _pairIndex,
        uint256 _positionSizeCollateral,
        bool _isCounterTrade
    ) external view returns (uint256);

    /**
     * @dev Returns collateral/USD price
     * @param _collateralIndex index of collateral
     */
    function getCollateralPriceUsd(uint8 _collateralIndex) external view returns (uint256);

    /**
     * @dev Returns USD normalized value from collateral value
     * @param _collateralIndex index of collateral
     * @param _collateralValue collateral value (collateral precision)
     */
    function getUsdNormalizedValue(uint8 _collateralIndex, uint256 _collateralValue) external view returns (uint256);

    /**
     * @dev Returns collateral value (collateral precision) from USD normalized value
     * @param _collateralIndex index of collateral
     * @param _normalizedValue normalized value (1e18 USD)
     */
    function getCollateralFromUsdNormalizedValue(
        uint8 _collateralIndex,
        uint256 _normalizedValue
    ) external view returns (uint256);

    /**
     * @dev Returns GNS/USD price based on GNS/collateral price
     * @param _collateralIndex index of collateral
     */
    function getGnsPriceUsd(uint8 _collateralIndex) external view returns (uint256);

    /**
     * @dev Returns GNS/USD price based on GNS/collateral price
     * @param _collateralIndex index of collateral
     * @param _gnsPriceCollateral GNS/collateral price (1e10)
     */
    function getGnsPriceUsd(uint8 _collateralIndex, uint256 _gnsPriceCollateral) external view returns (uint256);

    /**
     * @dev Returns GNS/collateral price
     * @param _collateralIndex index of collateral
     */
    function getGnsPriceCollateralIndex(uint8 _collateralIndex) external view returns (uint256);

    /**
     * @dev Returns GNS/collateral price
     * @param _collateral address of the collateral
     */
    function getGnsPriceCollateralAddress(address _collateral) external view returns (uint256);

    /**
     * @dev Returns the link/usd price feed address
     */
    function getLinkUsdPriceFeed() external view returns (IChainlinkFeed);

    /**
     * @dev Returns the twap interval in seconds
     */
    function getTwapInterval() external view returns (uint24);

    /**
     * @dev Returns the minimum answers to execute an order and take the median
     */
    function getMinAnswers() external view returns (uint8);

    /**
     * @dev Returns the market job id
     */
    function getMarketJobId() external view returns (bytes32);

    /**
     * @dev Returns the limit job id
     */
    function getLimitJobId() external view returns (bytes32);

    /**
     * @dev Returns a specific oracle
     * @param _index index of the oracle
     */
    function getOracle(uint256 _index) external view returns (address);

    /**
     * @dev Returns all oracles
     */
    function getOracles() external view returns (address[] memory);

    /**
     * @dev Returns collateral/gns liquidity pool info
     * @param _collateralIndex index of collateral
     */
    function getCollateralGnsLiquidityPool(uint8 _collateralIndex) external view returns (LiquidityPoolInfo memory);

    /**
     * @dev Returns collateral/usd chainlink price feed
     * @param _collateralIndex index of collateral
     */
    function getCollateralUsdPriceFeed(uint8 _collateralIndex) external view returns (IChainlinkFeed);

    /**
     * @dev Returns order data
     * @param _requestId index of collateral
     */
    function getPriceAggregatorOrder(bytes32 _requestId) external view returns (Order memory);

    /**
     * @dev Returns order data
     * @param _orderId order id
     */
    function getPriceAggregatorOrderAnswers(
        ITradingStorage.Id calldata _orderId
    ) external view returns (OrderAnswer[] memory);

    /**
     * @dev Returns chainlink token address
     */
    function getChainlinkToken() external view returns (address);

    /**
     * @dev Returns requestCount (used by ChainlinkClientUtils)
     */
    function getRequestCount() external view returns (uint256);

    /**
     * @dev Returns pendingRequests mapping entry (used by ChainlinkClientUtils)
     */
    function getPendingRequest(bytes32 _id) external view returns (address);

    /**
     * @dev Returns lookback job count
     */
    function getLimitJobCount() external view returns (uint8);

    /**
     * @dev Returns current lookback job index
     */
    function getLimitJobIndex() external view returns (uint88);

    /**
     * @dev Returns max market order deviation percentage (1e3 %)
     */
    function getMaxMarketDeviationP() external view returns (uint24);

    /**
     * @dev Returns max lookback order deviation percentage (1e3 %)
     */
    function getMaxLookbackDeviationP() external view returns (uint24);

    /**
     * @dev Returns temporary signed order answers for a pair
     * @param _pairIndex pair index
     */
    function getPairSignedOrderAnswersTemporary(
        uint16 _pairIndex
    ) external view returns (IPriceAggregator.OrderAnswer[] memory);

    /**
     * @dev Returns the median signed answer for a pair based on temporary storage
     * @param _pairIndex pair index
     */
    function getPairSignedMedianTemporary(
        uint16 _pairIndex
    ) external view returns (ITradingCallbacks.AggregatorAnswer memory);

    /**
     * @dev Returns signed pair indices stored temporarily (for cleanup)
     */
    function getSignedPairIndicesTemporary() external view returns (uint16[] memory);

    /**
     * @dev Emitted when LINK/USD price feed is updated
     * @param value new value
     */
    event LinkUsdPriceFeedUpdated(address value);

    /**
     * @dev Emitted when collateral/USD price feed is updated
     * @param collateralIndex collateral index
     * @param value new value
     */
    event CollateralUsdPriceFeedUpdated(uint8 collateralIndex, address value);

    /**
     * @dev Emitted when collateral/GNS Uniswap V3 pool is updated
     * @param collateralIndex collateral index
     * @param newValue new value
     */
    event CollateralGnsLiquidityPoolUpdated(uint8 collateralIndex, LiquidityPoolInfo newValue);

    /**
     * @dev Emitted when TWAP interval is updated
     * @param newValue new value
     */
    event TwapIntervalUpdated(uint32 newValue);

    /**
     * @dev Emitted when minimum answers count is updated
     * @param value new value
     */
    event MinAnswersUpdated(uint8 value);

    /**
     * @dev Emitted when an oracle is added
     * @param index new oracle index
     * @param value value
     */
    event OracleAdded(uint256 index, address value);

    /**
     * @dev Emitted when an oracle is replaced
     * @param index oracle index
     * @param oldOracle old value
     * @param newOracle new value
     */
    event OracleReplaced(uint256 index, address oldOracle, address newOracle);

    /**
     * @dev Emitted when an oracle is removed
     * @param index oracle index
     * @param oldOracle old value
     */
    event OracleRemoved(uint256 index, address oldOracle);

    /**
     * @dev Emitted when market job id is updated
     * @param index index
     * @param jobId new value
     */
    event JobIdUpdated(uint256 index, bytes32 jobId);

    /**
     * @dev Emitted when a chainlink request is created
     * @param request link request details
     */
    event LinkRequestCreated(Chainlink.Request request);

    /**
     * @dev Emitted when a price is requested to the oracles
     * @param collateralIndex collateral index
     * @param pairIndex trading pair index
     * @param pendingOrder corresponding pending order
     * @param positionSizeCollateral position size in collateral tokens (collateral precision)
     * @param fromBlock block number from which to start fetching prices (for lookbacks)
     * @param isCounterTrade whether corresponding trade is counter trade
     * @param isLookback true if lookback
     * @param job chainlink job id (market/lookback)
     * @param linkFeePerNode link fee distributed per node (1e18 precision)
     * @param nodesCount amount of nodes to fetch prices from
     */
    event PriceRequested(
        uint8 indexed collateralIndex,
        uint256 indexed pairIndex,
        ITradingStorage.PendingOrder pendingOrder,
        uint256 positionSizeCollateral,
        uint256 fromBlock,
        bool isCounterTrade,
        bool isLookback,
        bytes32 job,
        uint256 linkFeePerNode,
        uint256 nodesCount
    );

    /**
     * @dev Emitted when a trading callback is called from the price aggregator
     * @param a aggregator answer data
     * @param orderType order type
     */
    event TradingCallbackExecuted(ITradingCallbacks.AggregatorAnswer a, ITradingStorage.PendingOrderType orderType);

    /**
     * @dev Emitted when a price is received from the oracles
     * @param orderId pending order id
     * @param pairIndex trading pair index
     * @param request chainlink request id
     * @param priceData OrderAnswer compressed into uint256
     * @param isLookback true if lookback
     * @param usedInMedian false if order already fulfilled
     * @param minAnswersReached true if min answers count was reached
     * @param minFilteredAnswersReached true if min answers reached after filtering the ones above max deviation
     * @param unfilteredAnswers unfiltered oracle answers (1e10)
     * @param filteredAnswers filtered oracle answers (1e10)
     */
    event PriceReceived(
        ITradingStorage.Id orderId,
        uint16 indexed pairIndex,
        bytes32 request,
        uint256 priceData,
        bool isLookback,
        bool usedInMedian,
        bool minAnswersReached,
        bool minFilteredAnswersReached,
        IPriceAggregator.OrderAnswer[] unfilteredAnswers,
        IPriceAggregator.OrderAnswer[] filteredAnswers
    );

    /**
     * @dev Emitted when all signed prices have been processed for a pair
     * @param pairIndex trading pair index
     * @param isLookback true if lookback
     * @param fromBlock corresponding from block (for lookbacks)
     * @param minFilteredAnswersReached true if min answers reached after filtering the ones above max deviation
     * @param unfilteredAnswers unfiltered oracle answers (1e10)
     * @param filteredAnswers filtered oracle answers (1e10)
     */
    event SignedPricesReceived(
        uint16 indexed pairIndex,
        bool isLookback,
        uint32 fromBlock,
        bool minFilteredAnswersReached,
        IPriceAggregator.OrderAnswer[] unfilteredAnswers,
        IPriceAggregator.OrderAnswer[] filteredAnswers
    );

    /**
     * @dev Emitted when LINK tokens are claimed back by gov fund
     * @param amountLink amount of LINK tokens claimed back
     */
    event LinkClaimedBack(uint256 amountLink);

    /**
     * @dev Emitted when the count of limit jobs is updated
     * @param limitJobCount the count of limit jobs
     */
    event LimitJobCountUpdated(uint8 limitJobCount);

    /**
     * @dev Emitted when max market order deviation percentage is updated
     * @param maxMarketDeviationP new value (1e3, %)
     */
    event MaxMarketDeviationPUpdated(uint24 maxMarketDeviationP);

    /**
     * @dev Emitted when max lookback order deviation percentage is updated
     * @param maxLookbackDeviationP new value (1e3, %)
     */
    event MaxLookbackDeviationPUpdated(uint24 maxLookbackDeviationP);

    error TransferAndCallToOracleFailed();
    error SourceNotOracleOfRequest();
    error RequestAlreadyPending();
    error OracleAlreadyListed();
    error InvalidCandle();
    error WrongCollateralUsdDecimals();
    error InvalidPoolType();
    error WrongSignaturesCount();
    error WrongSignerIdOrder();
    error InvalidExpiryTimestamp();
    error LookbackMismatch();
    error FromBlockMismatch();
    error InvalidSignature();
    error PairAndCurrentPriceLengthMismatch();
    error PairLengthMismatchBetweenSigners();
    error PairIndexMismatchBetweenSigners();
    error DuplicateOrUnsortedPairIndices();
    error ExpiryTooFar();
    error InvalidCurrentPrice();
    error MinAnswersNotReached();
}
