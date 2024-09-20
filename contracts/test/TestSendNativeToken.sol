// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";

import "../interfaces/IWETH.sol";
import "../aggregators/gmx/libs/LibUtils.sol";

contract EthReceiver {
    bool public isNativeAcceptable;

    receive() external payable {
        require(isNativeAcceptable, "ETH not accepted");
        console.log("Received %s wei", msg.value);
    }

    function setIfNativeAcceptable(bool accept) external {
        isNativeAcceptable = accept;
    }

    function callContract(address to, bytes memory callData, uint256 value) external {
        Address.functionCallWithValue(to, callData, value);
    }
}

contract Sender {
    function trySendNativeTokenV1(address weth, address receiver, uint256 amount) external payable {
        LibUtils.trySendNativeToken(weth, receiver, amount);
    }
}

contract TestSendNativeToken {
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    Sender sender;
    EthReceiver receiver;

    function setup() external {
        sender = new Sender();
        receiver = new EthReceiver();
    }

    function test_sendEther() public {
        require(IERC20(WETH).balanceOf(address(receiver)) == 0, "testSendEther.E01");
        receiver.setIfNativeAcceptable(false);
        sender.trySendNativeTokenV1{ value: 1e18 }(WETH, address(receiver), 1e18);
        require(IERC20(WETH).balanceOf(address(receiver)) == 1e18, "testSendEther.E02");

        receiver.setIfNativeAcceptable(true);
        sender.trySendNativeTokenV1{ value: 1e18 }(WETH, address(receiver), 1e18);
        require(IERC20(WETH).balanceOf(address(receiver)) == 1e18, "testSendEther.E03");
        require(address(receiver).balance == 1e18, "testSendEther.E04");
    }
}
