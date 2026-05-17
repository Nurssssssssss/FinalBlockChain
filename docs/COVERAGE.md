# Coverage

## Command

```bash
forge coverage --ir-minimum --report summary --report lcov
```

## Test Inventory

The repository contains `88` Foundry tests:

- `62` unit tests
- `10` fuzz tests
- `5` invariant tests
- `3` fork tests
- `8` vulnerability regression tests

## Areas Covered

- ERC20Votes and ERC20Permit behavior
- Minting role checks and cap reverts
- Delegation and voting power movement
- Chainlink-style price reads, normalization, stale reverts, invalid answer reverts, incomplete round reverts
- ERC4626 deposits, mints, withdrawals, redemptions, rewards, pauses, unauthorized role paths
- AMM liquidity, swaps, slippage reverts, invalid token reverts, reserve sync
- CREATE and CREATE2 factory deployment, prediction, duplicate reverts, role reverts
- UUPS V1 to V2 upgrade and fee bounds
- Governor proposal state path
- Reentrancy exploit reproduction and fixed behavior
- Access-control exploit reproduction and fixed behavior

## Residual Coverage Notes

Fork tests safely return when RPC env vars are absent, so CI can run without secrets. When `BASE_SEPOLIA_RPC_URL` and feed env vars are present, they verify chain id, Chainlink-compatible reads, and CREATE2 prediction on a fork.

The subgraph and frontend have build/lint checks rather than unit tests. For a larger production app, add Playwright wallet mocks and mapping unit tests with Matchstick.

`--ir-minimum` is used because coverage disables the normal optimizer/viaIR settings and the deployment script otherwise triggers a Solidity stack-depth error during coverage compilation.
