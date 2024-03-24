// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.17;

import "../../../aggregators/gmxV2/libraries/LibDebt.sol";
import "../../../aggregators/gmxV2/libraries/LibGmxV2.sol";

import "../../../aggregators/gmxV2/interfaces/IGmxV2Adatper.sol";
import "../../../aggregators/gmxV2/interfaces/gmx/IReader.sol";
import "../../../interfaces/ILiquidityPool.sol";

import "hardhat/console.sol";

contract TestLibGmxV2 {
    using LibGmxV2 for IGmxV2Adatper.GmxAdapterStoreV2;
    using LibDebt for IGmxV2Adatper.GmxAdapterStoreV2;

    mapping(address => uint8) private _assetIds;
    mapping(uint8 => ILiquidityPool.Asset) private _assets;

    IGmxV2Adatper.GmxAdapterStoreV2 private _store;

    function testAll() external {
        console.log("testGetNextMuxFundingCase1");
        testGetNextMuxFundingCase1();
    }

    function getAssetId(uint256, address token) external view returns (uint8) {
        return _assetIds[token];
    }

    function getAssetInfo(uint8 assetId) external view returns (ILiquidityPool.Asset memory asset) {
        return _assets[assetId];
    }

    // virtual asset
    function testGetNextMuxFundingCase1() public {
        address usdc = address(0x1);

        // set env
        _store.factory = address(this);
        _store.liquidityPool = address(this);
        _store.account.collateralToken = usdc;
        _store.collateralTokenDecimals = 6;
        _store.account.debtEntryFunding = 207972500000000000;
        _store.account.debtCollateralAmount = 9350332;
        _store.marketConfigs.indexDecimals = 18;

        _assetIds[usdc] = 11;
        _assets[11].longCumulativeFundingRate = 207972500000000000;

        uint256 collateralAmount = 26554943;
        uint256 totalCostAmount = 1.309046e6;
        int256 pnlAfterPriceImpactUsd = -0.0004307285189455424936e30;

        uint256 collateralPrice = 1e18;

        uint256 marginValueUsd = _store.getMarginValueUsd(
            collateralAmount,
            totalCostAmount,
            pnlAfterPriceImpactUsd,
            collateralPrice
        );
        console.log("marginValueUsd", marginValueUsd);
        require(marginValueUsd == 17.2041802714810544575064e30);
    }
}
