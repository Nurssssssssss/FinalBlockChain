# Documented GraphQL Queries

Use these queries against `VITE_SUBGRAPH_URL` after the subgraph is deployed.

## 1. Recent swaps

```graphql
query RecentSwaps {
  swaps(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    sender
    receiver
    tokenIn
    tokenOut
    amountIn
    amountOut
    timestamp
  }
}
```

## 2. Liquidity history

```graphql
query LiquidityHistory {
  liquidityEvents(first: 20, orderBy: blockNumber, orderDirection: desc) {
    id
    kind
    provider
    amount0
    amount1
    shares
  }
}
```

## 3. Vault positions

```graphql
query VaultPositions {
  vaultPositions(first: 20, orderBy: assets, orderDirection: desc) {
    account
    shares
    assets
    updatedAt
  }
}
```

## 4. Governance proposals

```graphql
query GovernanceProposals {
  proposals(first: 10, orderBy: createdAt, orderDirection: desc) {
    proposalId
    proposer
    state
    forVotes
    againstVotes
    abstainVotes
    description
  }
}
```

## 5. Protocol aggregate stats

```graphql
query ProtocolStats {
  protocolStat(id: "global") {
    totalSwaps
    totalVolumeIn
    totalLiquidityEvents
    totalVaultDeposits
    totalVaultWithdrawals
    totalRewards
    updatedAt
  }
}
```
