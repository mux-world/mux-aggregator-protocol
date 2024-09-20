// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";

import "./gmx/IOrder.sol";

address constant WETH = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

uint256 constant PROJECT_ID = 2;
uint256 constant VIRTUAL_ASSET_ID = 255;

uint8 constant POSITION_MARKET_ORDER = 0x40;
uint8 constant POSITION_TPSL_ORDER = 0x08;

interface IGmxV2Adatper {
    enum ProjectConfigIds {
        SWAP_ROUTER,
        EXCHANGE_ROUTER,
        ORDER_VAULT,
        DATA_STORE,
        REFERRAL_STORE,
        READER,
        PRICE_HUB,
        EVENT_EMITTER,
        REFERRAL_CODE,
        FUNDING_ASSET_ID,
        FUNDING_ASSET,
        LIMIT_ORDER_EXPIRED_SECONDS,
        END
    }

    enum MarketConfigIds {
        BOOST_FEE_RATE,
        INITIAL_MARGIN_RATE,
        MAINTENANCE_MARGIN_RATE,
        LIQUIDATION_FEE_RATE,
        EMERGENCY_SWAP_SLIPPAGE,
        INDEX_DECIMALS,
        IS_BOOSTABLE,
        END
    }

    enum OrderCategory {
        Open,
        Close,
        TakeProfit,
        StopLoss,
        Liquidate
    }

    struct OrderRecord {
        bool isIncreasing;
        uint64 timestamp;
        uint256 blockNumber;
        uint256 collateralAmount;
        uint256 debtCollateralAmount;
    }

    struct PendingOrder {
        bytes32 key;
        uint256 debtCollateralAmount;
        uint256 timestamp;
        uint256 blockNumber;
        bool isIncreasing;
    }

    struct GmxAdapterStoreV2 {
        // =========
        address factory;
        address liquidityPool;
        bytes32 positionKey;
        // ==========
        uint32 projectConfigVersion;
        uint32 marketConfigVersion;
        uint8 shortTokenDecimals;
        uint8 longTokenDecimals;
        uint8 collateralTokenDecimals;
        ProjectConfigs projectConfigs;
        MarketConfigs marketConfigs;
        AccountState account;
        mapping(bytes32 => OrderRecord) pendingOrders;
        EnumerableSetUpgradeable.Bytes32Set pendingOrderIndexes;
        bytes32[50] __gaps;
    }

    struct ProjectConfigs {
        address swapRouter;
        address exchangeRouter;
        address orderVault;
        address dataStore;
        address referralStore;
        address reader;
        address priceHub;
        address eventEmitter;
        bytes32 referralCode;
        uint8 fundingAssetId;
        address fundingAsset;
        uint256 limitOrderExpiredSeconds;
        bytes32[9] reserved;
    }

    struct MarketConfigs {
        uint32 boostFeeRate;
        uint32 initialMarginRate;
        uint32 maintenanceMarginRate;
        uint32 liquidationFeeRate; // an extra fee rate for liquidation
        uint32 deleted0;
        uint8 indexDecimals;
        bool isBoostable;
        bytes32[10] reserved;
    }

    struct AccountState {
        address owner;
        address market;
        address indexToken;
        address longToken;
        address shortToken;
        address collateralToken;
        bool isLong;
        // --------------------------
        uint256 debtCollateralAmount; // collateral decimals
        uint256 inflightDebtCollateralAmount; // collateral decimals
        uint256 pendingFeeCollateralAmount; // collateral decimals
        uint256 debtEntryFunding;
        bool isLiquidating;
        bytes32[10] reserved;
    }

    struct OrderCreateParams {
        bytes swapPath;
        uint256 initialCollateralAmount;
        uint256 tokenOutMinAmount;
        uint256 borrowCollateralAmount;
        uint256 sizeDeltaUsd;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 callbackGasLimit;
        IOrder.OrderType orderType;
    }

    struct Prices {
        uint256 collateralPrice;
        uint256 indexTokenPrice;
        uint256 longTokenPrice;
        uint256 shortTokenPrice;
    }

    struct PositionResult {
        Prices prices;
        address gasToken;
        uint256 collateralAmount;
        uint256 borrowedCollateralAmount;
        bytes32 orderKey;
    }

    struct DebtResult {
        // common
        Prices prices;
        // repay
        uint256 collateralBalance;
        uint256 secondaryTokenBalance;
        uint256 debtCollateralAmount;
        // fee
        uint256 fundingFeeCollateralAmount;
        uint256 boostFeeCollateralAmount;
        uint256 liquidationFeeCollateralAmount;
        uint256 totalFeeCollateralAmount;
        // result
        uint256 repaidDebtCollateralAmount;
        uint256 repaidFeeCollateralAmount;
        uint256 repaidDebtSecondaryTokenAmount;
        uint256 repaidFeeSecondaryTokenAmount;
        uint256 unpaidDebtCollateralAmount;
        uint256 unpaidFeeCollateralAmount;
        // refund
        uint256 refundCollateralAmount;
        uint256 refundSecondaryTokenAmount;
        // borrow
        uint256 borrowedCollateralAmount;
    }

    function muxAccountState() external view returns (AccountState memory);

    function getPendingOrders() external view returns (PendingOrder[] memory pendingOrders);

    function placeOrder(OrderCreateParams memory createParams) external payable returns (bytes32);

    function updateOrder(
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice,
        bool autoCancel
    ) external;

    function cancelOrder(bytes32 key) external;
}
