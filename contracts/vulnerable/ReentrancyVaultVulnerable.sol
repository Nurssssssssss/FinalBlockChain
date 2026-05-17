// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

contract ReentrancyVaultVulnerable {
    mapping(address account => uint256 balance) public balances;

    error ZeroDeposit();
    error InsufficientBalance();
    error NativeTransferFailed();

    function deposit() external payable {
        if (msg.value == 0) revert ZeroDeposit();
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert NativeTransferFailed();
        unchecked {
            balances[msg.sender] -= amount;
        }
    }
}
