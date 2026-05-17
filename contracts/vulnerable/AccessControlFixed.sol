// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract AccessControlFixed is AccessControl {
    bytes32 public constant TREASURY_MANAGER_ROLE = keccak256("TREASURY_MANAGER_ROLE");

    address public treasury;

    error ZeroAddress();

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    constructor(address treasury_, address admin) {
        if (treasury_ == address(0) || admin == address(0)) revert ZeroAddress();
        treasury = treasury_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURY_MANAGER_ROLE, admin);
    }

    function setTreasury(address newTreasury) external onlyRole(TREASURY_MANAGER_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
}
