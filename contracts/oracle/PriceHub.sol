// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IChainLink.sol";
import "../aggregators/gmx/libs/LibUtils.sol";

contract PriceHub is Initializable, OwnableUpgradeable {
    enum SourceType {
        Invalid,
        Chainlink
    }

    struct PriceSource {
        SourceType sourceType;
        address endpoint;
        uint32 heartbeatPeriod;        // decimals = 0. if answer.updatedAt is older than heartbeatPeriod, then the price is considered as stale
        uint32 strictStableDeviation;   // decimals = 5. 0 means disabled. if the | price - 1.0 | is larger than strictStableDeviation, then the price is considered as 1.0
    }

    mapping(address => PriceSource) public priceSources;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setPriceSource(address token, SourceType sourceType, bytes memory sourceData) external onlyOwner {
        if (sourceType == SourceType.Chainlink) {
            require(sourceData.length == 32 * 3, "DAT"); // invalid DATa
            (address endpoint, uint32 heartbeatPeriod, uint32 strictStableDeviation) = abi.decode(sourceData, (address, uint32, uint32));
            require(IChainlinkV2V3(endpoint).decimals() == 8, "!D8"); // decimals must be 8
            priceSources[token] = PriceSource(sourceType, endpoint, heartbeatPeriod, strictStableDeviation);
        } else {
            revert("SRC"); // invalid SouRCe
        }
    }

    function getPriceByToken(address token) external view returns (uint256 price) {
        PriceSource storage source = priceSources[token];
        if (source.sourceType == SourceType.Chainlink) {
            (uint80 roundId, int256 answer, , uint256 updatedAt, uint80 answeredInRound) = IChainlinkV2V3(source.endpoint).latestRoundData();
            require(answer > 0, "P=0"); // oracle Price <= 0
            require(block.timestamp - updatedAt < source.heartbeatPeriod, "STL"); // STaLe
            require(answeredInRound >= roundId, "STL"); // STaLe
            answer *= 1e10; // decimals 8 => 18
            price = LibUtils.toU96(uint256(answer));
        } else {
            revert("SRC"); // invalid SouRCe
        }

        // strict stable
        if (source.strictStableDeviation > 0) {
            uint256 delta = price > 1e18 ? price - 1e18 : 1e18 - price;
            uint256 dampener = uint256(source.strictStableDeviation) * 1e13; // 1e5 => 1e18
            if (delta <= dampener) {
                price = 1e18;
            }
        }
    }
}
