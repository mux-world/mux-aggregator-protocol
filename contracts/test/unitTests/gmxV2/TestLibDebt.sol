// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.17;

import "../../../aggregators/gmxV2/libraries/LibDebt.sol";

import "../../../aggregators/gmxV2/interfaces/IGmxV2Adatper.sol";
import "../../../aggregators/gmxV2/interfaces/gmx/IReader.sol";
import "../../../interfaces/ILiquidityPool.sol";

import "hardhat/console.sol";

contract TestLibDebt {
    using LibDebt for IGmxV2Adatper.GmxAdapterStoreV2;

    mapping(address => uint8) private _assetIds;
    mapping(uint8 => ILiquidityPool.Asset) private _assets;

    IGmxV2Adatper.GmxAdapterStoreV2 private _store;

    function testAll() external {
        console.log("testGetNextMuxFundingCase1");
        testGetNextMuxFundingCase1();

        console.log("testGetNextMuxFundingCase2");
        testGetNextMuxFundingCase2();

        console.log("testGetNextMuxFundingCase3");
        testGetNextMuxFundingCase3();
    }

    function getAssetId(uint256, address token) external view returns (uint8) {
        return _assetIds[token];
    }

    function getAssetInfo(uint8 assetId) external view returns (ILiquidityPool.Asset memory asset) {
        return _assets[assetId];
    }

    // virtual asset
    function testGetNextMuxFundingCase1() public {
        address weth = address(0x1);

        // set env
        _store.factory = address(this);
        _store.liquidityPool = address(this);
        _store.account.collateralToken = weth;
        _assetIds[weth] = 255;

        (uint256 fundingFee, uint256 newFunding) = _store.getNextMuxFunding();
        require(fundingFee == 0);
        require(newFunding == 0);
    }

    // funding not stable decimals-18
    function testGetNextMuxFundingCase2() public {
        address weth = address(0x1);

        // set env
        _store.factory = address(this);
        _store.liquidityPool = address(this);
        _store.account.collateralToken = weth;

        _store.account.debtCollateralAmount = 12e18;
        _store.account.debtEntryFunding = 10e18;

        _assetIds[weth] = 3;
        _assets[3].longCumulativeFundingRate = 11e18; // increase by 1e18

        (uint256 fundingFee, uint256 newFunding) = _store.getNextMuxFunding();

        require(fundingFee == 12e18);
        require(newFunding == 11e18);
    }

    // funding not stable decimals-6
    function testGetNextMuxFundingCase3() public {
        address weth = address(0x1);

        // set env
        _store.factory = address(this);
        _store.liquidityPool = address(this);
        _store.account.collateralToken = weth;

        _store.account.debtCollateralAmount = 12e6;
        _store.account.debtEntryFunding = 10e18;

        _assetIds[weth] = 3;
        _assets[3].longCumulativeFundingRate = 11e18; // increase by 1e18

        (uint256 fundingFee, uint256 newFunding) = _store.getNextMuxFunding();

        require(fundingFee == 12e6);
        require(newFunding == 11e18);
    }
}
