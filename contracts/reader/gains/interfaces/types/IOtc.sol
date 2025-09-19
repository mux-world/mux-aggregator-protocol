// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSPairsStorage facet
 */
interface IOtc {
    struct OtcStorage {
        mapping(uint8 => uint256) collateralBalances; // collateralIndex => available OTC value (collateral precision)
        OtcConfig otcConfig;
        uint256[47] __gap;
    }

    struct OtcConfig {
        address gnsTreasury; /// @custom:deprecated Use `AddressStore.globalAddresses.treasury` instead
        uint64 treasuryShareP; // %, 1e10 precision
        uint64 stakingShareP; // %, 1e10 precision
        uint64 burnShareP; // %, 1e10 precision
        uint64 premiumP; // %, 1e10 precision
    }
}
