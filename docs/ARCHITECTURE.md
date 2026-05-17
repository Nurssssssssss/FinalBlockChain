# Architecture

## Page 1: System Overview

DeFi SuperApp Lite is a compact protocol that combines the minimum realistic surface of a governance-controlled DeFi application. It is intentionally small enough to deploy and audit in a course setting, but it still contains the core production patterns that show up in real protocols: tokenized voting power, tokenized yield shares, automated market making, oracle validation, timelocked governance, upgradeability, deterministic deployment, indexing, and a user-facing web application.

The protocol is organized around six main on-chain modules. `GovernanceToken` provides ERC20Votes and ERC20Permit. `YieldVault` wraps an ERC20 asset with ERC4626 accounting. `ConstantProductAMM` maintains an `x*y=k` pool with a 0.3% swap fee that stays in reserves for LPs. `PriceFeedOracle` wraps Chainlink-compatible feeds and rejects stale, incomplete, or non-positive answers. `DeFiGovernor` and `TimelockController` provide execution governance. `UpgradeableTreasuryV1/V2` demonstrates a UUPS upgrade path under role control.

The system uses a conservative trust model. During deployment the deployer performs initial wiring, then operational roles move to the timelock. The Governor is granted proposer and canceller rights on the Timelock, and the Timelock is granted administrative roles on protocol contracts. This means parameter updates, minting, pausing, feed changes, pair creation, and upgrades can be routed through governance instead of staying with an externally owned account.

The stack is deliberately simple. Foundry owns contracts, tests, scripts, coverage, and local deployment. React with Vite, Wagmi, and Viem owns the frontend. The Graph indexes events needed by the frontend and by reviewers. GitHub Actions runs the same core commands expected from a reviewer: formatting, build, tests, coverage, Slither, frontend lint/build, and subgraph codegen/build.

## Page 2: Token And Governance

`GovernanceToken` inherits OpenZeppelin ERC20, ERC20Permit, ERC20Votes, and AccessControl. The permit extension allows gasless approvals through EIP-2612 signatures. The votes extension creates checkpoints for delegated voting power and integrates with OpenZeppelin Governor. A hard `cap` prevents unlimited minting even if the minter role is compromised.

The token starts with an initial supply for the deployer so governance can bootstrap. After deployment, `MINTER_ROLE` and `DEFAULT_ADMIN_ROLE` are granted to the Timelock and removed from the deployer. In a real deployment, the initial holder should delegate before proposing. The tests cover minting, cap reverts, non-minter reverts, permit signatures, delegation, and vote movement after transfer.

`DeFiGovernor` uses OpenZeppelin Governor modules: settings, simple counting, token votes, quorum fraction, and timelock control. The Governor proposes operations and the Timelock executes them after delay. Voting is token-weighted through ERC20Votes. A proposal threshold prevents spam, while quorum fraction requires a meaningful voting supply before execution.

The intended governance flow is:

1. Token holders delegate voting power.
2. A proposer with threshold power creates a proposal.
3. Voters cast For, Against, or Abstain.
4. If the proposal succeeds, it is queued in the Timelock.
5. After the delay, anyone with executor permission, or the open executor, executes it.

The deployed Timelock grants executor role to `address(0)`, which is the OpenZeppelin pattern for open execution. Proposer and canceller roles are granted to the Governor. The deployment script revokes the deployer's Timelock admin role after setup.

## Page 3: Vault And AMM

`YieldVault` is an ERC4626 vault over a mock or deployed ERC20 asset. It uses standard ERC4626 share math. Deposits mint shares, withdrawals and redemptions burn shares, and direct rewards increase `totalAssets`, which increases the asset value per share. This provides a simple yield model without adding a strategy adapter, lending integration, or bridge risk.

The vault adds AccessControl roles for pausing and rewards. `PAUSER_ROLE` can pause deposits, mints, withdrawals, and redemptions. `REWARD_MANAGER_ROLE` can add rewards by transferring underlying assets into the vault with `SafeERC20`. ReentrancyGuard protects state-changing ERC4626 entry points.

`ConstantProductAMM` implements a Uniswap V2 style reserve model. Liquidity providers deposit token0 and token1 and receive a dedicated LP ERC20. Initial shares are the square root of the product. Later deposits use the reserve ratio and mint the smaller proportional amount. Swaps charge a 0.3% fee by multiplying input by 997 and dividing by 1000 in the output formula.

The AMM stores reserves as `uint112`, matching the conventional packed reserve size. Before narrowing, `_updateReserves` checks both balances fit into `uint112`. The contract does not support fee-on-transfer tokens as a formal feature, but it measures actual transferred input in swaps and deposits. All ERC20 movement uses `SafeERC20`.

The LP token is its own AccessControl ERC20. The AMM receives mint and burn rights, while administrative control is assigned to the pair admin. In the deployment flow, the pair admin is the Timelock.

## Page 4: Oracle, Factory, And Upgradeability

`PriceFeedOracle` accepts any Chainlink AggregatorV3-compatible feed. `latestPrice` rejects non-positive answers, incomplete rounds, zero timestamps, and stale timestamps. `normalizedPrice` converts the feed answer to 18 decimals for downstream comparison. The AMM exposes `oraclePriceToken0InToken1`, which compares normalized prices.

The oracle uses `block.timestamp` only for staleness validation. It is not used for randomness or miner-selectable outcomes. This is an accepted use of timestamps because the goal is rejecting old oracle data, not choosing winners or prices internally.

`PoolFactory` demonstrates both normal CREATE and CREATE2 deployment. `createPair` deploys a new AMM directly. `createPairDeterministic` deploys with a caller-provided salt. `predictDeterministicAddress` computes the expected CREATE2 address using creation code plus constructor arguments. The factory sorts token addresses so duplicate pairs are rejected regardless of input order.

`UpgradeableTreasuryV1` demonstrates UUPS upgradeability. It can receive native currency, accept ERC20 deposits, and allow treasurer withdrawals. `UpgradeableTreasuryV2` extends the implementation with `protocolFeeBps` and a setter capped at 1000 bps. Upgrade authorization is restricted by `UPGRADER_ROLE`, which is designed to be held by Timelock in production.

The upgrade script deploys V2 and prints `upgradeToAndCall` calldata. That calldata can be submitted as a governance proposal. Direct upgrade execution is intentionally opt-in through `EXECUTE_DIRECT_UPGRADE=true` for local demos.

## Page 5: Frontend And Subgraph

The frontend is a dashboard, not a landing page. It connects to MetaMask through Wagmi's injected connector, detects whether the user is on Base Sepolia or Arbitrum Sepolia, and offers switch buttons for supported chains. It reads governance token balance, voting power, delegate, vault shares, vault total assets, AMM reserves, AMM token addresses, and proposal states.

Write actions are grouped by domain. The vault panel supports approve and deposit. The AMM panel supports approve and swap for either governance token or asset token. The governance panel supports delegation and voting. Errors are normalized into readable first-line messages, and transaction hashes are shown after submission.

The subgraph indexes event-derived protocol state. It tracks token holders, vault positions, swaps, liquidity events, proposals, and aggregate protocol stats. The frontend reads recent swaps and vault positions from the subgraph. The manifest can build without hard-coded addresses; production indexing should specialize it with deployed addresses and start blocks.

GraphQL queries are documented in `subgraph/queries.md`. They cover recent swaps, liquidity history, vault positions, governance proposals, and global protocol stats. The mapping uses event IDs from transaction hash and log index for immutable event entities, while position and holder entities are mutable account-level records.

## Page 6: Testing, Deployment, And Operational Model

The test suite is intentionally broad. Unit tests cover token, permit, votes, oracle, vault, AMM, factory, math benchmark, treasury upgrade, and governor behavior. Fuzz tests cover vault round trips, AMM liquidity and swaps, oracle normalization, math equivalence, deterministic deployment, and V2 fee bounds. Invariant tests check AMM reserve consistency, vault asset backing, LP reserve consistency, oracle freshness, and token cap safety. Fork tests are present for Base Sepolia and safely no-op when RPC env vars are not configured.

The vulnerability regression suite includes a vulnerable reentrancy vault and a fixed version, plus an unrestricted access-control example and a fixed AccessControl version. These contracts are excluded from Slither production scans because they intentionally contain the bugs being demonstrated. The tests prove the vulnerable behavior and the fixed behavior.

Deployment is staged:

1. Deploy token, mock asset, oracle feeds or mock feeds, vault, factory, Timelock, Governor, AMM pair, treasury implementation, and treasury proxy.
2. Grant Governor roles on Timelock.
3. Grant Timelock admin roles on production contracts.
4. Revoke deployer roles.
5. Write deployment JSON.
6. Run post-deploy checks.
7. Fill frontend and subgraph network config with deployed addresses.

Operationally, the protocol is governed by Timelock. Emergency pause, oracle feed updates, token minting, pair creation, and upgrades should all become governance actions. For a class final, this demonstrates the correct authority model without requiring a large DAO voter base.
