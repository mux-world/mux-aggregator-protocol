// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Interface for Chainlink feeds
 */
interface IChainlinkFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);

    function decimals() external view returns (uint8);
}
