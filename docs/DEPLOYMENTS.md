# Deployments

No public L2 deployment has been broadcast from this local workspace yet. The deploy script is ready for Base Sepolia or Arbitrum Sepolia and writes `deployments/<chainId>.json` after a successful broadcast.

## Required Inputs

Fill these values in `.env` before deployment:

| Variable | Purpose |
| --- | --- |
| `PRIVATE_KEY` | Broadcaster key |
| `BASE_SEPOLIA_RPC_URL` | Base Sepolia RPC |
| `ARBITRUM_SEPOLIA_RPC_URL` | Arbitrum Sepolia RPC |
| `ETH_USD_FEED` | Chainlink-compatible ETH/USD feed |
| `ASSET_USD_FEED` | Chainlink-compatible asset/USD feed |
| `BASESCAN_API_KEY` | Optional Base verification |
| `ARBISCAN_API_KEY` | Optional Arbitrum verification |

If `ETH_USD_FEED` or `ASSET_USD_FEED` is zero, deployment uses mock feeds. For final submission, use real feed addresses and record them below.

## Base Sepolia

| Contract | Address |
| --- | --- |
| GovernanceToken | Fill from `deployments/84532.json` |
| AssetToken | Fill from `deployments/84532.json` |
| EthOracle | Fill from `deployments/84532.json` |
| AssetOracle | Fill from `deployments/84532.json` |
| YieldVault | Fill from `deployments/84532.json` |
| PoolFactory | Fill from `deployments/84532.json` |
| ConstantProductAMM | Fill from `deployments/84532.json` |
| LPToken | Fill from `deployments/84532.json` |
| TimelockController | Fill from `deployments/84532.json` |
| DeFiGovernor | Fill from `deployments/84532.json` |
| TreasuryProxy | Fill from `deployments/84532.json` |
| TreasuryImplementationV1 | Fill from `deployments/84532.json` |

## Arbitrum Sepolia

| Contract | Address |
| --- | --- |
| GovernanceToken | Fill from deployment JSON |
| AssetToken | Fill from deployment JSON |
| EthOracle | Fill from deployment JSON |
| AssetOracle | Fill from deployment JSON |
| YieldVault | Fill from deployment JSON |
| PoolFactory | Fill from deployment JSON |
| ConstantProductAMM | Fill from deployment JSON |
| LPToken | Fill from deployment JSON |
| TimelockController | Fill from deployment JSON |
| DeFiGovernor | Fill from deployment JSON |
| TreasuryProxy | Fill from deployment JSON |
| TreasuryImplementationV1 | Fill from deployment JSON |

## Post-Deployment Actions

1. Run `script/PostDeployCheck.s.sol`.
2. Verify contracts on the explorer.
3. Copy addresses to `frontend/.env`.
4. Add `source.address` and `startBlock` to `subgraph/subgraph.yaml` for production indexing.
5. Deploy the subgraph.
6. Create a first governance proposal and add its id to `VITE_PROPOSAL_IDS`.
7. Record explorer links in this file.


Вот готовый текст для `docs/DEPLOYMENTS.md`. Просто вставь в конец файла:

````markdown
## Current Deployment Status

The project has been tested locally and the deployment script is ready for Base Sepolia.

### Local Verification

The following checks were completed successfully:

| Check | Result |
| --- | --- |
| `forge build` | Passed |
| `forge test -vv` | 88 tests passed, 0 failed, 0 skipped |
| Frontend local run | Passed |
| MetaMask connection | Passed |
| Deployment script simulation | Passed |
| Public L2 broadcast | Not completed due to insufficient Base Sepolia test ETH |

### Deployment Simulation

The deployment script `script/Deploy.s.sol` was executed against the Base Sepolia RPC endpoint:

```bash
forge script script/Deploy.s.sol --rpc-url https://sepolia.base.org
````

The script compiled successfully and produced a valid simulated deployment output for the protocol contracts, including:

* GovernanceToken
* AssetToken
* YieldVault
* ConstantProductAMM
* LPToken
* TimelockController
* DeFiGovernor
* TreasuryProxy

This confirms that the deployment script is executable and that the contract dependency graph can be deployed in the expected order.

### Broadcast Attempt

A public broadcast deployment was attempted with:

```bash
forge script script/Deploy.s.sol --rpc-url https://sepolia.base.org --broadcast
```

The broadcast did not complete because the deployer wallet did not have enough Base Sepolia ETH to pay the maximum transaction fee.

Error summary:

```text
transaction validation error: lack of funds for max fee
```

This was an external testnet funding limitation, not a Solidity compilation or test failure.

### Notes

The simulated addresses printed by the deployment script were not recorded as final deployed addresses because the broadcast transaction did not complete on-chain.

To finish public deployment, the deployer wallet must be funded with additional Base Sepolia ETH. After funding, rerun:

```bash
forge script script/Deploy.s.sol --rpc-url https://sepolia.base.org --broadcast
```

After a successful broadcast, the generated `deployments/84532.json` file should be used to update:

* `docs/DEPLOYMENTS.md`
* `frontend/.env`
* `subgraph/subgraph.yaml`

```
```
