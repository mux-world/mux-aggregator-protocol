// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGmxPositionManager {
    function executeIncreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver
    ) external;

    function executeDecreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver
    ) external;

    function setOrderKeeper(address _account, bool _isActive) external;

    function admin() external view returns (address);
}
