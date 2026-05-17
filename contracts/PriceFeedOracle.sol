// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";

contract PriceFeedOracle is AccessControl, IPriceOracle {
    bytes32 public constant FEED_MANAGER_ROLE = keccak256("FEED_MANAGER_ROLE");

    AggregatorV3Interface public feed;
    uint256 public staleAfter;

    error InvalidFeed();
    error InvalidStaleAfter();
    error InvalidPrice();
    error StalePrice(uint256 updatedAt, uint256 staleAfter);
    error IncompleteRound(uint80 roundId, uint80 answeredInRound);

    event FeedUpdated(address indexed oldFeed, address indexed newFeed);
    event StaleAfterUpdated(uint256 oldValue, uint256 newValue);

    constructor(address feed_, uint256 staleAfter_, address admin) {
        if (feed_ == address(0) || admin == address(0)) revert InvalidFeed();
        if (staleAfter_ == 0) revert InvalidStaleAfter();
        feed = AggregatorV3Interface(feed_);
        staleAfter = staleAfter_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FEED_MANAGER_ROLE, admin);
    }

    function setFeed(address newFeed) external onlyRole(FEED_MANAGER_ROLE) {
        if (newFeed == address(0)) revert InvalidFeed();
        address oldFeed = address(feed);
        feed = AggregatorV3Interface(newFeed);
        emit FeedUpdated(oldFeed, newFeed);
    }

    function setStaleAfter(uint256 newStaleAfter) external onlyRole(FEED_MANAGER_ROLE) {
        if (newStaleAfter == 0) revert InvalidStaleAfter();
        uint256 oldValue = staleAfter;
        staleAfter = newStaleAfter;
        emit StaleAfterUpdated(oldValue, newStaleAfter);
    }

    function latestPrice() public view returns (uint256 price, uint8 decimals_, uint256 updatedAt) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound) =
            feed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        if (answeredInRound < roundId) revert IncompleteRound(roundId, answeredInRound);
        if (startedAt == 0 || updatedAt_ == 0 || block.timestamp - updatedAt_ > staleAfter) {
            revert StalePrice(updatedAt_, staleAfter);
        }
        return (uint256(answer), feed.decimals(), updatedAt_);
    }

    function normalizedPrice() external view returns (uint256 priceE18) {
        (uint256 price, uint8 decimals_,) = latestPrice();
        if (decimals_ == 18) return price;
        if (decimals_ < 18) return price * 10 ** (18 - decimals_);
        return price / 10 ** (decimals_ - 18);
    }
}
