// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { Script, console2 } from "forge-std/Script.sol";
import { GovernanceToken } from "../contracts/GovernanceToken.sol";
import { YieldVault } from "../contracts/YieldVault.sol";
import { ConstantProductAMM } from "../contracts/ConstantProductAMM.sol";
import { DeFiGovernor } from "../contracts/DeFiGovernor.sol";
import { PriceFeedOracle } from "../contracts/PriceFeedOracle.sol";
import { UpgradeableTreasuryV1 } from "../contracts/UpgradeableTreasuryV1.sol";

contract PostDeployCheck is Script {
    function run() external view {
        GovernanceToken token = GovernanceToken(vm.envAddress("GOVERNANCE_TOKEN"));
        YieldVault vault = YieldVault(vm.envAddress("VAULT"));
        ConstantProductAMM amm = ConstantProductAMM(vm.envAddress("AMM"));
        DeFiGovernor governor = DeFiGovernor(payable(vm.envAddress("GOVERNOR")));
        PriceFeedOracle oracle = PriceFeedOracle(vm.envAddress("PRICE_ORACLE"));
        UpgradeableTreasuryV1 treasury = UpgradeableTreasuryV1(payable(vm.envAddress("TREASURY_PROXY")));

        (uint112 reserve0, uint112 reserve1) = amm.getReserves();
        (uint256 price, uint8 decimals_, uint256 updatedAt) = oracle.latestPrice();

        console2.log("governor name", governor.name());
        console2.log("token supply", token.totalSupply());
        console2.log("vault asset", vault.asset());
        console2.log("vault total assets", vault.totalAssets());
        console2.log("amm token0", address(amm.token0()));
        console2.log("amm token1", address(amm.token1()));
        console2.log("amm reserve0", reserve0);
        console2.log("amm reserve1", reserve1);
        console2.log("oracle price", price);
        console2.log("oracle decimals", decimals_);
        console2.log("oracle updatedAt", updatedAt);
        console2.log("treasury version", treasury.version());
    }
}
