// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/ITradingCallbacks.sol";
import "../libraries/IUpdateLeverageUtils.sol";
import "../libraries/IUpdatePositionSizeUtils.sol";
import "../libraries/ITradingCommonUtils.sol";

/**
 * @dev Interface for GNSTradingCallbacks facet (inherits types and also contains functions, events, and custom errors)
 */
interface ITradingCallbacksUtils is
    ITradingCallbacks,
    IUpdateLeverageUtils,
    IUpdatePositionSizeUtils,
    ITradingCommonUtils
{
    /**
     *
     * @param _vaultClosingFeeP the % of closing fee going to vault
     */
    function initializeCallbacks(uint8 _vaultClosingFeeP) external;

    /**
     * @dev Initialize the treasury address
     * @param _treasury the treasury address
     */
    function initializeTreasuryAddress(address _treasury) external;

    /**
     * @dev Update the % of closing fee going to vault
     * @param _valueP the % of closing fee going to vault
     */
    function updateVaultClosingFeeP(uint8 _valueP) external;

    /**
     * @dev Updates the treasury address
     * @param _treasury the new treasury address
     */
    function updateTreasuryAddress(address _treasury) external;

    /**
     * @dev Claim the pending gov fees for all collaterals
     */
    function claimPendingGovFees() external;

    /**
     * @dev Executes a pending open trade market order
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function openTradeMarketCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes a pending close trade market order
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function closeTradeMarketCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes a pending open trigger order (for limit/stop orders)
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function executeTriggerOpenOrderCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes open trigger directly (for limit/stop orders)
     * @param _a the price aggregator answer (order id, price, etc.)
     * @param _trade the trade object to execute the trigger for
     * @param _orderType the pending order type
     * @param _initiator the address that initiated the trigger execution
     */
    function executeTriggerOpenOrderCallbackDirect(
        ITradingCallbacks.AggregatorAnswer memory _a,
        ITradingStorage.Trade memory _trade,
        ITradingStorage.PendingOrderType _orderType,
        address _initiator
    ) external;

    /**
     * @dev Executes a pending close trigger order (for tp/sl/liq orders)
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function executeTriggerCloseOrderCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes close trigger directly (for tp/sl/liq orders)
     * @param _a the price aggregator answer (order id, price, etc.)
     * @param _trade the trade object to execute the trigger for
     * @param _orderType the pending order type
     * @param _initiator the address that initiated the trigger execution
     */
    function executeTriggerCloseOrderCallbackDirect(
        ITradingCallbacks.AggregatorAnswer memory _a,
        ITradingStorage.Trade memory _trade,
        ITradingStorage.PendingOrderType _orderType,
        address _initiator
    ) external;

    /**
     * @dev Executes a pending update leverage order
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function updateLeverageCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes a pending increase position size market order
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function increasePositionSizeMarketCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes a pending decrease position size market order
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function decreasePositionSizeMarketCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes a pending pnl withdrawal
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function pnlWithdrawalCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes a pending holding fees realization
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function manualHoldingFeesRealizationCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Executes a pending negative pnl realization
     * @param _a the price aggregator answer (order id, price, etc.)
     */
    function manualNegativePnlRealizationCallback(AggregatorAnswer memory _a) external;

    /**
     * @dev Returns the current vaultClosingFeeP value (%)
     */
    function getVaultClosingFeeP() external view returns (uint8);

    /**
     * @dev Returns the current pending gov fees for a collateral index (collateral precision)
     */
    function getPendingGovFeesCollateral(uint8 _collateralIndex) external view returns (uint256);

    /**
     * @dev Makes open trigger (STOP/LIMIT) checks like slippage, price impact, missed targets and returns cancellation reason if any
     * @param _tradeId the id of the trade
     * @param _orderType the pending order type
     * @param _open the open value of the candle to check (1e10)
     * @param _high the high value of the candle to check (1e10)
     * @param _low the low value of the candle to check (1e10)
     * @param _currentPairPrice the current pair price (1e10)
     */
    function validateTriggerOpenOrderCallback(
        ITradingStorage.Id memory _tradeId,
        ITradingStorage.PendingOrderType _orderType,
        uint64 _open,
        uint64 _high,
        uint64 _low,
        uint64 _currentPairPrice
    ) external view returns (ITradingStorage.Trade memory t, ITradingCallbacks.Values memory v);

    /**
     * @dev Makes close trigger (SL/TP/LIQ) checks like slippage and price impact and returns cancellation reason if any
     * @param _tradeId the id of the trade
     * @param _orderType the pending order type
     * @param _open the open value of the candle to check (1e10)
     * @param _high the high value of the candle to check (1e10)
     * @param _low the low value of the candle to check (1e10)
     * @param _currentPairPrice the current pair price (1e10)
     */
    function validateTriggerCloseOrderCallback(
        ITradingStorage.Id memory _tradeId,
        ITradingStorage.PendingOrderType _orderType,
        uint64 _open,
        uint64 _high,
        uint64 _low,
        uint64 _currentPairPrice
    ) external view returns (ITradingStorage.Trade memory t, ITradingCallbacks.Values memory v);

    /**
     * @dev Emitted when vaultClosingFeeP is updated
     * @param valueP the % of closing fee going to vault
     */
    event VaultClosingFeePUpdated(uint8 valueP);

    /**
     * @dev Emitted when gov fees are claimed for a collateral
     * @param collateralIndex the collateral index
     * @param amountCollateral the amount of fees claimed (collateral precision)
     */
    event PendingGovFeesClaimed(uint8 collateralIndex, uint256 amountCollateral);

    /**
     * @dev Emitted when a market order is executed (open/close)
     * @param orderId the id of the corresponding pending market order
     * @param user trade user
     * @param index trade index
     * @param t the trade object
     * @param open true for a market open order, false for a market close order
     * @param oraclePrice the oracle price without spread/impact (1e10 precision)
     * @param marketPrice the price at which the trade was executed (1e10 precision)
     * @param liqPrice trade liquidation price (1e10 precision)
     * @param priceImpact price impact details
     * @param percentProfit the profit in percentage (1e10 precision)
     * @param amountSentToTrader the final amount of collateral sent to the trader
     * @param collateralPriceUsd the price of the collateral in USD (1e8 precision)
     */
    event MarketExecuted(
        ITradingStorage.Id orderId,
        address indexed user,
        uint32 indexed index,
        ITradingStorage.Trade t,
        bool open,
        uint256 oraclePrice,
        uint256 marketPrice,
        uint256 liqPrice,
        ITradingCommonUtils.TradePriceImpact priceImpact,
        int256 percentProfit, // before fees
        uint256 amountSentToTrader,
        uint256 collateralPriceUsd // 1e8
    );

    /**
     * @dev Emitted when a limit/stop order is executed
     * @param orderId the id of the corresponding pending trigger order
     * @param user trade user
     * @param index trade index
     * @param limitIndex limit index
     * @param t the trade object
     * @param triggerCaller the address that triggered the limit order
     * @param orderType the type of the pending order
     * @param oraclePrice the oracle price without spread/impact (1e10 precision)
     * @param marketPrice the price at which the trade was executed (1e10 precision)
     * @param liqPrice trade liquidation price (1e10 precision)
     * @param priceImpact price impact details
     * @param percentProfit the profit in percentage (1e10 precision)
     * @param amountSentToTrader the final amount of collateral sent to the trader
     * @param collateralPriceUsd the price of the collateral in USD (1e8 precision)
     * @param exactExecution true if guaranteed execution was used
     */
    event LimitExecuted(
        ITradingStorage.Id orderId,
        address indexed user,
        uint32 indexed index,
        uint32 indexed limitIndex,
        ITradingStorage.Trade t,
        address triggerCaller,
        ITradingStorage.PendingOrderType orderType,
        uint256 oraclePrice,
        uint256 marketPrice,
        uint256 liqPrice,
        ITradingCommonUtils.TradePriceImpact priceImpact,
        int256 percentProfit,
        uint256 amountSentToTrader,
        uint256 collateralPriceUsd, // 1e8
        bool exactExecution
    );

    /**
     * @dev Emitted when a pending market open order is canceled
     * @param orderId order id of the pending market open order
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param cancelReason reason for the cancellation
     * @param collateralReturned collateral returned to trader (collateral precision)
     */
    event MarketOpenCanceled(
        ITradingStorage.Id orderId,
        address indexed trader,
        uint256 indexed pairIndex,
        CancelReason cancelReason,
        uint256 collateralReturned
    );

    /**
     * @dev Emitted when a pending market close order is canceled
     * @param orderId order id of the pending market close order
     * @param trader address of the trader
     * @param pairIndex index of the trading pair
     * @param index index of the trade for trader
     * @param cancelReason reason for the cancellation
     */
    event MarketCloseCanceled(
        ITradingStorage.Id orderId,
        address indexed trader,
        uint256 indexed pairIndex,
        uint256 indexed index,
        CancelReason cancelReason
    );

    /**
     * @dev Emitted when a pending trigger order is canceled
     * @param orderId order id of the pending trigger order
     * @param triggerCaller address of the trigger caller
     * @param orderType type of the pending trigger order
     * @param cancelReason reason for the cancellation
     */
    event TriggerOrderCanceled(
        ITradingStorage.Id orderId,
        address indexed triggerCaller,
        ITradingStorage.PendingOrderType orderType,
        CancelReason cancelReason
    );

    /**
     * @dev Emitted when a trade's holding fees are manually realized
     * @param orderId corresponding order id
     * @param collateralIndex collateral index
     * @param trader address of the trader
     * @param index index of the trade
     * @param currentPairPrice current pair price (1e10 precision)
     */
    event TradeHoldingFeesManuallyRealized(
        ITradingStorage.Id orderId,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint32 indexed index,
        uint256 currentPairPrice
    );

    /**
     * @dev Emitted when positive pnl is claimed on an open trade
     * @param orderId corresponding order id
     * @param collateralIndex collateral index
     * @param trader address of the trader
     * @param index index of the trade
     * @param priceImpact closing price impact details
     * @param pnlPercent raw trade pnl percent (1e10 precision)
     * @param withdrawablePositivePnlCollateral maximum withdrawable positive pnl in collateral tokens (collateral precision)
     * @param currentPairPrice current pair price (1e10 precision)
     * @param pnlInputCollateral input for amount of positive pnl to withdraw (collateral precision)
     * @param pnlWithdrawnCollateral final positive pnl withdrawn in collateral tokens (collateral precision)
     */
    event TradePositivePnlWithdrawn(
        ITradingStorage.Id orderId,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint32 indexed index,
        ITradingCommonUtils.TradePriceImpact priceImpact,
        int256 pnlPercent,
        int256 withdrawablePositivePnlCollateral,
        uint256 currentPairPrice,
        uint256 pnlInputCollateral,
        uint256 pnlWithdrawnCollateral
    );

    /**
     * @dev Emitted when a trade's negative pnl is manually realized
     * @param orderId corresponding order id
     * @param collateralIndex collateral index
     * @param trader address of the trader
     * @param index index of the trade
     * @param negativePnlCollateral current negative pnl in collateral tokens (collateral precision)
     * @param existingManuallyRealizedNegativePnlCollateral existing manually realized negative pnl in collateral tokens (collateral precision)
     * @param newManuallyRealizedNegativePnlCollateral new manually realized negative pnl in collateral tokens (collateral precision)
     * @param currentPairPrice current pair price (1e10 precision)
     */
    event TradeNegativePnlManuallyRealized(
        ITradingStorage.Id orderId,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint32 indexed index,
        uint256 negativePnlCollateral,
        uint256 existingManuallyRealizedNegativePnlCollateral,
        uint256 newManuallyRealizedNegativePnlCollateral,
        uint256 currentPairPrice
    );

    /**
     * @dev Emitted when excess counter trade collateral is returned to trader
     * @param orderId corresponding order id
     * @param collateralIndex collateral index
     * @param trader trader address
     * @param collateralReturned collateral amount returned to trader (collateral precision)
     */
    event CounterTradeCollateralReturned(
        ITradingStorage.Id orderId,
        uint8 indexed collateralIndex,
        address indexed trader,
        uint256 collateralReturned
    );

    error PendingOrderNotOpen();
}
