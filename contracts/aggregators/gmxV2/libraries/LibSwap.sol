// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "../../../interfaces/IPriceHub.sol";
import "../interfaces/IGmxV2Adatper.sol";

library LibSwap {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function swapCollateral(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        bytes memory swapPath,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountOut) {
        address tokenIn = decodeInputToken(swapPath);
        require(tokenIn != store.account.collateralToken, "IllegalTokenIn");
        amountOut = swap(store, swapPath, tokenIn, amountIn, minAmountOut, recipient);
    }

    function swap(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        bytes memory swapPath,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountOut) {
        address swapRouter = store.projectConfigs.swapRouter;
        require(swapRouter != address(0), "swapRouterUnset");
        // exact input swap to convert exact amount of tokens into usdc
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: swapPath,
            recipient: recipient,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut
        });
        // executes the swap on uniswap pool
        IERC20Upgradeable(tokenIn).approve(store.projectConfigs.swapRouter, amountIn);
        // since exact input swap tokens used = token amount passed
        amountOut = ISwapRouter(store.projectConfigs.swapRouter).exactInput(params);
    }

    // function emergencySwap(
    //     IGmxV2Adatper.GmxAdapterStoreV2 storage store,
    //     bytes memory swapPath,
    //     address tokenIn,
    //     uint256 totalBalance,
    //     uint256 expAmountOut,
    //     uint256 minAmountOut,
    //     address recipient
    // ) external returns (uint256 amountIn, uint256 amountOut) {
    //     address swapRouter = store.projectConfigs.swapRouter;
    //     require(swapRouter != address(0), "swapRouterUnset");

    //     IERC20Upgradeable(tokenIn).approve(swapRouter, totalBalance);
    //     ISwapRouter.ExactOutputParams memory exactOutParams = ISwapRouter.ExactOutputParams({
    //         path: swapPath,
    //         recipient: recipient,
    //         deadline: block.timestamp,
    //         amountOut: expAmountOut,
    //         amountInMaximum: totalBalance
    //     });
    //     try ISwapRouter(swapRouter).exactOutput(exactOutParams) returns (uint256 amountIn_) {
    //         amountIn = amountIn_;
    //         amountOut = expAmountOut;
    //     } catch {
    //         // uint256 minAmountOut = (amountOut * (1e18 - slippageTolerance)) / 1e18;
    //         ISwapRouter.ExactInputParams memory exactInParams = ISwapRouter.ExactInputParams({
    //             path: swapPath,
    //             recipient: recipient,
    //             deadline: block.timestamp,
    //             amountIn: amountIn,
    //             amountOutMinimum: minAmountOut
    //         });
    //         // executes the swap on uniswap pool
    //         IERC20Upgradeable(tokenIn).approve(swapRouter, amountIn);
    //         // since exact input swap tokens used = token amount passed
    //         amountOut = ISwapRouter(swapRouter).exactInput(exactInParams);
    //         amountIn = totalBalance;
    //     }
    // }

    function decodeInputToken(bytes memory _bytes) internal pure returns (address) {
        require(_bytes.length >= 20, "outOfBounds");
        address tempAddress;
        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), 0)), 0x1000000000000000000000000)
        }
        return tempAddress;
    }
}
