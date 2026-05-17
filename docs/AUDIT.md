# Audit Notes

## Page 1: Executive Summary

This document reviews the DeFi SuperApp Lite protocol implemented in this repository. The review focuses on smart-contract security, role design, upgrade safety, oracle usage, ERC20 handling, frontend and subgraph trust assumptions, and the reproduced vulnerability examples. The protocol is not intended to custody mainnet funds, but it follows the same engineering patterns expected from a production-grade testnet deployment.

Current review result: no known High or Medium issues remain in the production contracts. Slither is configured to fail on Medium and High findings and to exclude intentionally vulnerable examples. The vulnerable examples are covered by dedicated regression tests and are documented as educational artifacts, not deployable protocol modules.

Primary security strengths:

- OpenZeppelin base contracts are used for ERC20, ERC4626, Governor, Timelock, AccessControl, Permit, Votes, UUPS, and ReentrancyGuard.
- ERC20 interactions use `SafeERC20`.
- Admin authority is designed to transfer to Timelock/Governor.
- No `tx.origin` usage.
- No `transfer` or `send`.
- No timestamp randomness.
- Oracle reads reject stale, incomplete, and non-positive answers.
- UUPS upgrades are role-gated.
- Tests include unit, fuzz, invariant, fork, and exploit-regression coverage.

## Page 2: Scope

In scope:

- `contracts/GovernanceToken.sol`
- `contracts/YieldVault.sol`
- `contracts/ConstantProductAMM.sol`
- `contracts/LPToken.sol`
- `contracts/PriceFeedOracle.sol`
- `contracts/PoolFactory.sol`
- `contracts/DeFiGovernor.sol`
- `contracts/UpgradeableTreasuryV1.sol`
- `contracts/UpgradeableTreasuryV2.sol`
- `contracts/MathBench.sol`
- `script/Deploy.s.sol`
- `script/PostDeployCheck.s.sol`
- `script/UpgradeTreasury.s.sol`
- Tests under `test/`
- Frontend and subgraph integration assumptions

Educational examples:

- `contracts/vulnerable/ReentrancyVaultVulnerable.sol`
- `contracts/vulnerable/ReentrancyVaultFixed.sol`
- `contracts/vulnerable/AccessControlVulnerable.sol`
- `contracts/vulnerable/AccessControlFixed.sol`

Out of scope:

- Mainnet economic modeling
- MEV-resistant routing
- Cross-chain bridge integration
- Real yield strategy risk
- Third-party RPC uptime
- Hosted subgraph operator behavior

## Page 3: Threat Model

The main assets are governance tokens, vault underlying assets, AMM reserves, LP shares, and treasury balances. The main actors are token holders, LPs, vault depositors, proposers, voters, keepers/executors, and deployers. The primary adversaries are malicious users attempting reentrancy, unauthorized role calls, stale oracle use, bad swaps, griefing through malformed inputs, or upgrade abuse.

Trust assumptions:

- OpenZeppelin libraries are trusted.
- Chainlink-compatible feeds are trusted if configured correctly.
- Timelock delay gives users time to react to governance actions.
- The deployer is trusted only during initial setup.
- The frontend is not a security boundary. Contract checks remain authoritative.
- The subgraph is an indexing layer, not a source of settlement truth.

The protocol deliberately avoids hidden owner powers after deployment. The deploy script grants roles to Timelock and revokes the deployer. If a deployment chooses to keep deployer roles for a demo, that should be disclosed in `docs/DEPLOYMENTS.md`.

## Page 4: Findings And Resolutions

### Informational: Oracle timestamp warning

Foundry lint warns that `block.timestamp` appears in a comparison. This is intentional and acceptable because the comparison checks oracle freshness. It is not used for randomness or selection.

Resolution: documented as accepted. The oracle reverts when `updatedAt == 0` or when `block.timestamp - updatedAt > staleAfter`.

### Informational: AMM fee-on-transfer support

The AMM measures actual received input, which helps with non-standard tokens, but it does not formally support fee-on-transfer output or rebasing assets. Production deployment should list supported assets.

Resolution: documented limitation. Tests use standard ERC20 mocks.

### Informational: Subgraph manifest address specialization

The subgraph manifest builds without source addresses, making it reusable before deployment. Production indexing should add deployed addresses and start blocks.

Resolution: documented in README and deployments guide.

### Informational: Upgrade governance process

The upgrade script can directly execute when `EXECUTE_DIRECT_UPGRADE=true`, but production authority should be Timelock.

Resolution: default behavior prints calldata for Governor/Timelock execution.

## Page 5: Reentrancy Review

Production contracts use ReentrancyGuard where external value movement and state changes interact. `YieldVault` wraps ERC4626 entry points with `nonReentrant`. `ConstantProductAMM` protects liquidity, swap, remove, and sync functions. `UpgradeableTreasuryV1` protects token and native withdrawals.

The intentionally vulnerable example demonstrates the classic bug: native value is sent before balance accounting is reduced. In Solidity 0.8, unchecked subtraction is used in the vulnerable example so the exploit is reproducible and visible in tests. The fixed version uses checks-effects-interactions and ReentrancyGuard.

Regression tests:

- `testReentrancyVulnerableCanBeDrainedBeyondDeposit`
- `testReentrancyFixedBlocksAttack`
- `testReentrancyFixedAllowsNormalWithdraw`

The production treasury uses `call` for native withdrawals instead of `transfer` or `send`, and it wraps the function with `nonReentrant`.

## Page 6: Access Control Review

Access control is based on OpenZeppelin AccessControl. The deployment model is:

- Token `DEFAULT_ADMIN_ROLE` and `MINTER_ROLE` to Timelock
- Vault `DEFAULT_ADMIN_ROLE`, `PAUSER_ROLE`, and `REWARD_MANAGER_ROLE` to Timelock
- Oracle `DEFAULT_ADMIN_ROLE` and `FEED_MANAGER_ROLE` to Timelock
- Factory `DEFAULT_ADMIN_ROLE` and `PAIR_CREATOR_ROLE` to Timelock
- Treasury `DEFAULT_ADMIN_ROLE`, `TREASURER_ROLE`, and `UPGRADER_ROLE` to Timelock
- Timelock proposer and canceller to Governor
- Timelock executor open to anyone

The intentionally vulnerable access-control example has an unrestricted `setTreasury`. The fixed version uses AccessControl and rejects unauthorized callers.

Regression tests:

- `testVulnerableAccessAllowsAttackerToChangeTreasury`
- `testFixedAccessRejectsAttacker`
- `testFixedAccessAllowsManager`

The major operational risk is an incomplete role handoff during deployment. The deploy script handles role migration, and the post-deploy check can be extended with role assertions for a specific network.

## Page 7: Oracle And AMM Review

The oracle wrapper checks:

- Feed address is non-zero
- `answer > 0`
- `answeredInRound >= roundId`
- `updatedAt != 0`
- `block.timestamp - updatedAt <= staleAfter`

The AMM uses reserve-based pricing. It does not rely on Chainlink prices for swap execution, which avoids mixing oracle and AMM pricing in a fragile way. The oracle price is exposed for UI, monitoring, and governance decisions.

Swap formula:

```text
amountInWithFee = amountIn * 997
amountOut = amountInWithFee * reserveOut / (reserveIn * 1000 + amountInWithFee)
```

This means the 0.3% fee remains in the pool and accrues to LPs. Slippage is caller-protected through `minAmountOut`. Liquidity removal is protected by `minAmount0` and `minAmount1`.

Known AMM limitations:

- No TWAP oracle
- No concentrated liquidity
- No protocol fee switch
- No fee-on-transfer support guarantee
- No multi-hop router

These are acceptable for the Lite scope.

## Page 8: Upgradeability, Tooling, And Final Checklist

The UUPS implementation follows the important rule: `_authorizeUpgrade` is restricted by `UPGRADER_ROLE`. V2 adds storage after V1 state and introduces a bounded fee setter. Tests verify V1 version, upgrade to V2, V2 fee setting, and high-fee revert.

Tooling:

- `forge build` compiles production contracts and scripts.
- `forge test -vv` currently passes `88` tests.
- `forge coverage` generates summary and lcov.
- `slither . --config-file slither.config.json --exclude divide-before-multiply,incorrect-equality` scans production contracts and fails on Medium/High. The two excluded detectors are documented false positives for AMM proportional math and intentional zero checks.
- Frontend `npm run lint` and `npm run build` are in CI.
- Subgraph `npm run codegen` and `npm run build` are in CI.

Checklist:

- No `tx.origin`: satisfied.
- No `transfer`/`send`: satisfied.
- No timestamp randomness: satisfied.
- SafeERC20 for token movement: satisfied.
- Timelock/Governor/AccessControl admin model: satisfied by deployment script.
- Reentrancy vulnerable and fixed examples: satisfied.
- Access-control vulnerable and fixed examples: satisfied.
- Chainlink staleness check: satisfied.
- CREATE and CREATE2: satisfied.
- UUPS V1 to V2 path: satisfied.
- Inline Yul and Solidity equivalent: satisfied.

Residual risks:

- Real Chainlink feed addresses must be verified before L2 deployment.
- Real deployment must confirm roles after broadcast.
- Frontend and subgraph env values must be filled from deployment JSON.
