// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGmxReader {
    // VaultReader
    function getVaultTokenInfoV4(address _vault, address _positionManager, address _weth, uint256 _usdgAmount, address[] memory _tokens) external view returns (uint256[] memory);

    // Reader
    function getPositions(address _vault, address _account, address[] memory _collateralTokens, address[] memory _indexTokens, bool[] memory _isLong) external view returns(uint256[] memory);
    function getFundingRates(address _vault, address _weth, address[] memory _tokens) external view returns (uint256[] memory);
}
