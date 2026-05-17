// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ReentrancyVaultFixed is ReentrancyGuard {
    mapping(address account => uint256 balance) public balances;

    error ZeroDeposit();
    error InsufficientBalance();
    error NativeTransferFailed();

    function deposit() external payable {
        if (msg.value == 0) revert ZeroDeposit();
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert NativeTransferFailed();
    }
}
