// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IGmxPositionRouter.sol";

contract MockGmxPositionRouter is IGmxPositionRouter {
    using SafeERC20 for IERC20;

    uint256 minFee = 1e9;

    mapping(address => uint256) public increasePositionsIndex;
    mapping(address => uint256) public decreasePositionsIndex;

    function setPositionKeeper(address _account, bool _isActive) external {}

    function minExecutionFee() external view returns (uint256) {
        return minFee;
    }

    function createIncreasePosition(
        address[] memory,
        address _indexToken,
        uint256 _amountIn,
        uint256,
        uint256,
        bool,
        uint256,
        uint256 _executionFee,
        bytes32,
        address
    ) external payable returns (bytes32) {
        require(msg.value == _executionFee);
        IERC20(_indexToken).safeTransferFrom(msg.sender, address(this), _amountIn);
        increasePositionsIndex[msg.sender] += 1;
    }

    function createDecreasePosition(
        address[] memory,
        address _indexToken,
        uint256 _collateralDelta,
        uint256,
        bool,
        address _receiver,
        uint256,
        uint256,
        uint256 _executionFee,
        bool,
        address
    ) external payable returns (bytes32) {
        require(msg.value == _executionFee);
        if (_collateralDelta > 0) {
            IERC20(_indexToken).safeTransfer(_receiver, _collateralDelta);
        }
        decreasePositionsIndex[msg.sender] += 1;
    }

    function cancelIncreasePosition(bytes32 _key, address payable _executionFeeReceiver) external returns (bool) {}

    function cancelDecreasePosition(bytes32 _key, address payable _executionFeeReceiver) external returns (bool) {}

    function increasePositionRequests(bytes32) external view returns (IncreasePositionRequest memory) {}

    function decreasePositionRequests(bytes32) external view returns (DecreasePositionRequest memory) {}

    function executeIncreasePosition(bytes32 _key, address payable _executionFeeReceiver) external returns (bool) {}

    function executeDecreasePosition(bytes32 _key, address payable _executionFeeReceiver) external returns (bool) {}
}
