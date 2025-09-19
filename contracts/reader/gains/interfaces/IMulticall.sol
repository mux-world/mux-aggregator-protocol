// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IMulticall {
    /**
     * @dev Call multiple functions in a single call.
     * @param data The data for the calls.
     * @return results The results of the calls.
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}
