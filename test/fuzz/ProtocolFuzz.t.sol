// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { ProtocolFixture } from "../fixtures/ProtocolFixture.sol";
import { UpgradeableTreasuryV2 } from "../../contracts/UpgradeableTreasuryV2.sol";

contract ProtocolFuzzTest is ProtocolFixture {
    function testFuzzVaultDepositWithdraw(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e6);
        vm.startPrank(alice);
        uint256 shares = vault.deposit(amount, alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertEq(assets, amount);
    }

    function testFuzzAmmInitialLiquidity(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 1e9, 10_000e18);
        amount1 = bound(amount1, 1e3, 5_000_000e6);
        uint256 shares = _seedLiquidity(amount0, amount1);
        assertGt(shares, 0);
    }

    function testFuzzAmmSwapGovForAsset(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e12, 100e18);
        _seedLiquidity(1000e18, 3_500_000e6);
        vm.prank(bob);
        uint256 out = amm.swap(address(govToken), amountIn, 1, bob);
        assertGt(out, 0);
    }

    function testFuzzAmmSwapAssetForGov(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e3, 250_000e6);
        _seedLiquidity(1000e18, 3_500_000e6);
        vm.prank(bob);
        uint256 out = amm.swap(address(asset), amountIn, 1, bob);
        assertGt(out, 0);
    }

    function testFuzzAmmRemoveLiquidity(uint256 numerator) public {
        uint256 shares = _seedLiquidity(1000e18, 3_500_000e6);
        numerator = bound(numerator, 1, 1000);
        uint256 burnShares = (shares * numerator) / 1000;
        vm.prank(alice);
        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(burnShares, 1, 1, alice);
        assertGt(amount0, 0);
        assertGt(amount1, 0);
    }

    function testFuzzOracleNormalization(uint256 answer) public {
        answer = bound(answer, 1, 1_000_000e8);
        ethFeed.updateAnswer(int256(answer));
        assertEq(ethOracle.normalizedPrice(), answer * 1e10);
    }

    function testFuzzMathMulDivEquivalent(uint256 x, uint256 y, uint256 denominator) public view {
        x = bound(x, 0, type(uint128).max);
        y = bound(y, 0, type(uint128).max);
        denominator = bound(denominator, 1, type(uint128).max);
        assertEq(mathBench.mulDivSolidity(x, y, denominator), mathBench.mulDivYul(x, y, denominator));
    }

    function testFuzzMathSumEquivalent(uint128 a, uint128 b, uint128 c) public view {
        uint256[] memory values = new uint256[](3);
        values[0] = a;
        values[1] = b;
        values[2] = c;
        assertEq(mathBench.sumSolidity(values), mathBench.sumYul(values));
    }

    function testFuzzFactoryCreate2Prediction(bytes32 salt) public {
        address predicted = factory.predictDeterministicAddress(
            address(weth),
            address(secondAsset),
            address(ethOracle),
            address(usdOracle),
            admin,
            "WETH-mEUR LP",
            "WME",
            salt
        );
        address pair = factory.createPairDeterministic(
            address(weth),
            address(secondAsset),
            address(ethOracle),
            address(usdOracle),
            admin,
            "WETH-mEUR LP",
            "WME",
            salt
        );
        assertEq(pair, predicted);
    }

    function testFuzzTreasuryV2Fee(uint256 feeBps) public {
        feeBps = bound(feeBps, 0, 1000);
        UpgradeableTreasuryV2 impl = new UpgradeableTreasuryV2();
        treasury.upgradeToAndCall(address(impl), "");
        UpgradeableTreasuryV2(payable(address(treasury))).setProtocolFeeBps(feeBps);
        assertEq(UpgradeableTreasuryV2(payable(address(treasury))).protocolFeeBps(), feeBps);
    }
}
