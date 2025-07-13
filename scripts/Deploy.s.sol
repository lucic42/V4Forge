// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PartyStarterV2} from "../src/PartyStarterV2.sol";
import {PublicPartyVenue} from "../src/PublicPartyVenue.sol";

contract Deploy is Script {
    function run() external returns (PartyStarterV2, PublicPartyVenue) {
        // Load configuration from environment variables, with defaults.
        // You can set these in a .env file and run `source .env` before deploying.
        address factory = vm.envAddress("FACTORY_ADDRESS");
        address positionManager = vm.envAddress("POSITION_MANAGER_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");

        // Deploy PartyStarterV2
        vm.startBroadcast();
        PartyStarterV2 partyStarterV2 = new PartyStarterV2(
            factory,
            positionManager,
            vault
        );
        vm.stopBroadcast();

        // Parameters for creating a new party
        uint256 timeout = block.timestamp + 1 days; // 1 day from now
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 1000 * 1e18;
        uint256 maxEthContribution = 0.1 ether;

        // Create a new party using the PartyStarterV2 contract
        vm.startBroadcast();
        address newPartyAddress = partyStarterV2.createParty(
            timeout,
            ethAmount,
            tokenAmount,
            maxEthContribution
        );
        vm.stopBroadcast();

        PublicPartyVenue publicPartyVenue = PublicPartyVenue(newPartyAddress);

        return (partyStarterV2, publicPartyVenue);
    }
}
