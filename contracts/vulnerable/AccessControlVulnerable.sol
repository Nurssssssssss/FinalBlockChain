// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

contract AccessControlVulnerable {
    address public treasury;

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    constructor(address treasury_) {
        treasury = treasury_;
    }

    function setTreasury(address newTreasury) external {
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
}
