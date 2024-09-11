// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../types/IBorrowingFees.sol";

/**
 * @custom:version 8
 * @dev Interface for GNSBorrowingFees facet (inherits types and also contains functions, events, and custom errors)
 */
interface IBorrowingFeesUtils is IBorrowingFees {
    /**
     * @dev Updates borrowing pair params of a pair
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     * @param _value new value
     */
    function setBorrowingPairParams(
        uint8 _collateralIndex,
        uint16 _pairIndex,
        BorrowingPairParams calldata _value
    ) external;

    /**
     * @dev Updates borrowing pair params of multiple pairs
     * @param _collateralIndex index of the collateral
     * @param _indices indices of the pairs
     * @param _values new values
     */
    function setBorrowingPairParamsArray(
        uint8 _collateralIndex,
        uint16[] calldata _indices,
        BorrowingPairParams[] calldata _values
    ) external;

    /**
     * @dev Updates borrowing group params of a group
     * @param _collateralIndex index of the collateral
     * @param _groupIndex index of the borrowing group
     * @param _value new value
     */
    function setBorrowingGroupParams(
        uint8 _collateralIndex,
        uint16 _groupIndex,
        BorrowingGroupParams calldata _value
    ) external;

    /**
     * @dev Updates borrowing group params of multiple groups
     * @param _collateralIndex index of the collateral
     * @param _indices indices of the groups
     * @param _values new values
     */
    function setBorrowingGroupParamsArray(
        uint8 _collateralIndex,
        uint16[] calldata _indices,
        BorrowingGroupParams[] calldata _values
    ) external;

    /**
     * @dev Callback after a trade is opened/closed to store pending borrowing fees and adjust open interests
     * @param _collateralIndex index of the collateral
     * @param _trader address of the trader
     * @param _pairIndex index of the pair
     * @param _index index of the trade
     * @param _positionSizeCollateral position size of the trade in collateral tokens
     * @param _open true if trade has been opened, false if trade has been closed
     * @param _long true if trade is long, false if trade is short
     */
    function handleTradeBorrowingCallback(
        uint8 _collateralIndex,
        address _trader,
        uint16 _pairIndex,
        uint32 _index,
        uint256 _positionSizeCollateral,
        bool _open,
        bool _long
    ) external;

    /**
     * @dev Returns the pending acc borrowing fees for a pair on both sides
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     * @param _currentBlock current block number
     * @return accFeeLong new pair acc borrowing fee on long side
     * @return accFeeShort new pair acc borrowing fee on short side
     * @return pairAccFeeDelta  pair acc borrowing fee delta (for side that changed)
     */
    function getBorrowingPairPendingAccFees(
        uint8 _collateralIndex,
        uint16 _pairIndex,
        uint256 _currentBlock
    ) external view returns (uint64 accFeeLong, uint64 accFeeShort, uint64 pairAccFeeDelta);

    /**
     * @dev Returns the pending acc borrowing fees for a borrowing group on both sides
     * @param _collateralIndex index of the collateral
     * @param _groupIndex index of the borrowing group
     * @param _currentBlock current block number
     * @return accFeeLong new group acc borrowing fee on long side
     * @return accFeeShort new group acc borrowing fee on short side
     * @return groupAccFeeDelta  group acc borrowing fee delta (for side that changed)
     */
    function getBorrowingGroupPendingAccFees(
        uint8 _collateralIndex,
        uint16 _groupIndex,
        uint256 _currentBlock
    ) external view returns (uint64 accFeeLong, uint64 accFeeShort, uint64 groupAccFeeDelta);

    /**
     * @dev Returns the borrowing fee for a trade
     * @param _input input data (collateralIndex, trader, pairIndex, index, long, collateral, leverage)
     * @return feeAmountCollateral borrowing fee (collateral precision)
     */
    function getTradeBorrowingFee(BorrowingFeeInput memory _input) external view returns (uint256 feeAmountCollateral);

    /**
     * @dev Returns the liquidation price for a trade
     * @param _input input data (collateralIndex, trader, pairIndex, index, openPrice, long, collateral, leverage)
     */
    function getTradeLiquidationPrice(LiqPriceInput calldata _input) external view returns (uint256);

    /**
     * @dev Returns the open interests for a pair
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     * @return longOi open interest on long side
     * @return shortOi open interest on short side
     */
    function getPairOisCollateral(
        uint8 _collateralIndex,
        uint16 _pairIndex
    ) external view returns (uint256 longOi, uint256 shortOi);

    /**
     * @dev Returns the borrowing group index for a pair
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     * @return groupIndex borrowing group index
     */
    function getBorrowingPairGroupIndex(
        uint8 _collateralIndex,
        uint16 _pairIndex
    ) external view returns (uint16 groupIndex);

    /**
     * @dev Returns the open interest in collateral tokens for a pair on one side
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     * @param _long true if long side
     */
    function getPairOiCollateral(uint8 _collateralIndex, uint16 _pairIndex, bool _long) external view returns (uint256);

    /**
     * @dev Returns whether a trade is within the max group borrowing open interest
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     * @param _long true if long side
     * @param _positionSizeCollateral position size of the trade in collateral tokens
     */
    function withinMaxBorrowingGroupOi(
        uint8 _collateralIndex,
        uint16 _pairIndex,
        bool _long,
        uint256 _positionSizeCollateral
    ) external view returns (bool);

    /**
     * @dev Returns a borrowing group's data
     * @param _collateralIndex index of the collateral
     * @param _groupIndex index of the borrowing group
     */
    function getBorrowingGroup(
        uint8 _collateralIndex,
        uint16 _groupIndex
    ) external view returns (BorrowingData memory group);

    /**
     * @dev Returns a borrowing group's oi data
     * @param _collateralIndex index of the collateral
     * @param _groupIndex index of the borrowing group
     */
    function getBorrowingGroupOi(
        uint8 _collateralIndex,
        uint16 _groupIndex
    ) external view returns (OpenInterest memory group);

    /**
     * @dev Returns a borrowing pair's data
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     */
    function getBorrowingPair(uint8 _collateralIndex, uint16 _pairIndex) external view returns (BorrowingData memory);

    /**
     * @dev Returns a borrowing pair's oi data
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     */
    function getBorrowingPairOi(uint8 _collateralIndex, uint16 _pairIndex) external view returns (OpenInterest memory);

    /**
     * @dev Returns a borrowing pair's oi data
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     */
    function getBorrowingPairGroups(
        uint8 _collateralIndex,
        uint16 _pairIndex
    ) external view returns (BorrowingPairGroup[] memory);

    /**
     * @dev Returns all borrowing pairs' borrowing data, oi data, and pair groups data
     * @param _collateralIndex index of the collateral
     */
    function getAllBorrowingPairs(
        uint8 _collateralIndex
    ) external view returns (BorrowingData[] memory, OpenInterest[] memory, BorrowingPairGroup[][] memory);

    /**
     * @dev Returns borrowing groups' data and oi data
     * @param _collateralIndex index of the collateral
     * @param _indices indices of the groups
     */
    function getBorrowingGroups(
        uint8 _collateralIndex,
        uint16[] calldata _indices
    ) external view returns (BorrowingData[] memory, OpenInterest[] memory);

    /**
     * @dev Returns borrowing groups' data
     * @param _collateralIndex index of the collateral
     * @param _trader address of trader
     * @param _index index of trade
     */
    function getBorrowingInitialAccFees(
        uint8 _collateralIndex,
        address _trader,
        uint32 _index
    ) external view returns (BorrowingInitialAccFees memory);

    /**
     * @dev Returns the max open interest for a pair
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     */
    function getPairMaxOi(uint8 _collateralIndex, uint16 _pairIndex) external view returns (uint256);

    /**
     * @dev Returns the max open interest in collateral tokens for a pair
     * @param _collateralIndex index of the collateral
     * @param _pairIndex index of the pair
     */
    function getPairMaxOiCollateral(uint8 _collateralIndex, uint16 _pairIndex) external view returns (uint256);

    /**
     * @dev Emitted when a pair's borrowing params is updated
     * @param pairIndex index of the pair
     * @param groupIndex index of its new group
     * @param feePerBlock new fee per block
     * @param feeExponent new fee exponent
     * @param maxOi new max open interest
     */
    event BorrowingPairParamsUpdated(
        uint8 indexed collateralIndex,
        uint16 indexed pairIndex,
        uint16 indexed groupIndex,
        uint32 feePerBlock,
        uint48 feeExponent,
        uint72 maxOi
    );

    /**
     * @dev Emitted when a pair's borrowing group has been updated
     * @param pairIndex index of the pair
     * @param prevGroupIndex previous borrowing group index
     * @param newGroupIndex new borrowing group index
     */
    event BorrowingPairGroupUpdated(
        uint8 indexed collateralIndex,
        uint16 indexed pairIndex,
        uint16 prevGroupIndex,
        uint16 newGroupIndex
    );

    /**
     * @dev Emitted when a group's borrowing params is updated
     * @param groupIndex index of the group
     * @param feePerBlock new fee per block
     * @param maxOi new max open interest
     * @param feeExponent new fee exponent
     */
    event BorrowingGroupUpdated(
        uint8 indexed collateralIndex,
        uint16 indexed groupIndex,
        uint32 feePerBlock,
        uint72 maxOi,
        uint48 feeExponent
    );

    /**
     * @dev Emitted when a trade's initial acc borrowing fees are stored
     * @param trader address of the trader
     * @param pairIndex index of the pair
     * @param index index of the trade
     * @param initialPairAccFee initial pair acc fee (for the side of the trade)
     * @param initialGroupAccFee initial group acc fee (for the side of the trade)
     */
    event BorrowingInitialAccFeesStored(
        uint8 indexed collateralIndex,
        address indexed trader,
        uint16 indexed pairIndex,
        uint32 index,
        uint64 initialPairAccFee,
        uint64 initialGroupAccFee
    );

    /**
     * @dev Emitted when a trade is executed and borrowing callback is handled
     * @param trader address of the trader
     * @param pairIndex index of the pair
     * @param index index of the trade
     * @param open true if trade has been opened, false if trade has been closed
     * @param long true if trade is long, false if trade is short
     * @param positionSizeCollateral position size of the trade in collateral tokens
     */
    event TradeBorrowingCallbackHandled(
        uint8 indexed collateralIndex,
        address indexed trader,
        uint16 indexed pairIndex,
        uint32 index,
        bool open,
        bool long,
        uint256 positionSizeCollateral
    );

    /**
     * @dev Emitted when a pair's borrowing acc fees are updated
     * @param pairIndex index of the pair
     * @param currentBlock current block number
     * @param accFeeLong new pair acc borrowing fee on long side
     * @param accFeeShort new pair acc borrowing fee on short side
     */
    event BorrowingPairAccFeesUpdated(
        uint8 indexed collateralIndex,
        uint16 indexed pairIndex,
        uint256 currentBlock,
        uint64 accFeeLong,
        uint64 accFeeShort
    );

    /**
     * @dev Emitted when a group's borrowing acc fees are updated
     * @param groupIndex index of the borrowing group
     * @param currentBlock current block number
     * @param accFeeLong new group acc borrowing fee on long side
     * @param accFeeShort new group acc borrowing fee on short side
     */
    event BorrowingGroupAccFeesUpdated(
        uint8 indexed collateralIndex,
        uint16 indexed groupIndex,
        uint256 currentBlock,
        uint64 accFeeLong,
        uint64 accFeeShort
    );

    /**
     * @dev Emitted when a borrowing pair's open interests are updated
     * @param pairIndex index of the pair
     * @param long true if long side
     * @param increase true if open interest is increased, false if decreased
     * @param delta change in open interest in collateral tokens (1e10 precision)
     * @param newOiLong new open interest on long side
     * @param newOiShort new open interest on short side
     */
    event BorrowingPairOiUpdated(
        uint8 indexed collateralIndex,
        uint16 indexed pairIndex,
        bool long,
        bool increase,
        uint72 delta,
        uint72 newOiLong,
        uint72 newOiShort
    );

    /**
     * @dev Emitted when a borrowing group's open interests are updated
     * @param groupIndex index of the borrowing group
     * @param long true if long side
     * @param increase true if open interest is increased, false if decreased
     * @param delta change in open interest in collateral tokens (1e10 precision)
     * @param newOiLong new open interest on long side
     * @param newOiShort new open interest on short side
     */
    event BorrowingGroupOiUpdated(
        uint8 indexed collateralIndex,
        uint16 indexed groupIndex,
        bool long,
        bool increase,
        uint72 delta,
        uint72 newOiLong,
        uint72 newOiShort
    );

    error BorrowingZeroGroup();
    error BorrowingWrongExponent();
}
