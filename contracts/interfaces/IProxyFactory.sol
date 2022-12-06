// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IProxyFactory {
    function weth() external view returns (address);

    function getProxiesOf(address account) external view returns (address[] memory);

    function isKeeper(address keeper) external view returns (bool);

    function getProjectConfig(uint256 projectId) external view returns (uint256[] memory);

    function getProjectAssetConfig(uint256 projectId, address assetToken) external view returns (uint256[] memory);

    function getBorrowStates(uint256 projectId, address assetToken)
        external
        view
        returns (
            uint256 totalBorrow,
            uint256 borrowLimit,
            uint256 badDebt
        );

    function referralCode() external view returns (bytes32);

    function getAssetId(uint256 projectId, address token) external view returns (uint8);

    function borrowAsset(
        uint256 projectId,
        address collateralToken,
        uint256 amount,
        uint256 fee
    ) external returns (uint256 amountOut);

    function repayAsset(
        uint256 projectId,
        address collateralToken,
        uint256 amount,
        uint256 fee,
        uint256 badDebt_
    ) external;

    function getConfigVersions(uint256 projectId, address assetToken)
        external
        view
        returns (uint32 projectConfigVersion, uint32 assetConfigVersion);
}
