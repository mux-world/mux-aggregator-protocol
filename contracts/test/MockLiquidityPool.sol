// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/ILiquidityPool.sol";

import "hardhat/console.sol";

contract MockLiquidityPool is ILiquidityPool {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(uint8 => Asset) internal assets;
    mapping(uint8 => uint256) public spotLiquidities;
    mapping(uint8 => mapping(address => uint256)) public debts;
    mapping(uint8 => uint256) public fees;

    function deposit(uint8 assetId, uint256 amount) external {
        require(assets[assetId].tokenAddress != address(0), "AssetNotExists");
        IERC20Upgradeable(assets[assetId].tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        spotLiquidities[assetId] += amount;
    }

    function withdraw(uint8 assetId, uint256 amount) external {
        require(assets[assetId].tokenAddress != address(0), "AssetNotExists");
        spotLiquidities[assetId] -= amount;
        IERC20Upgradeable(assets[assetId].tokenAddress).safeTransfer(msg.sender, amount);
    }

    function setAssetAddress(uint8 assetId, address assetAddress) external {
        assets[assetId].tokenAddress = assetAddress;
    }

    function setAssetFunding(
        uint8 assetId,
        uint128 longCumulativeFundingRate,
        uint128 shortCumulativeFunding
    ) external {
        assets[assetId].longCumulativeFundingRate = longCumulativeFundingRate;
        assets[assetId].shortCumulativeFunding = shortCumulativeFunding;
    }

    function borrowAsset(
        address borrower,
        uint8 assetId,
        uint256 rawAmount, // token.decimals
        uint256 rawFee // token.decimals
    ) external returns (uint256) {
        // debts[assetId][msg.sender] += rawAmount;
        fees[assetId] += rawFee;
        uint256 borrowed = rawAmount - rawFee;
        IERC20Upgradeable(assets[assetId].tokenAddress).safeTransfer(borrower, borrowed);
        console.log("=======> BORROW (to: %s) (amount: %s) (fee: %s)", borrower, rawAmount, rawFee);
        return borrowed;
    }

    function repayAsset(
        address repayer,
        uint8 assetId,
        uint256 rawAmount, // token.decimals
        uint256 rawFee, // token.decimals
        uint256 rawBadDebt // debt amount that cannot be recovered
    ) external {
        // debts[assetId][msg.sender] -= rawAmount;
        fees[assetId] += rawFee;
        console.log("=======> REPAY (to: %s) (amount: %s) (fee: %s)", repayer, rawAmount, rawFee);
        if (rawBadDebt > 0) {
            console.log("=======> REPAY (bad: %s)", rawBadDebt);
        }
    }

    function getAssetAddress(uint8 assetId) external view returns (address) {
        return assets[assetId].tokenAddress;
    }

    function getAssetInfo(uint8 assetId) external view returns (ILiquidityPool.Asset memory) {
        return assets[assetId];
    }

    function getAllAssetInfo() external view returns (Asset[] memory) {}

    function getLiquidityPoolStorage()
        external
        view
        returns (
            // [0] shortFundingBaseRate8H
            // [1] shortFundingLimitRate8H
            // [2] lastFundingTime
            // [3] fundingInterval
            // [4] liquidityBaseFeeRate
            // [5] liquidityDynamicFeeRate
            // [6] sequence. note: will be 0 after 0xffffffff
            // [7] strictStableDeviation
            uint32[8] memory u32s,
            // [0] mlpPriceLowerBound
            // [1] mlpPriceUpperBound
            uint96[2] memory u96s
        )
    {}

    function updateFundingState(
        uint32 stableUtilization, // 1e5
        uint8[] calldata unstableTokenIds,
        uint32[] calldata unstableUtilizations, // 1e5
        uint96[] calldata unstablePrices
    ) external {}

    function setLiquidityManager(address liquidityManager, bool enable) external {}
}
