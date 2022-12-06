// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../proxyFactory/ProxyFactory.sol";

contract TestProxyFactory is ProxyFactory {
    function setTotalBorrows(
        uint256 projectId,
        address assetToken,
        uint256 amount
    ) external {
        DebtData storage debtData = _debtData[projectId][assetToken];
        debtData.totalDebt = amount;
    }
}
