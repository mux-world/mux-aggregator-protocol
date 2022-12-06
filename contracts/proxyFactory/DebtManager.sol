// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../interfaces/ILiquidityPool.sol";
import "./Storage.sol";

abstract contract DebtManager is Storage {
    function _borrowAsset(
        uint256 projectId,
        address account,
        address assetToken,
        uint256 amount,
        uint256 fee
    ) internal returns (uint256 amountOut) {
        DebtData storage debtData = _debtData[projectId][assetToken];
        require(debtData.hasValue, "AssetNotAvailable");
        if (debtData.assetId == VIRTUAL_ASSET_ID) {
            require(amount == 0 && fee == 0, "VirtualAsset");
            amountOut = 0;
        } else {
            require(debtData.totalDebt + amount <= debtData.limit, "ExceedsBorrowLimit");
            amountOut = ILiquidityPool(_liquidityPool).borrowAsset(account, debtData.assetId, amount, fee);
            debtData.totalDebt += amount;
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
        DebtData storage debtData = _debtData[projectId][assetToken];
        require(debtData.hasValue, "AssetNotAvailable");
        if (debtData.assetId == VIRTUAL_ASSET_ID) {
            require(amount == 0 && fee == 0 && badDebt == 0, "VirtualAsset");
        } else {
            ILiquidityPool(_liquidityPool).repayAsset(account, debtData.assetId, amount, fee, badDebt);
            debtData.totalDebt -= amount;
            debtData.badDebt += badDebt;
        }
    }
}
