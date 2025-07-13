// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PartyStarterV2} from "../src/PartyStarterV2.sol";

contract DeployPartyStarterV2 is Script {
    function run() external returns (PartyStarterV2) {
        // These are placeholder addresses from the Goerli testnet.
        // You can replace them with addresses from your target network,
        // or load them from environment variables for more flexibility.
        address factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        address positionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
        address vault = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast();
        PartyStarterV2 partyStarterV2 = new PartyStarterV2(
            factory,
            positionManager,
            vault
        );
        vm.stopBroadcast();

        return partyStarterV2;
    }
}
