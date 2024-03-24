// // SPDX-License-Identifier: GPL-2.0-or-later

// pragma solidity 0.8.17;

// import "../../../aggregators/gmxV2/libraries/LibGmxV2.sol";
// import "../../../aggregators/gmxV2/interfaces/IGmxV2Adatper.sol";
// import "../../../aggregators/gmxV2/interfaces/gmx/IReader.sol";

// contract TestPlaceOrder {
//     using LibGmxV2 for IGmxV2Adatper.GmxAdapterStoreV2;

//     address private reader;
//     IGmxV2Adatper.GmxAdapterStoreV2 private store;

//     function initialize(address reader_, address factory_, address liquidityPool) external {
//         reader = reader_;
//     }

//     function getAssetId(uint256 projectId, address token) external view returns (uint8) {
//         return IReader(reader).getAssetId(token);
//     }

//     function testMarginValueUsdCase1() external view {
//         IReader.PositionInfo memory position;

//         position.position.numbers.collateralAmount = 5e18; // 5 eth
//         // store.marginValueUsd(position, 1);
//     }
// }
