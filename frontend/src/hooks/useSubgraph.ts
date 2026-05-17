import { useEffect, useState } from "react";
import { subgraphUrl } from "../config/addresses";

type Swap = {
  id: string;
  sender: string;
  tokenIn: string;
  tokenOut: string;
  amountIn: string;
  amountOut: string;
  timestamp: string;
};

type VaultPosition = {
  id: string;
  account: string;
  shares: string;
  assets: string;
};

type SubgraphState = {
  swaps: Swap[];
  vaultPositions: VaultPosition[];
  loading: boolean;
  error: string | null;
};

const query = `
  query DashboardActivity {
    swaps(first: 5, orderBy: timestamp, orderDirection: desc) {
      id
      sender
      tokenIn
      tokenOut
      amountIn
      amountOut
      timestamp
    }
    vaultPositions(first: 5, orderBy: updatedAt, orderDirection: desc) {
      id
      account
      shares
      assets
    }
  }
`;

export function useSubgraph(): SubgraphState {
  const [state, setState] = useState<SubgraphState>({ swaps: [], vaultPositions: [], loading: true, error: null });

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const response = await fetch(subgraphUrl, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ query }),
        });
        const json = await response.json();
        if (cancelled) return;
        if (json.errors?.length) {
          setState({ swaps: [], vaultPositions: [], loading: false, error: json.errors[0].message });
          return;
        }
        setState({
          swaps: json.data?.swaps ?? [],
          vaultPositions: json.data?.vaultPositions ?? [],
          loading: false,
          error: null,
        });
      } catch (error) {
        if (!cancelled) {
          setState({ swaps: [], vaultPositions: [], loading: false, error: (error as Error).message });
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  return state;
}
