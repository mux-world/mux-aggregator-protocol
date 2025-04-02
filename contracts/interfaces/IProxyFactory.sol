// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/IMuxOrderBook.sol";

interface IProxyFactory {
    struct OpenPositionArgsV2 {
        uint256 projectId;
        address collateralToken;
        address assetToken;
        bool isLong;
        address tokenIn;
        uint256 amountIn; // tokenIn.decimals
        uint256 minOut; // collateral.decimals
        uint256 borrow; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint96 tpPriceUsd; // 1e18
        uint96 slPriceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }
    struct ClosePositionArgsV2 {
        uint256 projectId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint96 tpPriceUsd; // 1e18
        uint96 slPriceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }

    struct MuxOrderParams {
        bytes32 subAccountId;
        uint96 collateralAmount; // erc20.decimals
        uint96 size; // 1e18
        uint96 price; // 1e18
        uint8 profitTokenId;
        uint8 flags;
        uint32 deadline; // 1e0
        bytes32 referralCode;
        IMuxOrderBook.PositionOrderExtra extra;
    }

    struct PositionOrderExtra {
        // tp/sl strategy
        uint96 tpPrice; // take-profit price. decimals = 18. only valid when flags.POSITION_TPSL_STRATEGY.
        uint96 slPrice; // stop-loss price. decimals = 18. only valid when flags.POSITION_TPSL_STRATEGY.
        uint8 tpslProfitTokenId; // only valid when flags.POSITION_TPSL_STRATEGY.
        uint32 tpslDeadline; // only valid when flags.POSITION_TPSL_STRATEGY.
    }

    struct OrderParams {
        bytes32 orderKey;
        uint256 collateralDelta;
        uint256 sizeDelta;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
    }

    struct ProxyCallParams {
        uint256 projectId;
        address collateralToken;
        address assetToken;
        bool isLong;
        bytes32 referralCode;
        uint256 value;
        bytes proxyCallData;
    }

    event SetMaintainer(address maintainer, bool enable);
    event SetKeeper(address keeper, bool enable);
    event SetBorrowConfig(
        uint256 projectId,
        address assetToken,
        uint8 prevAssetId,
        uint8 newAssetId,
        uint256 prevLimit,
        uint256 newLimit
    );
    event DisableBorrowConfig(uint256 projectId, address assetToken);
    event MuxCall(address target, uint256 value, bytes data);
    event SetLiquiditySource(uint256 indexed projectId, uint256 sourceId, address source);
    event SetDelegator(address delegator, bool enable);

    function weth() external view returns (address);

    function getProxiesOf(address account) external view returns (address[] memory);

    function isKeeper(address keeper) external view returns (bool);

    function getProjectConfig(uint256 projectId) external view returns (uint256[] memory);

    function getProjectAssetConfig(uint256 projectId, address assetToken) external view returns (uint256[] memory);

    function getBorrowStates(
        uint256 projectId,
        address assetToken
    ) external view returns (uint256 totalBorrow, uint256 borrowLimit, uint256 badDebt);

    function getAssetId(uint256 projectId, address token) external view returns (uint8);

    function getConfigVersions(
        uint256 projectId,
        address assetToken
    ) external view returns (uint32 projectConfigVersion, uint32 assetConfigVersion);

    function getProxyProjectId(address proxy) external view returns (uint256);

    function getLiquiditySource(uint256 projectId) external view returns (uint256 sourceId, address source);

    function borrowAsset(
        uint256 projectId,
        address collateralToken,
        uint256 amount,
        uint256 fee
    ) external returns (uint256 amountOut);

    function repayAsset(
        uint256 projectId,
        address collateralToken,
        uint256 amount,
        uint256 fee,
        uint256 badDebt_
    ) external;

    function proxyFunctionCall(ProxyCallParams calldata params) external payable;

    function proxyFunctionCall2(address account, ProxyCallParams calldata params) external payable;

    function multicall(bytes[] calldata proxyCalls) external payable returns (bytes[] memory results);
}
