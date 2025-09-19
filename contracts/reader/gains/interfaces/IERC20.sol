// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface for ERC20 tokens
 */
interface IERC20 is IERC20Metadata {
    function burn(address, uint256) external;

    function mint(address, uint256) external;

    function hasRole(bytes32, address) external view returns (bool);
}
