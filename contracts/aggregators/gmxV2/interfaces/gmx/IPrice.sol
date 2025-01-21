// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Price.sol
interface IPrice {
    // @param min the min price
    // @param max the max price
    struct Props {
        uint256 min;
        uint256 max;
    }
}
