// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PartyStarterV2} from "../src/PartyStarterV2.sol";
import {PublicPartyVenue} from "../src/PublicPartyVenue.sol";

contract TestMetadataSetter is Script {
    // These addresses are from the deployment script
    address constant PARTY_STARTER_V2 =
        0x9A676e781A523b5d0C0e43731313A708CB607508;

    function run() external {
        vm.startBroadcast();

        console.log("Testing new metadata setter functionality...");
        console.log("");

        // Create a new party for testing
        PartyStarterV2 partyStarter = PartyStarterV2(PARTY_STARTER_V2);
        address newPartyAddress = partyStarter.createParty(
            block.timestamp + 1 days, // timeout
            1 ether, // ethAmount
            1000 * 1e18, // tokenAmount
            0.1 ether // maxEthContribution
        );

        PublicPartyVenue venue = PublicPartyVenue(newPartyAddress);
        console.log("Created new party at:", newPartyAddress);

        // Test 1: Set individual fields
        testIndividualSetters(venue);

        // Create another party for batch testing
        address batchTestPartyAddress = partyStarter.createParty(
            block.timestamp + 1 days, // timeout
            2 ether, // ethAmount
            2000 * 1e18, // tokenAmount
            0.2 ether // maxEthContribution
        );

        PublicPartyVenue batchVenue = PublicPartyVenue(batchTestPartyAddress);
        console.log("Created batch test party at:", batchTestPartyAddress);

        // Test 2: Batch setter with partial fields
        testBatchSetter(batchVenue);

        // Test 3: Attempt to set already set fields (should fail)
        testAlreadySetFields(venue);

        vm.stopBroadcast();

        console.log("");
        console.log("All metadata setter tests completed!");
    }

    function testIndividualSetters(PublicPartyVenue venue) internal {
        console.log("Testing individual field setters...");

        // Set name
        venue.setName("Test Party Token");
        console.log("  Name set:", venue.name());
        console.log("  Name flag:", venue.nameSet());

        // Set symbol
        venue.setSymbol("TPT");
        console.log("  Symbol set:", venue.symbol());
        console.log("  Symbol flag:", venue.symbolSet());

        // Set metadata
        venue.setMetadata(
            "A test party for demonstrating metadata functionality"
        );
        console.log("  Metadata set:", venue.metadata());
        console.log("  Metadata flag:", venue.metadataSet());

        console.log("Individual setters test completed");
        console.log("");
    }

    function testBatchSetter(PublicPartyVenue venue) internal {
        console.log("Testing batch setter with partial fields...");

        // Set only some fields using batch setter
        venue.setBatchMetadata(
            "Batch Party Token", // name
            "BPT", // symbol
            "", // metadata (empty - don't set)
            "https://example.com/image.png", // image
            "https://example.com", // website
            "", // twitter (empty - don't set)
            "@batchparty" // telegram
        );

        console.log("  Name set:", venue.name());
        console.log("  Symbol set:", venue.symbol());
        console.log("  Metadata (should be empty):", venue.metadata());
        console.log("  Image set:", venue.image());
        console.log("  Website set:", venue.website());
        console.log("  Twitter (should be empty):", venue.twitter());
        console.log("  Telegram set:", venue.telegram());

        console.log("  Flags after batch set:");
        console.log("    nameSet:", venue.nameSet());
        console.log("    symbolSet:", venue.symbolSet());
        console.log("    metadataSet:", venue.metadataSet());
        console.log("    imageSet:", venue.imageSet());
        console.log("    websiteSet:", venue.websiteSet());
        console.log("    twitterSet:", venue.twitterSet());
        console.log("    telegramSet:", venue.telegramSet());

        console.log("Batch setter test completed");
        console.log("");
    }

    function testAlreadySetFields(PublicPartyVenue venue) internal {
        console.log("Testing already set field protection...");

        // Try to set name again (should fail)
        try venue.setName("Another Name") {
            console.log("  ERROR: Should not be able to set name again!");
        } catch {
            console.log(
                "  SUCCESS: Name setter correctly rejected (already set)"
            );
        }

        // Try to set symbol again (should fail)
        try venue.setSymbol("XXX") {
            console.log("  ERROR: Should not be able to set symbol again!");
        } catch {
            console.log(
                "  SUCCESS: Symbol setter correctly rejected (already set)"
            );
        }

        // Try batch set with already set fields (should fail)
        try
            venue.setBatchMetadata(
                "New Name", // This should fail since name is already set
                "", // symbol (empty)
                "", // metadata (empty)
                "", // image (empty)
                "", // website (empty)
                "", // twitter (empty)
                "" // telegram (empty)
            )
        {
            console.log("  ERROR: Should not be able to batch set name again!");
        } catch {
            console.log(
                "  SUCCESS: Batch setter correctly rejected (name already set)"
            );
        }

        console.log("Already set field protection test completed");
    }
}
