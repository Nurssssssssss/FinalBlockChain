// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { ProtocolFixture } from "../fixtures/ProtocolFixture.sol";
import { GovernanceToken } from "../../contracts/GovernanceToken.sol";
import { YieldVault } from "../../contracts/YieldVault.sol";
import { ConstantProductAMM } from "../../contracts/ConstantProductAMM.sol";
import { MockERC20 } from "../../contracts/mocks/MockERC20.sol";

contract ProtocolHandler {
    GovernanceToken internal govToken;
    MockERC20 internal asset;
    YieldVault internal vault;
    ConstantProductAMM internal amm;

    constructor(GovernanceToken govToken_, MockERC20 asset_, YieldVault vault_, ConstantProductAMM amm_) {
        govToken = govToken_;
        asset = asset_;
        vault = vault_;
        amm = amm_;
        govToken.approve(address(amm), type(uint256).max);
        asset.approve(address(amm), type(uint256).max);
        asset.approve(address(vault), type(uint256).max);
    }

    function depositVault(uint256 amount) external {
        amount = _bound(amount, 1, 100_000e6);
        if (asset.balanceOf(address(this)) >= amount) {
            vault.deposit(amount, address(this));
        }
    }

    function redeemVault(uint256 amount) external {
        uint256 shares = vault.balanceOf(address(this));
        if (shares == 0) return;
        amount = _bound(amount, 1, shares);
        vault.redeem(amount, address(this), address(this));
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external {
        amount0 = _bound(amount0, 1e12, 500e18);
        amount1 = _bound(amount1, 1e3, 1_750_000e6);
        if (govToken.balanceOf(address(this)) >= amount0 && asset.balanceOf(address(this)) >= amount1) {
            try amm.addLiquidity(amount0, amount1, 0, address(this)) { } catch { }
        }
    }

    function swapGovForAsset(uint256 amountIn) external {
        amountIn = _bound(amountIn, 1e12, 50e18);
        if (govToken.balanceOf(address(this)) >= amountIn) {
            try amm.swap(address(govToken), amountIn, 0, address(this)) { } catch { }
        }
    }

    function swapAssetForGov(uint256 amountIn) external {
        amountIn = _bound(amountIn, 1e3, 50_000e6);
        if (asset.balanceOf(address(this)) >= amountIn) {
            try amm.swap(address(asset), amountIn, 0, address(this)) { } catch { }
        }
    }

    function _bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        return min + (x % (max - min + 1));
    }
}

contract ProtocolInvariantTest is ProtocolFixture {
    ProtocolHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new ProtocolHandler(govToken, asset, vault, amm);
        govToken.mint(address(handler), 50_000e18);
        asset.mint(address(handler), 200_000_000e6);
        targetContract(address(handler));
    }

    function invariant_AMMReservesMatchBalances() public view {
        (uint112 r0, uint112 r1) = amm.getReserves();
        assertEq(uint256(r0), govToken.balanceOf(address(amm)));
        assertEq(uint256(r1), asset.balanceOf(address(amm)));
    }

    function invariant_VaultTotalAssetsMatchBalance() public view {
        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)));
    }

    function invariant_LpSupplyImpliesReserves() public view {
        uint256 supply = amm.lpToken().totalSupply();
        (uint112 r0, uint112 r1) = amm.getReserves();
        if (supply == 0) {
            assertEq(r0, 0);
            assertEq(r1, 0);
        } else {
            assertGt(r0, 0);
            assertGt(r1, 0);
        }
    }

    function invariant_OraclePriceIsFreshAndPositive() public view {
        assertGt(ethOracle.normalizedPrice(), 0);
        assertGt(usdOracle.normalizedPrice(), 0);
    }

    function invariant_GovernanceTokenNeverExceedsCap() public view {
        assertLe(govToken.totalSupply(), govToken.cap());
    }
}
