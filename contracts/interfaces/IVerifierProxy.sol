//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IVerifierProxy {
    function getVerifier(bytes32 configDigest) external view returns (address);

    function setVerifier(bytes32 currentConfigDigest, bytes32 newConfigDigest) external;

    function unsetVerifier(bytes32 configDigest) external;

    function initializeVerifier(address verifier) external;
}
