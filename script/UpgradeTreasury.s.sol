// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { Script, console2 } from "forge-std/Script.sol";
import { UpgradeableTreasuryV2 } from "../contracts/UpgradeableTreasuryV2.sol";

interface IUUPSUpgradeableProxy {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract UpgradeTreasury is Script {
    function run() external returns (address implementation, bytes memory timelockCalldata) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("TREASURY_PROXY");
        bool executeDirect = vm.envOr("EXECUTE_DIRECT_UPGRADE", false);

        vm.startBroadcast(privateKey);
        implementation = address(new UpgradeableTreasuryV2());
        timelockCalldata = abi.encodeCall(IUUPSUpgradeableProxy.upgradeToAndCall, (implementation, bytes("")));
        if (executeDirect) {
            IUUPSUpgradeableProxy(proxy).upgradeToAndCall(implementation, bytes(""));
        }
        vm.stopBroadcast();

        console2.log("TreasuryV2 implementation", implementation);
        console2.log("Target proxy", proxy);
        console2.logBytes(timelockCalldata);
    }
}
