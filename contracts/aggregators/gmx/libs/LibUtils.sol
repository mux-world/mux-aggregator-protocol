// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../../interfaces/IWETH.sol";

library LibUtils {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant RATE_DENOMINATOR = 1e5;

    function toAddress(bytes32 value) internal pure returns (address) {
        return address(bytes20(value));
    }

    function toAddress(uint256 value) internal pure returns (address) {
        return address(bytes20(bytes32(value)));
    }

    function toU256(address value) internal pure returns (uint256) {
        return uint256(uint160(value));
    }

    function toU32(bytes32 value) internal pure returns (uint32) {
        require(uint256(value) <= type(uint32).max, "OU32");
        return uint32(uint256(value));
    }

    function toU32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "OU32");
        return uint32(value);
    }

    function toU8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "OU8");
        return uint8(value);
    }

    function toU96(uint256 n) internal pure returns (uint96) {
        require(n <= type(uint96).max, "OU96"); // uint96 Overflow
        return uint96(n);
    }

    function rate(uint256 value, uint32 rate_) internal pure returns (uint256) {
        return (value * rate_) / RATE_DENOMINATOR;
    }

    function trySendNativeToken(address weth, address receiver, uint256 amount) internal {
        (bool success, ) = receiver.call{ value: amount }("");
        if (success) {
            return;
        }
        IWETH(weth).deposit{ value: amount }();
        IERC20Upgradeable(weth).safeTransfer(receiver, amount);
    }
}
