// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSChainConfig facet
 */
interface IChainConfig {
    struct ChainConfigStorage {
        uint256 reentrancyLock; // HAS TO BE FIRST AND TAKE A FULL SLOT (GNSReentrancyGuard expects it)
        uint16 nativeTransferGasLimit; // 16 bits. 64,535 max value
        bool nativeTransferEnabled; // When true, the diamond is allowed to unwrap native tokens on transfer out
        uint232 __placeholder;
        uint256[48] __gap;
    }
}
