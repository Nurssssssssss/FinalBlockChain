// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

contract MathBench {
    function mulDivSolidity(uint256 x, uint256 y, uint256 denominator) external pure returns (uint256) {
        require(denominator != 0, "DIV_BY_ZERO");
        return (x * y) / denominator;
    }

    function mulDivYul(uint256 x, uint256 y, uint256 denominator) external pure returns (uint256 result) {
        assembly ("memory-safe") {
            if iszero(denominator) {
                mstore(0x00, 0x08c379a0)
                mstore(0x20, 0x20)
                mstore(0x40, 0x0b)
                mstore(0x60, "DIV_BY_ZERO")
                revert(0x1c, 0x64)
            }
            result := div(mul(x, y), denominator)
        }
    }

    function sumSolidity(uint256[] calldata values) external pure returns (uint256 total) {
        for (uint256 i = 0; i < values.length; ++i) {
            total += values[i];
        }
    }

    function sumYul(uint256[] calldata values) external pure returns (uint256 total) {
        assembly ("memory-safe") {
            let offset := values.offset
            let end := add(offset, mul(values.length, 0x20))
            for { } lt(offset, end) { offset := add(offset, 0x20) } { total := add(total, calldataload(offset)) }
        }
    }
}
