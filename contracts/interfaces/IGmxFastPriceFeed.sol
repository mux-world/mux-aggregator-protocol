// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGmxFastPriceFeed {
    function setPricesWithBitsAndExecute(
        uint256 _priceBits,
        uint256 _timestamp,
        uint256 _endIndexForIncreasePositions,
        uint256 _endIndexForDecreasePositions,
        uint256 _maxIncreasePositions,
        uint256 _maxDecreasePositions
    ) external;

    function setPricesWithBits(uint256 _priceBits, uint256 _timestamp) external;

    function gov() external view returns (address);

    function setUpdater(address _account, bool _isActive) external;
}
