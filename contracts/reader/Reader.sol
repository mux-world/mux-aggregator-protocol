// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// aggregator
import "../interfaces/IProxyFactory.sol";

// gmx v1
import "../interfaces/IGmxVault.sol";
import "../interfaces/IGmxBasePositionManager.sol";
import "../interfaces/IGmxPositionRouter.sol";
import "../interfaces/IGmxOrderBook.sol";
import "../aggregators/gmx/GmxAdapter.sol";
import "../aggregators/gmx/libs/LibGmx.sol";

// gmx v2
import "../aggregators/gmxV2/interfaces/gmx/IReader.sol" as GmxV2Reader;
import "../aggregators/gmxV2/interfaces/gmx/IDataStore.sol" as GmxV2DataStore;
import "../aggregators/gmxV2/interfaces/IGmxV2Adatper.sol";

contract Reader {
    // mux
    IProxyFactory public immutable aggregatorFactory;

    // gmx v1
    IGmxVault public immutable gmxVault;
    IERC20 public immutable weth;
    IERC20 public immutable usdg;

    // gmx v2
    address public immutable gmxV2DataStore;
    GmxV2Reader.IReader public immutable gmxV2Reader;
    address public immutable gmxV2ReferralStorage;

    uint256 internal constant GMX_PROJECT_ID = 1;
    uint256 internal constant GMX_V2_PROJECT_ID = 2;
    uint256 internal constant SOURCE_ID_LIQUIDITY_POOL = 1;
    uint256 internal constant SOURCE_ID_LENDING_POOL = 2;

    constructor(
        // mux
        IProxyFactory aggregatorFactory_,
        // gmx v1
        IGmxVault gmxVault_,
        IERC20 weth_,
        IERC20 usdg_,
        // gmx v2
        address gmxV2DataStore_,
        GmxV2Reader.IReader gmxV2Reader_,
        address gmxV2ReferralStorage_
    ) {
        aggregatorFactory = aggregatorFactory_;
        gmxVault = gmxVault_;
        weth = weth_;
        usdg = usdg_;
        gmxV2DataStore = gmxV2DataStore_;
        gmxV2Reader = gmxV2Reader_;
        gmxV2ReferralStorage = gmxV2ReferralStorage_;
    }

    // aggregator for gmx v1
    struct MuxCollateral {
        // config
        uint256 boostFeeRate; // 1e5
        uint256 initialMarginRate; // 1e5
        uint256 maintenanceMarginRate; // 1e5
        uint256 liquidationFeeRate; // 1e5
        // state
        uint256 totalBorrow; // token.decimals. useless when borrowSource = lendingPool
        uint256 borrowLimit; // token.decimals. useless when borrowSource = lendingPool
    }

    // aggregator for gmx v2
    struct AggregatorMarketConfig {
        uint256 boostFeeRate; // 1e5
        uint256 initialMarginRate; // 1e5
        uint256 maintenanceMarginRate; // 1e5
        uint256 liquidationFeeRate; // 1e5
    }

    // gmx v1
    struct GmxAdapterStorage {
        uint256 borrowSource; // 0 = liquidityPool, 1 = lendingPool
        MuxCollateral[] collaterals;
        GmxCoreStorage gmx;
    }

    // gmx v1
    function getGmxAdapterStorage(
        IGmxBasePositionManager gmxPositionManager,
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        address[] memory gmxAggregatorCollateralAddresses, // borrowed collaterals for gmx v1
        address[] memory gmxTokenAddresses // gmx v1 tokens
    ) public view returns (GmxAdapterStorage memory store) {
        store.borrowSource = getLiquiditySource(GMX_PROJECT_ID);
        store.collaterals = _getMuxCollateralsForGmxV1(gmxAggregatorCollateralAddresses);
        store.gmx = _getGmxCoreStorage(gmxPositionRouter, gmxOrderBook);
        store.gmx.tokens = _getGmxCoreTokens(gmxPositionManager, gmxTokenAddresses);
    }

    // gmx v1
    function _getMuxCollateralsForGmxV1(
        address[] memory tokenAddresses
    ) internal view returns (MuxCollateral[] memory tokens) {
        tokens = new MuxCollateral[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            MuxCollateral memory token = tokens[i];
            // config
            uint256[] memory values = IProxyFactory(aggregatorFactory).getProjectAssetConfig(
                GMX_PROJECT_ID,
                tokenAddresses[i]
            );
            require(values.length >= uint256(TokenConfigIds.END), "MissingConfigs");
            token.boostFeeRate = uint256(values[uint256(TokenConfigIds.BOOST_FEE_RATE)]);
            token.initialMarginRate = uint256(values[uint256(TokenConfigIds.INITIAL_MARGIN_RATE)]);
            token.maintenanceMarginRate = uint256(values[uint256(TokenConfigIds.MAINTENANCE_MARGIN_RATE)]);
            token.liquidationFeeRate = uint256(values[uint256(TokenConfigIds.LIQUIDATION_FEE_RATE)]);
            // state
            (token.totalBorrow, token.borrowLimit, ) = IProxyFactory(aggregatorFactory).getBorrowStates(
                GMX_PROJECT_ID,
                tokenAddresses[i]
            );
        }
    }

    // gmx v1
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

    // gmx v1
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

    // gmx v1
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
        uint256 contractMinPrice; // 1e30
        uint256 contractMaxPrice; // 1e30
        uint256 guaranteedUsd;
        uint256 fundingRate;
        uint256 cumulativeFundingRate;
    }

    // gmx v1
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

    // gmx v2
    struct GmxV2AdapterStorage {
        AggregatorMarketConfig[] markets;
    }

    // gmx v2
    function getGmxV2AdapterStorage(
        address[] memory gmxV2MarketsAddresses
    ) public view returns (GmxV2AdapterStorage memory store2) {
        store2.markets = _getMarketConfigsForGmxV2(gmxV2MarketsAddresses);
    }

    // gmx v2
    function _getMarketConfigsForGmxV2(
        address[] memory marketAddresses
    ) internal view returns (AggregatorMarketConfig[] memory tokens) {
        tokens = new AggregatorMarketConfig[](marketAddresses.length);
        for (uint256 i = 0; i < marketAddresses.length; i++) {
            AggregatorMarketConfig memory token = tokens[i];
            uint256[] memory values = IProxyFactory(aggregatorFactory).getProjectAssetConfig(
                GMX_V2_PROJECT_ID,
                marketAddresses[i]
            );
            require(values.length >= uint256(IGmxV2Adatper.MarketConfigIds.END), "MissingConfigs");
            token.boostFeeRate = uint256(values[uint256(IGmxV2Adatper.MarketConfigIds.BOOST_FEE_RATE)]);
            token.initialMarginRate = uint256(values[uint256(IGmxV2Adatper.MarketConfigIds.INITIAL_MARGIN_RATE)]);
            token.maintenanceMarginRate = uint256(
                values[uint256(IGmxV2Adatper.MarketConfigIds.MAINTENANCE_MARGIN_RATE)]
            );
            token.liquidationFeeRate = uint256(values[uint256(IGmxV2Adatper.MarketConfigIds.LIQUIDATION_FEE_RATE)]);
        }
    }

    // all projects
    struct AggregatorSubAccount {
        // key
        address proxyAddress;
        uint256 projectId;
        address collateralAddress; // also known as debtTokenAddress
        address assetAddress; // gmx v1: index address. gmx v2: market address
        bool isLong;
        // store
        bool isLiquidating;
        uint256 cumulativeDebt; // token.decimals
        uint256 cumulativeFee; // token.decimals
        uint256 debtEntryFunding; // 1e18
        uint256 proxyCollateralBalance; // token.decimals. collateral erc20 balance of the proxy
        uint256 proxyEthBalance; // 1e18. native balance of the proxy
        // if gmx v1
        GmxCoreAccount gmx;
        GmxAdapterOrder[] gmxOrders;
        // if gmx v2
        GmxV2Reader.IReader.PositionInfo gmx2;
        uint256 claimableFundingAmountLong;
        uint256 claimableFundingAmountShort;
        GmxV2AdapterOrder[] gmx2Orders;
    }

    // for UI
    function getAggregatorSubAccountsOfAccount(
        // gmx v1
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        // mux aggregator
        address accountAddress,
        // gmx v2
        GmxV2Price[] memory gmxV2Prices // 1e30 - tokenDecimals
    ) public view returns (AggregatorSubAccount[] memory subAccounts) {
        address[] memory proxyAddresses = aggregatorFactory.getProxiesOf(accountAddress);
        return getAggregatorSubAccountsOfProxy(gmxPositionRouter, gmxOrderBook, proxyAddresses, gmxV2Prices);
    }

    // for keeper
    function getAggregatorSubAccountsOfProxy(
        // gmx v1
        IGmxPositionRouter gmxPositionRouter,
        IGmxOrderBook gmxOrderBook,
        // mux aggregator
        address[] memory proxyAddresses,
        // gmx v2
        GmxV2Price[] memory gmxV2Prices // 1e30 - tokenDecimals
    ) public view returns (AggregatorSubAccount[] memory subAccounts) {
        subAccounts = new AggregatorSubAccount[](proxyAddresses.length);
        for (uint256 i = 0; i < proxyAddresses.length; i++) {
            uint256 projectId = getProxyProjectId(proxyAddresses[i]);
            if (projectId == GMX_PROJECT_ID) {
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
            } else if (projectId == GMX_V2_PROJECT_ID) {
                // if gmx2
                IGmxV2Adatper adapter = IGmxV2Adatper(payable(proxyAddresses[i]));
                subAccounts[i] = _getMuxAggregatorSubAccountForGmx2Adapter(adapter);
                AggregatorSubAccount memory subAccount = subAccounts[i];
                subAccount.gmx2 = _getGmx2CoreAccount(address(adapter), subAccount, gmxV2Prices);
                (subAccount.claimableFundingAmountLong, subAccount.claimableFundingAmountShort) = _getGmx2Claimable(
                    subAccount.assetAddress,
                    subAccount.proxyAddress
                );
                subAccount.gmx2Orders = _getGmx2AdapterOrders(adapter);
            }
        }
    }

    // deprecated
    // this is for compatibility with both gmx v1 and gmx v2
    function getLiquiditySource(uint256 projectId) public view returns (uint256) {
        try aggregatorFactory.getLiquiditySource(projectId) returns (uint256 sourceId, address) {
            return sourceId;
        } catch {
            // the old version of aggregatorFactory does not have this function
            return SOURCE_ID_LIQUIDITY_POOL;
        }
    }

    // deprecated
    // this is for compatibility with both gmx v1 and gmx v2
    function getProxyProjectId(address proxyAddress) public view returns (uint256) {
        try aggregatorFactory.getProxyProjectId(proxyAddress) returns (uint256 id) {
            return id;
        } catch {
            // the old version of aggregatorFactory does not have this function
            return GMX_PROJECT_ID;
        }
    }

    // gmx v1
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

    // gmx v2
    function _getMuxAggregatorSubAccountForGmx2Adapter(
        IGmxV2Adatper adapter
    ) internal view returns (AggregatorSubAccount memory account) {
        account.projectId = GMX_V2_PROJECT_ID;
        IGmxV2Adatper.AccountState memory muxAccount = adapter.muxAccountState();
        account.proxyAddress = address(adapter);
        account.collateralAddress = muxAccount.collateralToken;
        account.assetAddress = muxAccount.market;
        account.isLong = muxAccount.isLong;
        account.isLiquidating = muxAccount.isLiquidating;
        account.cumulativeDebt = muxAccount.debtCollateralAmount;
        account.cumulativeFee = muxAccount.pendingFeeCollateralAmount;
        account.debtEntryFunding = muxAccount.debtEntryFunding;
        account.proxyCollateralBalance = IERC20(account.collateralAddress).balanceOf(account.proxyAddress);
        account.proxyEthBalance = account.proxyAddress.balance;
    }

    // gmx v1
    struct GmxCoreAccount {
        uint256 sizeUsd; // 1e30
        uint256 collateralUsd; // 1e30
        uint256 lastIncreasedTime;
        uint256 entryPrice; // 1e30
        uint256 entryFundingRate; // 1e6
    }

    // gmx v1
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

    // gmx v2
    struct GmxV2Price {
        address marketToken;
        GmxV2Reader.IMarket.MarketPrices prices;
    }

    // gmx v2
    function _getGmx2CoreAccount(
        address adapter,
        AggregatorSubAccount memory subAccount,
        GmxV2Price[] memory prices // 1e30 - tokenDecimals
    ) internal view returns (GmxV2Reader.IReader.PositionInfo memory account) {
        // see gmx v2 PositionUtils.getPositionKey
        bytes32 positionKey = keccak256(
            abi.encode(adapter, subAccount.assetAddress /* market */, subAccount.collateralAddress, subAccount.isLong)
        );
        // check if the position exists
        if (!hasGmxV2Position(positionKey)) {
            account.position.flags.isLong = subAccount.isLong;
            account.position.addresses.account = address(adapter);
            account.position.addresses.market = subAccount.assetAddress;
            account.position.addresses.collateralToken = subAccount.collateralAddress;
            return account;
        }

        // find the price
        GmxV2Price memory price;
        bool found;
        for (uint256 i = 0; i < prices.length; i++) {
            if (prices[i].marketToken == subAccount.assetAddress /* market */) {
                price = prices[i];
                found = true;
                break;
            }
        }
        require(found, "GMX v2 price not found");
        // see gmx v2 Reader.getAccountPositionInfoList
        return
            gmxV2Reader.getPositionInfo(
                gmxV2DataStore,
                gmxV2ReferralStorage,
                positionKey,
                price.prices,
                0, // sizeDeltaUsd
                address(0), // uiFeeReceiver
                true // usePositionSizeAsSizeDeltaUsd
            );
    }

    // gmx v2
    function hasGmxV2Position(bytes32 positionKey) public view returns (bool) {
        return GmxV2DataStore.IDataStore(gmxV2DataStore).containsBytes32(GmxV2DataStore.POSITION_LIST, positionKey);
    }

    // gmx v2
    bytes32 public constant GMX_V2_CLAIMABLE_FUNDING_AMOUNT = keccak256(abi.encode("CLAIMABLE_FUNDING_AMOUNT"));
    bytes32 public constant GMX_V2_LONG_TOKEN = keccak256(abi.encode("LONG_TOKEN"));
    bytes32 public constant GMX_V2_SHORT_TOKEN = keccak256(abi.encode("SHORT_TOKEN"));

    // gmx v2
    function _getGmx2Claimable(
        address gmxV2MarketAddress,
        address proxyAddress
    ) internal view returns (uint256 claimableFundingAmountLong, uint256 claimableFundingAmountShort) {
        address longToken = GmxV2DataStore.IDataStore(gmxV2DataStore).getAddress(
            keccak256(abi.encode(gmxV2MarketAddress, GMX_V2_LONG_TOKEN))
        );
        address shortToken = GmxV2DataStore.IDataStore(gmxV2DataStore).getAddress(
            keccak256(abi.encode(gmxV2MarketAddress, GMX_V2_SHORT_TOKEN))
        );
        claimableFundingAmountLong = GmxV2DataStore.IDataStore(gmxV2DataStore).getUint(
            keccak256(abi.encode(GMX_V2_CLAIMABLE_FUNDING_AMOUNT, gmxV2MarketAddress, longToken, proxyAddress))
        );
        claimableFundingAmountShort = GmxV2DataStore.IDataStore(gmxV2DataStore).getUint(
            keccak256(abi.encode(GMX_V2_CLAIMABLE_FUNDING_AMOUNT, gmxV2MarketAddress, shortToken, proxyAddress))
        );
    }

    // gmx v1
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

    // gmx v1
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

    // gmx v1
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

    // gmx v2
    struct GmxV2AdapterOrder {
        // aggregator order
        bytes32 orderHistoryKey; // see LibGmx.decodeOrderHistoryKey
        bool isIncrease;
        uint256 debt; // decimals = erc20
        uint32 timestamp;
        uint256 blockNumber;
        // gmx v2 order
        bool isFillOrCancel;
        GmxV2Reader.IOrder.Props gmxOrder;
    }

    // gmx v2
    function _getGmx2AdapterOrders(IGmxV2Adatper adapter) internal view returns (GmxV2AdapterOrder[] memory orders) {
        IGmxV2Adatper.PendingOrder[] memory pendingOrders = adapter.getPendingOrders();
        orders = new GmxV2AdapterOrder[](pendingOrders.length);
        for (uint256 i = 0; i < pendingOrders.length; i++) {
            orders[i] = _getGmxV2AdapterOrder(pendingOrders[i]);
        }
    }

    // gmx v2
    function _getGmxV2AdapterOrder(
        IGmxV2Adatper.PendingOrder memory pendingOrder
    ) internal view returns (GmxV2AdapterOrder memory order) {
        // aggregator order
        order.orderHistoryKey = pendingOrder.key;
        order.isIncrease = pendingOrder.isIncreasing;
        order.debt = pendingOrder.debtCollateralAmount;
        order.timestamp = uint32(pendingOrder.timestamp);
        order.blockNumber = pendingOrder.blockNumber;

        // gmx v2 order
        order.gmxOrder = gmxV2Reader.getOrder(gmxV2DataStore, pendingOrder.key);
        order.isFillOrCancel = order.gmxOrder.addresses.account == address(0);
    }
}
