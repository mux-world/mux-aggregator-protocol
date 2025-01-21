// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../../../interfaces/IWETH.sol";
import "../interfaces/gmx/IDataStore.sol";
import "../interfaces/gmx/IExchangeRouter.sol";
import "../interfaces/IGmxV2Adatper.sol";
import "../interfaces/IEventEmitter.sol";

import "./LibSwap.sol";
import "./LibDebt.sol";
import "./LibUtils.sol";

library LibGmxV2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using LibSwap for IGmxV2Adatper.GmxAdapterStoreV2;
    using LibDebt for IGmxV2Adatper.GmxAdapterStoreV2;
    using LibUtils for IGmxV2Adatper.GmxAdapterStoreV2;
    using LibUtils for uint256;

    uint256 constant MAX_ORDER_COUNT = 32;

    struct GmxPositionInfo {
        uint256 collateralAmount;
        uint256 sizeInUsd;
        uint256 totalCostAmount;
        int256 pnlAfterPriceImpactUsd;
    }

    // ===================================== READ =============================================

    function getMarginValueUsd(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        uint256 collateralAmount,
        uint256 totalCostAmount,
        int256 pnlAfterPriceImpactUsd,
        uint256 collateralPrice
    ) internal view returns (uint256) {
        int256 collateralUsd = int256(
            ((collateralAmount * collateralPrice) / 1e18).toDecimals(store.collateralTokenDecimals, 30)
        ); // to 30

        int256 gmxPnlUsd = pnlAfterPriceImpactUsd;
        int256 gmxCostUsd = int256(
            (totalCostAmount * collateralPrice).toDecimals(store.collateralTokenDecimals + 18, 30)
        ); // to 30
        uint256 muxDebt = store.account.debtCollateralAmount +
            store.account.pendingFeeCollateralAmount +
            store.getMuxFundingFee() -
            store.account.inflightDebtCollateralAmount;
        int256 muxDebtUsd = int256(((muxDebt * collateralPrice) / 1e18).toDecimals(store.collateralTokenDecimals, 30)); // to 30
        int256 marginValueUsd = collateralUsd + gmxPnlUsd - gmxCostUsd - muxDebtUsd;

        return marginValueUsd >= 0 ? uint256(marginValueUsd) : 0; // truncate to 0
    }

    function makeGmxPrices(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.Prices memory prices
    ) internal view returns (IMarket.MarketPrices memory) {
        uint256 indexTokenPrice = prices.indexTokenPrice.toDecimals(18, 30 - store.marketConfigs.indexDecimals);
        uint256 longTokenPrice = prices.longTokenPrice.toDecimals(18, 30 - store.longTokenDecimals);
        uint256 shortTokenPrice = prices.shortTokenPrice.toDecimals(18, 30 - store.shortTokenDecimals);

        return
            IMarket.MarketPrices({
                indexTokenPrice: IPrice.Props({ max: indexTokenPrice, min: indexTokenPrice }),
                longTokenPrice: IPrice.Props({ max: longTokenPrice, min: longTokenPrice }),
                shortTokenPrice: IPrice.Props({ max: shortTokenPrice, min: shortTokenPrice })
            });
    }

    // 1e18
    function getMarginRate(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.Prices memory prices
    ) public view returns (uint256) {
        uint256 sizeInUsd = IReaderLite(store.projectConfigs.reader).getPositionSizeInUsd(
            store.projectConfigs.dataStore,
            store.positionKey
        );
        if (sizeInUsd == 0) {
            return 0;
        }
        GmxPositionInfo memory info;
        (info.collateralAmount, info.sizeInUsd, info.totalCostAmount, info.pnlAfterPriceImpactUsd) = IReaderLite(
            store.projectConfigs.reader
        ).getPositionMarginInfo(
                store.projectConfigs.dataStore,
                store.projectConfigs.referralStore,
                store.positionKey,
                makeGmxPrices(store, prices)
            );
        uint256 marginValueUsd = getMarginValueUsd(
            store,
            info.collateralAmount,
            info.totalCostAmount,
            info.pnlAfterPriceImpactUsd,
            prices.collateralPrice
        );
        return ((marginValueUsd) * 1e18) / (info.sizeInUsd);
    }

    function isMarginSafe(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.Prices memory prices,
        uint256 deltaCollateralAmount, // without delta debt
        uint256 deltaSizeUsd,
        uint256 marginRateThreshold // 1e18
    ) public view returns (bool) {
        if (!store.marketConfigs.isBoostable) {
            return true;
        }
        uint256 sizeInUsd = IReaderLite(store.projectConfigs.reader).getPositionSizeInUsd(
            store.projectConfigs.dataStore,
            store.positionKey
        );
        if (sizeInUsd > 0) {
            GmxPositionInfo memory info;
            (info.collateralAmount, info.sizeInUsd, info.totalCostAmount, info.pnlAfterPriceImpactUsd) = IReaderLite(
                store.projectConfigs.reader
            ).getPositionMarginInfo(
                    store.projectConfigs.dataStore,
                    store.projectConfigs.referralStore,
                    store.positionKey,
                    makeGmxPrices(store, prices)
                );
            uint256 marginUsd = getMarginValueUsd(
                store,
                info.collateralAmount,
                info.totalCostAmount,
                info.pnlAfterPriceImpactUsd,
                prices.collateralPrice
            ); // 1e30
            if (marginUsd == 0) {
                // already bankrupt
                return false;
            }
            uint256 collateralUsd = ((deltaCollateralAmount * prices.collateralPrice) / 1e18).toDecimals(
                store.collateralTokenDecimals,
                30
            );
            uint256 nextMarginRate = ((marginUsd + collateralUsd) * 1e30) / (sizeInUsd + deltaSizeUsd) / 1e12; // 1e18
            if (nextMarginRate < marginRateThreshold) {
                return false;
            }
        } else {
            if (deltaSizeUsd == 0) {
                return true;
            }
            uint256 collateralUsd = ((deltaCollateralAmount * prices.collateralPrice) / 1e18).toDecimals(
                store.collateralTokenDecimals,
                30
            );
            uint256 nextMarginRate = ((collateralUsd) * 1e30) / (deltaSizeUsd) / 1e12; // 1e18
            if (nextMarginRate < marginRateThreshold) {
                return false;
            }
        }

        return true;
    }

    function isOpenSafe(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.Prices memory prices,
        uint256 deltaCollateralAmount, // without delta debt
        uint256 deltaSizeUsd
    ) public view returns (bool) {
        return
            isMarginSafe(
                store,
                prices,
                deltaCollateralAmount,
                deltaSizeUsd,
                uint256(store.marketConfigs.initialMarginRate) * 1e13
            );
    }

    function isCloseSafe(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.Prices memory prices
    ) public view returns (bool) {
        return isMarginSafe(store, prices, 0, 0, uint256(store.marketConfigs.maintenanceMarginRate) * 1e13);
    }

    // ===================================== WRITE =============================================
    function openPosition(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.OrderCreateParams memory createParams
    ) external returns (bytes32) {
        require(store.pendingOrderIndexes.length() < MAX_ORDER_COUNT, "ExceedsMaxOrderCount");

        IGmxV2Adatper.PositionResult memory result;
        // swap
        if (createParams.swapPath.length != 0) {
            // swap tokenIn => collateral
            result.collateralAmount = store.swapCollateral(
                createParams.swapPath,
                createParams.initialCollateralAmount,
                createParams.tokenOutMinAmount,
                address(this)
            );
        } else {
            // no swap
            result.collateralAmount = createParams.initialCollateralAmount;
        }
        if (store.marketConfigs.isBoostable) {
            result.prices = store.getOraclePrices(); // check account safe
            require(
                isOpenSafe(store, result.prices, result.collateralAmount, createParams.sizeDeltaUsd),
                "UnsafeToOpen"
            );
        }
        // borrow
        if (createParams.borrowCollateralAmount > 0) {
            require(store.marketConfigs.isBoostable, "NotBoostable");
            result.borrowedCollateralAmount = borrowCollateral(
                store,
                result.prices,
                createParams.borrowCollateralAmount
            );
        }
        // place order
        uint256 totalCollateralAmount = result.collateralAmount + result.borrowedCollateralAmount;
        // execution fee
        IERC20Upgradeable(store.account.collateralToken).safeTransfer(
            store.projectConfigs.orderVault,
            totalCollateralAmount
        );
        createParams.initialCollateralAmount = totalCollateralAmount;
        // primary order
        result.orderKey = placeOrder(store, createParams);
        store.appendOrder(result.orderKey, totalCollateralAmount, createParams.borrowCollateralAmount, true);
        IEventEmitter(store.projectConfigs.eventEmitter).onPlacePositionOrder(
            store.account.owner,
            createParams,
            result
        );
        return result.orderKey;
    }

    function closePosition(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.OrderCreateParams memory createParams
    ) external returns (bytes32) {
        require(store.pendingOrderIndexes.length() < MAX_ORDER_COUNT, "ExceedsMaxOrderCount");
        require(createParams.swapPath.length == 0, "SwapPathNotAvailable");
        // price
        IGmxV2Adatper.PositionResult memory result;
        if (store.marketConfigs.isBoostable) {
            result.prices = store.getOraclePrices();
            require(isCloseSafe(store, result.prices), "MarginUnsafe");
        }
        result.collateralAmount = createParams.initialCollateralAmount;
        // place order
        result.orderKey = placeOrder(store, createParams);
        store.appendOrder(result.orderKey);
        IEventEmitter(store.projectConfigs.eventEmitter).onPlacePositionOrder(
            store.account.owner,
            createParams,
            result
        );
        return result.orderKey;
    }

    function liquidatePosition(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.Prices memory prices,
        uint256 executionFee,
        uint256 callbackGasLimit
    ) external {
        require(executionFee == msg.value, "WrongExecutionFee");
        IWETH(WETH).deposit{ value: executionFee }();
        IGmxV2Adatper.PositionResult memory result;
        result.prices = prices;
        result = placeLiquidateOrder(store, executionFee, callbackGasLimit, result);
        IEventEmitter(store.projectConfigs.eventEmitter).onPlaceLiquidateOrder(store.account.owner, result);
    }

    function placeLiquidateOrder(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        uint256 executionFee,
        uint256 callbackGasLimit,
        IGmxV2Adatper.PositionResult memory result
    ) internal returns (IGmxV2Adatper.PositionResult memory) {
        // if no position, no need to liquidate
        uint256 sizeInUsd = IReaderLite(store.projectConfigs.reader).getPositionSizeInUsd(
            store.projectConfigs.dataStore,
            store.positionKey
        );
        require(sizeInUsd > 0, "NoPositionToLiquidate");
        // if position is safe, no need to liquidate
        require(!isCloseSafe(store, result.prices), "MarginSafe");
        // place market liquidate order
        result.orderKey = placeOrder(
            store,
            IGmxV2Adatper.OrderCreateParams({
                swapPath: "",
                initialCollateralAmount: 0,
                tokenOutMinAmount: 0,
                borrowCollateralAmount: 0,
                sizeDeltaUsd: sizeInUsd,
                triggerPrice: 0,
                acceptablePrice: store.account.isLong ? 0 : type(uint256).max,
                executionFee: executionFee,
                callbackGasLimit: callbackGasLimit,
                orderType: IOrder.OrderType.MarketDecrease
            })
        );
        store.appendOrder(result.orderKey);
        store.account.isLiquidating = true;
        return result;
    }

    function placeOrder(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.OrderCreateParams memory orderParams
    ) internal returns (bytes32 orderKey) {
        address exchangeRouter = store.projectConfigs.exchangeRouter;
        require(exchangeRouter != address(0), "ExchangeRouterUnset");
        // execution fee (weth)
        IERC20Upgradeable(WETH).safeTransfer(store.projectConfigs.orderVault, orderParams.executionFee);
        // place order
        orderKey = IExchangeRouter(store.projectConfigs.exchangeRouter).createOrder(
            IExchangeRouter.CreateOrderParams({
                addresses: IExchangeRouter.CreateOrderParamsAddresses({
                    receiver: address(this),
                    cancellationReceiver: address(this),
                    callbackContract: address(this),
                    uiFeeReceiver: address(0),
                    market: store.account.market,
                    initialCollateralToken: store.account.collateralToken,
                    swapPath: new address[](0)
                }),
                numbers: IExchangeRouter.CreateOrderParamsNumbers({
                    sizeDeltaUsd: orderParams.sizeDeltaUsd,
                    initialCollateralDeltaAmount: orderParams.initialCollateralAmount,
                    triggerPrice: orderParams.triggerPrice,
                    acceptablePrice: orderParams.acceptablePrice,
                    executionFee: orderParams.executionFee,
                    callbackGasLimit: orderParams.callbackGasLimit,
                    minOutputAmount: 0, // swap is not supported
                    validFromTime: 0
                }),
                orderType: orderParams.orderType,
                decreasePositionSwapType: IOrder.DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
                isLong: store.account.isLong,
                autoCancel: false,
                shouldUnwrapNativeToken: false,
                referralCode: store.projectConfigs.referralCode
            })
        );
    }

    function updateOrder(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice,
        bool autoCancel
    ) external {
        address exchangeRouter = store.projectConfigs.exchangeRouter;
        require(exchangeRouter != address(0), "ExchangeRouterUnset");
        IExchangeRouter(exchangeRouter).updateOrder(
            key,
            sizeDeltaUsd,
            acceptablePrice,
            triggerPrice,
            0, // minOutputAmount. swap is not supported
            0, // validFromTime
            autoCancel
        );
        IEventEmitter(store.projectConfigs.eventEmitter).onUpdateOrder(
            store.account.owner,
            key,
            sizeDeltaUsd,
            acceptablePrice,
            triggerPrice
        );
    }

    function cancelOrder(IGmxV2Adatper.GmxAdapterStoreV2 storage store, bytes32 key) external {
        if (store.pendingOrderIndexes.contains(key)) {
            cancelOrder(store, key, false);
        }
    }

    function cancelExpiredOrder(IGmxV2Adatper.GmxAdapterStoreV2 storage store, bytes32 key) external {
        if (store.pendingOrderIndexes.contains(key)) {
            IGmxV2Adatper.OrderRecord memory record = store.pendingOrders[key];
            require(
                record.isIncreasing &&
                    block.timestamp > record.timestamp + store.projectConfigs.limitOrderExpiredSeconds,
                "NotExpired"
            );
            cancelOrder(store, key, false);
        }
    }

    function cancelOrder(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        bytes32 key,
        bool ignoreFailure
    ) internal returns (bool) {
        address exchangeRouter = store.projectConfigs.exchangeRouter;
        require(exchangeRouter != address(0), "ExchangeRouterUnset");
        try IExchangeRouter(exchangeRouter).cancelOrder(key) {
            return true;
        } catch {
            require(ignoreFailure, "CancelOrderFailed");
            return false;
        }
    }

    function borrowCollateral(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        IGmxV2Adatper.Prices memory prices,
        uint256 borrowCollateralAmount
    ) internal returns (uint256 borrowedCollateralAmount) {
        IGmxV2Adatper.DebtResult memory result;
        result.prices = prices;
        result.fundingFeeCollateralAmount = store.updateMuxFundingFee();
        (result.borrowedCollateralAmount, result.boostFeeCollateralAmount) = store.borrowCollateral(
            borrowCollateralAmount
        );
        borrowedCollateralAmount = result.borrowedCollateralAmount;
        IEventEmitter(store.projectConfigs.eventEmitter).onBorrowCollateral(store.account.owner, result);
    }

    function claimToken(IGmxV2Adatper.GmxAdapterStoreV2 storage store, address token) internal returns (uint256) {
        uint256 sizeInUsd = IReaderLite(store.projectConfigs.reader).getPositionSizeInUsd(
            store.projectConfigs.dataStore,
            store.positionKey
        );
        require(sizeInUsd == 0 && store.account.debtCollateralAmount == 0, "NotAllowed");
        uint256 balance = IERC20Upgradeable(token).balanceOf(address(this));
        IERC20Upgradeable(token).safeTransfer(store.account.owner, balance);
        return balance;
    }

    function isOrderExist(IGmxV2Adatper.GmxAdapterStoreV2 storage store, bytes32 key) external view returns (bool) {
        return IReaderLite(store.projectConfigs.reader).isOrderExist(store.projectConfigs.dataStore, key);
    }
}
