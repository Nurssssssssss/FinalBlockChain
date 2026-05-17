import { Address, BigInt, Bytes, ethereum } from "@graphprotocol/graph-ts";
import { Transfer, DelegateVotesChanged } from "../generated/GovernanceToken/GovernanceToken";
import { Deposit, RewardsAdded, Withdraw } from "../generated/YieldVault/YieldVault";
import { LiquidityAdded, LiquidityRemoved, Swap as SwapEvent } from "../generated/ConstantProductAMM/ConstantProductAMM";
import { ProposalCreated, VoteCast } from "../generated/DeFiGovernor/DeFiGovernor";
import { LiquidityEvent, Proposal, ProtocolStat, Swap, TokenHolder, VaultPosition } from "../generated/schema";

const ZERO = "0x0000000000000000000000000000000000000000";

function entityId(eventHash: Bytes, logIndex: BigInt): string {
  return eventHash.toHexString().concat("-").concat(logIndex.toString());
}

function safeMinus(a: BigInt, b: BigInt): BigInt {
  return a.gt(b) ? a.minus(b) : BigInt.zero();
}

function holder(account: Address, timestamp: BigInt): TokenHolder {
  let id = account.toHexString();
  let entity = TokenHolder.load(id);
  if (entity == null) {
    entity = new TokenHolder(id);
    entity.account = account;
    entity.balance = BigInt.zero();
    entity.votingPower = BigInt.zero();
  }
  entity.updatedAt = timestamp;
  return entity;
}

function position(account: Address, timestamp: BigInt): VaultPosition {
  let id = account.toHexString();
  let entity = VaultPosition.load(id);
  if (entity == null) {
    entity = new VaultPosition(id);
    entity.account = account;
    entity.shares = BigInt.zero();
    entity.assets = BigInt.zero();
  }
  entity.updatedAt = timestamp;
  return entity;
}

function stats(timestamp: BigInt): ProtocolStat {
  let entity = ProtocolStat.load("global");
  if (entity == null) {
    entity = new ProtocolStat("global");
    entity.totalSwaps = BigInt.zero();
    entity.totalVolumeIn = BigInt.zero();
    entity.totalLiquidityEvents = BigInt.zero();
    entity.totalVaultDeposits = BigInt.zero();
    entity.totalVaultWithdrawals = BigInt.zero();
    entity.totalRewards = BigInt.zero();
  }
  entity.updatedAt = timestamp;
  return entity;
}

export function handleTransfer(event: Transfer): void {
  if (event.params.from.toHexString() != ZERO) {
    let from = holder(event.params.from, event.block.timestamp);
    from.balance = safeMinus(from.balance, event.params.value);
    from.save();
  }
  if (event.params.to.toHexString() != ZERO) {
    let to = holder(event.params.to, event.block.timestamp);
    to.balance = to.balance.plus(event.params.value);
    to.save();
  }
}

export function handleDelegateVotesChanged(event: DelegateVotesChanged): void {
  let entity = holder(event.params.delegate, event.block.timestamp);
  entity.votingPower = event.params.newVotes;
  entity.save();
}

export function handleVaultDeposit(event: Deposit): void {
  let entity = position(event.params.owner, event.block.timestamp);
  entity.shares = entity.shares.plus(event.params.shares);
  entity.assets = entity.assets.plus(event.params.assets);
  entity.save();

  let protocol = stats(event.block.timestamp);
  protocol.totalVaultDeposits = protocol.totalVaultDeposits.plus(BigInt.fromI32(1));
  protocol.save();
}

export function handleVaultWithdraw(event: Withdraw): void {
  let entity = position(event.params.owner, event.block.timestamp);
  entity.shares = safeMinus(entity.shares, event.params.shares);
  entity.assets = safeMinus(entity.assets, event.params.assets);
  entity.save();

  let protocol = stats(event.block.timestamp);
  protocol.totalVaultWithdrawals = protocol.totalVaultWithdrawals.plus(BigInt.fromI32(1));
  protocol.save();
}

export function handleRewardsAdded(event: RewardsAdded): void {
  let protocol = stats(event.block.timestamp);
  protocol.totalRewards = protocol.totalRewards.plus(event.params.assets);
  protocol.save();
}

export function handleSwap(event: SwapEvent): void {
  let entity = new Swap(entityId(event.transaction.hash, event.logIndex));
  entity.sender = event.params.sender;
  entity.receiver = event.params.receiver;
  entity.tokenIn = event.params.tokenIn;
  entity.tokenOut = event.params.tokenOut;
  entity.amountIn = event.params.amountIn;
  entity.amountOut = event.params.amountOut;
  entity.transactionHash = event.transaction.hash;
  entity.timestamp = event.block.timestamp;
  entity.blockNumber = event.block.number;
  entity.save();

  let protocol = stats(event.block.timestamp);
  protocol.totalSwaps = protocol.totalSwaps.plus(BigInt.fromI32(1));
  protocol.totalVolumeIn = protocol.totalVolumeIn.plus(event.params.amountIn);
  protocol.save();
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  saveLiquidityEvent("ADD", event.params.provider, event.params.receiver, event.params.amount0, event.params.amount1, event.params.shares, event);
}

export function handleLiquidityRemoved(event: LiquidityRemoved): void {
  saveLiquidityEvent("REMOVE", event.params.provider, event.params.receiver, event.params.amount0, event.params.amount1, event.params.shares, event);
}

function saveLiquidityEvent(
  kind: string,
  provider: Address,
  receiver: Address,
  amount0: BigInt,
  amount1: BigInt,
  shares: BigInt,
  event: ethereum.Event,
): void {
  let entity = new LiquidityEvent(entityId(event.transaction.hash, event.logIndex));
  entity.kind = kind;
  entity.provider = provider;
  entity.receiver = receiver;
  entity.amount0 = amount0;
  entity.amount1 = amount1;
  entity.shares = shares;
  entity.transactionHash = event.transaction.hash;
  entity.timestamp = event.block.timestamp;
  entity.blockNumber = event.block.number;
  entity.save();

  let protocol = stats(event.block.timestamp);
  protocol.totalLiquidityEvents = protocol.totalLiquidityEvents.plus(BigInt.fromI32(1));
  protocol.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  let id = event.params.proposalId.toString();
  let entity = new Proposal(id);
  entity.proposalId = event.params.proposalId;
  entity.proposer = event.params.proposer;
  entity.description = event.params.description;
  entity.voteStart = event.params.voteStart;
  entity.voteEnd = event.params.voteEnd;
  entity.state = "CREATED";
  entity.forVotes = BigInt.zero();
  entity.againstVotes = BigInt.zero();
  entity.abstainVotes = BigInt.zero();
  entity.createdAt = event.block.timestamp;
  entity.updatedAt = event.block.timestamp;
  entity.save();
}

export function handleVoteCast(event: VoteCast): void {
  let id = event.params.proposalId.toString();
  let entity = Proposal.load(id);
  if (entity == null) return;

  if (event.params.support == 0) {
    entity.againstVotes = entity.againstVotes.plus(event.params.weight);
  } else if (event.params.support == 1) {
    entity.forVotes = entity.forVotes.plus(event.params.weight);
  } else {
    entity.abstainVotes = entity.abstainVotes.plus(event.params.weight);
  }
  entity.state = "VOTING";
  entity.updatedAt = event.block.timestamp;
  entity.save();
}
