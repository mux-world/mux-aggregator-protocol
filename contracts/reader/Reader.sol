// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IGmxVault.sol";
import "../interfaces/IGmxBasePositionManager.sol";
import "../interfaces/IGmxPositionRouter.sol";
import "../interfaces/IGmxOrderBook.sol";
import "../interfaces/IProxyFactory.sol";
import "../aggregators/gmx/Type.sol";
import "../aggregators/gmx/GmxAdapter.sol";
import "../aggregators/gmx/libs/LibGmx.sol";

contract Reader {
    IProxyFactory public immutable aggregatorFactory;
    IGmxVault public immutable gmxVault;
    IERC20 public immutable weth;
    IERC20 public immutable usdg;

    uint256 internal constant GMX_PROJECT_ID = 1;

    constructor(IProxyFactory aggregatorFactory_, IGmxVault gmxVault_, IERC20 weth_, IERC20 usdg_) {
        aggregatorFactory = aggregatorFactory_;
        gmxVault = gmxVault_;
        weth = weth_;
        usdg = usdg_;
    }

    struct GmxAdapterStorage {
        MuxCollateral[] collaterals;
        GmxCoreStorage gmx;
    }

    function getGmxAdapterStorage(
        IGmxBasePositionManager gmxPositionManager,
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        address[] memory aggregatorCollateralAddresses,
        address[] memory gmxTokenAddresses
    ) public view returns (GmxAdapterStorage memory store) {
        // gmx
        store.collaterals = _getMuxCollaterals(GMX_PROJECT_ID, aggregatorCollateralAddresses);
        store.gmx = _getGmxCoreStorage(gmxPositionRouter, gmxOrderBook);
        store.gmx.tokens = _getGmxCoreTokens(gmxPositionManager, gmxTokenAddresses);
    }

    struct MuxCollateral {
        // config
        uint256 boostFeeRate; // 1e5
        uint256 initialMarginRate; // 1e5
        uint256 maintenanceMarginRate; // 1e5
        uint256 liquidationFeeRate; // 1e5
        // state
        uint256 totalBorrow; // token.decimals
        uint256 borrowLimit; // token.decimals
    }

    function _getMuxCollaterals(
        uint256 projectId,
        address[] memory tokenAddresses
    ) internal view returns (MuxCollateral[] memory tokens) {
        tokens = new MuxCollateral[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            MuxCollateral memory token = tokens[i];
            // config
            uint256[] memory values = IProxyFactory(aggregatorFactory).getProjectAssetConfig(
                projectId,
                tokenAddresses[i]
            );
            require(values.length >= uint256(TokenConfigIds.END), "MissingConfigs");
            token.boostFeeRate = uint256(values[uint256(TokenConfigIds.BOOST_FEE_RATE)]);
            token.initialMarginRate = uint256(values[uint256(TokenConfigIds.INITIAL_MARGIN_RATE)]);
            token.maintenanceMarginRate = uint256(values[uint256(TokenConfigIds.MAINTENANCE_MARGIN_RATE)]);
            token.liquidationFeeRate = uint256(values[uint256(TokenConfigIds.LIQUIDATION_FEE_RATE)]);
            // state
            (token.totalBorrow, token.borrowLimit, ) = IProxyFactory(aggregatorFactory).getBorrowStates(
                projectId,
                tokenAddresses[i]
            );
        }
    }

    struct GmxCoreStorage {
        // config
        uint256 totalTokenWeights; // 1e0
        uint256 minProfitTime; // 1e0
        uint256 minExecutionFee;
        uint256 liquidationFeeUsd; // 1e30
        uint256 _marginFeeBasisPoints; // 1e4. note: do NOT use this one. the real fee is in TimeLock
        uint256 swapFeeBasisPoints; // 1e4
        uint256 stableSwapFeeBasisPoints; // 1e4
        uint256 taxBasisPoints; // 1e4
        uint256 stableTaxBasisPoints; // 1e4
        // state
        uint256 usdgSupply; // 1e18
        GmxToken[] tokens;
    }

    function _getGmxCoreStorage(
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook
    ) internal view returns (GmxCoreStorage memory store) {
        store.totalTokenWeights = gmxVault.totalTokenWeights();
        store.minProfitTime = gmxVault.minProfitTime();
        uint256 exec1 = gmxPositionRouter.minExecutionFee();
        uint256 exec2 = gmxOrderBook.minExecutionFee();
        store.minExecutionFee = exec1 > exec2 ? exec1 : exec2;
        store.liquidationFeeUsd = gmxVault.liquidationFeeUsd();
        store._marginFeeBasisPoints = gmxVault.marginFeeBasisPoints();
        store.swapFeeBasisPoints = gmxVault.swapFeeBasisPoints();
        store.stableSwapFeeBasisPoints = gmxVault.stableSwapFeeBasisPoints();
        store.taxBasisPoints = gmxVault.taxBasisPoints();
        store.stableTaxBasisPoints = gmxVault.stableTaxBasisPoints();
        store.usdgSupply = usdg.totalSupply();
    }

    struct GmxToken {
        // config
        uint256 minProfit;
        uint256 weight;
        uint256 maxUsdgAmounts;
        uint256 maxGlobalShortSize;
        uint256 maxGlobalLongSize;
        // storage
        uint256 poolAmount;
        uint256 reservedAmount;
        uint256 usdgAmount;
        uint256 redemptionAmount;
        uint256 bufferAmounts;
        uint256 globalShortSize;
        uint256 contractMinPrice;
        uint256 contractMaxPrice;
        uint256 guaranteedUsd;
        uint256 fundingRate;
        uint256 cumulativeFundingRate;
    }

    function _getGmxCoreTokens(
        IGmxBasePositionManager gmxPositionManager,
        address[] memory tokenAddresses
    ) internal view returns (GmxToken[] memory tokens) {
        tokens = new GmxToken[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            GmxToken memory token = tokens[i];

            // config
            token.minProfit = gmxVault.minProfitBasisPoints(tokenAddress);
            token.weight = gmxVault.tokenWeights(tokenAddress);
            token.maxUsdgAmounts = gmxVault.maxUsdgAmounts(tokenAddress);
            token.maxGlobalShortSize = gmxPositionManager.maxGlobalShortSizes(tokenAddress);
            token.maxGlobalLongSize = gmxPositionManager.maxGlobalLongSizes(tokenAddress);

            // storage
            token.poolAmount = gmxVault.poolAmounts(tokenAddress);
            token.reservedAmount = gmxVault.reservedAmounts(tokenAddress);
            token.usdgAmount = gmxVault.usdgAmounts(tokenAddress);
            token.redemptionAmount = gmxVault.getRedemptionAmount(tokenAddress, 10 ** 30);
            token.bufferAmounts = gmxVault.bufferAmounts(tokenAddress);
            token.globalShortSize = gmxVault.globalShortSizes(tokenAddress);
            token.contractMinPrice = gmxVault.getMinPrice(tokenAddress);
            token.contractMaxPrice = gmxVault.getMaxPrice(tokenAddress);
            token.guaranteedUsd = gmxVault.guaranteedUsd(tokenAddress);

            // funding
            uint256 fundingRateFactor = gmxVault.stableTokens(tokenAddress)
                ? gmxVault.stableFundingRateFactor()
                : gmxVault.fundingRateFactor();
            if (token.poolAmount > 0) {
                token.fundingRate = (fundingRateFactor * token.reservedAmount) / token.poolAmount;
            }
            uint256 acc = gmxVault.cumulativeFundingRates(tokenAddress);
            if (acc > 0) {
                uint256 nextRate = gmxVault.getNextFundingRate(tokenAddress);
                uint256 baseRate = gmxVault.cumulativeFundingRates(tokenAddress);
                token.cumulativeFundingRate = baseRate + nextRate;
            }
        }
    }

    struct AggregatorSubAccount {
        // key
        address proxyAddress;
        uint256 projectId;
        address collateralAddress;
        address assetAddress;
        bool isLong;
        // store
        bool isLiquidating;
        uint256 cumulativeDebt; // token.decimals
        uint256 cumulativeFee; // token.decimals
        uint256 debtEntryFunding; // 1e18
        uint256 proxyCollateralBalance; // token.decimals. collateral erc20 balance of the proxy
        uint256 proxyEthBalance; // 1e18. native balance of the proxy
        // if gmx
        GmxCoreAccount gmx;
        GmxAdapterOrder[] gmxOrders;
    }

    // for UI
    function getAggregatorSubAccountsOfAccount(
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        address accountAddress
    ) public view returns (AggregatorSubAccount[] memory subAccounts) {
        address[] memory proxyAddresses = aggregatorFactory.getProxiesOf(accountAddress);
        return getAggregatorSubAccountsOfProxy(gmxPositionRouter, gmxOrderBook, proxyAddresses);
    }

    // for keeper
    function getAggregatorSubAccountsOfProxy(
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        address[] memory proxyAddresses
    ) public view returns (AggregatorSubAccount[] memory subAccounts) {
        subAccounts = new AggregatorSubAccount[](proxyAddresses.length);
        for (uint256 i = 0; i < proxyAddresses.length; i++) {
            // if gmx
            GmxAdapter adapter = GmxAdapter(payable(proxyAddresses[i]));
            subAccounts[i] = _getMuxAggregatorSubAccountForGmxAdapter(adapter);
            AggregatorSubAccount memory subAccount = subAccounts[i];
            subAccount.gmx = _getGmxCoreAccount(
                address(adapter),
                subAccount.collateralAddress,
                subAccount.assetAddress,
                subAccount.isLong
            );
            subAccount.gmxOrders = _getGmxAdapterOrders(gmxPositionRouter, gmxOrderBook, adapter);
        }
    }

    function _getMuxAggregatorSubAccountForGmxAdapter(
        GmxAdapter adapter
    ) internal view returns (AggregatorSubAccount memory account) {
        account.projectId = GMX_PROJECT_ID;
        AccountState memory muxAccount = adapter.muxAccountState();
        account.proxyAddress = address(adapter);
        account.collateralAddress = muxAccount.collateralToken;
        account.assetAddress = muxAccount.indexToken;
        account.isLong = muxAccount.isLong;
        account.isLiquidating = muxAccount.isLiquidating;
        (account.cumulativeDebt, account.cumulativeFee, account.debtEntryFunding) = adapter.debtStates();
        account.proxyCollateralBalance = IERC20(account.collateralAddress).balanceOf(account.proxyAddress);
        account.proxyEthBalance = account.proxyAddress.balance;
    }

    struct GmxCoreAccount {
        uint256 sizeUsd; // 1e30
        uint256 collateralUsd; // 1e30
        uint256 lastIncreasedTime;
        uint256 entryPrice; // 1e30
        uint256 entryFundingRate; // 1e6
    }

    function _getGmxCoreAccount(
        address accountAddress,
        address collateralAddress,
        address indexAddress,
        bool isLong
    ) internal view returns (GmxCoreAccount memory account) {
        (
            uint256 size,
            uint256 collateral,
            uint256 averagePrice,
            uint256 entryFundingRate,
            ,
            ,
            ,
            uint256 lastIncreasedTime
        ) = gmxVault.getPosition(accountAddress, collateralAddress, indexAddress, isLong);
        account.sizeUsd = size;
        account.collateralUsd = collateral;
        account.lastIncreasedTime = lastIncreasedTime;
        account.entryPrice = averagePrice;
        account.entryFundingRate = entryFundingRate;
    }

    struct GmxAdapterOrder {
        // aggregator order
        bytes32 orderHistoryKey; // see LibGmx.decodeOrderHistoryKey
        // gmx order
        bool isFillOrCancel;
        uint256 amountIn; // increase only, collateral.decimals
        uint256 collateralDeltaUsd; // decrease only, 1e30
        uint256 sizeDeltaUsd; // 1e30
        uint256 triggerPrice; // 0 if market order, 1e30
        bool triggerAboveThreshold;
        // tp/sl strategy only
        bytes32 tpOrderHistoryKey;
        bytes32 slOrderHistoryKey;
    }

    function _getGmxAdapterOrders(
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        GmxAdapter aggregator
    ) internal view returns (GmxAdapterOrder[] memory orders) {
        bytes32[] memory pendingKeys = aggregator.getPendingGmxOrderKeys();
        orders = new GmxAdapterOrder[](pendingKeys.length);
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            orders[i] = _getGmxAdapterOrder(gmxPositionRouter, gmxOrderBook, aggregator, pendingKeys[i]);
        }
    }

    function _getGmxAdapterOrder(
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        GmxAdapter aggregator,
        bytes32 key
    ) internal view returns (GmxAdapterOrder memory order) {
        LibGmx.OrderHistory memory entry = LibGmx.decodeOrderHistoryKey(key);
        order.orderHistoryKey = key;
        if (entry.receiver == LibGmx.OrderReceiver.PR_INC) {
            IGmxPositionRouter.IncreasePositionRequest memory request = gmxPositionRouter.increasePositionRequests(
                LibGmx.encodeOrderKey(address(aggregator), entry.index)
            );
            order.isFillOrCancel = request.account == address(0);
            order.amountIn = request.amountIn;
            order.sizeDeltaUsd = request.sizeDelta;
        } else if (entry.receiver == LibGmx.OrderReceiver.PR_DEC) {
            IGmxPositionRouter.DecreasePositionRequest memory request = gmxPositionRouter.decreasePositionRequests(
                LibGmx.encodeOrderKey(address(aggregator), entry.index)
            );
            order.isFillOrCancel = request.account == address(0);
            order.collateralDeltaUsd = request.collateralDelta;
            order.sizeDeltaUsd = request.sizeDelta;
        } else if (entry.receiver == LibGmx.OrderReceiver.OB_INC) {
            (
                ,
                uint256 purchaseTokenAmount,
                address collateralToken,
                ,
                uint256 sizeDelta,
                ,
                uint256 triggerPrice,
                bool triggerAboveThreshold,

            ) = gmxOrderBook.getIncreaseOrder(address(aggregator), entry.index);
            order.isFillOrCancel = collateralToken == address(0);
            order.amountIn = purchaseTokenAmount;
            order.sizeDeltaUsd = sizeDelta;
            order.triggerPrice = triggerPrice;
            order.triggerAboveThreshold = triggerAboveThreshold;
        } else if (entry.receiver == LibGmx.OrderReceiver.OB_DEC) {
            (
                address collateralToken,
                uint256 collateralDelta,
                ,
                uint256 sizeDelta,
                ,
                uint256 triggerPrice,
                bool triggerAboveThreshold,

            ) = gmxOrderBook.getDecreaseOrder(address(aggregator), entry.index);
            order.isFillOrCancel = collateralToken == address(0);
            order.collateralDeltaUsd = collateralDelta;
            order.sizeDeltaUsd = sizeDelta;
            order.triggerPrice = triggerPrice;
            order.triggerAboveThreshold = triggerAboveThreshold;
        }
        (order.tpOrderHistoryKey, order.slOrderHistoryKey) = aggregator.getTpslOrderKeys(key);
    }
}
