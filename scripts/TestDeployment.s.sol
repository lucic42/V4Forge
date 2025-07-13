// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PartyStarterV2} from "../src/PartyStarterV2.sol";
import {PublicPartyVenue} from "../src/PublicPartyVenue.sol";

contract TestDeployment is Script {
    // These addresses are from the deployment script
    address constant WETH9 = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant FACTORY = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address constant POSITION_MANAGER =
        0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address constant PARTY_STARTER_V2 =
        0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant TEST_PARTY_VENUE =
        0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81;

    function run() external {
        vm.startBroadcast();

        console.log("Testing deployed contracts...");
        console.log("");

        // Test PartyStarterV2
        testPartyStarter();

        // Test PublicPartyVenue
        testPartyVenue();

        // Test creating a new party
        testCreateNewParty();

        vm.stopBroadcast();

        console.log("");
        console.log("All tests passed!");
    }

    function testPartyStarter() internal {
        console.log("Testing PartyStarterV2...");

        PartyStarterV2 partyStarter = PartyStarterV2(PARTY_STARTER_V2);

        // Check that the addresses are set correctly
        require(partyStarter.factory() == FACTORY, "Factory address mismatch");
        require(
            partyStarter.positionManager() == POSITION_MANAGER,
            "Position manager address mismatch"
        );

        console.log("  PartyStarterV2 configuration is correct");
    }

    function testPartyVenue() internal {
        console.log("Testing PublicPartyVenue...");

        PublicPartyVenue venue = PublicPartyVenue(TEST_PARTY_VENUE);

        // Check basic properties
        uint256 ethAmount = venue.ethAmount();
        uint256 tokenAmount = venue.tokenAmount();
        uint256 maxEthContribution = venue.maxEthContribution();

        require(ethAmount == 1 ether, "ETH amount mismatch");
        require(tokenAmount == 1000 * 1e18, "Token amount mismatch");
        require(maxEthContribution == 0.1 ether, "Max contribution mismatch");

        console.log("  PublicPartyVenue configuration is correct");
        console.log("    - ETH Amount:", ethAmount);
        console.log("    - Token Amount:", tokenAmount);
        console.log("    - Max Contribution:", maxEthContribution);
    }

    function testCreateNewParty() internal {
        console.log("Testing party creation...");

        PartyStarterV2 partyStarter = PartyStarterV2(PARTY_STARTER_V2);

        // Create a new party
        address newPartyAddress = partyStarter.createParty(
            block.timestamp + 2 days, // timeout
            2 ether, // ethAmount
            2000 * 1e18, // tokenAmount
            0.2 ether // maxEthContribution
        );

        require(newPartyAddress != address(0), "Party creation failed");

        // Test the new party
        PublicPartyVenue newVenue = PublicPartyVenue(newPartyAddress);
        require(
            newVenue.ethAmount() == 2 ether,
            "New party ETH amount mismatch"
        );
        require(
            newVenue.tokenAmount() == 2000 * 1e18,
            "New party token amount mismatch"
        );

        console.log("  New party created successfully");
        console.log("    - Address:", newPartyAddress);
        console.log("    - ETH Amount:", newVenue.ethAmount());
        console.log("    - Token Amount:", newVenue.tokenAmount());
    }
}
