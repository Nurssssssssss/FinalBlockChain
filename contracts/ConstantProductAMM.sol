// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { LPToken } from "./LPToken.sol";

contract ConstantProductAMM is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant SWAP_FEE_BPS = 3; // 0.3%

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    IPriceOracle public immutable oracle0;
    IPriceOracle public immutable oracle1;
    LPToken public immutable lpToken;

    uint112 private reserve0;
    uint112 private reserve1;

    error IdenticalTokens();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error SlippageExceeded(uint256 actual, uint256 minimum);
    error InvalidTokenIn();
    error ReserveOverflow();

    event LiquidityAdded(
        address indexed provider, address indexed receiver, uint256 amount0, uint256 amount1, uint256 shares
    );
    event LiquidityRemoved(
        address indexed provider, address indexed receiver, uint256 amount0, uint256 amount1, uint256 shares
    );
    event Swap(
        address indexed sender,
        address indexed receiver,
        address indexed tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut
    );
    event ReservesSynced(uint112 reserve0, uint112 reserve1);

    constructor(
        address token0_,
        address token1_,
        address oracle0_,
        address oracle1_,
        address admin,
        string memory lpName,
        string memory lpSymbol
    ) {
        if (token0_ == token1_) revert IdenticalTokens();
        if (token0_ == address(0) || token1_ == address(0) || oracle0_ == address(0) || oracle1_ == address(0)) {
            revert ZeroAddress();
        }
        if (admin == address(0)) revert ZeroAddress();

        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        oracle0 = IPriceOracle(oracle0_);
        oracle1 = IPriceOracle(oracle1_);
        lpToken = new LPToken(lpName, lpSymbol, address(this), admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function getReserves() public view returns (uint112 reserve0_, uint112 reserve1_) {
        return (reserve0, reserve1);
    }

    function addLiquidity(uint256 amount0Desired, uint256 amount1Desired, uint256 minShares, address receiver)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1, uint256 shares)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (amount0Desired == 0 || amount1Desired == 0) revert ZeroAmount();

        uint112 reserve0_ = reserve0;
        uint112 reserve1_ = reserve1;
        uint256 supply = lpToken.totalSupply();

        if (supply == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            if (reserve0_ == 0 || reserve1_ == 0) revert InsufficientLiquidity();
            uint256 amount1Optimal = (amount0Desired * reserve1_) / reserve0_;
            if (amount1Optimal <= amount1Desired) {
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0_) / reserve1_;
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }

        if (amount0 == 0 || amount1 == 0) revert ZeroAmount();

        uint256 balance0Before = token0.balanceOf(address(this));
        uint256 balance1Before = token1.balanceOf(address(this));
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);
        amount0 = token0.balanceOf(address(this)) - balance0Before;
        amount1 = token1.balanceOf(address(this)) - balance1Before;

        if (supply == 0) {
            shares = _sqrt(amount0 * amount1);
        } else {
            shares = _min((amount0 * supply) / reserve0_, (amount1 * supply) / reserve1_);
        }
        if (shares == 0) revert InsufficientLiquidity();
        if (shares < minShares) revert SlippageExceeded(shares, minShares);

        _updateReserves(uint256(reserve0_) + amount0, uint256(reserve1_) + amount1);
        lpToken.mint(receiver, shares);
        emit LiquidityAdded(msg.sender, receiver, amount0, amount1, shares);
    }

    function removeLiquidity(uint256 shares, uint256 minAmount0, uint256 minAmount1, address receiver)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();

        uint256 supply = lpToken.totalSupply();
        if (supply == 0) revert InsufficientLiquidity();

        uint112 reserve0_ = reserve0;
        uint112 reserve1_ = reserve1;
        amount0 = (uint256(reserve0_) * shares) / supply;
        amount1 = (uint256(reserve1_) * shares) / supply;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();
        if (amount0 < minAmount0) revert SlippageExceeded(amount0, minAmount0);
        if (amount1 < minAmount1) revert SlippageExceeded(amount1, minAmount1);

        _updateReserves(uint256(reserve0_) - amount0, uint256(reserve1_) - amount1);
        lpToken.burn(msg.sender, shares);
        token0.safeTransfer(receiver, amount0);
        token1.safeTransfer(receiver, amount1);

        emit LiquidityRemoved(msg.sender, receiver, amount0, amount1, shares);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address receiver)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();
        if (reserve0 == 0 || reserve1 == 0) revert InsufficientLiquidity();

        bool zeroForOne = false;
        if (tokenIn == address(token0)) {
            zeroForOne = true;
        } else if (tokenIn == address(token1)) {
            zeroForOne = false;
        } else {
            revert InvalidTokenIn();
        }

        (IERC20 inputToken, IERC20 outputToken, uint112 reserveIn, uint112 reserveOut) =
            zeroForOne ? (token0, token1, reserve0, reserve1) : (token1, token0, reserve1, reserve0);

        uint256 balanceBefore = inputToken.balanceOf(address(this));
        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 actualAmountIn = inputToken.balanceOf(address(this)) - balanceBefore;

        amountOut = quoteSwap(tokenIn, actualAmountIn);
        if (amountOut == 0 || amountOut >= reserveOut) revert InsufficientOutputAmount();
        if (amountOut < minAmountOut) revert SlippageExceeded(amountOut, minAmountOut);

        if (zeroForOne) {
            _updateReserves(uint256(reserveIn) + actualAmountIn, uint256(reserveOut) - amountOut);
        } else {
            _updateReserves(uint256(reserveOut) - amountOut, uint256(reserveIn) + actualAmountIn);
        }

        outputToken.safeTransfer(receiver, amountOut);
        emit Swap(msg.sender, receiver, tokenIn, actualAmountIn, address(outputToken), amountOut);
    }

    function quoteSwap(address tokenIn, uint256 amountIn) public view returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        uint256 reserveIn = 0;
        uint256 reserveOut = 0;
        if (tokenIn == address(token0)) {
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else if (tokenIn == address(token1)) {
            reserveIn = reserve1;
            reserveOut = reserve0;
        } else {
            revert InvalidTokenIn();
        }
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - SWAP_FEE_BPS);
        return (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    function oraclePriceToken0InToken1() external view returns (uint256 priceE18) {
        uint256 p0 = oracle0.normalizedPrice();
        uint256 p1 = oracle1.normalizedPrice();
        return (p0 * 1e18) / p1;
    }

    function sync() external nonReentrant {
        _updateReserves(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
        emit ReservesSynced(reserve0, reserve1);
    }

    function _updateReserves(uint256 balance0, uint256 balance1) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert ReserveOverflow();
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y == 0) return 0;
        if (y <= 3) return 1;
        z = y;
        uint256 x = y / 2 + 1;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }
}
