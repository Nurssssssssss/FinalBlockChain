// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

interface IPriceOracle {
    function latestPrice() external view returns (uint256 price, uint8 decimals, uint256 updatedAt);
    function normalizedPrice() external view returns (uint256 priceE18);
}
