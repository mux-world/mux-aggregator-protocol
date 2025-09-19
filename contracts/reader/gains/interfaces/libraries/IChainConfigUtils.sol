// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IChainConfig.sol";

/**
 * @dev Interface for GNSChainConfig facet (inherits types and also contains functions, events, and custom errors)
 */
interface IChainConfigUtils is IChainConfig {
    /**
     * @dev Initializer for ChainConfig facet
     * @param _nativeTransferGasLimit new native transfer gas limit
     * @param _nativeTransferEnabled whether native transfers should be enabled
     */
    function initializeChainConfig(uint16 _nativeTransferGasLimit, bool _nativeTransferEnabled) external;

    /**
     * @dev Updates native transfer gas limit
     * @param _nativeTransferGasLimit new native transfer gas limit. Must be greater or equal to MIN_NATIVE_TRANSFER_GAS_LIMIT.
     */
    function updateNativeTransferGasLimit(uint16 _nativeTransferGasLimit) external;

    /**
     * @dev Updates `nativeTransferEnabled`. When true, the diamond is allowed to unwrap native tokens on transfer-out.
     * @param _nativeTransferEnable the new value
     */
    function updateNativeTransferEnabled(bool _nativeTransferEnable) external;

    /**
     * @dev Returns gas limit to be used for native transfers, with a minimum of `MIN_NATIVE_TRANSFER_GAS_LIMIT` (21k gas)
     */
    function getNativeTransferGasLimit() external returns (uint16);

    /**
     * @dev Returns whether native transfers are enabled
     */
    function getNativeTransferEnabled() external returns (bool);

    /**
     * @dev Returns the current value for reentrancy lock
     */
    function getReentrancyLock() external returns (uint256);

    /**
     * @dev Emitted when `nativeTransferGasLimit` is updated
     * @param newLimit new gas limit
     */
    event NativeTransferGasLimitUpdated(uint16 newLimit);

    /**
     * @dev Emitted when `nativeTransferEnabled` is updated
     * @param enabled the new value
     */
    event NativeTransferEnabledUpdated(bool enabled);
}
