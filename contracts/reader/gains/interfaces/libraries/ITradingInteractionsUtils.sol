// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/ITradingInteractions.sol";
import "../types/ITradingStorage.sol";
import "../types/IPriceAggregator.sol";
import "../libraries/IUpdateLeverageUtils.sol";
import "../libraries/IUpdatePositionSizeUtils.sol";

/**
 * @dev Interface for GNSTradingInteractions facet (inherits types and also contains functions, events, and custom errors)
 */
interface ITradingInteractionsUtils is ITradingInteractions, IUpdateLeverageUtils, IUpdatePositionSizeUtils {
    /**
     * @dev Initializes the trading facet
     * @param _marketOrdersTimeoutBlocks The number of blocks after which a market order is considered timed out
     */
    function initializeTrading(uint16 _marketOrdersTimeoutBlocks, address[] memory _usersByPassTriggerLink) external;

    /**
     * @dev Updates marketOrdersTimeoutBlocks
     * @param _valueBlocks blocks after which a market order times out
     */
    function updateMarketOrdersTimeoutBlocks(uint16 _valueBlocks) external;

    /**
     * @dev Updates the users that can bypass the link cost of triggerOrder
     * @param _users array of addresses that can bypass the link cost of triggerOrder
     * @param _shouldByPass whether each user should bypass the link cost
     */
    function updateByPassTriggerLink(address[] memory _users, bool[] memory _shouldByPass) external;

    /**
     * @dev Initiates manual holding fees / negative pnl realization for an open trade (sends negative pnl into vault to avoid temporary imbalances due to timing of trades closing)
     * @param _trader trader address
     * @param _index trade index
     * @param _isHoldingFees true if holding fees realization, false if negative pnl realization
     */
    function initiateManualNegativePnlRealization(address _trader, uint32 _index, bool _isHoldingFees) external;

    /**
     * @dev Sets _delegate as the new delegate of caller (can call delegatedAction)
     * @param _delegate the new delegate address
     */
    function setTradingDelegate(address _delegate) external;

    /**
     * @dev Removes the delegate of caller (can't call delegatedAction)
     */
    function removeTradingDelegate() external;

    /**
     * @dev Caller executes a trading action on behalf of _trader using delegatecall
     * @param _trader the trader address to execute the trading action for
     * @param _callData the data to be executed (open trade/close trade, etc.)
     */
    function delegatedTradingAction(address _trader, bytes calldata _callData) external returns (bytes memory);

    /**
     * @dev Opens a new trade/limit order/stop order
     * @param _trade the trade to be opened
     * @param _maxSlippageP the maximum allowed slippage % when open the trade (1e3 precision)
     * @param _referrer the address of the referrer (can only be set once for a trader)
     */
    function openTrade(ITradingStorage.Trade memory _trade, uint16 _maxSlippageP, address _referrer) external;

    /**
     * @dev Wraps native token and opens a new trade/limit order/stop order
     * @param _trade the trade to be opened
     * @param _maxSlippageP the maximum allowed slippage % when open the trade (1e3 precision)
     * @param _referrer the address of the referrer (can only be set once for a trader)
     */
    function openTradeNative(
        ITradingStorage.Trade memory _trade,
        uint16 _maxSlippageP,
        address _referrer
    ) external payable;

    /**
     * @dev Updates existing trade's max closing slippage % for caller
     * @param _index index of trade
     * @param _maxSlippageP new max closing slippage % (1e3 precision)
     */
    function updateMaxClosingSlippageP(uint32 _index, uint16 _maxSlippageP) external;

    /**
     * @dev Closes an open trade (market order) for caller
     * @param _index the index of the trade of caller
     * @param _expectedPrice expected closing price, used to check max slippage (1e10 precision)
     */
    function closeTradeMarket(uint32 _index, uint64 _expectedPrice) external;

    /**
     * @dev Updates an existing limit/stop order for caller
     * @param _index index of limit/stop order of caller
     * @param _triggerPrice new trigger price of limit/stop order (1e10 precision)
     * @param _tp new tp of limit/stop order (1e10 precision)
     * @param _sl new sl of limit/stop order (1e10 precision)
     * @param _maxSlippageP new max slippage % of limit/stop order (1e3 precision)
     */
    function updateOpenOrder(
        uint32 _index,
        uint64 _triggerPrice,
        uint64 _tp,
        uint64 _sl,
        uint16 _maxSlippageP
    ) external;

    /**
     * @dev Cancels an open limit/stop order for caller
     * @param _index index of limit/stop order of caller
     */
    function cancelOpenOrder(uint32 _index) external;

    /**
     * @dev Updates the tp of an open trade for caller
     * @param _index index of open trade of caller
     * @param _newTp new tp of open trade (1e10 precision)
     */
    function updateTp(uint32 _index, uint64 _newTp) external;

    /**
     * @dev Updates the sl of an open trade for caller
     * @param _index index of open trade of caller
     * @param _newSl new sl of open trade (1e10 precision)
     */
    function updateSl(uint32 _index, uint64 _newSl) external;

    /**
     * @dev Initiates a new trigger order (for tp/sl/liq/limit/stop orders)
     * @param _packed the packed data of the trigger order (orderType, trader, index)
     */
    function triggerOrder(uint256 _packed) external;

    /**
     * @dev Triggers an order using signed prices (for tp/sl/liq/limit/stop orders)
     * @param _packed the packed data of the trigger order (orderType, trader, index)
     * @param _signedPairPrices the signed lookback pair prices to be used for the trigger order
     */
    function triggerOrderWithSignatures(
        uint256 _packed,
        IPriceAggregator.SignedPairPrices[] calldata _signedPairPrices
    ) external;

    /**
     * @dev Safety function in case oracles don't answer in time, allows caller to cancel a pending order and if relevant claim back any stuck collateral
     * @dev Only allowed for MARKET_OPEN, MARKET_CLOSE, UPDATE_LEVERAGE, MARKET_PARTIAL_OPEN, and MARKET_PARTIAL_CLOSE orders
     * @param _orderIndex the id of the pending order to cancel
     */
    function cancelOrderAfterTimeout(uint32 _orderIndex) external;

    /**
     * @dev Update trade leverage
     * @param _index index of trade
     * @param _newLeverage new leverage (1e3)
     */
    function updateLeverage(uint32 _index, uint24 _newLeverage) external;

    /**
     * @dev Wraps native tokens and updates trade leverage
     * @param _index index of trade
     * @param _newLeverage new leverage (1e3)
     */
    function updateLeverageNative(uint32 _index, uint24 _newLeverage) external payable;

    /**
     * @dev Increase trade position size
     * @param _index index of trade
     * @param _collateralDelta collateral to add (collateral precision)
     * @param _leverageDelta partial trade leverage (1e3)
     * @param _expectedPrice expected price of execution (1e10 precision)
     * @param _maxSlippageP max slippage % (1e3)
     */
    function increasePositionSize(
        uint32 _index,
        uint120 _collateralDelta,
        uint24 _leverageDelta,
        uint64 _expectedPrice,
        uint16 _maxSlippageP
    ) external;

    /**
     * @dev Wraps native token and increase trade position size
     * @param _index index of trade
     * @param _collateralDelta collateral to add (collateral precision)
     * @param _leverageDelta partial trade leverage (1e3)
     * @param _expectedPrice expected price of execution (1e10 precision)
     * @param _maxSlippageP max slippage % (1e3)
     */
    function increasePositionSizeNative(
        uint32 _index,
        uint120 _collateralDelta,
        uint24 _leverageDelta,
        uint64 _expectedPrice,
        uint16 _maxSlippageP
    ) external payable;

    /**
     * @dev Decrease trade position size
     * @param _index index of trade
     * @param _collateralDelta collateral to remove (collateral precision)
     * @param _leverageDelta leverage to reduce by (1e3)
     * @param _expectedPrice expected closing price, used to check max slippage (1e10 precision)
     */
    function decreasePositionSize(
        uint32 _index,
        uint120 _collateralDelta,
        uint24 _leverageDelta,
        uint64 _expectedPrice
    ) external;

    /**
     * @dev Initiates pnl withdrawal request for a trade
     * @param _index index of the trade
     * @param _amountCollateral amount of pnl to claim in collateral tokens (collateral precision)
     */
    function withdrawPositivePnl(uint32 _index, uint120 _amountCollateral) external;

    /**
     * @dev Returns the wrapped native token or address(0) if the current chain, or the wrapped token, is not supported.
     */
    function getWrappedNativeToken() external view returns (address);

    /**
     * @dev Returns true if the token is the wrapped native token for the current chain, where supported.
     * @param _token token address
     */
    function isWrappedNativeToken(address _token) external view returns (bool);

    /**
     * @dev Returns the address a trader delegates his trading actions to
     * @param _trader address of the trader
     */
    function getTradingDelegate(address _trader) external view returns (address);

    /**
     * @dev Returns the current marketOrdersTimeoutBlocks value
     */
    function getMarketOrdersTimeoutBlocks() external view returns (uint16);

    /**
     * @dev Returns whether a user bypasses trigger link costs
     * @param _user address of the user
     */
    function getByPassTriggerLink(address _user) external view returns (bool);

    /**
     * @dev Emitted when marketOrdersTimeoutBlocks is updated
     * @param newValueBlocks the new value of marketOrdersTimeoutBlocks
     */
    event MarketOrdersTimeoutBlocksUpdated(uint256 newValueBlocks);

    /**
     * @dev Emitted when a user is allowed/disallowed to bypass the link cost of triggerOrder
     * @param user address of the user
     * @param bypass whether the user can bypass the link cost of triggerOrder
     */
    event ByPassTriggerLinkUpdated(address indexed user, bool bypass);

    /**
     * @dev Emitted when a manual negative pnl realization is initiated
     * @param orderId order id
     * @param trader trader address
     * @param index index of trade
     * @param isHoldingFeesRealization whether holding fees or negative pnl realization
     */
    event ManualNegativePnlRealizationInitiated(
        ITradingStorage.Id orderId,
        address indexed trader,
        uint32 indexed index,
        bool isHoldingFeesRealization
    );

    /**
     * @dev Emitted when a market order is initiated
     * @param orderId price aggregator order id of the pending market order
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param open whether the market order is for opening or closing a trade
     */
    event MarketOrderInitiated(ITradingStorage.Id orderId, address indexed trader, uint16 indexed pairIndex, bool open);

    /**
     * @dev Emitted when a new limit/stop order is placed
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param index index of the open limit order for caller
     */
    event OpenOrderPlaced(address indexed trader, uint16 indexed pairIndex, uint32 indexed index);

    /**
     *
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param index index of the open limit/stop order for caller
     * @param newPrice new trigger price (1e10 precision)
     * @param newTp new tp (1e10 precision)
     * @param newSl new sl (1e10 precision)
     * @param maxSlippageP new max slippage % (1e3 precision)
     */
    event OpenLimitUpdated(
        address indexed trader,
        uint16 indexed pairIndex,
        uint32 indexed index,
        uint64 newPrice,
        uint64 newTp,
        uint64 newSl,
        uint64 maxSlippageP
    );

    /**
     * @dev Emitted when a limit/stop order is canceled (collateral sent back to trader)
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param index index of the open limit/stop order for caller
     */
    event OpenLimitCanceled(address indexed trader, uint16 indexed pairIndex, uint32 indexed index);

    /**
     * @dev Emitted when a trader initiates a pnl withdrawal request
     * @param orderId order id
     * @param trader address of the trader
     * @param index index of the trade
     * @param amountCollateral amount of positive pnl to claim in collateral tokens (collateral precision)
     */
    event PositivePnlWithdrawalInitiated(
        ITradingStorage.Id orderId,
        address indexed trader,
        uint32 indexed index,
        uint256 amountCollateral
    );

    /**
     * @dev Emitted when a trigger order is initiated (tp/sl/liq/limit/stop orders)
     * @param orderId price aggregator order id of the pending trigger order
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param byPassesLinkCost whether the caller bypasses the link cost
     */
    event TriggerOrderInitiated(
        ITradingStorage.Id orderId,
        address indexed trader,
        uint16 indexed pairIndex,
        bool byPassesLinkCost
    );

    /**
     * @dev Emitted when a pending market order is canceled due to timeout
     * @param pendingOrderId id of the pending order
     * @param pairIndex index of the trading pair
     */
    event ChainlinkCallbackTimeout(ITradingStorage.Id pendingOrderId, uint256 indexed pairIndex);

    /**
     * @dev Emitted when a pending market order is canceled due to timeout and new closeTradeMarket() call failed
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param index index of the open trade for caller
     */
    event CouldNotCloseTrade(address indexed trader, uint16 indexed pairIndex, uint32 indexed index);

    /**
     * @dev Emitted when a native token is wrapped
     * @param trader address of the trader
     * @param nativeTokenAmount amount of native token wrapped
     */
    event NativeTokenWrapped(address indexed trader, uint256 nativeTokenAmount);

    /**
     * @dev Emitted when a trade's collateral is returned after timeout
     * @param pendingOrderId corresponding order id
     * @param collateralIndex index of collateral
     * @param trader trader address
     * @param collateralAmount collateral amount returned (collateral precision)
     */
    event CollateralReturnedAfterTimeout(
        ITradingStorage.Id pendingOrderId,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint256 collateralAmount
    );

    error NotWrappedNativeToken();
    error DelegateNotApproved();
    error PriceZero();
    error CollateralNotActive();
    error PriceImpactTooHigh();
    error NoTrade();
    error NoOrder();
    error AlreadyBeingMarketClosed();
    error ConflictingPendingOrder(ITradingStorage.PendingOrderType);
    error WrongLeverage();
    error WrongTp();
    error WrongSl();
    error WaitTimeout();
    error PendingTrigger();
    error NoSl();
    error NoTp();
    error NotYourOrder();
    error DelegatedActionNotAllowed();
    error InsufficientCollateral();
    error WrongFromBlock();
}
