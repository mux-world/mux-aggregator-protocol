// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./types/IDiamondStorage.sol";

/**
 * @author Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * @author Gains Network
 * @dev Based on EIP-2535: Diamonds (https://eips.ethereum.org/EIPS/eip-2535)
 * @dev Follows diamond-3 implementation (https://github.com/mudgen/diamond-3-hardhat/)
 * @dev One of the diamond standard interfaces, used for diamond management.
 */
interface IGNSDiamondCut is IDiamondStorage {
    /**
     * @notice Add/replace/remove any number of functions and optionally execute a function with delegatecall
     * @param _diamondCut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments _calldata is executed with delegatecall on _init
     */
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;

    /**
     * @dev Emitted when function selectors of a facet of the diamond is added, replaced, or removed
     * @param _diamondCut Contains the update data (facet addresses, action, function selectors)
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata Function call to execute after the diamond cut
     */
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
    error InvalidFacetCutAction();
    error NotContract();
    error NotFound();
}
