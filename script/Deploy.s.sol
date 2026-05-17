// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { GovernanceToken } from "../contracts/GovernanceToken.sol";
import { DeFiGovernor } from "../contracts/DeFiGovernor.sol";
import { YieldVault } from "../contracts/YieldVault.sol";
import { PriceFeedOracle } from "../contracts/PriceFeedOracle.sol";
import { PoolFactory } from "../contracts/PoolFactory.sol";
import { ConstantProductAMM } from "../contracts/ConstantProductAMM.sol";
import { UpgradeableTreasuryV1 } from "../contracts/UpgradeableTreasuryV1.sol";
import { MockERC20 } from "../contracts/mocks/MockERC20.sol";
import { MockAggregatorV3 } from "../contracts/mocks/MockAggregatorV3.sol";

contract Deploy is Script {
    uint256 internal constant INITIAL_GOV_SUPPLY = 10_000_000e18;
    uint256 internal constant GOV_CAP = 100_000_000e18;
    uint256 internal constant INITIAL_ASSET_SUPPLY = 50_000_000e6;
    uint256 internal constant STALE_AFTER = 1 days;
    uint256 internal constant TIMELOCK_DELAY = 2 days;

    struct Deployment {
        address governanceToken;
        address assetToken;
        address ethUsdFeed;
        address assetUsdFeed;
        address ethOracle;
        address assetOracle;
        address vault;
        address factory;
        address amm;
        address lpToken;
        address timelock;
        address governor;
        address treasuryImplementation;
        address treasuryProxy;
    }

    function run() external returns (Deployment memory d) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        GovernanceToken governanceToken = new GovernanceToken(deployer, INITIAL_GOV_SUPPLY, GOV_CAP);
        governanceToken.delegate(deployer);

        MockERC20 assetToken = new MockERC20("Mock USD Asset", "mUSD", 6);
        assetToken.mint(deployer, INITIAL_ASSET_SUPPLY);

        address ethUsdFeed = _feedOrMock("ETH_USD_FEED", 3500e8);
        address assetUsdFeed = _feedOrMock("ASSET_USD_FEED", 1e8);
        PriceFeedOracle ethOracle = new PriceFeedOracle(ethUsdFeed, STALE_AFTER, deployer);
        PriceFeedOracle assetOracle = new PriceFeedOracle(assetUsdFeed, STALE_AFTER, deployer);

        YieldVault vault = new YieldVault(assetToken, deployer);
        PoolFactory factory = new PoolFactory(deployer);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, deployer);
        DeFiGovernor governor = new DeFiGovernor(governanceToken, timelock);

        bytes32 salt = keccak256("DSG_MUSD_BASE_PAIR");
        address ammAddress = factory.createPairDeterministic(
            address(governanceToken),
            address(assetToken),
            address(ethOracle),
            address(assetOracle),
            address(timelock),
            "DSG-mUSD LP",
            "DSG-MUSD-LP",
            salt
        );
        ConstantProductAMM amm = ConstantProductAMM(ammAddress);

        UpgradeableTreasuryV1 treasuryImplementation = new UpgradeableTreasuryV1();
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(
            address(treasuryImplementation), abi.encodeCall(UpgradeableTreasuryV1.initialize, (deployer))
        );
        UpgradeableTreasuryV1 treasury = UpgradeableTreasuryV1(payable(address(treasuryProxy)));

        _moveProtocolRolesToTimelock(
            governanceToken, vault, ethOracle, assetOracle, factory, treasury, timelock, governor, deployer
        );

        d = Deployment({
            governanceToken: address(governanceToken),
            assetToken: address(assetToken),
            ethUsdFeed: ethUsdFeed,
            assetUsdFeed: assetUsdFeed,
            ethOracle: address(ethOracle),
            assetOracle: address(assetOracle),
            vault: address(vault),
            factory: address(factory),
            amm: address(amm),
            lpToken: address(amm.lpToken()),
            timelock: address(timelock),
            governor: address(governor),
            treasuryImplementation: address(treasuryImplementation),
            treasuryProxy: address(treasuryProxy)
        });

        vm.stopBroadcast();

        _writeDeployment(d);
        _logDeployment(d);
    }

    function _feedOrMock(string memory envKey, int256 mockAnswer) internal returns (address feed) {
        feed = vm.envOr(envKey, address(0));
        if (feed == address(0)) {
            feed = address(new MockAggregatorV3(8, mockAnswer));
        }
    }

    function _moveProtocolRolesToTimelock(
        GovernanceToken governanceToken,
        YieldVault vault,
        PriceFeedOracle ethOracle,
        PriceFeedOracle assetOracle,
        PoolFactory factory,
        UpgradeableTreasuryV1 treasury,
        TimelockController timelock,
        DeFiGovernor governor,
        address deployer
    ) internal {
        address tl = address(timelock);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        governanceToken.grantRole(governanceToken.DEFAULT_ADMIN_ROLE(), tl);
        governanceToken.grantRole(governanceToken.MINTER_ROLE(), tl);
        governanceToken.revokeRole(governanceToken.MINTER_ROLE(), deployer);
        governanceToken.revokeRole(governanceToken.DEFAULT_ADMIN_ROLE(), deployer);

        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), tl);
        vault.grantRole(vault.PAUSER_ROLE(), tl);
        vault.grantRole(vault.REWARD_MANAGER_ROLE(), tl);
        vault.revokeRole(vault.PAUSER_ROLE(), deployer);
        vault.revokeRole(vault.REWARD_MANAGER_ROLE(), deployer);
        vault.revokeRole(vault.DEFAULT_ADMIN_ROLE(), deployer);

        ethOracle.grantRole(ethOracle.DEFAULT_ADMIN_ROLE(), tl);
        ethOracle.grantRole(ethOracle.FEED_MANAGER_ROLE(), tl);
        ethOracle.revokeRole(ethOracle.FEED_MANAGER_ROLE(), deployer);
        ethOracle.revokeRole(ethOracle.DEFAULT_ADMIN_ROLE(), deployer);

        assetOracle.grantRole(assetOracle.DEFAULT_ADMIN_ROLE(), tl);
        assetOracle.grantRole(assetOracle.FEED_MANAGER_ROLE(), tl);
        assetOracle.revokeRole(assetOracle.FEED_MANAGER_ROLE(), deployer);
        assetOracle.revokeRole(assetOracle.DEFAULT_ADMIN_ROLE(), deployer);

        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), tl);
        factory.grantRole(factory.PAIR_CREATOR_ROLE(), tl);
        factory.revokeRole(factory.PAIR_CREATOR_ROLE(), deployer);
        factory.revokeRole(factory.DEFAULT_ADMIN_ROLE(), deployer);

        treasury.grantRole(treasury.DEFAULT_ADMIN_ROLE(), tl);
        treasury.grantRole(treasury.TREASURER_ROLE(), tl);
        treasury.grantRole(treasury.UPGRADER_ROLE(), tl);
        treasury.revokeRole(treasury.TREASURER_ROLE(), deployer);
        treasury.revokeRole(treasury.UPGRADER_ROLE(), deployer);
        treasury.revokeRole(treasury.DEFAULT_ADMIN_ROLE(), deployer);

        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _writeDeployment(Deployment memory d) internal {
        vm.createDir("deployments", true);
        string memory object = "deployment";
        string memory json = vm.serializeAddress(object, "governanceToken", d.governanceToken);
        json = vm.serializeAddress(object, "assetToken", d.assetToken);
        json = vm.serializeAddress(object, "ethUsdFeed", d.ethUsdFeed);
        json = vm.serializeAddress(object, "assetUsdFeed", d.assetUsdFeed);
        json = vm.serializeAddress(object, "ethOracle", d.ethOracle);
        json = vm.serializeAddress(object, "assetOracle", d.assetOracle);
        json = vm.serializeAddress(object, "vault", d.vault);
        json = vm.serializeAddress(object, "factory", d.factory);
        json = vm.serializeAddress(object, "amm", d.amm);
        json = vm.serializeAddress(object, "lpToken", d.lpToken);
        json = vm.serializeAddress(object, "timelock", d.timelock);
        json = vm.serializeAddress(object, "governor", d.governor);
        json = vm.serializeAddress(object, "treasuryImplementation", d.treasuryImplementation);
        json = vm.serializeAddress(object, "treasuryProxy", d.treasuryProxy);
        vm.writeJson(json, string.concat("deployments/", vm.toString(block.chainid), ".json"));
    }

    function _logDeployment(Deployment memory d) internal pure {
        console2.log("GovernanceToken", d.governanceToken);
        console2.log("AssetToken", d.assetToken);
        console2.log("Vault", d.vault);
        console2.log("AMM", d.amm);
        console2.log("LPToken", d.lpToken);
        console2.log("Timelock", d.timelock);
        console2.log("Governor", d.governor);
        console2.log("TreasuryProxy", d.treasuryProxy);
    }
}
