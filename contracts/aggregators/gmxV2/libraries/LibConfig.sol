// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../../../interfaces/IProxyFactory.sol";
import "../interfaces/IGmxV2Adatper.sol";

import "../libraries/LibUtils.sol";

library LibConfig {
    using LibUtils for uint256;

    function updateConfigs(IGmxV2Adatper.GmxAdapterStoreV2 storage store) internal {
        address market = store.account.market;

        (uint32 remoteProjectVersion, uint32 remoteMarketVersion) = IProxyFactory(store.factory).getConfigVersions(
            PROJECT_ID,
            market
        );

        if (store.projectConfigVersion < remoteProjectVersion) {
            updateProjectConfigs(store);
            store.projectConfigVersion = remoteProjectVersion;
        }

        // pull configs from factory
        if (store.marketConfigVersion < remoteMarketVersion) {
            updateMarketConfigs(store, market);
            store.marketConfigVersion = remoteMarketVersion;
        }
    }

    function updateProjectConfigs(IGmxV2Adatper.GmxAdapterStoreV2 storage store) public {
        uint256[] memory values = IProxyFactory(store.factory).getProjectConfig(PROJECT_ID);
        require(values.length >= uint256(IGmxV2Adatper.ProjectConfigIds.END), "MissingConfigs");
        store.projectConfigs.swapRouter = values[uint256(IGmxV2Adatper.ProjectConfigIds.SWAP_ROUTER)].toAddress();
        store.projectConfigs.exchangeRouter = values[uint256(IGmxV2Adatper.ProjectConfigIds.EXCHANGE_ROUTER)]
            .toAddress();
        store.projectConfigs.orderVault = values[uint256(IGmxV2Adatper.ProjectConfigIds.ORDER_VAULT)].toAddress();
        store.projectConfigs.dataStore = values[uint256(IGmxV2Adatper.ProjectConfigIds.DATA_STORE)].toAddress();
        store.projectConfigs.referralStore = values[uint256(IGmxV2Adatper.ProjectConfigIds.REFERRAL_STORE)].toAddress();
        store.projectConfigs.reader = values[uint256(IGmxV2Adatper.ProjectConfigIds.READER)].toAddress();
        store.projectConfigs.priceHub = values[uint256(IGmxV2Adatper.ProjectConfigIds.PRICE_HUB)].toAddress();
        store.projectConfigs.eventEmitter = values[uint256(IGmxV2Adatper.ProjectConfigIds.EVENT_EMITTER)].toAddress();
        store.projectConfigs.referralCode = values[uint256(IGmxV2Adatper.ProjectConfigIds.REFERRAL_CODE)].toBytes32();
        store.projectConfigs.fundingAssetId = values[uint256(IGmxV2Adatper.ProjectConfigIds.FUNDING_ASSET_ID)].toU8();
        store.projectConfigs.fundingAsset = values[uint256(IGmxV2Adatper.ProjectConfigIds.FUNDING_ASSET)].toAddress();
        store.projectConfigs.limitOrderExpiredSeconds = values[
            uint256(IGmxV2Adatper.ProjectConfigIds.LIMIT_ORDER_EXPIRED_SECONDS)
        ];
    }

    function updateMarketConfigs(IGmxV2Adatper.GmxAdapterStoreV2 storage store, address market) public {
        uint256[] memory values = IProxyFactory(store.factory).getProjectAssetConfig(PROJECT_ID, market);
        require(values.length >= uint256(IGmxV2Adatper.MarketConfigIds.END), "MissingConfigs");
        store.marketConfigs.boostFeeRate = values[uint256(IGmxV2Adatper.MarketConfigIds.BOOST_FEE_RATE)].toU32();
        store.marketConfigs.initialMarginRate = values[uint256(IGmxV2Adatper.MarketConfigIds.INITIAL_MARGIN_RATE)]
            .toU32();
        store.marketConfigs.maintenanceMarginRate = values[
            uint256(IGmxV2Adatper.MarketConfigIds.MAINTENANCE_MARGIN_RATE)
        ].toU32();
        store.marketConfigs.liquidationFeeRate = values[uint256(IGmxV2Adatper.MarketConfigIds.LIQUIDATION_FEE_RATE)]
            .toU32();
        store.marketConfigs.indexDecimals = values[uint256(IGmxV2Adatper.MarketConfigIds.INDEX_DECIMALS)].toU8();
        store.marketConfigs.isBoostable = values[uint256(IGmxV2Adatper.MarketConfigIds.IS_BOOSTABLE)] > 0;
        store.marketConfigs.maxBorrowingRate = values[uint256(IGmxV2Adatper.MarketConfigIds.MAX_BORROWING_RATE)]
            .toU32();
    }
}
