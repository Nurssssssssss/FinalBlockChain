import { parseAbi } from "viem";

const erc20AbiLines = [
  "function balanceOf(address account) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
] as const;

export const erc20Abi = parseAbi(erc20AbiLines);

export const governanceTokenAbi = parseAbi([
  ...erc20AbiLines,
  "function delegate(address delegatee)",
  "function delegates(address account) view returns (address)",
  "function getVotes(address account) view returns (uint256)",
] as const);

export const vaultAbi = parseAbi([
  ...erc20AbiLines,
  "function asset() view returns (address)",
  "function totalAssets() view returns (uint256)",
  "function convertToAssets(uint256 shares) view returns (uint256)",
  "function deposit(uint256 assets, address receiver) returns (uint256 shares)",
  "function redeem(uint256 shares, address receiver, address owner) returns (uint256 assets)",
] as const);

export const ammAbi = parseAbi([
  "function token0() view returns (address)",
  "function token1() view returns (address)",
  "function lpToken() view returns (address)",
  "function getReserves() view returns (uint112 reserve0, uint112 reserve1)",
  "function quoteSwap(address tokenIn, uint256 amountIn) view returns (uint256 amountOut)",
  "function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address receiver) returns (uint256 amountOut)",
]);

export const governorAbi = parseAbi([
  "function name() view returns (string)",
  "function state(uint256 proposalId) view returns (uint8)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
]);
