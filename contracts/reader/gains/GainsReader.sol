// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./interfaces/IGNSMultiCollatDiamond.sol";
import "./interfaces/types/IPairsStorage.sol";
import "./interfaces/types/ITradingStorage.sol";
import "./interfaces/types/IPriceImpact.sol";
import "./interfaces/types/IBorrowingFees.sol";
import "./interfaces/types/IFundingFees.sol";
import "./interfaces/types/IFeeTiers.sol";
import "./interfaces/IERC20.sol";

contract GainsReader {
    struct TradeContainer {
        ITradingStorage.Trade trade;
        ITradingStorage.TradeInfo tradeInfo;
        IPairsStorage.GroupLiquidationParams liquidationParams;
        IBorrowingFees.BorrowingInitialAccFees initialAccFees;
        IFundingFees.TradeFeesData tradeFeesData;
        IFundingFees.UiRealizedPnlData uiRealizedPnlData;
    }

    struct FeeTier {
        uint32 currentDay;
        IFeeTiers.FeeTier[] feeMultiplier;
        uint256[] multipliers;
    }

    struct PairBorrowingFees {
        IBorrowingFees.BorrowingData data;
        IBorrowingFees.OpenInterest oi;
        IBorrowingFees.BorrowingPairGroup[] groups;
        IBorrowingFees.BorrowingFeePerBlockCap feePerBlockCap;
    }

    struct GroupBorrowingFees {
        IBorrowingFees.BorrowingData data;
        IBorrowingFees.OpenInterest oi;
    }

    struct PairBorrowingFeesV2 {
        IFundingFees.BorrowingFeeParams[] params;
        IFundingFees.PairBorrowingFeeData[] data;
    }

    struct PairFundingFees {
        IFundingFees.PairFundingFeeData data;
        IFundingFees.PairGlobalParams globalParams;
        IFundingFees.FundingFeeParams params;
    }

    struct UnifiedPairOi {
        uint72 maxCollateral;
        IBorrowingFees.OpenInterest beforeV10Collateral;
        IPriceImpact.PairOiCollateral collateral;
        IPriceImpact.PairOiToken token;
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

    struct TraderFeeTierInfo {
        IFeeTiers.TraderDailyInfo traderDailyInfo;
        IFeeTiers.TraderInfo traderInfo;
        IFeeTiers.TraderEnrollment traderEnrollment;
    }

    struct DepthBands {
        uint256 totalDepthUsd;
        uint16[] bands;
    }

    struct PairDepthBands {
        DepthBands above;
        DepthBands below;
    }

    IGNSMultiCollatDiamond public immutable multiCollatDiamond;

    constructor(IGNSMultiCollatDiamond multiCollatDiamond_) {
        multiCollatDiamond = multiCollatDiamond_;
    }

    function _getCurrentDay() internal view returns (uint32) {
        return uint32(block.timestamp / 1 days);
    }

    function _getTradeUiRealizedPnlData(address _trader, uint32 _index) internal view returns (IFundingFees.UiRealizedPnlData memory) {
        address[] memory traders = new address[](1);
        uint32[] memory indices = new uint32[](1);
        traders[0] = _trader;
        indices[0] = _index;
        
        IFundingFees.UiRealizedPnlData[] memory pnlDataArray = multiCollatDiamond.getTradeUiRealizedPnlDataArray(traders, indices);
        if (pnlDataArray.length > 0) {
            return pnlDataArray[0];
        }
    }

    function getPositionsAndOrders(
        address trader
    ) external view returns (
        TradeContainer[] memory trades,
        ITradingStorage.PendingOrder[] memory pendingOrders
    ) {
        ITradingStorage.Trade[] memory tradesFormStore = multiCollatDiamond.getTrades(trader);

        trades = new TradeContainer[](tradesFormStore.length);

        for (uint256 i = 0; i < tradesFormStore.length; i++) {
            ITradingStorage.Trade memory t = tradesFormStore[i];
            trades[i] = TradeContainer(
                t,
                multiCollatDiamond.getTradeInfo(trader, t.index),
                multiCollatDiamond.getTradeLiquidationParams(trader, t.index),
                multiCollatDiamond.getBorrowingInitialAccFees(t.collateralIndex, trader, t.index),
                multiCollatDiamond.getTradeFeesData(trader, t.index),
                _getTradeUiRealizedPnlData(trader, t.index)
            );
        }

        pendingOrders = multiCollatDiamond.getPendingOrders(trader);
        return (trades, pendingOrders);
    }

    function getTraderFeeTierInfo(address _trader) external view returns (TraderFeeTierInfo memory) {
        IFeeTiers.TraderDailyInfo memory traderDailyInfo = multiCollatDiamond.getFeeTiersTraderDailyInfo(_trader, _getCurrentDay());
        IFeeTiers.TraderInfo memory traderInfo = multiCollatDiamond.getFeeTiersTraderInfo(_trader);
        IFeeTiers.TraderEnrollment memory traderEnrollment = multiCollatDiamond.getTraderFeeTiersEnrollment(_trader);
        return TraderFeeTierInfo(traderDailyInfo, traderInfo, traderEnrollment);
    }

    function getCollaterals() external view returns (Collateral[] memory) {
        uint8 count = multiCollatDiamond.getCollateralsCount();
        Collateral[] memory collaterals = new Collateral[](count);

        for (uint8 i = 1; i <= count; i++) {
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

            collaterals[i-1] = collateralInfo;
        }
        return collaterals;
    }
    function getTradeGroups() external view returns (IPairsStorage.Group[] memory) {
        uint256 count = multiCollatDiamond.groupsCount();
        IPairsStorage.Group[] memory groups = new IPairsStorage.Group[](count);
        for (uint256 i = 0; i < count; i++) {
            groups[i] = multiCollatDiamond.groups(i);
        }
        return groups;
    }

    function getFees() external view returns (IPairsStorage.FeeGroup[] memory) {
        uint256 count = multiCollatDiamond.feesCount();
        IPairsStorage.FeeGroup[] memory fees = new IPairsStorage.FeeGroup[](count);
        for (uint256 i = 0; i < count; i++) {
            fees[i] = multiCollatDiamond.fees(i);
        }
        return fees;
    }

    function getPairs() external view returns (IPairsStorage.Pair[] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        IPairsStorage.Pair[] memory pairs = new IPairsStorage.Pair[](count);
        for (uint256 i = 0; i < count; i++) {
            pairs[i] = multiCollatDiamond.pairs(i);
        }
        return pairs;
    }

    function getPairDepthBandsArray() external view returns (IPriceImpact.PairDepthBands[] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        uint256[] memory indices = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            indices[i] = i;
        }
        return multiCollatDiamond.getPairDepthBandsArray(indices);
    }

     function getPairDepthBandsDecoded(uint256 _pairIndex) external view returns (PairDepthBands memory) {
        (
            uint256 totalDepthAboveUsd, 
            uint256 totalDepthBelowUsd, 
            uint16[] memory bandsAbove, 
            uint16[] memory bandsBelow
        ) = multiCollatDiamond.getPairDepthBandsDecoded(_pairIndex);
        return PairDepthBands(
            DepthBands(totalDepthAboveUsd, bandsAbove),
            DepthBands(totalDepthBelowUsd, bandsBelow)
        );
    }
     
    function getDepthBandsMapping() external view returns (uint256 slot1, uint256 slot2) {
        return multiCollatDiamond.getDepthBandsMapping();
    }

    function getDepthBandsMappingDecoded() external view returns (uint16[] memory) {
        return multiCollatDiamond.getDepthBandsMappingDecoded();
    }

    function getMaxNegativePnlOnOpenP() external view returns (uint256) {
        return 400000000000; // constant -40% after 2024-01-23. 1e10
    }

    function getTradingActivated() external view returns (ITradingStorage.TradingActivated) {
        return multiCollatDiamond.getTradingActivated();
    }

    function getOiWindowsSettings() external view returns (IPriceImpact.OiWindowsSettings memory) {
        return multiCollatDiamond.getOiWindowsSettings();
    }

    function getAllPairsOiWindows(uint48 _windowsDuration, uint256[] calldata _windowIds) external view returns (IPriceImpact.PairOi[][] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        IPriceImpact.PairOi[][] memory oiWindows = new IPriceImpact.PairOi[][](count);
        for (uint256 i = 0; i < count; i++) {
            oiWindows[i] = multiCollatDiamond.getOiWindows(_windowsDuration, i, _windowIds);
        }
        return oiWindows;
    }

    function getFeeTiers() external view returns (FeeTier memory) {
        uint256 groupsCount = multiCollatDiamond.groupsCount();
        uint256 feeTiersCount = multiCollatDiamond.getFeeTiersCount();
        FeeTier memory feeTiers = FeeTier(_getCurrentDay(), new IFeeTiers.FeeTier[](feeTiersCount), new uint256[](groupsCount));
        for (uint256 i = 0; i < feeTiersCount; i++) {
            feeTiers.feeMultiplier[i] = multiCollatDiamond.getFeeTier(i);
        }
        for (uint256 i = 0; i < groupsCount; i++) {
            feeTiers.multipliers[i] = multiCollatDiamond.getGroupVolumeMultiplier(i);
        }
        return feeTiers;
    }

    function getPairLiquidationParams() external view returns (IPairsStorage.GroupLiquidationParams[] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        IPairsStorage.GroupLiquidationParams[] memory liquidationParams = new IPairsStorage.GroupLiquidationParams[](count);
        for (uint256 i = 0; i < count; i++) {
            liquidationParams[i] = multiCollatDiamond.getPairLiquidationParams(i);
        }
        return liquidationParams;
    }

    function getGroupLiquidationParams() external view returns (IPairsStorage.GroupLiquidationParams[] memory) {
        uint256 count = multiCollatDiamond.groupsCount();
        IPairsStorage.GroupLiquidationParams[] memory liquidationParams = new IPairsStorage.GroupLiquidationParams[](count);
        for (uint256 i = 0; i < count; i++) {
            liquidationParams[i] = multiCollatDiamond.getGroupLiquidationParams(i);
        }
        return liquidationParams;
    }

    function getCounterTradeSettings() external view returns (IPairsStorage.CounterTradeSettings[] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        IPairsStorage.CounterTradeSettings[] memory counterTradeSettings = new IPairsStorage.CounterTradeSettings[](count);
        for (uint256 i = 0; i < count; i++) {
            counterTradeSettings[i] = IPairsStorage.CounterTradeSettings(
                multiCollatDiamond.getPairCounterTradeMaxLeverage(uint16(i)),
                multiCollatDiamond.getPairCounterTradeFeeRateMultiplier(uint16(i)),
                0
            );
        }
        return counterTradeSettings;
    }

    function getGlobalTradeFeeParams() external view returns (IPairsStorage.GlobalTradeFeeParams memory) {
        return multiCollatDiamond.getGlobalTradeFeeParams();
    }

    function getPairFactors() external view returns (IPriceImpact.PairFactors[] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        uint256[] memory indices = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            indices[i] = i;
        }
        return multiCollatDiamond.getPairFactors(indices);
    }

    function getNegPnlCumulVolMultiplier() external view returns (uint48) {
        return multiCollatDiamond.getNegPnlCumulVolMultiplier();
    }

    function getPairSkewDepths(uint8 _collateralIndex) external view returns (uint256[] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        uint8[] memory collateralIndices = new uint8[](count);
        uint16[] memory indices = new uint16[](count);
        for (uint16 i = 0; i < count; i++) {
            collateralIndices[i] = _collateralIndex;
            indices[i] = i;
        }
        return multiCollatDiamond.getPairSkewDepths(collateralIndices, indices);
    }


    function getPairBorrowingFees(uint8 _collateralIndex) external view returns (PairBorrowingFees[] memory) {
        uint256 count = multiCollatDiamond.pairsCount();
        PairBorrowingFees[] memory fees = new PairBorrowingFees[](count);
        (
            IBorrowingFees.BorrowingData[] memory pairsData, 
            IBorrowingFees.OpenInterest[] memory pairsOi,
            IBorrowingFees.BorrowingPairGroup[][] memory pairGroups
        ) = multiCollatDiamond.getAllBorrowingPairs(_collateralIndex);
        for (uint256 i = 0; i < count; i++) {
            fees[i] = PairBorrowingFees(
                pairsData[i],
                pairsOi[i],
                pairGroups[i],
                multiCollatDiamond.getBorrowingPairFeePerBlockCap(_collateralIndex, uint16(i))
            );
        }
        return fees;
    }

    function getGroupBorrowingFees(uint8 _collateralIndex, uint16[] calldata _borrowingGroupsIndices) external view returns (GroupBorrowingFees[] memory) {
        GroupBorrowingFees[] memory fees = new GroupBorrowingFees[](_borrowingGroupsIndices.length);
        (
            IBorrowingFees.BorrowingData[] memory groupsData, 
            IBorrowingFees.OpenInterest[] memory groupsOi
        ) = multiCollatDiamond.getBorrowingGroups(_collateralIndex, _borrowingGroupsIndices);

        for (uint256 i = 0; i < groupsData.length; i++) {
            fees[i] = GroupBorrowingFees(
                groupsData[i],
                groupsOi[i]
            );
        }
        return fees;
    }

    function getFundingFees(uint8 _collateralIndex) external view returns (PairFundingFees[] memory) {
        uint256 pairCount = multiCollatDiamond.pairsCount();
        PairFundingFees[] memory fees = new PairFundingFees[](pairCount);

        // Create arrays from 0 to pairCount-1
        uint8[] memory collateralIndices = new uint8[](pairCount);      
        uint16[] memory pairIndices = new uint16[](pairCount);
        for (uint16 i = 0; i < pairCount; i++) {
            pairIndices[i] = i;
            collateralIndices[i] = _collateralIndex;
        }

        IFundingFees.PairFundingFeeData[] memory pairFundingFeeData = multiCollatDiamond.getPairFundingFeeData(collateralIndices, pairIndices);
        IFundingFees.PairGlobalParams[] memory pairGlobalParams = multiCollatDiamond.getPairGlobalParamsArray(collateralIndices, pairIndices);
        IFundingFees.FundingFeeParams[] memory pairFundingFeeParams = multiCollatDiamond.getPairFundingFeeParams(collateralIndices, pairIndices);

        for (uint256 i = 0; i < pairCount; i++) {
            fees[i] = PairFundingFees(
                pairFundingFeeData[i],
                pairGlobalParams[i],
                pairFundingFeeParams[i]
            );
        }
        return fees;
    }

    function getUnifiedPairOi(uint8 _collateralIndex) external view returns (UnifiedPairOi[] memory) {
        uint256 pairCount = multiCollatDiamond.pairsCount();
        UnifiedPairOi[] memory oi = new UnifiedPairOi[](pairCount);
        for (uint256 i = 0; i < pairCount; i++) {
            IBorrowingFees.OpenInterest memory oiBeforeV10 = multiCollatDiamond.getBorrowingPairOiBeforeV10(_collateralIndex, uint16(i));

            oi[i] = UnifiedPairOi(
                oiBeforeV10.max,
                IBorrowingFees.OpenInterest(uint72(oiBeforeV10.long), uint72(oiBeforeV10.short), 0, 0),
                multiCollatDiamond.getPairOiAfterV10Collateral(_collateralIndex, uint16(i)),
                multiCollatDiamond.getPairOiAfterV10Token(_collateralIndex, uint16(i))
            );
        }
        return oi;
    }

    function getPairBorrowingFeesV2(uint8 _collateralIndex) external view returns (PairBorrowingFeesV2 memory) {
        uint256 pairCount = multiCollatDiamond.pairsCount();
        uint8[] memory collateralIndices = new uint8[](pairCount);
        uint16[] memory pairIndices = new uint16[](pairCount);
        for (uint16 i = 0; i < pairCount; i++) {
            pairIndices[i] = i;
            collateralIndices[i] = _collateralIndex;
        }
        return PairBorrowingFeesV2(
            multiCollatDiamond.getPairBorrowingFeeParams(collateralIndices, pairIndices),
            multiCollatDiamond.getPairBorrowingFeeData(collateralIndices, pairIndices)
        );
    }

    function getPairMaxLeverage() external view returns (uint256[] memory) {
        return multiCollatDiamond.getAllPairsRestrictedMaxLeverage();
    }

    function getPairMinFeeUsd() external view returns (uint256[] memory) {
        uint256 pairCount = multiCollatDiamond.pairsCount();
        uint256[] memory minFeeUsd = new uint256[](pairCount);
        for (uint256 i = 0; i < pairCount; i++) {
            minFeeUsd[i] = multiCollatDiamond.pairMinFeeUsd(i);
        }
        return minFeeUsd;
    }

    function getUserPriceImpact(address _trader) external view returns (IPriceImpact.UserPriceImpact[] memory) {
        uint256 pairCount = multiCollatDiamond.pairsCount();
        IPriceImpact.UserPriceImpact[] memory userPriceImpact = new IPriceImpact.UserPriceImpact[](pairCount);
        for (uint256 i = 0; i < pairCount; i++) {
            userPriceImpact[i] = multiCollatDiamond.getUserPriceImpact(_trader, uint16(i));
        }
        return userPriceImpact;
    }
}
