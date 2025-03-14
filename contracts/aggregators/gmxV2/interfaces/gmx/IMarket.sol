// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IPrice.sol";

interface IMarket {
    // Market.sol
    struct Props {
        address marketToken;
        address indexToken;
        address longToken;
        address shortToken;
    }

    // MarketUtils.sol
    struct MarketPrices {
        IPrice.Props indexTokenPrice;
        IPrice.Props longTokenPrice;
        IPrice.Props shortTokenPrice;
    }
}
