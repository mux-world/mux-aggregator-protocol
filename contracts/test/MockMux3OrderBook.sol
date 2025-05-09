// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IMux3OrderBook.sol";
import "hardhat/console.sol";

contract MockMux3OrderBook is IMux3OrderBook {
    uint256 public lastWrapNativeAmount;
    uint256 public lastWrapNativeValue;

    address public lastTransferToken;
    uint256 public lastTransferTokenAmount;

    address public lastTransferFromToken;
    uint256 public lastTransferTokenFromAmount;

    uint256 public lastDepositGasAmount;

    bytes32 public lastSetInitialLeveragePositionId;
    bytes32 public lastSetInitialLeverageMarketId;
    uint256 public lastSetInitialLeverageInitialLeverage;

    // PositionOrderParams public lastPlacePositionOrderOrderParams;
    bytes32 public lastPlacePositionOrderPositionId;
    bytes32 public lastPlacePositionOrderMarketId;
    bytes32 public lastPlacePositionOrderReferralCode;

    receive() external payable {}

    /**
     * @notice Trader/LP can wrap native ETH to WETH and WETH will stay in OrderBook for subsequent commands
     * @param amount Amount of ETH to wrap
     * @dev Amount must be greater than 0 and less than or equal to msg.value
     */
    function wrapNative(uint256 amount) external payable {
        require(address(this).balance >= amount, "Amount must be greater than 0 and less than or equal to msg.value");
        lastWrapNativeAmount = amount;
        lastWrapNativeValue = msg.value;
    }

    /**
     * @notice Trader/LP transfer ERC20 tokens to the OrderBook
     * @param token Address of the token to transfer
     * @param amount Amount of tokens to transfer
     */
    function transferToken(address token, uint256 amount) external payable {
        lastTransferToken = token;
        lastTransferTokenAmount = amount;
    }

    /**
     * @notice Allows Delegator to transfer tokens from Trader/LP to OrderBook
     * @param from Address to transfer tokens from
     * @param token Address of the token to transfer
     * @param amount Amount of tokens to transfer
     */
    function transferTokenFrom(address from, address token, uint256 amount) external payable {
        lastTransferFromToken = token;
        lastTransferTokenFromAmount = amount;
    }

    /**
     * @notice Trader/LP should pay for gas for their orders
     *         you should pay at least configValue(MCO_ORDER_GAS_FEE_GWEI) * 1e9 / 1e18 ETH for each order
     * @param amount The amount of gas to deposit
     */
    function depositGas(address account, uint256 amount) external payable {
        lastDepositGasAmount = amount;
    }

    /**
     * @notice A trader should set initial leverage at least once before open-position
     * @param positionId The ID of the position
     * @param marketId The ID of the market
     * @param initialLeverage The initial leverage to set
     */
    function setInitialLeverage(bytes32 positionId, bytes32 marketId, uint256 initialLeverage) external payable {
        lastSetInitialLeveragePositionId = positionId;
        lastSetInitialLeverageMarketId = marketId;
        lastSetInitialLeverageInitialLeverage = initialLeverage;
    }

    /**
     * @notice A Trader can open/close position
     *         Market order will expire after marketOrderTimeout seconds.
     *         Limit/Trigger order will expire after deadline.
     * @param orderParams The parameters for the position order
     * @param referralCode The referral code for the position order
     */
    function placePositionOrder(PositionOrderParams memory orderParams, bytes32 referralCode) external payable {
        lastPlacePositionOrderPositionId = orderParams.positionId;
        lastPlacePositionOrderMarketId = orderParams.marketId;
        lastPlacePositionOrderReferralCode = referralCode;
    }
}
