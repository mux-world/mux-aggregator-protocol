// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../aggregators/gmxV2/interfaces/gmx/IPrice.sol";
import "../aggregators/gmxV2/interfaces/gmx/IOrder.sol";
import "../aggregators/gmxV2/interfaces/gmx/IMarket.sol";
import "../aggregators/gmxV2/interfaces/gmx/IPosition.sol";
import "../aggregators/gmxV2/interfaces/gmx/IPositionPricing.sol";

contract MockGmxV2Reader {
    uint256 sizeInUsd;

    function setSizeInUsd(uint256 sizeInUsd_) external {
        sizeInUsd = sizeInUsd_;
    }

    function getPosition(address, bytes32) external view returns (IPosition.Props memory props) {
        props.numbers.sizeInUsd = sizeInUsd;
    }

    function getMarket(address, address) external view returns (IMarket.Props memory props) {
        props.marketToken = address(0x70d95587d40A2caf56bd97485aB3Eec10Bee6336);
        props.indexToken = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        props.longToken = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        props.shortToken = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    }

    function getMarketTokens(
        address dataStore,
        address key
    ) external view returns (address marketToken, address indexToken, address longToken, address shortToken) {
        marketToken = address(0x70d95587d40A2caf56bd97485aB3Eec10Bee6336);
        indexToken = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        longToken = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        shortToken = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    }

    function isOrderExist(address dataStore, bytes32 orderKey) external view returns (bool) {
        return false;
    }

    function getPositionSizeInUsd(address dataStore, bytes32 positionKey) external view returns (uint256) {
        return sizeInUsd;
    }

    function getPositionMarginInfo(
        address dataStore,
        address referralStorage,
        bytes32 positionKey,
        IMarket.MarketPrices memory prices
    )
        external
        view
        returns (uint256 collateralAmount, uint256 _sizeInUsd, uint256 totalCostAmount, int256 pnlAfterPriceImpactUsd)
    {
        collateralAmount = 0;
        _sizeInUsd = sizeInUsd;
        totalCostAmount = 0;
        pnlAfterPriceImpactUsd = 0;
    }
}
