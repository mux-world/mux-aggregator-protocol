// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./interfaces/IGNSMultiCollatDiamond.sol";
import "./interfaces/types/IPairsStorage.sol";
import "./interfaces/types/ITradingStorage.sol";
import "./interfaces/types/IPriceImpact.sol";
import "./interfaces/types/IBorrowingFees.sol";
import "./interfaces/IERC20.sol";

contract GainsReader {

    struct BorrowingPairConfig {
        IBorrowingFees.BorrowingData data;
        IBorrowingFees.OpenInterest oi;
        IBorrowingFees.BorrowingPairGroup[] groups;
    }

    struct BorrowingGroupConfig {
        IBorrowingFees.BorrowingData data;
        IBorrowingFees.OpenInterest oi;
    }

    struct BorrowingFees {
        uint8 collateralIndex;
        BorrowingPairConfig[] pairs;
        BorrowingGroupConfig[] groups;
    }

    struct Collateral {
        uint8 collateralIndex;
        address collateral;
        bool isActive;
        string symbol; 
        uint8 decimals;
        uint256 collateralPriceUsd; // 1e8
        uint128 precision;
        uint128 precisionDelta;
    }

    struct GainsConfig {
        IPairsStorage.Fee[] fees;
        IPairsStorage.Group[] groups;
        Collateral[] collaterals;
        uint256 maxNegativePnlOnOpenP;
        ITradingStorage.TradingActivated tradingState;
        uint256 pairsCount;
        IPriceImpact.OiWindowsSettings oiWindowsSettings;
    }

    struct PairInfo {
        IPriceImpact.PairDepth pairDepth;
        uint256 maxLeverage;
        uint256 pairMinFeeUsd;
    }

    struct GainsPair {
        IPairsStorage.Pair pair;
        IPriceImpact.PairOi[] oiWindows;
        PairInfo pairInfo;
    }

    struct Trade {
        ITradingStorage.Trade trade;
        ITradingStorage.TradeInfo tradeInfo;
        IBorrowingFees.BorrowingInitialAccFees initialAccFees;
    }

    IGNSMultiCollatDiamond public immutable multiCollatDiamond;

    constructor(IGNSMultiCollatDiamond multiCollatDiamond_) {
        multiCollatDiamond = multiCollatDiamond_;
    }

    function borrowingFees(uint8 _collateralIndex, uint16[] calldata _borrowingGroupsIndices) external view returns (BorrowingFees memory) {
        uint256 pairCount = multiCollatDiamond.pairsCount();

        BorrowingFees memory fees = BorrowingFees(
            _collateralIndex,
            new BorrowingPairConfig[](pairCount),
            new BorrowingGroupConfig[](_borrowingGroupsIndices.length)
        );

        (
            IBorrowingFees.BorrowingData[] memory pairsData, 
            IBorrowingFees.OpenInterest[] memory pairsOi,
            IBorrowingFees.BorrowingPairGroup[][] memory pairGroups
        ) = multiCollatDiamond.getAllBorrowingPairs(_collateralIndex);

        for (uint256 i = 0; i < pairsData.length; i++) {
            fees.pairs[i] = BorrowingPairConfig(
                    pairsData[i],
                    pairsOi[i],
                    pairGroups[i]
            );
        }

        (
            IBorrowingFees.BorrowingData[] memory groupsData, 
            IBorrowingFees.OpenInterest[] memory groupsOi
        ) = multiCollatDiamond.getBorrowingGroups(_collateralIndex, _borrowingGroupsIndices);

        for (uint256 i = 0; i < groupsData.length; i++) {
            fees.groups[i] = BorrowingGroupConfig(
                groupsData[i],
                groupsOi[i]
            );
        }
        return fees;
    }

    function config() external view returns (GainsConfig memory) {
        uint256 feesCount = multiCollatDiamond.feesCount();
        uint256 groupsCount = multiCollatDiamond.groupsCount();
        uint256 pairsCount = multiCollatDiamond.pairsCount();
        uint8 collateralCount = multiCollatDiamond.getCollateralsCount();

        GainsConfig memory gainsInfo = GainsConfig(
            new IPairsStorage.Fee[](feesCount),
            new IPairsStorage.Group[](groupsCount),
            new Collateral[](collateralCount),
            400000000000, // constant -40% after 2024-01-23. 1e10
            multiCollatDiamond.getTradingActivated(),
            pairsCount,
            multiCollatDiamond.getOiWindowsSettings()
        );
        for (uint256 i = 0; i < feesCount; i++) {
            gainsInfo.fees[i] = multiCollatDiamond.fees(i);
        }
        for (uint256 i = 0; i < groupsCount; i++) {
            gainsInfo.groups[i] = multiCollatDiamond.groups(i);
        }
        for (uint8 i = 1; i <= collateralCount; i++) {
            ITradingStorage.Collateral memory collateral = multiCollatDiamond.getCollateral(i);
            IERC20 collateralToken = IERC20(collateral.collateral);

            Collateral memory collateralInfo = Collateral(
                i,
                collateral.collateral,
                collateral.isActive,
                collateralToken.symbol(),
                collateralToken.decimals(),
                multiCollatDiamond.getCollateralPriceUsd(i),
                collateral.precision,
                collateral.precisionDelta
            );

            gainsInfo.collaterals[i-1] = collateralInfo;
        }
        return gainsInfo;
    }

    function pair(uint256 _pairIndex, uint48 _windowsDuration, uint256[] calldata _windowIds) external view returns (GainsPair memory gainsPair) {
        gainsPair.pair = multiCollatDiamond.pairs(_pairIndex);
        gainsPair.oiWindows = multiCollatDiamond.getOiWindows(_windowsDuration, _pairIndex, _windowIds);
        gainsPair.pairInfo = PairInfo(
            multiCollatDiamond.getPairDepth(_pairIndex),
            multiCollatDiamond.pairMaxLeverage(_pairIndex),
            multiCollatDiamond.pairMinFeeUsd(_pairIndex)
        );
    }

    function getPositionsAndOrders(
        address trader
    ) external view returns (
        Trade[] memory trades,
        ITradingStorage.PendingOrder[] memory pendingOrders
    ) {
        ITradingStorage.Trade[] memory tradesFormStore = multiCollatDiamond.getTrades(trader);
        ITradingStorage.TradeInfo[] memory tradeInfosFromStore = multiCollatDiamond.getTradeInfos(trader);

        trades = new Trade[](tradesFormStore.length);

        for (uint256 i = 0; i < tradesFormStore.length; i++) {
            ITradingStorage.Trade memory t = tradesFormStore[i];
            trades[i] = Trade(
                t,
                tradeInfosFromStore[i],
                multiCollatDiamond.getBorrowingInitialAccFees(t.collateralIndex, trader, t.index)
            );
        }

        pendingOrders = multiCollatDiamond.getPendingOrders(trader);
        return (trades, pendingOrders);
    }

}
