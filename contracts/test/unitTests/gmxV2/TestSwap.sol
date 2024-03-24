// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.17;

import "../../../interfaces/ILiquidityPool.sol";

import "../../../aggregators/gmxV2/libraries/LibSwap.sol";
import "../../../aggregators/gmxV2/interfaces/IGmxV2Adatper.sol";
import "../../../aggregators/gmxV2/interfaces/gmx/IReader.sol";

import "hardhat/console.sol";

contract TestLibSwap {
    using LibSwap for IGmxV2Adatper.GmxAdapterStoreV2;
    using LibSwap for bytes;

    mapping(address => uint8) private _assetIds;
    mapping(uint8 => ILiquidityPool.Asset) private _assets;

    IGmxV2Adatper.GmxAdapterStoreV2 private _store;

    function testAll() external {
        before();

        console.log("testSwapCase1");
        testSwapCase1();

        console.log("testSwapCase2");
        testSwapCase2();
    }

    function getAssetId(uint256, address token) external view returns (uint8) {
        return _assetIds[token];
    }

    function getAssetInfo(uint8 assetId) external view returns (ILiquidityPool.Asset memory asset) {
        return _assets[assetId];
    }

    function before() internal {
        _store.projectConfigs.swapRouter = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    }

    // virtual asset
    function testSwapCase1() public {
        address weth = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        address usdc = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        uint24 fee = 500;

        bytes memory swapPath = abi.encodePacked(bytes20(weth), bytes3(fee), bytes20(usdc));

        IGmxV2Adatper.OrderCreateParams memory createParams;
        createParams.swapPath = swapPath;
        createParams.initialCollateralAmount = 1e18;

        _swapCollateral(createParams, address(this));

        require(IERC20Upgradeable(usdc).balanceOf(address(this)) > 0);
    }

    function testSwapCase2() public {
        address weth = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        address usdc = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        address usdt = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
        uint24 fee = 500;

        bytes memory swapPath = abi.encodePacked(bytes20(weth), bytes3(fee), bytes20(usdc), bytes3(fee), bytes20(usdt));

        IGmxV2Adatper.OrderCreateParams memory createParams;
        createParams.swapPath = swapPath;
        createParams.initialCollateralAmount = 1e18;

        _swapCollateral(createParams, address(this));

        require(IERC20Upgradeable(usdt).balanceOf(address(this)) > 0);
    }

    function _swapCollateral(
        IGmxV2Adatper.OrderCreateParams memory createParams,
        address recipient
    ) internal returns (uint256 amountOut) {
        address tokenIn = createParams.swapPath.decodeInputToken();
        amountOut = _store.swap(
            createParams.swapPath,
            tokenIn,
            createParams.initialCollateralAmount,
            createParams.tokenOutMinAmount,
            recipient
        );
    }

    function buildPath2(address token1, uint24 fee1, address token2) external pure returns (bytes memory path) {
        path = abi.encodePacked(bytes20(token1), bytes3(fee1), bytes20(token2));
    }

    function buildPath3(
        address token1,
        uint24 fee1,
        address token2,
        uint24 fee2,
        address token3
    ) external pure returns (bytes memory path) {
        path = abi.encodePacked(bytes20(token1), bytes3(fee1), bytes20(token2), bytes3(fee2), bytes20(token3));
    }
}
