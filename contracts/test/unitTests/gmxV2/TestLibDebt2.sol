// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.17;

import "../../../aggregators/gmxV2/libraries/LibDebt.sol";
import "../../../aggregators/gmxV2/libraries/LibUtils.sol";

import "../../../aggregators/gmxV2/interfaces/IGmxV2Adatper.sol";
import "../../../aggregators/gmxV2/interfaces/gmx/IReader.sol";
import "../../../interfaces/ILiquidityPool.sol";

import "hardhat/console.sol";

contract TestLibDebt2 {
    using LibUtils for uint256;
    using LibDebt for IGmxV2Adatper.GmxAdapterStoreV2;

    IGmxV2Adatper.GmxAdapterStoreV2 private _store;

    function muxAccountState() external view returns (IGmxV2Adatper.AccountState memory) {
        return _store.account;
    }

    function setFactory(address factory) external {
        _store.factory = factory;
    }

    function setOwner(address owner) external {
        _store.account.owner = owner;
    }

    function setDebtStates(
        uint256 debtCollateralAmount,
        uint256 inflightDebtCollateralAmount,
        uint256 pendingFeeCollateralAmount,
        uint256 debtEntryFunding
    ) external {
        _store.account.debtCollateralAmount = debtCollateralAmount;
        _store.account.inflightDebtCollateralAmount = inflightDebtCollateralAmount;
        _store.account.pendingFeeCollateralAmount = pendingFeeCollateralAmount;
        _store.account.debtEntryFunding = debtEntryFunding;
    }

    function setTokens(address longToken, address shortToken, address collateralToken) external {
        _store.account.longToken = longToken;
        _store.account.shortToken = shortToken;
        _store.account.collateralToken = collateralToken;
    }

    function setProjectConfig(uint256[] memory values) external {
        require(values.length >= uint256(IGmxV2Adatper.ProjectConfigIds.END), "MissingConfigs");
        _store.projectConfigs.swapRouter = values[uint256(IGmxV2Adatper.ProjectConfigIds.SWAP_ROUTER)].toAddress();
        _store.projectConfigs.exchangeRouter = values[uint256(IGmxV2Adatper.ProjectConfigIds.EXCHANGE_ROUTER)]
            .toAddress();
        _store.projectConfigs.orderVault = values[uint256(IGmxV2Adatper.ProjectConfigIds.ORDER_VAULT)].toAddress();
        _store.projectConfigs.dataStore = values[uint256(IGmxV2Adatper.ProjectConfigIds.DATA_STORE)].toAddress();
        _store.projectConfigs.referralStore = values[uint256(IGmxV2Adatper.ProjectConfigIds.REFERRAL_STORE)]
            .toAddress();
        _store.projectConfigs.reader = values[uint256(IGmxV2Adatper.ProjectConfigIds.READER)].toAddress();
        _store.projectConfigs.priceHub = values[uint256(IGmxV2Adatper.ProjectConfigIds.PRICE_HUB)].toAddress();
        _store.projectConfigs.eventEmitter = values[uint256(IGmxV2Adatper.ProjectConfigIds.EVENT_EMITTER)].toAddress();
        _store.projectConfigs.referralCode = values[uint256(IGmxV2Adatper.ProjectConfigIds.REFERRAL_CODE)].toBytes32();
        _store.projectConfigs.fundingAssetId = values[uint256(IGmxV2Adatper.ProjectConfigIds.FUNDING_ASSET_ID)].toU8();
        _store.projectConfigs.fundingAsset = values[uint256(IGmxV2Adatper.ProjectConfigIds.FUNDING_ASSET)].toAddress();
    }

    function setMarketConfig(uint256[] memory values) external {
        require(values.length >= uint256(IGmxV2Adatper.MarketConfigIds.END), "MissingConfigs");
        _store.marketConfigs.boostFeeRate = values[uint256(IGmxV2Adatper.MarketConfigIds.BOOST_FEE_RATE)].toU32();
        _store.marketConfigs.initialMarginRate = values[uint256(IGmxV2Adatper.MarketConfigIds.INITIAL_MARGIN_RATE)]
            .toU32();
        _store.marketConfigs.maintenanceMarginRate = values[
            uint256(IGmxV2Adatper.MarketConfigIds.MAINTENANCE_MARGIN_RATE)
        ].toU32();
        _store.marketConfigs.liquidationFeeRate = values[uint256(IGmxV2Adatper.MarketConfigIds.LIQUIDATION_FEE_RATE)]
            .toU32();
        _store.marketConfigs.indexDecimals = values[uint256(IGmxV2Adatper.MarketConfigIds.INDEX_DECIMALS)].toU8();
        _store.marketConfigs.isBoostable = values[uint256(IGmxV2Adatper.MarketConfigIds.IS_BOOSTABLE)] > 0;
    }

    function borrowAsset(
        uint256 borrowCollateralAmount
    ) external returns (uint256 borrowedCollateralAmount, uint256 boostFeeCollateralAmount) {
        return _store.borrowCollateral(borrowCollateralAmount);
    }

    function repayCancelledDebt(uint256 totalCollateralAmount, uint256 debtCollateralAmount) external {
        _store.repayCancelledDebt(totalCollateralAmount, debtCollateralAmount);
    }

    function repayCancelledCollateral(
        uint256 debtCollateralAmount,
        uint256 balance
    )
        external
        returns (uint256 toUserCollateralAmount, uint256 repayCollateralAmount, uint256 boostFeeCollateralAmount)
    {
        return _store.repayCancelledCollateral(debtCollateralAmount, balance);
    }

    function repayDebt(IGmxV2Adatper.Prices memory prices) external {
        _store.repayDebt(prices);
    }

    function repayByCollateral(
        uint256 debtCollateralAmount,
        uint256 debtFeeCollateralAmount,
        uint256 collateralAmount
    )
        external
        returns (
            uint256 remainCollateralAmount,
            uint256 repaidCollateralAmount,
            uint256 repaidFeeCollateralAmount,
            uint256 unpaidDebtCollateralAmount,
            uint256 unpaidFeeCollateralAmount
        )
    {
        IGmxV2Adatper.DebtResult memory result;
        result.debtCollateralAmount = debtCollateralAmount;
        result.totalFeeCollateralAmount = debtFeeCollateralAmount;
        result.collateralBalance = collateralAmount;
        result = _store.repayByCollateral(result);
        return (
            result.refundCollateralAmount,
            result.repaidDebtCollateralAmount,
            result.repaidFeeCollateralAmount,
            result.unpaidDebtCollateralAmount,
            result.unpaidFeeCollateralAmount
        );
    }

    function repayBySecondaryToken(
        IGmxV2Adatper.Prices memory prices,
        uint256 debtCollateralAmount,
        uint256 debtFeeCollateralAmount,
        address secondaryToken,
        uint256 secondaryAmount
    )
        external
        returns (
            uint256 remainSecondaryAmount,
            uint256 repaidSecondaryAmount,
            uint256 repaidFeeSecondaryAmount,
            uint256 unpaidDebtCollateralAmount,
            uint256 unpaidFeeCollateralAmount
        )
    {
        IGmxV2Adatper.DebtResult memory result;
        result.unpaidDebtCollateralAmount = debtCollateralAmount;
        result.unpaidFeeCollateralAmount = debtFeeCollateralAmount;
        result.secondaryTokenBalance = secondaryAmount;

        result = _store.repayBySecondaryToken(result, secondaryToken);

        return (
            result.refundSecondaryTokenAmount,
            result.repaidDebtSecondaryTokenAmount,
            result.repaidFeeSecondaryTokenAmount,
            result.unpaidDebtCollateralAmount,
            result.unpaidFeeCollateralAmount
        );
    }
}
