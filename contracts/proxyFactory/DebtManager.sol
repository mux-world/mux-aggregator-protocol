// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/ILiquidityPool.sol";
import "../interfaces/ILendingPool.sol";
import "./Storage.sol";

abstract contract DebtManager is Storage {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function _getLiquiditySource(uint256 projectId) internal view returns (uint256 sourceId, address source) {
        sourceId = _liquiditySourceId[projectId];
        if (sourceId == 0) {
            // default source = liquidityPool
            sourceId = SOURCE_ID_LIQUIDITY_POOL;
            source = _liquidityPool;
        } else {
            // else
            source = _liquiditySource[sourceId];
        }
    }

    function _borrowAsset(
        uint256 projectId,
        address account,
        address assetToken,
        uint256 amount,
        uint256 fee
    ) internal returns (uint256 amountOut) {
        require(projectId == _proxyProjectIds[msg.sender], "BadProjectId");
        (uint256 sourceId, address source) = _getLiquiditySource(projectId);
        if (sourceId == SOURCE_ID_LIQUIDITY_POOL) {
            DebtData storage debtData = _debtData[projectId][assetToken];
            require(debtData.hasValue, "AssetNotAvailable");
            if (debtData.assetId == VIRTUAL_ASSET_ID) {
                require(amount == 0 && fee == 0, "VirtualAsset");
                amountOut = 0;
            } else {
                require(debtData.totalDebt + amount <= debtData.limit, "ExceedsBorrowLimit");
                amountOut = ILiquidityPool(source).borrowAsset(account, debtData.assetId, amount, fee);
                debtData.totalDebt += amount;
            }
        } else if (sourceId == SOURCE_ID_LENDING_POOL) {
            return ILendingPool(source).borrowToken(projectId, account, assetToken, amount, fee);
        } else {
            revert("UnknownSource");
        }
    }

    function _repayAsset(
        uint256 projectId,
        address account,
        address assetToken,
        uint256 amount,
        uint256 fee,
        uint256 badDebt
    ) internal {
        (uint256 sourceId, address source) = _getLiquiditySource(projectId);
        if (sourceId == SOURCE_ID_LIQUIDITY_POOL) {
            DebtData storage debtData = _debtData[projectId][assetToken];
            require(debtData.hasValue, "AssetNotAvailable");
            if (debtData.assetId == VIRTUAL_ASSET_ID) {
                require(amount == 0 && fee == 0 && badDebt == 0, "VirtualAsset");
            } else {
                ILiquidityPool(_liquidityPool).repayAsset(account, debtData.assetId, amount, fee, badDebt);
                debtData.totalDebt -= amount;
                debtData.badDebt += badDebt;
            }
        } else if (sourceId == SOURCE_ID_LENDING_POOL) {
            IERC20Upgradeable(assetToken).safeTransfer(source, amount + fee);
            ILendingPool(source).repayToken(projectId, account, assetToken, amount, fee, badDebt);
        } else {
            revert("UnknownSource");
        }
    }
}
