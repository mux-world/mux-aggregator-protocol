// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../../../interfaces/ILiquidityPool.sol";
import "../../../interfaces/IProxyFactory.sol";
import "../../../interfaces/ILendingPool.sol";
import "../../../interfaces/IWETH.sol";
import "../../../interfaces/IPriceHub.sol";

import "../interfaces/IGmxV2Adatper.sol";
import "../interfaces/IEventEmitter.sol";

import "./LibGmxV2.sol";
import "./LibUtils.sol";

library LibDebt {
    using LibUtils for uint256;
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    using LibGmxV2 for IGmxV2Adatper.GmxAdapterStoreV2;
    using LibUtils for IGmxV2Adatper.GmxAdapterStoreV2;

    uint56 internal constant ASSET_IS_STABLE = 0x00000000000001; // is stable

    // implementations
    function updateMuxFundingFee(IGmxV2Adatper.GmxAdapterStoreV2 storage store) internal returns (uint256) {
        (uint256 fundingFee, uint256 nextFunding) = getNextMuxFunding(store);
        store.account.pendingFeeCollateralAmount += fundingFee;
        store.account.debtEntryFunding = nextFunding;
        return fundingFee;
    }

    function getMuxFundingFee(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store
    ) internal view returns (uint256 fundingFee) {
        (fundingFee, ) = getNextMuxFunding(store);
    }

    function getNextMuxFunding(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store
    ) internal view returns (uint256 fundingFee, uint256 newFunding) {
        uint8 collateralId = IProxyFactory(store.factory).getAssetId(PROJECT_ID, store.account.collateralToken);
        // is virtual
        if (collateralId == VIRTUAL_ASSET_ID) {
            fundingFee = 0;
            newFunding = 0;
            return (fundingFee, newFunding);
        }
        ILiquidityPool.Asset memory asset = ILiquidityPool(store.liquidityPool).getAssetInfo(collateralId);
        if (asset.flags & ASSET_IS_STABLE == 0) {
            // unstable
            newFunding = asset.longCumulativeFundingRate; // 1e18
            fundingFee = ((newFunding - store.account.debtEntryFunding) * store.account.debtCollateralAmount) / 1e18; // collateral.decimal
        } else {
            // stable
            ILiquidityPool.Asset memory fundingAsset = ILiquidityPool(store.liquidityPool).getAssetInfo(
                store.projectConfigs.fundingAssetId
            );
            newFunding = fundingAsset.shortCumulativeFunding; // 1e18
            uint256 fundingTokenPrice = IPriceHub(store.projectConfigs.priceHub).getPriceByToken(
                store.projectConfigs.fundingAsset
            ); // 1e18
            fundingFee =
                ((newFunding - store.account.debtEntryFunding) * store.account.debtCollateralAmount) /
                fundingTokenPrice; // collateral.decimal
        }
    }

    function borrowCollateral(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        uint256 borrowCollateralAmount
    ) internal returns (uint256 borrowedCollateralAmount, uint256 boostFeeCollateralAmount) {
        boostFeeCollateralAmount = (borrowCollateralAmount * store.marketConfigs.boostFeeRate) / 1e5;
        borrowedCollateralAmount = borrowCollateralAmount - boostFeeCollateralAmount;
        borrow(store, borrowCollateralAmount, boostFeeCollateralAmount);
        store.account.debtCollateralAmount += borrowCollateralAmount;
    }

    function repayCancelledDebt(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        uint256 totalCollateralAmount,
        uint256 debtCollateralAmount
    ) internal {
        IGmxV2Adatper.DebtResult memory result;
        result.fundingFeeCollateralAmount = updateMuxFundingFee(store);
        result.collateralBalance = IERC20Upgradeable(store.account.collateralToken).balanceOf(address(this));
        require(result.collateralBalance >= totalCollateralAmount, "NotEnoughBalance");
        (
            result.refundCollateralAmount,
            result.repaidDebtCollateralAmount,
            result.repaidFeeCollateralAmount
        ) = repayCancelledCollateral(store, debtCollateralAmount, totalCollateralAmount);
        transferTokenToOwner(store, store.account.collateralToken, result.refundCollateralAmount);
    }

    function repayCancelledCollateral(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        uint256 debtCollateralAmount,
        uint256 balance
    )
        internal
        returns (uint256 toUserCollateralAmount, uint256 repayCollateralAmount, uint256 boostFeeCollateralAmount)
    {
        toUserCollateralAmount = balance;
        if (debtCollateralAmount > 0) {
            // return collateral
            repayCollateralAmount = store.account.debtCollateralAmount.min(debtCollateralAmount);
            require(balance >= repayCollateralAmount, "InsufficientBalance");
            store.account.debtCollateralAmount -= repayCollateralAmount;
            toUserCollateralAmount -= repayCollateralAmount;
            // pay fee
            boostFeeCollateralAmount = repayCollateralAmount.rate(store.marketConfigs.boostFeeRate);
            if (toUserCollateralAmount >= boostFeeCollateralAmount) {
                // pay fee this time
                toUserCollateralAmount -= boostFeeCollateralAmount;
            } else {
                // pay fee next time
                store.account.pendingFeeCollateralAmount += boostFeeCollateralAmount;
                boostFeeCollateralAmount = 0;
            }
            repay(store, store.account.collateralToken, repayCollateralAmount, boostFeeCollateralAmount, 0);
        }
    }

    function refundTokens(IGmxV2Adatper.GmxAdapterStoreV2 storage store) internal {
        uint256 collateralBalance = IERC20Upgradeable(store.account.collateralToken).balanceOf(address(this));
        transferTokenToOwner(store, store.account.collateralToken, collateralBalance);
        address secondaryToken = store.getSecondaryToken();
        if (store.account.collateralToken != secondaryToken) {
            uint256 secondaryTokenBalance = IERC20Upgradeable(secondaryToken).balanceOf(address(this));
            transferTokenToOwner(store, secondaryToken, secondaryTokenBalance);
        }
        store.account.isLiquidating = false;
    }

    function repayDebt(IGmxV2Adatper.GmxAdapterStoreV2 storage store, IGmxV2Adatper.Prices memory prices) internal {
        IGmxV2Adatper.DebtResult memory result;
        if (store.account.collateralToken == WETH) {
            IWETH(WETH).deposit{ value: address(this).balance }();
        }
        // 1. get oracle price and gmx position
        uint256 sizeInUsd = IReaderLite(store.projectConfigs.reader).getPositionSizeInUsd(
            store.projectConfigs.dataStore,
            store.positionKey
        );
        result.prices = prices;
        // 2. get balance in proxy
        result.fundingFeeCollateralAmount = updateMuxFundingFee(store);
        result.collateralBalance = IERC20Upgradeable(store.account.collateralToken).balanceOf(address(this));
        if (sizeInUsd != 0) {
            if (store.isOpenSafe(result.prices, 0, 0)) {
                result.refundCollateralAmount = result.collateralBalance;
                transferTokenToOwner(store, store.account.collateralToken, result.refundCollateralAmount);
            }
        } else {
            // totalDebt
            result.debtCollateralAmount =
                store.account.debtCollateralAmount -
                store.account.inflightDebtCollateralAmount;
            // totalFee
            result.boostFeeCollateralAmount = result.debtCollateralAmount.rate(store.marketConfigs.boostFeeRate);
            if (store.account.isLiquidating) {
                result.liquidationFeeCollateralAmount = result.debtCollateralAmount.rate(
                    store.marketConfigs.liquidationFeeRate
                );
            }
            result.totalFeeCollateralAmount =
                result.boostFeeCollateralAmount +
                store.account.pendingFeeCollateralAmount +
                result.liquidationFeeCollateralAmount;
            // repay by collateral
            result = repayByCollateral(store, result);
            // check secondary token
            address secondaryToken = store.getSecondaryToken();
            result.secondaryTokenBalance = IERC20Upgradeable(secondaryToken).balanceOf(address(this));
            if (result.unpaidDebtCollateralAmount > 0 || result.unpaidFeeCollateralAmount > 0) {
                // if there is secondary token, but debt has not been fully repaid
                // try repay left debt with secondary token ...
                result = repayBySecondaryToken(store, result, secondaryToken);
            } else {
                // or give all secondary token back to user
                result.refundSecondaryTokenAmount = result.secondaryTokenBalance;
            }
            store.account.debtCollateralAmount = store.account.inflightDebtCollateralAmount;
            store.account.pendingFeeCollateralAmount = 0;

            transferTokenToOwner(store, store.account.collateralToken, result.refundCollateralAmount);
            transferTokenToOwner(store, secondaryToken, result.refundSecondaryTokenAmount);
            store.account.isLiquidating = false;
        }
        IEventEmitter(store.projectConfigs.eventEmitter).onRepayCollateral(store.account.owner, result);
    }

    function repayByCollateral(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.DebtResult memory result
    ) internal returns (IGmxV2Adatper.DebtResult memory) {
        // 0. total fee to repay
        result.refundCollateralAmount = result.collateralBalance;
        // 1. pay the debt, missing part will be turned into bad debt
        result.repaidDebtCollateralAmount = result.debtCollateralAmount.min(result.refundCollateralAmount);
        result.refundCollateralAmount -= result.repaidDebtCollateralAmount;
        // 2. pay the fee, if possible
        if (result.refundCollateralAmount > 0) {
            result.repaidFeeCollateralAmount = result.refundCollateralAmount.min(result.totalFeeCollateralAmount);
            result.refundCollateralAmount -= result.repaidFeeCollateralAmount;
        }
        result.unpaidDebtCollateralAmount = result.debtCollateralAmount - result.repaidDebtCollateralAmount;
        result.unpaidFeeCollateralAmount = result.totalFeeCollateralAmount - result.repaidFeeCollateralAmount;
        repay(
            store,
            store.account.collateralToken,
            result.repaidDebtCollateralAmount,
            result.repaidFeeCollateralAmount,
            0
        );
        return result;
    }

    function repayBySecondaryToken(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.DebtResult memory result,
        address secondaryToken
    ) internal returns (IGmxV2Adatper.DebtResult memory) {
        if (result.secondaryTokenBalance == 0) {
            return result;
        }
        uint256 collateralPrice = result.prices.collateralPrice;
        uint256 secondaryPrice = secondaryToken == store.account.longToken
            ? result.prices.longTokenPrice
            : result.prices.shortTokenPrice;

        uint8 collateralDecimals = store.collateralTokenDecimals;
        uint8 secondaryDecimals = IERC20MetadataUpgradeable(secondaryToken).decimals();
        uint256 debtSecondaryAmount = ((result.unpaidDebtCollateralAmount * collateralPrice) / secondaryPrice)
            .toDecimals(collateralDecimals, secondaryDecimals);

        result.repaidDebtSecondaryTokenAmount = result.secondaryTokenBalance.min(debtSecondaryAmount);
        result.refundSecondaryTokenAmount = result.secondaryTokenBalance - result.repaidDebtSecondaryTokenAmount;

        if (result.refundSecondaryTokenAmount > 0) {
            uint256 debtFeeSecondaryAmount = ((result.unpaidFeeCollateralAmount * collateralPrice) / secondaryPrice)
                .toDecimals(collateralDecimals, secondaryDecimals);
            result.repaidFeeSecondaryTokenAmount = result.refundSecondaryTokenAmount.min(debtFeeSecondaryAmount);
            result.refundSecondaryTokenAmount -= result.repaidFeeSecondaryTokenAmount;
        }
        result.unpaidDebtCollateralAmount -=
            (result.repaidDebtSecondaryTokenAmount.toDecimals(secondaryDecimals, collateralDecimals) * secondaryPrice) /
            collateralPrice;
        result.unpaidFeeCollateralAmount -=
            (result.repaidFeeSecondaryTokenAmount.toDecimals(secondaryDecimals, collateralDecimals) * secondaryPrice) /
            collateralPrice;
        repay(
            store,
            secondaryToken,
            result.repaidDebtSecondaryTokenAmount,
            result.repaidFeeSecondaryTokenAmount,
            result.unpaidDebtCollateralAmount
        );
        return result;
    }

    // virtual methods
    function borrow(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        uint256 amount,
        uint256 fee
    ) internal returns (uint256 amountOut) {
        amountOut = IProxyFactory(store.factory).borrowAsset(PROJECT_ID, store.account.collateralToken, amount, fee);
    }

    function repay(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        address token,
        uint256 debtAmount,
        uint256 feeAmount,
        uint256 badDebt
    ) internal {
        IERC20Upgradeable(token).safeTransfer(store.factory, debtAmount + feeAmount);
        IProxyFactory(store.factory).repayAsset(PROJECT_ID, token, debtAmount, feeAmount, badDebt);
    }

    function transferTokenToOwner(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        address token,
        uint256 amount
    ) internal {
        if (amount == 0) {
            return;
        }
        // TODO: send failed try/catch
        if (token == WETH) {
            IWETH(WETH).withdraw(amount);
            payable(store.account.owner).transfer(amount);
        } else {
            IERC20Upgradeable(token).safeTransfer(store.account.owner, amount);
        }
    }
}
