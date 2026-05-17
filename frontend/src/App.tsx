import { useMemo, useState } from "react";
import { Activity, ArrowRightLeft, Check, CircleAlert, Landmark, PlugZap, RefreshCcw, ShieldCheck, Vote, Wallet } from "lucide-react";
import { Address, formatUnits, parseUnits, zeroAddress } from "viem";
import {
  useAccount,
  useChainId,
  useConnect,
  useDisconnect,
  useReadContract,
  useSwitchChain,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";
import { ammAbi, erc20Abi, governanceTokenAbi, governorAbi, vaultAbi } from "./config/abis";
import { addresses, configured, proposalIds } from "./config/addresses";
import { supportedChains } from "./config/wagmi";
import { useSubgraph } from "./hooks/useSubgraph";

const proposalStates = ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"];

const shortAddress = (value?: string) => (value ? `${value.slice(0, 6)}...${value.slice(-4)}` : "0x0000...0000");

const display = (value?: bigint, decimals = 18, precision = 4) => {
  if (value === undefined) return "-";
  const formatted = formatUnits(value, decimals);
  const [whole, fraction = ""] = formatted.split(".");
  return fraction ? `${whole}.${fraction.slice(0, precision)}` : whole;
};

const readableError = (error: unknown) => {
  if (!error) return "";
  const message = error instanceof Error ? error.message : String(error);
  return message.split("\n")[0].replace("User rejected the request.", "Transaction rejected in wallet.");
};

function ProposalRow({ proposalId }: { proposalId: bigint }) {
  const state = useReadContract({
    address: configured(addresses.governor) ? addresses.governor : undefined,
    abi: governorAbi,
    functionName: "state",
    args: [proposalId],
    query: { enabled: configured(addresses.governor) },
  });

  const stateIndex = Number(state.data ?? 0);
  return (
    <div className="table-row">
      <span>{proposalId.toString()}</span>
      <span className="badge">{proposalStates[stateIndex] ?? "Unknown"}</span>
    </div>
  );
}

export function App() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { connect, connectors, isPending: isConnecting } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();
  const { writeContractAsync, data: hash, error: writeError, isPending } = useWriteContract();
  const receipt = useWaitForTransactionReceipt({ hash });
  const subgraph = useSubgraph();

  const [depositAmount, setDepositAmount] = useState("100");
  const [swapAmount, setSwapAmount] = useState("1");
  const [swapToken, setSwapToken] = useState<"gov" | "asset">("gov");
  const [delegatee, setDelegatee] = useState("");
  const [proposalId, setProposalId] = useState("");
  const [support, setSupport] = useState("1");
  const [localError, setLocalError] = useState("");

  const supported = supportedChains.some((chain) => chain.id === chainId);

  const govDecimals = useReadContract({
    address: configured(addresses.governanceToken) ? addresses.governanceToken : undefined,
    abi: erc20Abi,
    functionName: "decimals",
    query: { enabled: configured(addresses.governanceToken) },
  });

  const vaultAsset = useReadContract({
    address: configured(addresses.vault) ? addresses.vault : undefined,
    abi: vaultAbi,
    functionName: "asset",
    query: { enabled: configured(addresses.vault) },
  });

  const assetAddress = useMemo<Address>(() => {
    const fromVault = vaultAsset.data as Address | undefined;
    if (fromVault && fromVault !== zeroAddress) return fromVault;
    return addresses.assetToken;
  }, [vaultAsset.data]);

  const assetDecimals = useReadContract({
    address: configured(assetAddress) ? assetAddress : undefined,
    abi: erc20Abi,
    functionName: "decimals",
    query: { enabled: configured(assetAddress) },
  });

  const govBalance = useReadContract({
    address: configured(addresses.governanceToken) ? addresses.governanceToken : undefined,
    abi: governanceTokenAbi,
    functionName: "balanceOf",
    args: [address ?? zeroAddress],
    query: { enabled: isConnected && configured(addresses.governanceToken) },
  });

  const votingPower = useReadContract({
    address: configured(addresses.governanceToken) ? addresses.governanceToken : undefined,
    abi: governanceTokenAbi,
    functionName: "getVotes",
    args: [address ?? zeroAddress],
    query: { enabled: isConnected && configured(addresses.governanceToken) },
  });

  const delegatedTo = useReadContract({
    address: configured(addresses.governanceToken) ? addresses.governanceToken : undefined,
    abi: governanceTokenAbi,
    functionName: "delegates",
    args: [address ?? zeroAddress],
    query: { enabled: isConnected && configured(addresses.governanceToken) },
  });

  const assetBalance = useReadContract({
    address: configured(assetAddress) ? assetAddress : undefined,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address ?? zeroAddress],
    query: { enabled: isConnected && configured(assetAddress) },
  });

  const vaultShares = useReadContract({
    address: configured(addresses.vault) ? addresses.vault : undefined,
    abi: vaultAbi,
    functionName: "balanceOf",
    args: [address ?? zeroAddress],
    query: { enabled: isConnected && configured(addresses.vault) },
  });

  const vaultAssets = useReadContract({
    address: configured(addresses.vault) ? addresses.vault : undefined,
    abi: vaultAbi,
    functionName: "totalAssets",
    query: { enabled: configured(addresses.vault) },
  });

  const reserves = useReadContract({
    address: configured(addresses.amm) ? addresses.amm : undefined,
    abi: ammAbi,
    functionName: "getReserves",
    query: { enabled: configured(addresses.amm) },
  });

  const token0 = useReadContract({
    address: configured(addresses.amm) ? addresses.amm : undefined,
    abi: ammAbi,
    functionName: "token0",
    query: { enabled: configured(addresses.amm) },
  });

  const token1 = useReadContract({
    address: configured(addresses.amm) ? addresses.amm : undefined,
    abi: ammAbi,
    functionName: "token1",
    query: { enabled: configured(addresses.amm) },
  });

  const decimals = {
    gov: Number(govDecimals.data ?? 18),
    asset: Number(assetDecimals.data ?? 6),
  };

  const execute = async (action: () => Promise<unknown>) => {
    setLocalError("");
    try {
      await action();
    } catch (error) {
      setLocalError(readableError(error));
    }
  };

  const approveVault = () =>
    execute(() =>
      writeContractAsync({
        address: assetAddress,
        abi: erc20Abi,
        functionName: "approve",
        args: [addresses.vault, parseUnits(depositAmount || "0", decimals.asset)],
      }),
    );

  const depositVault = () =>
    execute(() =>
      writeContractAsync({
        address: addresses.vault,
        abi: vaultAbi,
        functionName: "deposit",
        args: [parseUnits(depositAmount || "0", decimals.asset), address ?? zeroAddress],
      }),
    );

  const approveAmm = () =>
    execute(() => {
      const tokenIn = swapToken === "gov" ? addresses.governanceToken : assetAddress;
      const unit = swapToken === "gov" ? decimals.gov : decimals.asset;
      return writeContractAsync({
        address: tokenIn,
        abi: erc20Abi,
        functionName: "approve",
        args: [addresses.amm, parseUnits(swapAmount || "0", unit)],
      });
    });

  const swap = () =>
    execute(() => {
      const tokenIn = swapToken === "gov" ? addresses.governanceToken : assetAddress;
      const unit = swapToken === "gov" ? decimals.gov : decimals.asset;
      return writeContractAsync({
        address: addresses.amm,
        abi: ammAbi,
        functionName: "swap",
        args: [tokenIn, parseUnits(swapAmount || "0", unit), 0n, address ?? zeroAddress],
      });
    });

  const delegate = () =>
    execute(() =>
      writeContractAsync({
        address: addresses.governanceToken,
        abi: governanceTokenAbi,
        functionName: "delegate",
        args: [((delegatee || address) ?? zeroAddress) as Address],
      }),
    );

  const voteOnProposal = () =>
    execute(() =>
      writeContractAsync({
        address: addresses.governor,
        abi: governorAbi,
        functionName: "castVote",
        args: [BigInt(proposalId || "0"), Number(support)],
      }),
    );

  const reserveData = reserves.data ?? [0n, 0n];
  const txMessage = receipt.isSuccess ? `Confirmed ${shortAddress(hash)}` : hash ? `Pending ${shortAddress(hash)}` : "";
  const connector = connectors[0];

  return (
    <main className="shell">
      <header className="topbar">
        <div className="brand">
          <div className="mark">D</div>
          <div>
            <h1>DeFi SuperApp Lite</h1>
            <p>Base Sepolia / Arbitrum Sepolia</p>
          </div>
        </div>
        <div className="wallet-zone">
          <span className={supported ? "status ok" : "status warn"}>
            {supported ? "Network ready" : `Unsupported chain ${chainId}`}
          </span>
          {isConnected ? (
            <button className="icon-button" title="Disconnect wallet" onClick={() => disconnect()}>
              <Wallet size={18} />
              {shortAddress(address)}
            </button>
          ) : (
            <button className="icon-button primary" title="Connect MetaMask" disabled={!connector || isConnecting} onClick={() => connect({ connector })}>
              <PlugZap size={18} />
              Connect
            </button>
          )}
        </div>
      </header>

      {!supported && (
        <section className="network-strip">
          {supportedChains.map((chain) => (
            <button key={chain.id} className="icon-button" onClick={() => switchChain({ chainId: chain.id })}>
              <RefreshCcw size={16} />
              {chain.name}
            </button>
          ))}
        </section>
      )}

      <section className="metrics-grid">
        <div className="metric">
          <span>DSG Balance</span>
          <strong>{display(govBalance.data, decimals.gov)}</strong>
        </div>
        <div className="metric">
          <span>Voting Power</span>
          <strong>{display(votingPower.data, decimals.gov)}</strong>
        </div>
        <div className="metric">
          <span>Vault Shares</span>
          <strong>{display(vaultShares.data, decimals.asset)}</strong>
        </div>
        <div className="metric">
          <span>Asset Balance</span>
          <strong>{display(assetBalance.data, decimals.asset)}</strong>
        </div>
      </section>

      <section className="grid">
        <article className="panel">
          <div className="panel-title">
            <Landmark size={20} />
            <h2>Vault</h2>
          </div>
          <div className="data-row">
            <span>Total Assets</span>
            <strong>{display(vaultAssets.data, decimals.asset)}</strong>
          </div>
          <label>
            Deposit
            <input value={depositAmount} onChange={(event) => setDepositAmount(event.target.value)} inputMode="decimal" />
          </label>
          <div className="actions">
            <button className="icon-button" disabled={!isConnected || isPending} onClick={approveVault} title="Approve vault">
              <ShieldCheck size={16} />
              Approve
            </button>
            <button className="icon-button primary" disabled={!isConnected || isPending} onClick={depositVault} title="Deposit to vault">
              <Check size={16} />
              Deposit
            </button>
          </div>
        </article>

        <article className="panel">
          <div className="panel-title">
            <ArrowRightLeft size={20} />
            <h2>AMM</h2>
          </div>
          <div className="data-row">
            <span>{shortAddress(token0.data)}</span>
            <strong>{display(reserveData[0], decimals.gov)}</strong>
          </div>
          <div className="data-row">
            <span>{shortAddress(token1.data)}</span>
            <strong>{display(reserveData[1], decimals.asset)}</strong>
          </div>
          <div className="segmented">
            <button className={swapToken === "gov" ? "selected" : ""} onClick={() => setSwapToken("gov")}>DSG</button>
            <button className={swapToken === "asset" ? "selected" : ""} onClick={() => setSwapToken("asset")}>Asset</button>
          </div>
          <label>
            Swap Amount
            <input value={swapAmount} onChange={(event) => setSwapAmount(event.target.value)} inputMode="decimal" />
          </label>
          <div className="actions">
            <button className="icon-button" disabled={!isConnected || isPending} onClick={approveAmm} title="Approve AMM">
              <ShieldCheck size={16} />
              Approve
            </button>
            <button className="icon-button primary" disabled={!isConnected || isPending} onClick={swap} title="Swap">
              <ArrowRightLeft size={16} />
              Swap
            </button>
          </div>
        </article>

        <article className="panel">
          <div className="panel-title">
            <Vote size={20} />
            <h2>Governance</h2>
          </div>
          <div className="data-row">
            <span>Delegate</span>
            <strong>{shortAddress(delegatedTo.data)}</strong>
          </div>
          <label>
            Delegatee
            <input value={delegatee} onChange={(event) => setDelegatee(event.target.value)} placeholder={address ?? zeroAddress} />
          </label>
          <button className="icon-button primary full" disabled={!isConnected || isPending} onClick={delegate} title="Delegate votes">
            <Vote size={16} />
            Delegate
          </button>
          <div className="vote-line">
            <input value={proposalId} onChange={(event) => setProposalId(event.target.value)} placeholder="Proposal ID" />
            <select value={support} onChange={(event) => setSupport(event.target.value)}>
              <option value="1">For</option>
              <option value="0">Against</option>
              <option value="2">Abstain</option>
            </select>
          </div>
          <button className="icon-button" disabled={!isConnected || isPending} onClick={voteOnProposal} title="Vote">
            <Check size={16} />
            Vote
          </button>
        </article>

        <article className="panel">
          <div className="panel-title">
            <Activity size={20} />
            <h2>Proposals</h2>
          </div>
          <div className="table">
            {proposalIds.length === 0 ? (
              <div className="empty">No proposal ids configured</div>
            ) : (
              proposalIds.map((id) => <ProposalRow key={id.toString()} proposalId={id} />)
            )}
          </div>
        </article>
      </section>

      <section className="panel wide">
        <div className="panel-title">
          <Activity size={20} />
          <h2>Subgraph Activity</h2>
        </div>
        {subgraph.loading && <div className="empty">Loading</div>}
        {subgraph.error && <div className="error-line"><CircleAlert size={16} />{subgraph.error}</div>}
        {!subgraph.loading && !subgraph.error && (
          <div className="activity-grid">
            <div>
              <h3>Recent Swaps</h3>
              {subgraph.swaps.length === 0 && <div className="empty">No swaps indexed</div>}
              {subgraph.swaps.map((swapItem) => (
                <div className="table-row" key={swapItem.id}>
                  <span>{shortAddress(swapItem.sender)}</span>
                  <strong>{swapItem.amountIn} to {swapItem.amountOut}</strong>
                </div>
              ))}
            </div>
            <div>
              <h3>Vault Positions</h3>
              {subgraph.vaultPositions.length === 0 && <div className="empty">No positions indexed</div>}
              {subgraph.vaultPositions.map((position) => (
                <div className="table-row" key={position.id}>
                  <span>{shortAddress(position.account)}</span>
                  <strong>{position.shares} shares</strong>
                </div>
              ))}
            </div>
          </div>
        )}
      </section>

      {(localError || writeError || txMessage) && (
        <footer className={localError || writeError ? "toast error" : "toast"}>
          {localError || readableError(writeError) || txMessage}
        </footer>
      )}
    </main>
  );
}
