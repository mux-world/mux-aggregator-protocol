// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./IPairsStorage.sol";

/**
 * @dev Contains the types for the GNSBorrowingFees facet
 */
interface IBorrowingFees {
    struct BorrowingFeesStorage {
        mapping(uint8 => mapping(uint16 => BorrowingData)) pairs;
        mapping(uint8 => mapping(uint16 => BorrowingPairGroup[])) pairGroups;
        mapping(uint8 => mapping(uint16 => OpenInterest)) pairOis;
        mapping(uint8 => mapping(uint16 => BorrowingData)) groups;
        mapping(uint8 => mapping(uint16 => OpenInterest)) groupOis;
        mapping(uint8 => mapping(address => mapping(uint32 => BorrowingInitialAccFees))) initialAccFees;
        mapping(uint8 => mapping(uint16 => BorrowingFeePerBlockCap)) pairFeePerBlockCaps;
        BorrowingFeePerBlockCap feePerBlockCap;
        uint256[42] __gap;
    }

    struct BorrowingData {
        uint32 feePerBlock; // 1e10 (%)
        uint64 accFeeLong; // 1e10 (%)
        uint64 accFeeShort; // 1e10 (%)
        uint48 accLastUpdatedBlock;
        uint48 feeExponent;
    }

    struct BorrowingPairGroup {
        uint16 groupIndex;
        uint48 block;
        uint64 initialAccFeeLong; // 1e10 (%)
        uint64 initialAccFeeShort; // 1e10 (%)
        uint64 prevGroupAccFeeLong; // 1e10 (%)
        uint64 prevGroupAccFeeShort; // 1e10 (%)
        uint64 pairAccFeeLong; // 1e10 (%)
        uint64 pairAccFeeShort; // 1e10 (%)
        uint64 __placeholder; // might be useful later
    }

    struct OpenInterest {
        uint72 long; // 1e10 (collateral)
        uint72 short; // 1e10 (collateral)
        uint72 max; // 1e10 (collateral)
        uint40 __placeholder; // might be useful later
    }

    struct BorrowingInitialAccFees {
        uint64 accPairFee; // 1e10 (%)
        uint64 accGroupFee; // 1e10 (%)
        uint48 block;
        uint80 __placeholder; // might be useful later
    }

    struct BorrowingPairParams {
        uint16 groupIndex;
        uint32 feePerBlock; // 1e10 (%)
        uint48 feeExponent;
        uint72 maxOi;
    }

    struct BorrowingGroupParams {
        uint32 feePerBlock; // 1e10 (%)
        uint72 maxOi; // 1e10
        uint48 feeExponent;
    }

    struct BorrowingFeePerBlockCap {
        uint32 minP; // 1e3 (%)
        uint32 maxP; // 1e3 (%)
    }

    struct BorrowingFeeInput {
        uint8 collateralIndex;
        address trader;
        uint16 pairIndex;
        uint32 index;
        bool long;
        uint256 collateral; // 1e18 | 1e6 (collateral)
        uint256 leverage; // 1e3
    }

    struct LiqPriceInput {
        uint8 collateralIndex;
        address trader;
        uint16 pairIndex;
        uint32 index;
        uint64 openPrice; // 1e10
        bool long;
        uint256 collateral; // 1e18 | 1e6 (collateral)
        uint256 leverage; // 1e3
        bool useBorrowingFees;
        IPairsStorage.GroupLiquidationParams liquidationParams;
    }

    struct PendingBorrowingAccFeesInput {
        uint64 accFeeLong; // 1e10 (%)
        uint64 accFeeShort; // 1e10 (%)
        uint256 oiLong; // 1e18 | 1e6
        uint256 oiShort; // 1e18 | 1e6
        uint32 feePerBlock; // 1e10
        uint256 currentBlock;
        uint256 accLastUpdatedBlock;
        uint72 maxOi; // 1e10
        uint48 feeExponent;
        uint128 collateralPrecision;
        BorrowingFeePerBlockCap feePerBlockCap;
    }

    // Useful to avoid stack too deep errors
    struct AccFeesDeltaValues {
        bool moreShorts;
        uint256 blockDistance;
        uint256 maxOiScaled; // 1e18 | 1e6
        uint256 netOi; // 1e18 | 1e6
        uint256 minNetOi; // 1e18 | 1e6
        uint256 maxNetOi; // 1e18 | 1e6
        uint256 cappedNetOi; // 1e18 | 1e6
    }
}
