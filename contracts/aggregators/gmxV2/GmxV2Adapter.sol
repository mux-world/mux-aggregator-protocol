// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../../components/ImplementationGuard.sol";
import "./interfaces/gmx/IOrderCallbackReceiver.sol";
import "./interfaces/gmx/IRoleStore.sol";

import "./libraries/LibGmxV2.sol";
import "./libraries/LibDebt.sol";
import "./libraries/LibConfig.sol";

import "./Storage.sol";
import "./Getter.sol";

contract GmxV2Adapter is
    Storage,
    Getter,
    Initializable,
    ReentrancyGuardUpgradeable,
    ImplementationGuard,
    IOrderCallbackReceiver
{
    using LibUtils for uint256;
    using MathUpgradeable for uint256;

    using LibGmxV2 for GmxAdapterStoreV2;
    using LibConfig for GmxAdapterStoreV2;
    using LibDebt for GmxAdapterStoreV2;
    using LibUtils for GmxAdapterStoreV2;

    receive() external payable {}

    modifier onlyTrader() {
        require(_isValidCaller(), "OnlyTraderOrFactory");
        _;
    }

    modifier onlyKeeper() {
        require(IProxyFactory(_store.factory).isKeeper(msg.sender), "onlyKeeper");
        _;
    }

    modifier onlyValidCallbackSender() {
        require(_isValidCallbackSender(), "InvalidCallbackSender");
        _;
    }

    modifier onlyNotLiquidating() {
        require(!_store.account.isLiquidating, "Liquidating");
        _;
    }

    function initialize(
        uint256 projectId_,
        address liquidityPool,
        address owner,
        address collateralToken,
        address market,
        bool isLong
    ) external initializer onlyDelegateCall {
        require(liquidityPool != address(0), "InvalidLiquidityPool");
        require(projectId_ == PROJECT_ID, "InvalidProject");

        _store.factory = msg.sender;
        _store.liquidityPool = liquidityPool;
        _store.positionKey = keccak256(abi.encode(address(this), market, collateralToken, isLong));
        _store.account.isLong = isLong;
        _store.account.market = market;
        _store.account.owner = owner;

        _store.updateConfigs();
        _store.setupTokens(collateralToken);
        _store.setupCallback();
    }

    /// @notice Place a openning request on GMXv2.
    function placeOrder(
        OrderCreateParams memory createParams
    ) external payable onlyTrader onlyNotLiquidating nonReentrant returns (bytes32) {
        _store.updateConfigs();
        if (_isIncreasing(createParams.orderType)) {
            return _store.openPosition(createParams);
        } else {
            return _store.closePosition(createParams);
        }
    }

    function updateOrder(
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice,
        bool autoCancel
    ) external onlyTrader onlyNotLiquidating nonReentrant {
        _store.updateConfigs();
        _store.updateOrder(key, sizeDeltaUsd, acceptablePrice, triggerPrice, autoCancel);
    }

    function liquidatePosition(
        Prices memory prices,
        uint256 executionFee,
        uint256 callbackGasLimit
    ) external payable onlyKeeper onlyNotLiquidating nonReentrant {
        _store.updateConfigs();
        _store.liquidatePosition(prices, executionFee, callbackGasLimit);
    }

    function cancelOrder(bytes32 key) external onlyTrader onlyNotLiquidating nonReentrant {
        _store.updateConfigs();
        _store.cancelOrder(key);
    }

    function cancelExpiredOrder(bytes32 key) external onlyNotLiquidating nonReentrant {
        _store.updateConfigs();
        _store.cancelExpiredOrder(key);
    }

    // =========================================== fee && reward ===========================================
    function claimFundingFees(
        address[] memory markets,
        address[] memory tokens
    ) external payable returns (uint256[] memory) {
        return
            IExchangeRouter(_store.projectConfigs.exchangeRouter).claimFundingFees(
                markets,
                tokens,
                _store.account.owner
            );
    }

    function claimToken(address token) external returns (uint256) {
        return _store.claimToken(token);
    }

    function claimNativeToken() external returns (uint256) {
        return _store.claimNativeToken();
    }

    // =========================================== calbacks ===========================================
    function afterOrderExecution(
        bytes32 key,
        IOrder.Props memory,
        IEvent.EventLogData memory
    ) external onlyValidCallbackSender {
        uint256 oldDebtCollateralAmount = _store.account.debtCollateralAmount;
        uint256 oldInflightDebtCollateralAmount = _store.account.inflightDebtCollateralAmount;
        uint256 oldPendingFeeCollateralAmount = _store.account.pendingFeeCollateralAmount;
        uint256 oldDebtEntryFunding = _store.account.debtEntryFunding;
        require(!_store.isOrderExist(key), "OrderNotFilled");
        OrderRecord memory pendingOrder = _store.removeOrder(key);
        if (!pendingOrder.isIncreasing) {
            if (_store.account.debtCollateralAmount > 0) {
                Prices memory prices = _store.getOraclePrices();
                _store.repayDebt(prices);
            } else {
                _store.refundTokens();
            }
        }
        _store.claimNativeToken();
        IEventEmitter(_store.projectConfigs.eventEmitter).onUpdateDebt(
            _store.account.owner,
            key,
            oldDebtCollateralAmount,
            oldInflightDebtCollateralAmount,
            oldPendingFeeCollateralAmount,
            oldDebtEntryFunding,
            _store.account.debtCollateralAmount,
            _store.account.inflightDebtCollateralAmount,
            _store.account.pendingFeeCollateralAmount,
            _store.account.debtEntryFunding
        );
    }

    function afterOrderCancellation(
        bytes32 key,
        IOrder.Props memory,
        IEvent.EventLogData memory
    ) external onlyValidCallbackSender {
        uint256 oldDebtCollateralAmount = _store.account.debtCollateralAmount;
        uint256 oldInflightDebtCollateralAmount = _store.account.inflightDebtCollateralAmount;
        uint256 oldPendingFeeCollateralAmount = _store.account.pendingFeeCollateralAmount;
        uint256 oldDebtEntryFunding = _store.account.debtEntryFunding;
        require(!_store.isOrderExist(key), "OrderNotCancelled");
        OrderRecord memory pendingOrder = _store.removeOrder(key);
        if (pendingOrder.isIncreasing) {
            _store.repayCancelledDebt(pendingOrder.collateralAmount, pendingOrder.debtCollateralAmount);
        }
        _store.claimNativeToken();
        IEventEmitter(_store.projectConfigs.eventEmitter).onUpdateDebt(
            _store.account.owner,
            key,
            oldDebtCollateralAmount,
            oldInflightDebtCollateralAmount,
            oldPendingFeeCollateralAmount,
            oldDebtEntryFunding,
            _store.account.debtCollateralAmount,
            _store.account.inflightDebtCollateralAmount,
            _store.account.pendingFeeCollateralAmount,
            _store.account.debtEntryFunding
        );
    }

    function afterOrderFrozen(
        bytes32 key,
        IOrder.Props memory,
        IEvent.EventLogData memory
    ) external onlyValidCallbackSender {}

    // =========================================== internals ===========================================
    function _isValidCallbackSender() internal view returns (bool) {
        if (IProxyFactory(_store.factory).isKeeper(msg.sender)) {
            return true;
        }
        // let it pass if the caller is a gmx controller
        IRoleStore roleStore = IRoleStore(IDataStore(_store.projectConfigs.dataStore).roleStore());
        if (roleStore.hasRole(msg.sender, CONTROLLER)) {
            return true;
        }
        return false;
    }

    function _isValidCaller() internal view returns (bool) {
        if (msg.sender == _store.factory) {
            return true;
        }
        if (msg.sender == _store.account.owner) {
            return true;
        }
        return false;
    }

    function _isIncreasing(IOrder.OrderType orderType) internal pure returns (bool) {
        return orderType == IOrder.OrderType.MarketIncrease || orderType == IOrder.OrderType.LimitIncrease;
    }
}
