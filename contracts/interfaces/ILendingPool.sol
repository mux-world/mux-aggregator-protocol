// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

uint256 constant STATE_IS_ENABLED = 0x1;
uint256 constant STATE_IS_BORROWABLE = 0x2;
uint256 constant STATE_IS_REPAYABLE = 0x4;
uint256 constant STATE_IS_DEPOSITABLE = 0x8;
uint256 constant STATE_IS_WITHDRAWABLE = 0x10;

interface ILendingPool {
    struct BorrowState {
        uint256 flags;
        uint256 supplyAmount;
        uint256 borrowFeeAmount;
        uint256 totalAmountOut;
        uint256 totalAmountIn;
        uint256 badDebtAmount;
        bytes32[10] __reserves;
    }

    struct LendingPoolStore {
        address priceHub;
        address swapRouter;
        address liquidityPool;
        uint256 totalBorrowUsd;
        uint256 totalRepayUsd;
        mapping(address => uint256) borrowUsds;
        mapping(address => uint256) repayUsds;
        mapping(address => bool) borrowers;
        mapping(address => bool) maintainers;
        mapping(address => BorrowState) borrowStates;
        bytes32[50] __reserves;
    }

    event BorrowToken(address indexed borrower, address indexed token, uint256 borrowAmount, uint256 borrowFee);
    event RepayToken(
        address indexed repayer,
        address indexed token,
        uint256 repayAmount,
        uint256 borrowFee,
        uint256 badDebt
    );
    event SetMaintainer(address indexed maintainer, bool enabled);
    event SetBorrower(address indexed borrower, bool enabled);
    event SetSwapRouter(address indexed swapRouter);
    event SetFlags(address indexed token, uint256 enables, uint256 disables, uint256 result);
    event Deposit(address indexed token, uint256 amount);
    event Withdraw(address indexed token, uint256 amount);
    event ClaimFee(address indexed token, address recipient, uint256 amount);

    function borrowToken(
        uint256 projectId,
        address borrower,
        address token,
        uint256 borrowAmount,
        uint256 borrowFee
    ) external returns (uint256);

    function repayToken(
        uint256 projectId,
        address repayer,
        address token,
        uint256 repayAmount,
        uint256 borrowFee,
        uint256 badDebt
    ) external returns (uint256);
}
