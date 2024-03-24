// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import "../../../interfaces/IProxyFactory.sol";
import "../../../interfaces/IArbSys.sol";
import "../../../interfaces/IPriceHub.sol";

import "../interfaces/IGmxV2Adatper.sol";
import "../interfaces/gmx/IMarket.sol";
import "../interfaces/gmx/IReaderLite.sol";

library LibUtils {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    uint256 internal constant RATE_DENOMINATOR = 1e5;
    address internal constant ARB_SYS = address(100);
    uint256 internal constant ARBITRUM_CHAIN_ID = 42161;

    function toDecimals(uint256 n, uint8 decimalsFrom, uint8 decimalsTo) internal pure returns (uint256) {
        if (decimalsFrom > decimalsTo) {
            return n / (10 ** (decimalsFrom - decimalsTo));
        } else if (decimalsFrom < decimalsTo) {
            return n * (10 ** (decimalsTo - decimalsFrom));
        } else {
            return n;
        }
    }

    function toAddress(bytes32 value) internal pure returns (address) {
        return address(bytes20(value));
    }

    function toAddress(uint256 value) internal pure returns (address) {
        return address(bytes20(bytes32(value)));
    }

    function toBytes32(uint256 value) internal pure returns (bytes32) {
        return bytes32(value);
    }

    function toU256(address value) internal pure returns (uint256) {
        return uint256(bytes32(bytes20(uint160(value))));
    }

    function toU32(bytes32 value) internal pure returns (uint32) {
        require(uint256(value) <= type(uint32).max, "OU32");
        return uint32(uint256(value));
    }

    function toU32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "OU32");
        return uint32(value);
    }

    function toU8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "OU8");
        return uint8(value);
    }

    function toU96(uint256 n) internal pure returns (uint96) {
        require(n <= type(uint96).max, "OU96"); // uint96 Overflow
        return uint96(n);
    }

    function rate(uint256 value, uint32 rate_) internal pure returns (uint256) {
        return (value * rate_) / RATE_DENOMINATOR;
    }

    function setupTokens(IGmxV2Adatper.GmxAdapterStoreV2 storage store, address collateralToken) internal {
        (, address indexToken, address longToken, address shortToken) = IReaderLite(store.projectConfigs.reader)
            .getMarketTokens(store.projectConfigs.dataStore, store.account.market);
        store.account.indexToken = indexToken;
        store.account.longToken = longToken;
        store.account.shortToken = shortToken;
        store.account.collateralToken = collateralToken;
        store.collateralTokenDecimals = IERC20MetadataUpgradeable(collateralToken).decimals();
        store.longTokenDecimals = IERC20MetadataUpgradeable(longToken).decimals();
        store.shortTokenDecimals = IERC20MetadataUpgradeable(shortToken).decimals();
        require(
            collateralToken == store.account.longToken || collateralToken == store.account.shortToken,
            "InvalidToken"
        );
    }

    function getOraclePrices(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store
    ) internal view returns (IGmxV2Adatper.Prices memory prices) {
        IPriceHub priceHub = IPriceHub(store.projectConfigs.priceHub);
        prices.indexTokenPrice = priceHub.getPriceByToken(store.account.indexToken);
        prices.longTokenPrice = priceHub.getPriceByToken(store.account.longToken);
        prices.shortTokenPrice = priceHub.getPriceByToken(store.account.shortToken);
        prices.collateralPrice = store.account.collateralToken == store.account.longToken
            ? prices.longTokenPrice
            : prices.shortTokenPrice;
    }

    function getSecondaryToken(IGmxV2Adatper.GmxAdapterStoreV2 storage store) internal view returns (address) {
        if (store.account.collateralToken == store.account.longToken) {
            return store.account.shortToken;
        } else {
            return store.account.longToken;
        }
    }

    function claimNativeToken(IGmxV2Adatper.GmxAdapterStoreV2 storage store) internal returns (uint256) {
        if (store.account.collateralToken != WETH) {
            uint256 balance = address(this).balance;
            AddressUpgradeable.sendValue(payable(store.account.owner), balance);
            return balance;
        } else {
            return 0;
        }
    }

    function appendOrder(IGmxV2Adatper.GmxAdapterStoreV2 storage store, bytes32 key) internal {
        appendOrder(store, key, 0, 0, false);
    }

    function appendOrder(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        bytes32 key,
        uint256 collateralAmount, // collateral + debt
        uint256 debtCollateralAmount,
        bool isIncreasing
    ) internal {
        store.pendingOrders[key] = IGmxV2Adatper.OrderRecord({
            isIncreasing: isIncreasing,
            timestamp: uint64(block.timestamp),
            blockNumber: getBlockNumber(),
            collateralAmount: collateralAmount,
            debtCollateralAmount: debtCollateralAmount
        });
        store.pendingOrderIndexes.add(key);
        store.account.inflightDebtCollateralAmount += debtCollateralAmount;
    }

    function removeOrder(
        IGmxV2Adatper.GmxAdapterStoreV2 storage store,
        bytes32 key
    ) internal returns (IGmxV2Adatper.OrderRecord memory orderRecord) {
        // main order
        //     \_ store.tpOrderKeys => tp order
        //     \_ store.slOrderKeys => sl order
        orderRecord = store.pendingOrders[key];
        uint256 debtCollateralAmount = orderRecord.debtCollateralAmount;
        delete store.pendingOrders[key];
        store.pendingOrderIndexes.remove(key);
        store.account.inflightDebtCollateralAmount -= debtCollateralAmount;
    }

    function getBlockNumber() internal view returns (uint256) {
        if (block.chainid == ARBITRUM_CHAIN_ID) {
            return IArbSys(address(100)).arbBlockNumber();
        }
        return block.number;
    }

    function setupCallback(IGmxV2Adatper.GmxAdapterStoreV2 storage store) internal {
        IExchangeRouter(store.projectConfigs.exchangeRouter).setSavedCallbackContract(
            store.account.market,
            address(this)
        );
    }
}
