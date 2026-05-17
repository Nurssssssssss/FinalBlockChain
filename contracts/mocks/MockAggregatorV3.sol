// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
    uint8 private immutable _decimals;
    string private _description;
    uint256 private immutable _version;

    uint80 public roundId;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;

    constructor(uint8 decimals_, int256 initialAnswer) {
        _decimals = decimals_;
        _description = "Mock Chainlink Feed";
        _version = 1;
        updateAnswer(initialAnswer);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external view returns (uint256) {
        return _version;
    }

    function updateAnswer(int256 newAnswer) public {
        roundId += 1;
        answer = newAnswer;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

    function setUpdatedAt(uint256 newUpdatedAt) external {
        updatedAt = newUpdatedAt;
    }

    function setAnsweredInRound(uint80 newAnsweredInRound) external {
        answeredInRound = newAnsweredInRound;
    }

    function getRoundData(uint80 requestedRoundId)
        external
        view
        returns (uint80 roundId_, int256 answer_, uint256 startedAt_, uint256 updatedAt_, uint80 answeredInRound_)
    {
        requestedRoundId;
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId_, int256 answer_, uint256 startedAt_, uint256 updatedAt_, uint80 answeredInRound_)
    {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
