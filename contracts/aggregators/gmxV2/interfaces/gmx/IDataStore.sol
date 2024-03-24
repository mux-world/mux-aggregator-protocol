// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

bytes32 constant MIN_COLLATERAL_USD = keccak256(abi.encode("MIN_COLLATERAL_USD"));
bytes32 constant POSITION_LIST = keccak256(abi.encode("POSITION_LIST"));

interface IDataStore {
    function roleStore() external view returns (address);

    function getUint(bytes32 key) external view returns (uint256);

    function getInt(bytes32 key) external view returns (int256);

    function getAddress(bytes32 key) external view returns (address);

    function getBool(bytes32 key) external view returns (bool);

    function getString(bytes32 key) external view returns (string memory);

    function getBytes32(bytes32 key) external view returns (bytes32);

    function getUintArray(bytes32 key) external view returns (uint256[] memory);

    function getIntArray(bytes32 key) external view returns (int256[] memory);

    function getAddressArray(bytes32 key) external view returns (address[] memory);

    function getBoolArray(bytes32 key) external view returns (bool[] memory);

    function getStringArray(bytes32 key) external view returns (string[] memory);

    function getBytes32Array(bytes32 key) external view returns (bytes32[] memory);

    function containsBytes32(bytes32 setKey, bytes32 value) external view returns (bool);

    function getBytes32Count(bytes32 setKey) external view returns (uint256);

    function getBytes32ValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (bytes32[] memory);

    function containsAddress(bytes32 setKey, address value) external view returns (bool);

    function getAddressCount(bytes32 setKey) external view returns (uint256);

    function getAddressValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (address[] memory);

    function containsUint(bytes32 setKey, uint256 value) external view returns (bool);

    function getUintCount(bytes32 setKey) external view returns (uint256);

    function getUintValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (uint256[] memory);
}
