// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

bytes32 constant CONTROLLER = keccak256(abi.encode("CONTROLLER"));

interface IRoleStore {
    function hasRole(address account, bytes32 roleKey) external view returns (bool);
}
