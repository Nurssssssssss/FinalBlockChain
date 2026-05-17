// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { GovernanceToken } from "../../contracts/GovernanceToken.sol";
import { DeFiGovernor } from "../../contracts/DeFiGovernor.sol";
import { YieldVault } from "../../contracts/YieldVault.sol";
import { PriceFeedOracle } from "../../contracts/PriceFeedOracle.sol";
import { ConstantProductAMM } from "../../contracts/ConstantProductAMM.sol";
import { PoolFactory } from "../../contracts/PoolFactory.sol";
import { MathBench } from "../../contracts/MathBench.sol";
import { UpgradeableTreasuryV1 } from "../../contracts/UpgradeableTreasuryV1.sol";
import { UpgradeableTreasuryV2 } from "../../contracts/UpgradeableTreasuryV2.sol";
import { MockERC20 } from "../../contracts/mocks/MockERC20.sol";
import { MockAggregatorV3 } from "../../contracts/mocks/MockAggregatorV3.sol";

abstract contract ProtocolFixture is Test {
    address internal admin = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA20);
    address internal timelockAdmin = address(0x71);

    GovernanceToken internal govToken;
    MockERC20 internal asset;
    MockERC20 internal secondAsset;
    MockERC20 internal weth;
    MockAggregatorV3 internal ethFeed;
    MockAggregatorV3 internal usdFeed;
    PriceFeedOracle internal ethOracle;
    PriceFeedOracle internal usdOracle;
    YieldVault internal vault;
    ConstantProductAMM internal amm;
    PoolFactory internal factory;
    MathBench internal mathBench;
    TimelockController internal timelock;
    DeFiGovernor internal governor;
    UpgradeableTreasuryV1 internal treasury;
    UpgradeableTreasuryV1 internal treasuryImplementation;

    uint256 internal constant GOV_INITIAL_SUPPLY = 10_000_000e18;
    uint256 internal constant GOV_CAP = 100_000_000e18;

    function setUp() public virtual {
        govToken = new GovernanceToken(admin, GOV_INITIAL_SUPPLY, GOV_CAP);
        asset = new MockERC20("Mock USD", "mUSD", 6);
        secondAsset = new MockERC20("Mock Euro", "mEUR", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        ethFeed = new MockAggregatorV3(8, 3500e8);
        usdFeed = new MockAggregatorV3(8, 1e8);
        ethOracle = new PriceFeedOracle(address(ethFeed), 1 days, admin);
        usdOracle = new PriceFeedOracle(address(usdFeed), 1 days, admin);
        vault = new YieldVault(asset, admin);
        amm = new ConstantProductAMM(
            address(govToken), address(asset), address(ethOracle), address(usdOracle), admin, "DSG-mUSD LP", "DSG-LP"
        );
        factory = new PoolFactory(admin);
        mathBench = new MathBench();

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(2 days, proposers, executors, timelockAdmin);
        governor = new DeFiGovernor(govToken, timelock);
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        vm.prank(timelockAdmin);
        timelock.grantRole(proposerRole, address(governor));

        treasuryImplementation = new UpgradeableTreasuryV1();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(treasuryImplementation), abi.encodeCall(UpgradeableTreasuryV1.initialize, (admin))
        );
        treasury = UpgradeableTreasuryV1(payable(address(proxy)));

        govToken.delegate(admin);
        _fund(alice, 1_000_000e18, 5_000_000e6);
        _fund(bob, 1_000_000e18, 5_000_000e6);
        _fund(carol, 1_000_000e18, 5_000_000e6);
    }

    function _fund(address user, uint256 govAmount, uint256 assetAmount) internal {
        govToken.mint(user, govAmount);
        asset.mint(user, assetAmount);
        secondAsset.mint(user, assetAmount);
        weth.mint(user, govAmount);
        vm.startPrank(user);
        govToken.approve(address(amm), type(uint256).max);
        asset.approve(address(amm), type(uint256).max);
        asset.approve(address(vault), type(uint256).max);
        asset.approve(address(treasury), type(uint256).max);
        secondAsset.approve(address(factory), type(uint256).max);
        govToken.delegate(user);
        vm.stopPrank();
    }

    function _seedLiquidity(uint256 govAmount, uint256 assetAmount) internal returns (uint256 shares) {
        vm.prank(alice);
        (,, shares) = amm.addLiquidity(govAmount, assetAmount, 0, alice);
    }
}
