# DeFi SuperApp Lite

Full-stack Web3 final project for Blockchain Technologies 2. The repo contains a compact but complete DeFi protocol:

- ERC20Votes + ERC20Permit governance token
- ERC4626 yield vault
- constant product AMM with 0.3% LP fee
- LP token
- Chainlink-style price feed wrapper with staleness checks
- OpenZeppelin Governor + TimelockController
- UUPS upgradeable treasury with V1 to V2 path
- Factory with CREATE and CREATE2 pair deployment
- Inline Yul and equivalent Solidity benchmark functions
- Foundry tests, fuzzing, invariants, fork tests, Slither config, GitHub Actions
- React + Vite + Wagmi/Viem frontend
- The Graph subgraph
- Audit, architecture, gas, coverage, and deployment docs

## Repository Layout

```text
contracts/      Solidity contracts, mocks, and vulnerability examples
script/         Deploy, post-deploy check, and UUPS upgrade scripts
test/           Unit, fuzz, invariant, fork, and vulnerability regression tests
frontend/       React/Vite/Wagmi app
subgraph/       The Graph manifest, schema, mappings, ABIs, and queries
docs/           Architecture, audit, gas, coverage, deployments
config/         Example environment configuration
.github/        CI workflow
```

## Prerequisites

- Foundry `forge 1.7+`
- Node.js 20 for CI parity. Node 18 can build the current frontend and downgraded subgraph CLI locally, but Node 20 is the clean target.
- npm
- Optional: Slither via `pipx install slither-analyzer`

## Install

```bash
npm install
npm --prefix frontend install
npm --prefix subgraph install
```

## Test And Build

```bash
forge fmt --check
forge build
forge test -vv
forge coverage --report summary --report lcov
slither . --config-file slither.config.json --exclude divide-before-multiply,incorrect-equality
npm --prefix frontend run lint
npm --prefix frontend run build
npm --prefix subgraph run codegen
npm --prefix subgraph run build
```

Current local result: `forge test -vv` passes `88` tests.

## Local Deployment

Use Anvil:

```bash
anvil
```

In another terminal:

```bash
cp config/example.env .env
source .env
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

The deploy script writes `deployments/<chainId>.json`.

## L2 Testnet Deployment

Base Sepolia:

```bash
cp config/example.env .env
source .env
export ETH_USD_FEED=$BASE_SEPOLIA_ETH_USD_FEED
export ASSET_USD_FEED=$BASE_SEPOLIA_USDC_USD_FEED
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$BASESCAN_API_KEY"
```

Arbitrum Sepolia:

```bash
source .env
export ETH_USD_FEED=$ARBITRUM_SEPOLIA_ETH_USD_FEED
export ASSET_USD_FEED=$ARBITRUM_SEPOLIA_USDC_USD_FEED
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$ARBITRUM_SEPOLIA_RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ARBISCAN_API_KEY"
```

If feed env vars are zero, the deploy script uses mock feeds. For a real L2 submission, set Chainlink feed addresses explicitly.

## Post-Deploy Check

```bash
source .env
export GOVERNANCE_TOKEN=<deployed token>
export VAULT=<deployed vault>
export AMM=<deployed amm>
export GOVERNOR=<deployed governor>
export PRICE_ORACLE=<deployed oracle>
export TREASURY_PROXY=<deployed treasury proxy>
forge script script/PostDeployCheck.s.sol:PostDeployCheck --rpc-url "$BASE_SEPOLIA_RPC_URL"
```

## Upgrade Path

```bash
source .env
export TREASURY_PROXY=<deployed treasury proxy>
forge script script/UpgradeTreasury.s.sol:UpgradeTreasury --rpc-url "$BASE_SEPOLIA_RPC_URL" --broadcast
```

By default, the script deploys V2 and prints calldata for Governor/Timelock execution. Direct execution is available only when the broadcaster has `UPGRADER_ROLE`:

```bash
export EXECUTE_DIRECT_UPGRADE=true
```

## Frontend

Fill frontend env values after deployment:

```bash
cp config/example.env frontend/.env
npm --prefix frontend run dev
```

The app supports MetaMask, network detection, balances, voting power, delegation, AMM reserves, vault shares, deposits, swaps, voting, proposal states, and subgraph activity.

## Subgraph

```bash
npm --prefix subgraph run codegen
npm --prefix subgraph run build
```

The manifest omits fixed source addresses so it can build before deployment and can be specialized later for a deployed network. For hosted production indexing, add deployed `source.address` values and an appropriate `startBlock`.

Documented queries are in `subgraph/queries.md`.

## Security Posture

- No `tx.origin`
- No `transfer` or `send`
- No timestamp randomness
- ERC20 transfers use `SafeERC20`
- Admin authority is designed to move to Timelock/Governor
- Slither excludes intentionally vulnerable examples and checks production contracts for zero High and zero Medium findings
- Reentrancy and access-control vulnerabilities are reproduced and fixed in dedicated contracts and tests

See `docs/AUDIT.md` for the full security write-up.
