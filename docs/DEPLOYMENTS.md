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
