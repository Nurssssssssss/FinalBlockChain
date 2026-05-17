# Gas Report

The project includes `MathBench` for direct comparison between a pure Solidity implementation and an inline Yul implementation. The test suite also prints per-test gas under `forge test -vv`.

## Commands

```bash
forge test --gas-report
forge snapshot
```

## Representative Local Gas

These values come from the latest local `forge test -vv` run in this workspace:

| Operation | Approx gas |
| --- | ---: |
| AMM add liquidity | 193,466 |
| AMM swap token0 to token1 | 241,073 |
| AMM swap token1 to token0 | 240,255 |
| AMM remove liquidity | 217,015 |
| Factory CREATE pair | 2,188,782 |
| Factory CREATE2 pair | 2,201,290 |
| Vault deposit | 101,999 |
| Vault redeem | 114,243 |
| Treasury upgrade to V2 | 987,074 |
| Permit approval | 114,102 |

## Notes

- Factory pair deployment is high because it deploys a full AMM plus an LP token.
- UUPS upgrade tests include deploying the V2 implementation and calling the proxy upgrade.
- AMM swaps include SafeERC20 transfer calls and reserve updates.
- `via_ir = true` is enabled to keep complex OpenZeppelin inheritance compilation stable with Solidity 0.8.35.
