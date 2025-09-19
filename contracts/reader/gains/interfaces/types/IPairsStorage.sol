// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSPairsStorage facet
 */
interface IPairsStorage {
    struct PairsStorage {
        mapping(uint256 => Pair) pairs;
        mapping(uint256 => Group) groups;
        mapping(uint256 => Fee) fees; /// @custom:deprecated
        mapping(string => mapping(string => bool)) isPairListed;
        mapping(uint256 => uint256) pairCustomMaxLeverage; // 1e3 precision
        uint256 currentOrderId; /// @custom:deprecated
        uint256 pairsCount;
        uint256 groupsCount;
        uint256 feesCount;
        mapping(uint256 => GroupLiquidationParams) groupLiquidationParams;
        mapping(uint256 => FeeGroup) feeGroups;
        GlobalTradeFeeParams globalTradeFeeParams;
        uint256[38] __gap;
    }

    struct Pair {
        string from;
        string to;
        Feed feed; /// @custom:deprecated
        uint256 spreadP; // 1e10
        uint256 groupIndex;
        uint256 feeIndex;
    }

    struct Group {
        string name;
        bytes32 job; /// @custom:deprecated
        uint256 minLeverage; // 1e3 precision
        uint256 maxLeverage; // 1e3 precision
    }

    struct GlobalTradeFeeParams {
        uint24 referralFeeP; // 1e3 (%)
        uint24 govFeeP; // 1e3 (%)
        uint24 triggerOrderFeeP; // 1e3 (%)
        uint24 gnsOtcFeeP; // 1e3 (%)
        uint24 gTokenFeeP; // 1e3 (%)
        uint136 __placeholder;
    }

    struct FeeGroup {
        uint40 totalPositionSizeFeeP; // 1e10 (%)
        uint40 totalLiqCollateralFeeP; // 1e10 (%)
        uint40 oraclePositionSizeFeeP; // 1e10 (%)
        uint32 minPositionSizeUsd; // 1e3
        uint104 __placeholder;
    }

    struct TradeFees {
        uint256 totalFeeCollateral; // collateral precision
        uint256 referralFeeCollateral; // collateral precision
        uint256 govFeeCollateral; // collateral precision
        uint256 triggerOrderFeeCollateral; // collateral precision
        uint256 gnsOtcFeeCollateral; // collateral precision
        uint256 gTokenFeeCollateral; // collateral precision
    }

    struct GroupLiquidationParams {
        uint40 maxLiqSpreadP; // 1e10 (%)
        uint40 startLiqThresholdP; // 1e10 (%)
        uint40 endLiqThresholdP; // 1e10 (%)
        uint24 startLeverage; // 1e3
        uint24 endLeverage; // 1e3
    }

    // Deprecated structs
    enum FeedCalculation {
        DEFAULT,
        INVERT,
        COMBINE
    } /// @custom:deprecated
    struct Feed {
        address feed1;
        address feed2;
        FeedCalculation feedCalculation;
        uint256 maxDeviationP;
    } /// @custom:deprecated
    struct Fee {
        string name;
        uint256 openFeeP; // 1e10 (% of position size)
        uint256 closeFeeP; // 1e10 (% of position size)
        uint256 oracleFeeP; // 1e10 (% of position size)
        uint256 triggerOrderFeeP; // 1e10 (% of position size)
        uint256 minPositionSizeUsd; // 1e18 (collateral x leverage, useful for min fee)
    } /// @custom:deprecated
}
