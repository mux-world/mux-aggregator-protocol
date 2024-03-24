// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract MockPriceHub {
    mapping(address => uint256) prices;

    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    function getPriceByToken(address token) external view returns (uint256) {
        // console.log("getPriceByToken", token, prices[token]);
        require(prices[token] != 0, "Price not found");
        return prices[token];
    }
}
