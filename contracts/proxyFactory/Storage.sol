// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Storage is Initializable {
    uint256 internal constant VIRTUAL_ASSET_ID = 255;

    struct ConfigData {
        uint32 version;
        uint256[] values;
    }

    struct DebtData {
        uint256 limit;
        uint256 totalDebt;
        uint256 badDebt;
        uint8 assetId;
        bool hasValue;
        uint256[5] reserved;
    }

    mapping(uint256 => address) internal _implementations;
    // id => proxy
    mapping(bytes32 => address) internal _tradingProxies;
    // user => proxies
    mapping(address => address[]) internal _ownedProxies;
    // proxy => projectId
    mapping(address => uint256) internal _proxyProjectIds;

    address internal _liquidityPool;

    mapping(uint256 => ConfigData) internal _projectConfigs;
    mapping(uint256 => mapping(address => ConfigData)) internal _projectAssetConfigs;

    address internal _weth;
    mapping(address => bool) internal _keepers;

    address internal _referralManager;

    mapping(uint256 => mapping(address => DebtData)) internal _debtData;

    mapping(address => bool) _maintainers;

    address internal _muxOrderBook;

    bytes32[50] private __gaps;
}
