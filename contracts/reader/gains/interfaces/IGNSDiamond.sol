// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./IGNSAddressStore.sol";
import "./IGNSDiamondCut.sol";
import "./IGNSDiamondLoupe.sol";
import "./types/ITypes.sol";

/**
 * @custom:version 8
 * @dev the non-expanded interface for multi-collat diamond, only contains types/structs/enums
 */

interface IGNSDiamond is IGNSAddressStore, IGNSDiamondCut, IGNSDiamondLoupe, ITypes {

}
