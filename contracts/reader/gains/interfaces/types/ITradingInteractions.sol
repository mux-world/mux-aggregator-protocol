// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSTradingInteractions facet
 */
interface ITradingInteractions {
    struct TradingInteractionsStorage {
        address senderOverride; // 160 bits
        uint16 marketOrdersTimeoutBlocks; // 16 bits
        uint80 __placeholder;
        mapping(address => address) delegations;
        mapping(address => bool) byPassTriggerLink;
        uint256[47] __gap;
    }
}
