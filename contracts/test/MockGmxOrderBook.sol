// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IGmxOrderBook.sol";

contract MockGmxOrderBook is IGmxOrderBook {
    struct IncreaseOrder {
        bool thisIsJustAMock;
    }
    struct DecreaseOrder {
        bool thisIsJustAMock;
    }

    mapping(address => mapping(uint256 => IncreaseOrder)) public increaseOrders;
    mapping(address => uint256) public increaseOrdersIndex;
    mapping(address => mapping(uint256 => DecreaseOrder)) public decreaseOrders;
    mapping(address => uint256) public decreaseOrdersIndex;

    function minExecutionFee() external view returns (uint256) {
        return 1e9;
    }

    function cancelMultiple(
        uint256[] memory _swapOrderIndexes,
        uint256[] memory _increaseOrderIndexes,
        uint256[] memory _decreaseOrderIndexes
    ) external {}

    function getIncreaseOrder(
        address _account,
        uint256 _orderIndex
    )
        public
        view
        override
        returns (
            address purchaseToken,
            uint256 purchaseTokenAmount,
            address collateralToken,
            address indexToken,
            uint256 sizeDelta,
            bool isLong,
            uint256 triggerPrice,
            bool triggerAboveThreshold,
            uint256 executionFee
        )
    {
        return (address(0), 0, address(0), address(0), 0, true, 0, true, 0);
    }

    function createIncreaseOrder(
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        address _collateralToken,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee,
        bool _shouldWrap
    ) external payable {
        require(msg.value == _executionFee);
        _path; // unused
        _amountIn; // unused
        _indexToken; // unused
        _minOut; // unused
        _sizeDelta; // unused
        _collateralToken; // unused
        _isLong; // unused
        _triggerPrice; // unused
        _triggerAboveThreshold; // unused
        _shouldWrap; // unused
        uint256 _orderIndex = increaseOrdersIndex[msg.sender] += 1;
        increaseOrdersIndex[msg.sender] += 1;
        increaseOrders[msg.sender][_orderIndex] = IncreaseOrder({ thisIsJustAMock: true });
    }

    function cancelIncreaseOrder(uint256 _orderIndex) external {
        delete increaseOrders[msg.sender][_orderIndex];
    }

    function getDecreaseOrder(
        address,
        uint256
    )
        public
        pure
        override
        returns (
            address collateralToken,
            uint256 collateralDelta,
            address indexToken,
            uint256 sizeDelta,
            bool isLong,
            uint256 triggerPrice,
            bool triggerAboveThreshold,
            uint256 executionFee
        )
    {
        return (address(0), 0, address(0), 0, true, 0, true, 0);
    }

    function createDecreaseOrder(address, uint256, address, uint256, bool, uint256, bool) external payable {
        uint256 _orderIndex = decreaseOrdersIndex[msg.sender] += 1;
        decreaseOrdersIndex[msg.sender] += 1;
        decreaseOrders[msg.sender][_orderIndex] = DecreaseOrder({ thisIsJustAMock: true });
    }

    function cancelDecreaseOrder(uint256 _orderIndex) external {
        delete decreaseOrders[msg.sender][_orderIndex];
    }

    function updateDecreaseOrder(
        uint256 _orderIndex,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external {}

    function updateIncreaseOrder(
        uint256 _orderIndex,
        uint256 _sizeDelta,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external {}

    function executeDecreaseOrder(address, uint256, address payable) external {}

    function executeIncreaseOrder(address, uint256, address payable) external {}
}
