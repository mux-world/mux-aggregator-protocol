// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @dev Contains the types for the GNSPairsStorage facet
 */
interface IPairsStorage {
    struct PairsStorage {
        mapping(uint256 => Pair) pairs;
        mapping(uint256 => Group) groups;
        mapping(uint256 => Fee) fees;
        mapping(string => mapping(string => bool)) isPairListed;
        mapping(uint256 => uint256) pairCustomMaxLeverage; // 0 decimal precision
        uint256 currentOrderId; /// @custom:deprecated
        uint256 pairsCount;
        uint256 groupsCount;
        uint256 feesCount;
        mapping(uint256 => GroupLiquidationParams) groupLiquidationParams;
        uint256[40] __gap;
    }

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
        bytes32 job;
        uint256 minLeverage; // 0 decimal precision
        uint256 maxLeverage; // 0 decimal precision
    }
    struct Fee {
        string name;
        uint256 openFeeP; // 1e10 (% of position size)
        uint256 closeFeeP; // 1e10 (% of position size)
        uint256 oracleFeeP; // 1e10 (% of position size)
        uint256 triggerOrderFeeP; // 1e10 (% of position size)
        uint256 minPositionSizeUsd; // 1e18 (collateral x leverage, useful for min fee)
    }

    struct GroupLiquidationParams {
        uint40 maxLiqSpreadP; // 1e10 (%)
        uint40 startLiqThresholdP; // 1e10 (%)
        uint40 endLiqThresholdP; // 1e10 (%)
        uint24 startLeverage; // 1e3
        uint24 endLeverage; // 1e3
    }
}
