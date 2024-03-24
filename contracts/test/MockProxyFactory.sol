// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/ILendingPool.sol";

contract MockProjectFactory {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public lendingPool;
    uint256 public defaultProjectId;

    mapping(address => uint256) mockProjectId;

    constructor(uint256 defaultProjectId_) {
        defaultProjectId = defaultProjectId_;
    }

    function setLendingPool(address pool) external {
        lendingPool = pool;
    }

    function setProjectId(address sender, uint256 pejectId) external {
        mockProjectId[sender] = pejectId;
    }

    function getProxyProjectId(address sender) external view returns (uint256) {
        if (mockProjectId[sender] != 0) {
            return mockProjectId[sender];
        }
        return defaultProjectId;
    }

    function getAssetId(uint256 projectId, address token) external view returns (uint8) {
        return 255;
    }

    function borrowAsset(
        uint256 projectId,
        address assetToken,
        uint256 toBorrow,
        uint256 fee
    ) external returns (uint256 amountOut) {
        return ILendingPool(lendingPool).borrowToken(projectId, msg.sender, assetToken, toBorrow, fee);
    }

    function repayAsset(uint256 projectId, address assetToken, uint256 toRepay, uint256 fee, uint256 badDebt) external {
        IERC20Upgradeable(assetToken).safeTransfer(lendingPool, toRepay + fee);
        ILendingPool(lendingPool).repayToken(projectId, msg.sender, assetToken, toRepay, fee, badDebt);
    }
}
