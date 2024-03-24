// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

contract MockArbSys {
    uint256 public initialBlockNumber;
    uint256 incremental;

    function conructor(uint256 init) external {
        initialBlockNumber = init;
    }

    function resetBlockNumber() external {
        incremental = 0;
    }

    function increaseBlockNumber(uint256 amount) external {
        incremental += amount;
    }

    function arbBlockNumber() external view returns (uint256) {
        return initialBlockNumber + incremental;
    }
}
