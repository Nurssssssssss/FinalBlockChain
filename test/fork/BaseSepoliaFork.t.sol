// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { Test } from "forge-std/Test.sol";
import { PriceFeedOracle } from "../../contracts/PriceFeedOracle.sol";
import { PoolFactory } from "../../contracts/PoolFactory.sol";

contract BaseSepoliaForkTest is Test {
    function testForkBaseSepoliaChainId() public {
        string memory rpc = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);
        assertEq(block.chainid, 84_532);
    }

    function testForkBaseSepoliaChainlinkFeedIfConfigured() public {
        string memory rpc = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        address feed = vm.envOr("BASE_SEPOLIA_ETH_USD_FEED", address(0));
        if (bytes(rpc).length == 0 || feed == address(0)) return;
        vm.createSelectFork(rpc);
        PriceFeedOracle oracle = new PriceFeedOracle(feed, 1 days, address(this));
        (uint256 price,,) = oracle.latestPrice();
        assertGt(price, 0);
    }

    function testForkCreate2PredictionIsStable() public {
        string memory rpc = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);
        PoolFactory factory = new PoolFactory(address(this));
        bytes32 salt = keccak256("fork-stable");
        address predicted = factory.predictDeterministicAddress(
            address(0x1001), address(0x1002), address(0x2001), address(0x2002), address(this), "Fork LP", "FLP", salt
        );
        assertTrue(predicted != address(0));
    }
}
