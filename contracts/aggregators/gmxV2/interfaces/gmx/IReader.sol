// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IPrice.sol";
import "./IOrder.sol";
import "./IMarket.sol";
import "./IPosition.sol";
import "./IPositionPricing.sol";

interface IReader {
    // ReaderPricingUtils.sol
    struct ExecutionPriceResult {
        int256 priceImpactUsd;
        uint256 priceImpactDiffUsd;
        uint256 executionPrice;
    }

    struct PositionInfo {
        IPosition.Props position;
        IPositionPricing.PositionFees fees;
        ExecutionPriceResult executionPriceResult;
        int256 basePnlUsd;
        int256 pnlAfterPriceImpactUsd;
    }

    function getPositionInfo(
        address dataStore,
        address referralStorage,
        bytes32 positionKey,
        IMarket.MarketPrices memory prices,
        uint256 sizeDeltaUsd,
        address uiFeeReceiver,
        bool usePositionSizeAsSizeDeltaUsd
    ) external view returns (PositionInfo memory);

    function getPosition(address dataStore, bytes32 key) external view returns (IPosition.Props memory);

    function getOrder(address dataStore, bytes32 key) external view returns (IOrder.Props memory);

    function getAccountOrders(
        address dataStore,
        address account,
        uint256 start,
        uint256 end
    ) external view returns (IOrder.Props[] memory);

    function getMarket(address dataStore, address key) external view returns (IMarket.Props memory);
}
