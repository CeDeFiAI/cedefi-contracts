// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/AggregatorV3Interface.sol";
contract MockChainlinkAggregator is AggregatorV3Interface {
    uint80 public latestRoundId;
    int256 public latestAnswer;
    uint256 public latestTimestamp;

    constructor(uint80 _latestRoundId, int256 _latestAnswer, uint256 _latestTimestamp) {
        latestRoundId = _latestRoundId;
        latestAnswer = _latestAnswer;
        latestTimestamp = _latestTimestamp;
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (latestRoundId, latestAnswer, 0, latestTimestamp, 0);
    }
}