// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Type.sol";

contract Storage is Initializable {
    uint256 internal constant PROJECT_ID = 1;
    uint256 internal constant VIRTUAL_ASSET_ID = 255;

    uint32 internal _localProjectVersion;
    mapping(address => uint32) _localAssetVersions;

    address internal _factory;
    address internal _liquidityPool;
    bytes32 internal _gmxPositionKey;

    ProjectConfigs internal _projectConfigs;
    TokenConfigs internal _assetConfigs;

    AccountState internal _account;
    EnumerableSetUpgradeable.Bytes32Set internal _pendingOrders;
    EnumerableMapUpgradeable.Bytes32ToBytes32Map internal _openTpslOrderIndexes;
    EnumerableSetUpgradeable.Bytes32Set internal _closeTpslOrderIndexes;

    bytes32[48] private __gaps;
}
