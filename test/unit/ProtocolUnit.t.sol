// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ProtocolFixture } from "../fixtures/ProtocolFixture.sol";
import { ConstantProductAMM } from "../../contracts/ConstantProductAMM.sol";
import { PoolFactory } from "../../contracts/PoolFactory.sol";
import { PriceFeedOracle } from "../../contracts/PriceFeedOracle.sol";
import { YieldVault } from "../../contracts/YieldVault.sol";
import { GovernanceToken } from "../../contracts/GovernanceToken.sol";
import { UpgradeableTreasuryV2 } from "../../contracts/UpgradeableTreasuryV2.sol";
import { MockAggregatorV3 } from "../../contracts/mocks/MockAggregatorV3.sol";
import { MockERC20 } from "../../contracts/mocks/MockERC20.sol";

contract ProtocolUnitTest is ProtocolFixture {
    function testTokenMetadata() public view {
        assertEq(govToken.name(), "DeFi SuperApp Governance");
        assertEq(govToken.symbol(), "DSG");
        assertEq(govToken.decimals(), 18);
        assertEq(govToken.cap(), GOV_CAP);
    }

    function testTokenInitialSupply() public view {
        assertEq(govToken.totalSupply(), GOV_INITIAL_SUPPLY + 3_000_000e18);
        assertEq(govToken.balanceOf(admin), GOV_INITIAL_SUPPLY);
    }

    function testTokenMintByMinter() public {
        govToken.mint(bob, 10e18);
        assertEq(govToken.balanceOf(bob), 1_000_010e18);
    }

    function testTokenMintRevertsForNonMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        govToken.mint(alice, 1);
    }

    function testTokenMintRevertsAboveCap() public {
        uint256 amount = GOV_CAP + 1 - govToken.totalSupply();
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.CapExceeded.selector, GOV_CAP + 1, GOV_CAP));
        govToken.mint(alice, amount);
    }

    function testPermitApprovesSpender() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        govToken.mint(owner, 100e18);
        uint256 value = 25e18;
        uint256 deadline = block.timestamp + 1 days;
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, owner, bob, value, govToken.nonces(owner), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        govToken.permit(owner, bob, value, deadline, v, r, s);
        assertEq(govToken.allowance(owner, bob), value);
    }

    function testVotesIncreaseAfterDelegation() public {
        vm.roll(block.number + 1);
        assertEq(govToken.getVotes(alice), govToken.balanceOf(alice));
    }

    function testVotesMoveOnTransfer() public {
        vm.prank(alice);
        govToken.transfer(bob, 10e18);
        assertEq(govToken.getVotes(alice), 999_990e18);
        assertEq(govToken.getVotes(bob), 1_000_010e18);
    }

    function testNoncesStartAtZero() public view {
        assertEq(govToken.nonces(alice), 0);
    }

    function testOracleLatestPrice() public view {
        (uint256 price, uint8 decimals_, uint256 updatedAt) = ethOracle.latestPrice();
        assertEq(price, 3500e8);
        assertEq(decimals_, 8);
        assertEq(updatedAt, block.timestamp);
    }

    function testOracleNormalizedPrice() public view {
        assertEq(ethOracle.normalizedPrice(), 3500e18);
    }

    function testOracleRevertsWhenStale() public {
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert();
        ethOracle.latestPrice();
    }

    function testOracleRevertsOnInvalidPrice() public {
        ethFeed.updateAnswer(0);
        vm.expectRevert(PriceFeedOracle.InvalidPrice.selector);
        ethOracle.latestPrice();
    }

    function testOracleRevertsOnIncompleteRound() public {
        ethFeed.setAnsweredInRound(0);
        vm.expectRevert();
        ethOracle.latestPrice();
    }

    function testOracleManagerCanUpdateFeed() public {
        MockAggregatorV3 newFeed = new MockAggregatorV3(8, 4000e8);
        ethOracle.setFeed(address(newFeed));
        assertEq(address(ethOracle.feed()), address(newFeed));
    }

    function testOracleUpdateFeedRevertsForNonManager() public {
        MockAggregatorV3 newFeed = new MockAggregatorV3(8, 4000e8);
        vm.prank(alice);
        vm.expectRevert();
        ethOracle.setFeed(address(newFeed));
    }

    function testOracleManagerCanUpdateStaleness() public {
        ethOracle.setStaleAfter(2 days);
        assertEq(ethOracle.staleAfter(), 2 days);
    }

    function testOracleZeroStaleAfterReverts() public {
        vm.expectRevert(PriceFeedOracle.InvalidStaleAfter.selector);
        ethOracle.setStaleAfter(0);
    }

    function testVaultMetadataAndAsset() public view {
        assertEq(vault.name(), "DeFi SuperApp Vault Share");
        assertEq(vault.symbol(), "dsvASSET");
        assertEq(vault.asset(), address(asset));
    }

    function testVaultDepositMintsShares() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1000e6, alice);
        assertEq(shares, 1000e6);
        assertEq(vault.balanceOf(alice), 1000e6);
    }

    function testVaultWithdrawReturnsAssets() public {
        vm.startPrank(alice);
        vault.deposit(1000e6, alice);
        vault.withdraw(400e6, alice, alice);
        vm.stopPrank();
        assertEq(vault.balanceOf(alice), 600e6);
    }

    function testVaultRewardsIncreaseSharePrice() public {
        vm.prank(alice);
        vault.deposit(1000e6, alice);
        asset.mint(admin, 100e6);
        asset.approve(address(vault), 100e6);
        vault.addRewards(100e6);
        assertGt(vault.convertToAssets(1000e6), 1000e6);
    }

    function testVaultPauseBlocksDeposit() public {
        vault.pause();
        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1e6, alice);
    }

    function testVaultUnpauseAllowsDeposit() public {
        vault.pause();
        vault.unpause();
        vm.prank(alice);
        uint256 shares = vault.deposit(1e6, alice);
        assertEq(shares, 1e6);
    }

    function testVaultAddRewardsRevertsForNonManager() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.addRewards(1e6);
    }

    function testVaultRedeemBurnsShares() public {
        vm.startPrank(alice);
        vault.deposit(1000e6, alice);
        vault.redeem(500e6, alice, alice);
        vm.stopPrank();
        assertEq(vault.balanceOf(alice), 500e6);
    }

    function testVaultMintUsesUnderlying() public {
        vm.prank(alice);
        uint256 assetsUsed = vault.mint(250e6, alice);
        assertEq(assetsUsed, 250e6);
        assertEq(vault.balanceOf(alice), 250e6);
    }

    function testVaultWithdrawWithAllowance() public {
        vm.prank(alice);
        vault.deposit(1000e6, alice);
        vm.prank(alice);
        vault.approve(bob, 300e6);
        vm.prank(bob);
        vault.withdraw(300e6, bob, alice);
        assertEq(vault.balanceOf(alice), 700e6);
    }

    function testAmmInitialReservesAreZero() public view {
        (uint112 r0, uint112 r1) = amm.getReserves();
        assertEq(r0, 0);
        assertEq(r1, 0);
    }

    function testAmmAddLiquidityMintsLp() public {
        uint256 shares = _seedLiquidity(1000e18, 3_500_000e6);
        assertGt(shares, 0);
        assertEq(amm.lpToken().balanceOf(alice), shares);
    }

    function testAmmAddLiquidityRevertsOnMinShares() public {
        vm.prank(alice);
        vm.expectRevert();
        amm.addLiquidity(1000e18, 3_500_000e6, type(uint256).max, alice);
    }

    function testAmmAddLiquidityRevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(ConstantProductAMM.ZeroAmount.selector);
        amm.addLiquidity(0, 1, 0, alice);
    }

    function testAmmAddLiquidityRevertsOnZeroReceiver() public {
        vm.prank(alice);
        vm.expectRevert(ConstantProductAMM.ZeroAddress.selector);
        amm.addLiquidity(1, 1, 0, address(0));
    }

    function testAmmQuoteSwap() public {
        _seedLiquidity(1000e18, 3_500_000e6);
        uint256 out = amm.quoteSwap(address(govToken), 10e18);
        assertGt(out, 0);
    }

    function testAmmSwapToken0ForToken1() public {
        _seedLiquidity(1000e18, 3_500_000e6);
        uint256 beforeBalance = asset.balanceOf(bob);
        vm.prank(bob);
        uint256 out = amm.swap(address(govToken), 10e18, 1, bob);
        assertEq(asset.balanceOf(bob), beforeBalance + out);
    }

    function testAmmSwapToken1ForToken0() public {
        _seedLiquidity(1000e18, 3_500_000e6);
        uint256 beforeBalance = govToken.balanceOf(bob);
        vm.prank(bob);
        uint256 out = amm.swap(address(asset), 10_000e6, 1, bob);
        assertEq(govToken.balanceOf(bob), beforeBalance + out);
    }

    function testAmmSwapRevertsForInvalidToken() public {
        _seedLiquidity(1000e18, 3_500_000e6);
        vm.prank(bob);
        vm.expectRevert(ConstantProductAMM.InvalidTokenIn.selector);
        amm.swap(address(secondAsset), 1e6, 0, bob);
    }

    function testAmmSwapRevertsOnSlippage() public {
        _seedLiquidity(1000e18, 3_500_000e6);
        vm.prank(bob);
        vm.expectRevert();
        amm.swap(address(govToken), 10e18, type(uint256).max, bob);
    }

    function testAmmRemoveLiquidityBurnsLp() public {
        uint256 shares = _seedLiquidity(1000e18, 3_500_000e6);
        vm.prank(alice);
        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(shares / 2, 1, 1, alice);
        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(amm.lpToken().balanceOf(alice), shares - shares / 2);
    }

    function testAmmRemoveLiquidityRevertsForZeroShares() public {
        _seedLiquidity(1000e18, 3_500_000e6);
        vm.prank(alice);
        vm.expectRevert(ConstantProductAMM.ZeroAmount.selector);
        amm.removeLiquidity(0, 0, 0, alice);
    }

    function testAmmRemoveLiquidityRevertsOnSlippage() public {
        uint256 shares = _seedLiquidity(1000e18, 3_500_000e6);
        vm.prank(alice);
        vm.expectRevert();
        amm.removeLiquidity(shares, type(uint256).max, 0, alice);
    }

    function testAmmOraclePriceToken0InToken1() public view {
        assertEq(amm.oraclePriceToken0InToken1(), 3500e18);
    }

    function testAmmSyncCapturesDonations() public {
        _seedLiquidity(1000e18, 3_500_000e6);
        govToken.mint(address(amm), 1e18);
        amm.sync();
        (uint112 r0,) = amm.getReserves();
        assertEq(r0, 1001e18);
    }

    function testFactoryCreatePair() public {
        address pair = factory.createPair(
            address(weth), address(secondAsset), address(ethOracle), address(usdOracle), admin, "WETH-mEUR LP", "WME"
        );
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.getPair(address(weth), address(secondAsset)), pair);
    }

    function testFactoryCreate2PredictsAddress() public {
        bytes32 salt = keccak256("factory-salt");
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

    function testFactoryDuplicatePairReverts() public {
        factory.createPair(
            address(weth), address(secondAsset), address(ethOracle), address(usdOracle), admin, "WETH-mEUR LP", "WME"
        );
        vm.expectRevert();
        factory.createPair(
            address(secondAsset), address(weth), address(usdOracle), address(ethOracle), admin, "WETH-mEUR LP", "WME"
        );
    }

    function testFactoryNonCreatorReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        factory.createPair(
            address(weth), address(secondAsset), address(ethOracle), address(usdOracle), admin, "WETH-mEUR LP", "WME"
        );
    }

    function testFactoryRejectsIdenticalTokens() public {
        vm.expectRevert(PoolFactory.IdenticalTokens.selector);
        factory.createPair(address(weth), address(weth), address(ethOracle), address(usdOracle), admin, "Bad", "BAD");
    }

    function testMathMulDivEquivalent() public view {
        assertEq(mathBench.mulDivSolidity(12, 30, 5), mathBench.mulDivYul(12, 30, 5));
    }

    function testMathSumEquivalent() public view {
        uint256[] memory values = new uint256[](4);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;
        values[3] = 4;
        assertEq(mathBench.sumSolidity(values), mathBench.sumYul(values));
    }

    function testMathRevertsOnDivisionByZero() public {
        vm.expectRevert();
        mathBench.mulDivYul(1, 1, 0);
    }

    function testTreasuryInitialVersion() public view {
        assertEq(treasury.version(), 1);
    }

    function testTreasuryDepositToken() public {
        vm.prank(alice);
        treasury.depositToken(IERC20(address(asset)), 100e6);
        assertEq(asset.balanceOf(address(treasury)), 100e6);
    }

    function testTreasuryWithdrawTokenByTreasurer() public {
        vm.prank(alice);
        treasury.depositToken(IERC20(address(asset)), 100e6);
        treasury.withdrawToken(IERC20(address(asset)), bob, 40e6);
        assertEq(asset.balanceOf(bob), 5_000_040e6);
    }

    function testTreasuryWithdrawRevertsForNonTreasurer() public {
        vm.prank(alice);
        vm.expectRevert();
        treasury.withdrawToken(IERC20(address(asset)), bob, 1);
    }

    function testTreasuryNativeWithdraw() public {
        vm.deal(address(treasury), 1 ether);
        uint256 beforeBalance = bob.balance;
        treasury.withdrawNative(payable(bob), 0.25 ether);
        assertEq(bob.balance, beforeBalance + 0.25 ether);
    }

    function testTreasuryUpgradeToV2() public {
        UpgradeableTreasuryV2 impl = new UpgradeableTreasuryV2();
        treasury.upgradeToAndCall(address(impl), "");
        assertEq(UpgradeableTreasuryV2(payable(address(treasury))).version(), 2);
    }

    function testTreasuryV2CanSetFee() public {
        UpgradeableTreasuryV2 impl = new UpgradeableTreasuryV2();
        treasury.upgradeToAndCall(address(impl), "");
        UpgradeableTreasuryV2 upgraded = UpgradeableTreasuryV2(payable(address(treasury)));
        upgraded.setProtocolFeeBps(100);
        assertEq(upgraded.protocolFeeBps(), 100);
    }

    function testTreasuryV2RejectsHighFee() public {
        UpgradeableTreasuryV2 impl = new UpgradeableTreasuryV2();
        treasury.upgradeToAndCall(address(impl), "");
        vm.expectRevert(abi.encodeWithSelector(UpgradeableTreasuryV2.FeeTooHigh.selector, 1001));
        UpgradeableTreasuryV2(payable(address(treasury))).setProtocolFeeBps(1001);
    }

    function testGovernorName() public view {
        assertEq(governor.name(), "DeFiSuperAppGovernor");
    }

    function testGovernorProposalLifecycleToSucceeded() public {
        vm.roll(block.number + 1);
        bytes memory calldata_ = abi.encodeCall(YieldVault.pause, ());
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(vault);
        calldatas[0] = calldata_;
        uint256 proposalId = governor.propose(targets, values, calldatas, "Pause vault");
        vm.roll(block.number + governor.votingDelay() + 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        assertEq(uint256(governor.state(proposalId)), 4);
    }

    function testAccessControlErrorsExposeRole() public {
        bytes32 pauserRole = vault.PAUSER_ROLE();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, pauserRole)
        );
        vault.pause();
    }
}
