// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./Storage.sol";

contract ProxyConfig is Storage {
    uint256 internal constant MUX_ASSET_ID = 0;

    event SetProjectConfig(uint256 projectId, uint256[] values, uint256 version);
    event SetProjectAssetConfig(uint256 projectId, address assetToken, uint256[] values, uint256 version);

    function _getLatestVersions(uint256 projectId, address assetToken)
        internal
        view
        returns (uint32 projectConfigVersion, uint32 assetConfigVersion)
    {
        projectConfigVersion = _projectConfigs[projectId].version;
        assetConfigVersion = _projectAssetConfigs[projectId][assetToken].version;
    }

    function _getConfig(uint256 projectId, address assetToken)
        internal
        view
        returns (uint256[] memory projectConfigValues, uint256[] memory assetConfigValues)
    {
        projectConfigValues = _projectConfigs[projectId].values;
        assetConfigValues = _projectAssetConfigs[projectId][assetToken].values;
    }

    function _setProjectConfig(uint256 projectId, uint256[] memory values) internal {
        _projectConfigs[projectId].values = values;
        _projectConfigs[projectId].version += 1;
        emit SetProjectConfig(projectId, values, _projectConfigs[projectId].version);
    }

    function _setProjectAssetConfig(
        uint256 projectId,
        address assetToken,
        uint256[] memory values
    ) internal {
        _projectAssetConfigs[projectId][assetToken].values = values;
        _projectAssetConfigs[projectId][assetToken].version += 1;
        emit SetProjectAssetConfig(projectId, assetToken, values, _projectAssetConfigs[projectId][assetToken].version);
    }
}
