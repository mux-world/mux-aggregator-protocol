// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @custom:version 8
 * @dev Generic interface for liquidity pool methods for fetching observations (to calculate TWAP) and other basic information
 */
interface ILiquidityPool {
    /**
     * @dev AlgebraPool V1.9 equivalent of Uniswap V3 `observe` function
     * See https://github.com/cryptoalgebra/AlgebraV1.9/blob/main/src/core/contracts/interfaces/pool/IAlgebraPoolDerivedState.sol for more information
     */
    function getTimepoints(
        uint32[] calldata secondsAgos
    )
        external
        view
        returns (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulatives,
            uint112[] memory volatilityCumulatives,
            uint256[] memory volumePerAvgLiquiditys
        );

    /**
     * @dev Uniswap V3 `observe` function
     * See `https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol` for more information
     */
    function observe(
        uint32[] calldata secondsAgos
    ) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /**
     * @notice The first of the two tokens of the pool, sorted by address
     * @return The token contract address
     */
    function token0() external view returns (address);

    /**
     * @notice The second of the two tokens of the pool, sorted by address
     * @return The token contract address
     */
    function token1() external view returns (address);
}
