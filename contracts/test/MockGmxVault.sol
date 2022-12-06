// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IGmxVault.sol";

contract MockGmxVault is IGmxVault {
    using SafeERC20 for IERC20;

    uint256 public minPrice;
    uint256 public maxPrice;
    mapping(address => mapping(address => uint256)) public swapRate;

    function setPrice(uint256 _minPrice, uint256 _maxPrice) external {
        minPrice = _minPrice;
        maxPrice = _maxPrice;
    }

    function swap(
        address _tokenIn,
        address _tokenOut,
        address _receiver
    ) external returns (uint256) {
        uint256 amountIn = IERC20(_tokenIn).balanceOf(address(this));
        uint256 rate = swapRate[_tokenIn][_tokenOut];
        uint256 amountOut = (amountIn * rate) / 1e18;
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(_tokenOut).safeTransfer(_receiver, amountOut);
        return amountOut;
    }

    function getPositionDelta(
        address,
        address,
        address,
        bool
    ) external pure returns (bool, uint256) {
        return (true, 10**30);
    }

    function getDelta(
        address,
        uint256,
        uint256,
        bool,
        uint256
    ) external pure returns (bool, uint256) {
        return (true, 10**30);
    }

    function getMaxPrice(address) external view returns (uint256) {
        return maxPrice;
    }

    function getMinPrice(address) external view returns (uint256) {
        return minPrice;
    }

    function positions(bytes32 key) external pure returns (Position memory) {}

    function getPosition(
        address,
        address,
        address,
        bool
    )
        external
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            uint256
        )
    {
        return (0, 0, 0, 0, 0, 0, false, 0);
    }

    function getFundingFee(
        address,
        uint256,
        uint256
    ) external pure returns (uint256) {
        return 0;
    }

    function getNextAveragePrice(
        address,
        uint256,
        uint256,
        bool,
        uint256,
        uint256,
        uint256
    ) external pure returns (uint256) {
        return 0;
    }

    function gov() external pure returns (address) {}

    function usdgAmounts(address) external pure returns (uint256) {
        return 0;
    }

    function tokenWeights(address) external pure returns (uint256) {
        return 0;
    }

    function totalTokenWeights() external pure returns (uint256) {
        return 0;
    }

    function liquidationFeeUsd() external pure returns (uint256) {
        return 0;
    }

    function taxBasisPoints() external pure returns (uint256) {
        return 0;
    }

    function stableTaxBasisPoints() external pure returns (uint256) {
        return 0;
    }

    function swapFeeBasisPoints() external pure returns (uint256) {
        return 0;
    }

    function stableSwapFeeBasisPoints() external pure returns (uint256) {
        return 0;
    }

    function marginFeeBasisPoints() external pure returns (uint256) {
        return 0;
    }

    function priceFeed() external pure returns (address) {
        return address(0);
    }

    function poolAmounts(address) external pure returns (uint256) {
        return 0;
    }

    function bufferAmounts(address) external pure returns (uint256) {
        return 0;
    }

    function reservedAmounts(address) external pure returns (uint256) {
        return 0;
    }

    function getRedemptionAmount(address, uint256) external pure returns (uint256) {
        return 0;
    }

    function minProfitTime() external pure returns (uint256) {
        return 0;
    }

    function minProfitBasisPoints(address) external pure returns (uint256) {
        return 0;
    }

    function maxUsdgAmounts(address) external pure returns (uint256) {
        return 0;
    }

    function globalShortSizes(address) external pure returns (uint256) {
        return 0;
    }

    function maxGlobalShortSizes(address) external pure returns (uint256) {
        return 0;
    }

    function guaranteedUsd(address) external pure returns (uint256) {
        return 0;
    }

    function stableTokens(address) external pure returns (bool) {
        return false;
    }

    function fundingRateFactor() external pure returns (uint256) {
        return 0;
    }

    function stableFundingRateFactor() external pure returns (uint256) {
        return 0;
    }

    function cumulativeFundingRates(address) external pure returns (uint256) {
        return 0;
    }

    function getNextFundingRate(address) external pure returns (uint256) {
        return 0;
    }

    function getEntryFundingRate(
        address,
        address,
        bool
    ) external pure returns (uint256) {
        return 0;
    }

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external {}

    function setLiquidator(address, bool) external {}
}
