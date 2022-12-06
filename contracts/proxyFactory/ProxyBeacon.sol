// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import "../interfaces/IAggregator.sol";

import "./Storage.sol";

contract ProxyBeacon is Storage, IBeacon {
    event Upgraded(uint256 projectId, address indexed implementation);
    event CreateProxy(
        uint256 projectId,
        bytes32 proxyId,
        address owner,
        address proxy,
        bytes32 gmxPositionKey,
        address assetToken,
        address collateralToken,
        uint8 collateralTokenId,
        bool isLong
    );

    function implementation() public view virtual override returns (address) {
        require(_isCreatedProxy(msg.sender), "NotProxy");
        return _implementations[_proxyProjectIds[msg.sender]];
    }

    function _isCreatedProxy(address proxy_) internal view returns (bool) {
        return _proxyProjectIds[proxy_] != 0;
    }

    function _setImplementation(uint256 projectId, address newImplementation_) internal {
        require(newImplementation_ != address(0), "ZeroImplementationAddress");
        _implementations[projectId] = newImplementation_;
    }

    function _upgradeTo(uint256 projectId, address newImplementation_) internal virtual {
        _setImplementation(projectId, newImplementation_);
        emit Upgraded(projectId, newImplementation_);
    }

    function _createProxy(
        uint256 projectId,
        bytes32 proxyId,
        bytes memory bytecode
    ) internal returns (address proxy) {
        proxy = _getAddress(bytecode, proxyId);
        _proxyProjectIds[proxy] = projectId; // IMPORTANT
        assembly {
            proxy := create2(0x0, add(0x20, bytecode), mload(bytecode), proxyId)
        }
        require(proxy != address(0), "CreateFailed");
    }

    function _createBeaconProxy(
        uint256 projectId,
        address liquidityPool,
        address account,
        address assetToken,
        address collateralToken,
        uint8 collateralId,
        bool isLong
    ) internal returns (address) {
        // require(projectId) // isValid
        bytes32 proxyId = _makeProxyId(projectId, account, collateralToken, assetToken, isLong);
        require(_tradingProxies[proxyId] == address(0), "AlreadyCreated");
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint256,address,address,address,address,bool)",
            projectId,
            liquidityPool,
            account,
            collateralToken,
            assetToken,
            isLong
        );
        bytes memory bytecode = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(address(this), initData));
        address proxy = _createProxy(projectId, proxyId, bytecode);
        _tradingProxies[proxyId] = proxy;
        _ownedProxies[account].push(proxy);
        bytes32 gmxKey = _makeGmxPositionKey(proxy, collateralToken, assetToken, isLong);
        emit CreateProxy(projectId, proxyId, account, proxy, gmxKey, assetToken, collateralToken, collateralId, isLong);
        return proxy;
    }

    function _getBeaconProxyAddress(
        uint256 projectId,
        address liquidityPool,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) internal view returns (address) {
        // require(projectId) // isValid
        bytes32 proxyId = _makeProxyId(projectId, account, collateralToken, assetToken, isLong);
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint256,address,address,address,address,bool)",
            projectId,
            liquidityPool,
            account,
            collateralToken,
            assetToken,
            isLong
        );
        bytes memory bytecode = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(address(this), initData));
        return _getAddress(bytecode, proxyId);
    }

    function _getAddress(bytes memory bytecode, bytes32 proxyId) internal view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), proxyId, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function _makeProxyId(
        uint256 projectId_,
        address account_,
        address collateralToken_,
        address assetToken_,
        bool isLong_
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(projectId_, account_, collateralToken_, assetToken_, isLong_));
    }

    function _makeGmxPositionKey(
        address account_,
        address collateralToken_,
        address indexToken_,
        bool isLong_
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account_, collateralToken_, indexToken_, isLong_));
    }
}
