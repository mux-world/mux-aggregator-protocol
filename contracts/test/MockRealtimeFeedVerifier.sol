// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IVerifierProxy.sol";

import "hardhat/console.sol";

contract MockRealtimeFeedVerifier {
    function verify(bytes memory data) external view returns (bytes memory) {
        // console.log("timestamp  ", block.timestamp);
        // console.log("blocknumber", block.number);
        return data;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function setVerifier(address verifierProxy, bytes32 currentConfigDigest, bytes32 newConfigDigest) external {
        IVerifierProxy(verifierProxy).setVerifier(currentConfigDigest, newConfigDigest);
    }
}
