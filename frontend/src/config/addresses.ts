import { Address, zeroAddress } from "viem";

const envAddress = (key: string): Address => {
  const value = import.meta.env[key] as string | undefined;
  return value && /^0x[a-fA-F0-9]{40}$/.test(value) ? (value as Address) : zeroAddress;
};

export const addresses = {
  governanceToken: envAddress("VITE_GOVERNANCE_TOKEN"),
  assetToken: envAddress("VITE_ASSET_TOKEN"),
  vault: envAddress("VITE_VAULT"),
  amm: envAddress("VITE_AMM"),
  governor: envAddress("VITE_GOVERNOR"),
  timelock: envAddress("VITE_TIMELOCK"),
  treasuryProxy: envAddress("VITE_TREASURY_PROXY"),
};

export const configured = (address: Address) => address !== zeroAddress;

export const proposalIds = ((import.meta.env.VITE_PROPOSAL_IDS as string | undefined) ?? "")
  .split(",")
  .map((id) => id.trim())
  .filter(Boolean)
  .map((id) => BigInt(id));

export const subgraphUrl =
  (import.meta.env.VITE_SUBGRAPH_URL as string | undefined) ??
  "http://localhost:8000/subgraphs/name/defi-superapp-lite";
