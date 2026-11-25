// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/ITradingStorage.sol";

/**
 * @dev Interface for GNSTradingStorage facet (inherits types and also contains functions, events, and custom errors)
 */
interface ITradingStorageUtils is ITradingStorage {
    /**
     * @dev Initializes the trading storage facet
     * @param _gns address of the gns token
     * @param _gnsStaking address of the gns staking contract
     * @param _collaterals collateral addresses to add
     * @param _gTokens corresponding gToken vault addresses
     */
    function initializeTradingStorage(
        address _gns,
        address _gnsStaking,
        address[] memory _collaterals,
        address[] memory _gTokens
    ) external;

    /**
     * @dev Updates the trading activated state
     * @param _activated the new trading activated state
     */
    function updateTradingActivated(TradingActivated _activated) external;

    /**
     * @dev Lists a new supported collateral (disabled by default).
     * @dev Important: updateCollateralGnsLiquidityPool, updateCollateralUsdPriceFeed, and toggleCollateralActiveState must be called after this function.
     * @param _collateral the address of the collateral
     * @param _gToken the gToken contract of the collateral
     */
    function addCollateral(address _collateral, address _gToken) external;

    /**
     * @dev Toggles the active state of a supported collateral
     * @param _collateralIndex index of the collateral
     */
    function toggleCollateralActiveState(uint8 _collateralIndex) external;

    /**
     * @dev Updates the contracts of a supported collateral trading stack
     * @param _collateral address of the collateral
     * @param _gToken the gToken contract of the collateral
     */
    function updateGToken(address _collateral, address _gToken) external;

    /**
     * @dev Stores a new trade (trade/limit/stop)
     * @param _trade trade to be stored
     * @param _tradeInfo trade info to be stored
     * @param _currentPairPrice the current pair price (1e10)
     */
    function storeTrade(
        Trade memory _trade,
        TradeInfo memory _tradeInfo,
        uint64 _currentPairPrice
    ) external returns (Trade memory);

    /**
     * @dev Updates an existing trade max closing slippage %
     * @param _tradeId id of the trade
     * @param _maxSlippageP new max slippage % (1e3 precision)
     */
    function updateTradeMaxClosingSlippageP(ITradingStorage.Id memory _tradeId, uint16 _maxSlippageP) external;

    /**
     * @dev Updates an open trade collateral
     * @param _tradeId id of updated trade
     * @param _collateralAmount new collateral amount value (collateral precision)
     * @param _leverage new leverage value
     * @param _openPrice new open price value
     * @param _pendingOrderType corresponding pending order type (ignore dust OI delta for leverage updates, refresh trade liq params for partial adds)
     * @param _positionSizeTokenDelta position size token delta (1e18)
     * @param _isPnlPositive whether the pnl is positive (only relevant when closing)
     * @param _currentPairPrice the current pair price (1e10)
     */
    function updateTradePosition(
        Id memory _tradeId,
        uint120 _collateralAmount,
        uint24 _leverage,
        uint64 _openPrice,
        ITradingStorage.PendingOrderType _pendingOrderType,
        uint256 _positionSizeTokenDelta,
        bool _isPnlPositive,
        uint64 _currentPairPrice
    ) external;

    /**
     * @dev Updates an open order details (limit/stop)
     * @param _tradeId id of updated trade
     * @param _openPrice new open price (1e10)
     * @param _tp new take profit price (1e10)
     * @param _sl new stop loss price (1e10)
     * @param _maxSlippageP new max slippage % value (1e3)
     */
    function updateOpenOrderDetails(
        Id memory _tradeId,
        uint64 _openPrice,
        uint64 _tp,
        uint64 _sl,
        uint16 _maxSlippageP
    ) external;

    /**
     * @dev Updates the take profit of an open trade
     * @param _tradeId the trade id
     * @param _newTp the new take profit (1e10 precision)
     */
    function updateTradeTp(Id memory _tradeId, uint64 _newTp) external;

    /**
     * @dev Updates the stop loss of an open trade
     * @param _tradeId the trade id
     * @param _newSl the new sl (1e10 precision)
     */
    function updateTradeSl(Id memory _tradeId, uint64 _newSl) external;

    /**
     * @dev Marks an open trade/limit/stop as closed
     * @param _tradeId the trade id
     * @param _isPnlPositive whether the pnl is positive
     * @param _currentPairPrice the current pair price (1e10)
     */
    function closeTrade(Id memory _tradeId, bool _isPnlPositive, uint64 _currentPairPrice) external;

    /**
     * @dev Stores a new pending order
     * @param _pendingOrder the pending order to be stored
     */
    function storePendingOrder(PendingOrder memory _pendingOrder) external returns (PendingOrder memory);

    /**
     * @dev Closes a pending order
     * @param _orderId the id of the pending order to be closed
     */
    function closePendingOrder(Id memory _orderId) external;

    /**
     * @dev Validates an open trade order (for all order types apart from MARKET_OPEN)
     * @param _trade the trade to validate
     * @param _orderType the pending order type to validate
     */
    function validateOpenTradeOrder(Trade memory _trade, PendingOrderType _orderType) external view;

    /**
     * @dev Returns collateral data by index
     * @param _index the index of the supported collateral
     */
    function getCollateral(uint8 _index) external view returns (Collateral memory);

    /**
     * @dev Returns whether can open new trades with a collateral
     * @param _index the index of the collateral to check
     */
    function isCollateralActive(uint8 _index) external view returns (bool);

    /**
     * @dev Returns whether a collateral has been listed
     * @param _index the index of the collateral to check
     */
    function isCollateralListed(uint8 _index) external view returns (bool);

    /**
     * @dev Returns whether a collateral is the GNS token
     * @param _index the index of the collateral to check
     */
    function isCollateralGns(uint8 _index) external view returns (bool);

    /**
     * @dev Returns the number of supported collaterals
     */
    function getCollateralsCount() external view returns (uint8);

    /**
     * @dev Returns the supported collaterals
     */
    function getCollaterals() external view returns (Collateral[] memory);

    /**
     * @dev Returns the index of a supported collateral
     * @param _collateral the address of the collateral
     */
    function getCollateralIndex(address _collateral) external view returns (uint8);

    /**
     * @dev Returns the collateral index of the GNS token. If 0, GNS is not a collateral.
     */
    function getGnsCollateralIndex() external view returns (uint8);

    /**
     * @dev Returns the trading activated state
     */
    function getTradingActivated() external view returns (TradingActivated);

    /**
     * @dev Returns whether a trader is stored in the traders array
     * @param _trader trader to check
     */
    function getTraderStored(address _trader) external view returns (bool);

    /**
     * @dev Returns the length of the traders array
     */
    function getTradersCount() external view returns (uint256);

    /**
     * @dev Returns all traders that have open trades using a pagination system
     * @param _offset start index in the traders array
     * @param _limit end index in the traders array
     */
    function getTraders(uint32 _offset, uint32 _limit) external view returns (address[] memory);

    /**
     * @dev Returns open trade/limit/stop order
     * @param _trader address of the trader
     * @param _index index of the trade for trader
     */
    function getTrade(address _trader, uint32 _index) external view returns (Trade memory);

    /**
     * @dev Returns all open trades/limit/stop orders for a trader
     * @param _trader address of the trader
     */
    function getTrades(address _trader) external view returns (Trade[] memory);

    /**
     * @dev Returns all trade/limit/stop orders using a pagination system
     * @param _traders list of traders to return trades for
     * @param _offset index of first trade to return
     * @param _limit index of last trade to return
     */
    function getAllTradesForTraders(
        address[] memory _traders,
        uint256 _offset,
        uint256 _limit
    ) external view returns (Trade[] memory);

    /**
     * @dev Returns all trade/limit/stop orders using a pagination system.
     * @dev Calls `getAllTradesForTraders` internally with all traders.
     * @param _offset index of first trade to return
     * @param _limit index of last trade to return
     */
    function getAllTrades(uint256 _offset, uint256 _limit) external view returns (Trade[] memory);

    /**
     * @dev Returns trade info of an open trade/limit/stop order
     * @param _trader address of the trader
     * @param _index index of the trade for trader
     */
    function getTradeInfo(address _trader, uint32 _index) external view returns (TradeInfo memory);

    /**
     * @dev Returns all trade infos of open trade/limit/stop orders for a trader
     * @param _trader address of the trader
     */
    function getTradeInfos(address _trader) external view returns (TradeInfo[] memory);

    /**
     * @dev Returns all trade infos of open trade/limit/stop orders using a pagination system
     * @param _traders list of traders to return tradeInfo for
     * @param _offset index of first tradeInfo to return
     * @param _limit index of last tradeInfo to return
     */
    function getAllTradeInfosForTraders(
        address[] memory _traders,
        uint256 _offset,
        uint256 _limit
    ) external view returns (TradeInfo[] memory);

    /**
     * @dev Returns all trade infos of open trade/limit/stop orders using a pagination system.
     * @dev Calls `getAllTradeInfosForTraders` internally with all traders.
     * @param _offset index of first tradeInfo to return
     * @param _limit index of last tradeInfo to return
     */
    function getAllTradeInfos(uint256 _offset, uint256 _limit) external view returns (TradeInfo[] memory);

    /**
     * @dev Returns a pending ordeer
     * @param _orderId id of the pending order
     */
    function getPendingOrder(Id memory _orderId) external view returns (PendingOrder memory);

    /**
     * @dev Returns all pending orders for a trader
     * @param _user address of the trader
     */
    function getPendingOrders(address _user) external view returns (PendingOrder[] memory);

    /**
     * @dev Returns all pending orders using a pagination system
     * @param _traders list of traders to return pendingOrder for
     * @param _offset index of first pendingOrder to return
     * @param _limit index of last pendingOrder to return
     */
    function getAllPendingOrdersForTraders(
        address[] memory _traders,
        uint256 _offset,
        uint256 _limit
    ) external view returns (PendingOrder[] memory);

    /**
     * @dev Returns all pending orders using a pagination system
     * @dev Calls `getAllPendingOrdersForTraders` internally with all traders.
     * @param _offset index of first pendingOrder to return
     * @param _limit index of last pendingOrder to return
     */
    function getAllPendingOrders(uint256 _offset, uint256 _limit) external view returns (PendingOrder[] memory);

    /**
     * @dev Returns the block number of the pending order for a trade (0 = doesn't exist)
     * @param _tradeId id of the trade
     * @param _orderType pending order type to check
     */
    function getTradePendingOrderBlock(Id memory _tradeId, PendingOrderType _orderType) external view returns (uint256);

    /**
     * @dev Returns the counters of a trader (currentIndex / open count for trades/tradeInfos and pendingOrders mappings)
     * @param _trader address of the trader
     * @param _type the counter type (trade/pending order)
     */
    function getCounters(address _trader, CounterType _type) external view returns (Counter memory);

    /**
     * @dev Returns the counters for a list of traders
     * @param _traders the list of traders
     * @param _type the counter type (trade/pending order)
     */
    function getCountersForTraders(
        address[] calldata _traders,
        CounterType _type
    ) external view returns (Counter[] memory);

    /**
     * @dev Returns the address of the gToken for a collateral stack
     * @param _collateralIndex the index of the supported collateral
     */
    function getGToken(uint8 _collateralIndex) external view returns (address);

    /**
     * @dev Returns the liquidation params for a trade
     * @param _trader address of the trader
     * @param _index index of the trade for trader
     */
    function getTradeLiquidationParams(
        address _trader,
        uint32 _index
    ) external view returns (IPairsStorage.GroupLiquidationParams memory);

    /**
     * @dev Returns all trade liquidation params of open trade/limit/stop orders for a trader
     * @param _trader address of the trader
     */
    function getTradesLiquidationParams(
        address _trader
    ) external view returns (IPairsStorage.GroupLiquidationParams[] memory);

    /**
     * @dev Returns all trade liquidation params of open trade/limit/stop orders using a pagination system
     * @param _traders list of traders to return liq params for
     * @param _offset index of first liq param to return
     * @param _limit index of last liq param to return
     */
    function getAllTradesLiquidationParamsForTraders(
        address[] memory _traders,
        uint256 _offset,
        uint256 _limit
    ) external view returns (IPairsStorage.GroupLiquidationParams[] memory);

    /**
     * @dev Returns all trade liquidation params of open trade/limit/stop orders using a pagination system
     * @dev Calls `getAllTradesLiquidationParamsForTraders` internally with all traders.
     * @param _offset index of first liq param to return
     * @param _limit index of last liq param to return
     */
    function getAllTradesLiquidationParams(
        uint256 _offset,
        uint256 _limit
    ) external view returns (IPairsStorage.GroupLiquidationParams[] memory);

    /**
     * @dev Returns the current contracts version
     */
    function getCurrentContractsVersion() external view returns (ITradingStorage.ContractsVersion);

    /**
     * @dev Returns the contracts version for a trade
     * @param _trader address of the trader
     * @param _index index of the trade
     */
    function getTradeContractsVersion(
        address _trader,
        uint32 _index
    ) external view returns (ITradingStorage.ContractsVersion);

    /**
     * @dev Returns the corresponding lookback fromBlock for a trigger
     * @param _trader address of the trader
     * @param _index index of the trade
     * @param _orderType trigger order type
     */
    function getLookbackFromBlock(
        address _trader,
        uint32 _index,
        ITradingStorage.PendingOrderType _orderType
    ) external view returns (uint32);

    /**
     * @dev Emitted when the trading activated state is updated
     * @param activated the new trading activated state
     */
    event TradingActivatedUpdated(TradingActivated activated);

    /**
     * @dev Emitted when a new supported collateral is added
     * @param collateral the address of the collateral
     * @param index the index of the supported collateral
     * @param gToken the gToken contract of the collateral
     */
    event CollateralAdded(address collateral, uint8 index, address gToken);

    /**
     * @dev Emitted when an existing supported collateral active state is updated
     * @param index the index of the supported collateral
     * @param isActive the new active state
     */
    event CollateralUpdated(uint8 indexed index, bool isActive);

    /**
     * @dev Emitted when an existing supported collateral is disabled (can still close trades but not open new ones)
     * @param index the index of the supported collateral
     */
    event CollateralDisabled(uint8 index);

    /**
     * @dev Emitted when the contracts of a supported collateral trading stack are updated
     * @param collateral the address of the collateral
     * @param index the index of the supported collateral
     * @param gToken the gToken contract of the collateral
     */
    event GTokenUpdated(address collateral, uint8 index, address gToken);

    /**
     * @dev Emitted when a new trade is stored
     * @param user trade user
     * @param index trade index
     * @param trade the trade stored
     * @param tradeInfo the trade info stored
     * @param liquidationParams the trade liquidation params stored
     */
    event TradeStored(
        address indexed user,
        uint32 indexed index,
        Trade trade,
        TradeInfo tradeInfo,
        IPairsStorage.GroupLiquidationParams liquidationParams
    );

    /**
     * @dev Emitted when the max closing slippage % of an open trade is updated
     * @param user trade user
     * @param index trade index
     * @param maxClosingSlippageP new max closing slippage % value (1e3 precision)
     */
    event TradeMaxClosingSlippagePUpdated(address indexed user, uint32 indexed index, uint16 maxClosingSlippageP);

    /**
     * @dev Emitted when an open trade collateral is updated
     * @param user trade user
     * @param index trade index
     * @param collateralAmount new collateral value (collateral precision)
     */
    event TradeCollateralUpdated(address indexed user, uint32 indexed index, uint120 collateralAmount);

    /**
     * @dev Emitted when an open trade collateral is updated
     * @param user trade user
     * @param index trade index
     * @param collateralAmount new collateral value (collateral precision)
     * @param leverage new leverage value (1e3)
     * @param openPrice new open price value (1e10)
     * @param newSl new sl price (1e10)
     * @param newPositionSizeToken new position size in token amount (1e18)
     * @param pendingOrderType corresponding pending order type
     * @param isPnlPositive true if trade pnl is positive (only relevant when closing)
     */
    event TradePositionUpdated(
        address indexed user,
        uint32 indexed index,
        uint120 collateralAmount,
        uint24 leverage,
        uint64 openPrice,
        uint64 newSl,
        uint160 newPositionSizeToken,
        ITradingStorage.PendingOrderType pendingOrderType,
        bool isPnlPositive
    );

    /**
     * @dev Emitted when an existing trade/limit order/stop order is updated
     * @param user trade user
     * @param index trade index
     * @param openPrice new open price value (1e10)
     * @param tp new take profit value (1e10)
     * @param sl new stop loss value (1e10)
     * @param maxSlippageP new max slippage % value (1e3)
     */
    event OpenOrderDetailsUpdated(
        address indexed user,
        uint32 indexed index,
        uint64 openPrice,
        uint64 tp,
        uint64 sl,
        uint16 maxSlippageP
    );

    /**
     * @dev Emitted when the take profit of an open trade is updated
     * @param user trade user
     * @param index trade index
     * @param newTp the new take profit (1e10 precision)
     */
    event TradeTpUpdated(address indexed user, uint32 indexed index, uint64 newTp);

    /**
     * @dev Emitted when the stop loss of an open trade is updated
     * @param user trade user
     * @param index trade index
     * @param newSl the new sl (1e10 precision)
     */
    event TradeSlUpdated(address indexed user, uint32 indexed index, uint64 newSl);

    /**
     * @dev Emitted when an open trade is closed
     * @param user trade user
     * @param index trade index
     * @param isPnlPositive true if trade pnl is positive
     */
    event TradeClosed(address indexed user, uint32 indexed index, bool isPnlPositive);

    /**
     * @dev Emitted when a new pending order is stored
     * @param pendingOrder the pending order stored
     */
    event PendingOrderStored(PendingOrder pendingOrder);

    /**
     * @dev Emitted when a pending order is closed
     * @param orderId the id of the pending order closed
     */
    event PendingOrderClosed(Id orderId);

    error MissingCollaterals();
    error CollateralAlreadyActive();
    error CollateralAlreadyDisabled();
    error TradePositionSizeZero();
    error TradeOpenPriceZero();
    error TradePairNotListed();
    error TradeTpInvalid();
    error TradeSlInvalid();
    error MaxSlippageZero();
    error TradeInfoCollateralPriceUsdZero();
}
