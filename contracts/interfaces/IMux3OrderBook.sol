// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

enum OrderType {
    None, // 0
    PositionOrder, // 1
    LiquidityOrder, // 2
    WithdrawalOrder, // 3
    RebalanceOrder, // 4
    AdlOrder, // 5
    LiquidateOrder // 6
}

struct OrderData {
    uint64 id;
    address account;
    OrderType orderType;
    uint8 version;
    uint64 placeOrderTime;
    uint64 gasFeeGwei;
    bytes payload;
}

interface IMux3OrderBook {
    struct PositionOrderParams {
        bytes32 positionId;
        bytes32 marketId;
        uint256 size;
        uint256 flags; // see "constant POSITION_*"
        uint256 limitPrice; // decimals = 18
        uint64 expiration; // timestamp. decimals = 0
        address lastConsumedToken; // when paying fees or losses (for both open and close positions), this token will be consumed last. can be 0 if no preference
        // when openPosition
        // * collateralToken == 0 means do not deposit collateral
        // * collateralToken != 0 means to deposit collateralToken as collateral
        // * deduct fees
        // * open positions
        address collateralToken; // only valid when flags.POSITION_OPEN
        uint256 collateralAmount; // only valid when flags.POSITION_OPEN. erc20.decimals
        // when closePosition, pnl and fees
        // * realize pnl
        // * deduct fees
        // * flags.POSITION_WITHDRAW_PROFIT means also withdraw (profit - fee)
        // * withdrawUsd means to withdraw collateral. this is independent of flags.POSITION_WITHDRAW_PROFIT
        // * flags.POSITION_UNWRAP_ETH means to unwrap WETH into ETH
        uint256 withdrawUsd; // only valid when close a position
        address withdrawSwapToken; // only valid when close a position and withdraw. try to swap to this token
        uint256 withdrawSwapSlippage; // only valid when close a position and withdraw. slippage tolerance for withdrawSwapToken. if swap cannot achieve this slippage, swap will be skipped
        // tpsl strategy, only valid when openPosition
        uint256 tpPriceDiff; // take-profit price will be marketPrice * diff. decimals = 18. only valid when flags.POSITION_TPSL_STRATEGY
        uint256 slPriceDiff; // stop-loss price will be marketPrice * diff. decimals = 18. only valid when flags.POSITION_TPSL_STRATEGY
        uint64 tpslExpiration; // timestamp. decimals = 0. only valid when flags.POSITION_TPSL_STRATEGY
        uint256 tpslFlags; // POSITION_WITHDRAW_ALL_IF_EMPTY, POSITION_WITHDRAW_PROFIT, POSITION_UNWRAP_ETH. only valid when flags.POSITION_TPSL_STRATEGY
        address tpslWithdrawSwapToken; // only valid when flags.POSITION_TPSL_STRATEGY
        uint256 tpslWithdrawSwapSlippage; // only valid when flags.POSITION_TPSL_STRATEGY
    }

    /**
     * @notice Trader/LP can wrap native ETH to WETH and WETH will stay in OrderBook for subsequent commands
     * @param amount Amount of ETH to wrap
     * @dev Amount must be greater than 0 and less than or equal to msg.value
     */
    function wrapNative(uint256 amount) external payable;

    /**
     * @notice Trader/LP transfer ERC20 tokens to the OrderBook
     * @param token Address of the token to transfer
     * @param amount Amount of tokens to transfer
     */
    function transferToken(address token, uint256 amount) external payable;

    /**
     * @notice Allows Delegator to transfer tokens from Trader/LP to OrderBook
     * @param from Address to transfer tokens from
     * @param token Address of the token to transfer
     * @param amount Amount of tokens to transfer
     */
    function transferTokenFrom(address from, address token, uint256 amount) external payable;

    /**
     * @notice Trader/LP should pay for gas for their orders
     *         you should pay at least configValue(MCO_ORDER_GAS_FEE_GWEI) * 1e9 / 1e18 ETH for each order
     * @param amount The amount of gas to deposit
     */
    function depositGas(address account, uint256 amount) external payable;

    /**
     * @notice A trader should set initial leverage at least once before open-position
     * @param positionId The ID of the position
     * @param marketId The ID of the market
     * @param initialLeverage The initial leverage to set
     */
    function setInitialLeverage(bytes32 positionId, bytes32 marketId, uint256 initialLeverage) external payable;

    /**
     * @notice A Trader can open/close position
     *         Market order will expire after marketOrderTimeout seconds.
     *         Limit/Trigger order will expire after deadline.
     * @param orderParams The parameters for the position order
     * @param referralCode The referral code for the position order
     */
    function placePositionOrder(PositionOrderParams memory orderParams, bytes32 referralCode) external payable;

    function getOrder(uint64 orderId) external view returns (OrderData memory, bool);

    /**
     * @notice A Trader/LP can cancel an Order by orderId after a cool down period.
     *         A Broker can also cancel an Order after expiration.
     */
    function cancelOrder(uint64 orderId) external payable;
}
