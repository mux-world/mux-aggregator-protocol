// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IMarket.sol";

interface IReaderLite {
    function getMarketTokens(
        address dataStore,
        address key
    ) external view returns (address marketToken, address indexToken, address longToken, address shortToken);

    function isOrderExist(address dataStore, bytes32 orderKey) external view returns (bool);

    function getPositionSizeInUsd(address dataStore, bytes32 positionKey) external view returns (uint256);

    function getPositionMarginInfo(
        address dataStore,
        address referralStorage,
        bytes32 positionKey,
        IMarket.MarketPrices memory prices
    )
        external
        view
        returns (uint256 collateralAmount, uint256 sizeInUsd, uint256 totalCostAmount, int256 pnlAfterPriceImpactUsd);

    function getMaxPositionFeeUsd(
        address dataStore,
        uint256 sizeDeltaUsd
    ) external view returns (uint256 positionFeeUsd);
}
