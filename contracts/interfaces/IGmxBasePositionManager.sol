// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IGmxBasePositionManager {
    function maxGlobalLongSizes(address _token) external view returns (uint256);
    function maxGlobalShortSizes(address _token) external view returns (uint256);
}
