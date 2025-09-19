// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSAddressStore facet
 */
interface IAddressStore {
    enum Role {
        GOV_TIMELOCK,
        GOV,
        MANAGER,
        GOV_EMERGENCY
    }

    struct Addresses {
        address gns;
        address gnsStaking;
        address treasury;
    }

    struct AddressStore {
        uint256 __deprecated; // previously globalAddresses (gns token only, 1 slot)
        mapping(address => mapping(Role => bool)) accessControl;
        Addresses globalAddresses;
        uint256[7] __gap1; // gap for global addresses
        // insert new storage here
        uint256[38] __gap2; // gap for rest of diamond storage
    }
}
