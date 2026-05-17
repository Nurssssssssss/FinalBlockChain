import { http, createConfig } from "wagmi";
import { injected } from "wagmi/connectors";
import { arbitrumSepolia, baseSepolia } from "wagmi/chains";

const rpcUrl = import.meta.env.VITE_RPC_URL as string | undefined;

export const wagmiConfig = createConfig({
  chains: [baseSepolia, arbitrumSepolia],
  connectors: [injected({ target: "metaMask" })],
  transports: {
    [baseSepolia.id]: http(rpcUrl || "https://sepolia.base.org"),
    [arbitrumSepolia.id]: http(rpcUrl || "https://sepolia-rollup.arbitrum.io/rpc"),
  },
});

export const supportedChains = [baseSepolia, arbitrumSepolia];
