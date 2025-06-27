// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "../utils/TestBase.sol";
import {console} from "forge-std/console.sol";
import {PartyTypes} from "../../src/types/PartyTypes.sol";
import {PartyVenue} from "../../src/venue/PartyVenue.sol";
import {UniswapV4ERC20} from "../../src/tokens/UniswapV4ERC20.sol";
import {PartyStarter} from "../../src/PartyStarter.sol";

contract LoadTest is TestBase {
    // ============ High Volume Party Creation ============

    function test_Load_100_InstantParties() public {
        uint256 partyCount = 100;
        uint256 totalGasUsed = 0;

        console.log("Creating 100 instant parties...");

        for (uint256 i = 0; i < partyCount; i++) {
            address creator = address(uint160(0x7000 + i));
            vm.deal(creator, 10 ether);

            PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
                string(abi.encodePacked("LoadToken", vm.toString(i))),
                string(abi.encodePacked("LOAD", vm.toString(i % 1000)))
            );

            uint256 gasBeforeCreate = gasleft();

            vm.prank(creator);
            uint256 partyId = partyStarter.createInstantParty{value: 1 ether}(
                metadata
            );

            uint256 gasAfterCreate = gasleft();
            uint256 gasUsedForThisParty = gasBeforeCreate - gasAfterCreate;
            totalGasUsed += gasUsedForThisParty;

            // Verify party was created correctly
            assertPartyCreated(partyId, PartyTypes.PartyType.INSTANT, creator);
            assertPartyLaunched(partyId);

            if ((i + 1) % 20 == 0) {
                // console.log(
                //     "Created",
                //     i + 1,
                //     "parties. Avg gas:",
                //     totalGasUsed / (i + 1)
                // );
            }
        }

        uint256 averageGasPerParty = totalGasUsed / partyCount;

        console.log("=== LOAD TEST RESULTS ===");
        console.log("Total parties created:", partyCount);
        console.log("Average gas per party:", averageGasPerParty);
        console.log("Treasury balance:", TREASURY.balance);
        console.log("==========================");

        // Verify system state
        assertEq(partyStarter.partyCounter(), partyCount);
        assertEq(partyVault.getTokenCount(), partyCount);
        assertTrue(averageGasPerParty < 2000000); // 2M gas per party max
    }

    function test_Load_50_PublicParties_With_Contributions() public {
        uint256 partyCount = 50;

        console.log("Creating 50 public parties with contributions...");

        uint256[] memory partyIds = new uint256[](partyCount);

        // Create all public parties first
        for (uint256 i = 0; i < partyCount; i++) {
            address creator = address(uint160(0x8000 + i));
            vm.deal(creator, 1 ether);

            PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
                string(abi.encodePacked("PublicToken", vm.toString(i))),
                string(abi.encodePacked("PUB", vm.toString(i % 1000)))
            );

            vm.prank(creator);
            partyIds[i] = partyStarter.createPublicParty(metadata, 5 ether);

            assertPartyCreated(
                partyIds[i],
                PartyTypes.PartyType.PUBLIC,
                creator
            );
        }

        console.log(
            "All public parties created. Now contributing to launch them..."
        );

        uint256 launchedCount = 0;

        // Now contribute to launch each party
        for (uint256 i = 0; i < partyCount; i++) {
            PartyTypes.Party memory party = getPartyDetails(partyIds[i]);
            PartyVenue venue = PartyVenue(payable(party.venueAddress));

            // Create multiple contributors for each party
            for (uint256 j = 0; j < 3; j++) {
                address contributor = address(uint160(0x9000 + i * 10 + j));
                vm.deal(contributor, 10 ether);

                uint256 contribution = (j == 2) ? 3 ether : 1 ether; // Last contributor completes the target

                vm.prank(contributor);
                venue.contribute{value: contribution}();

                // Check if party launched
                if (isPartyLaunched(partyIds[i])) {
                    launchedCount++;
                    break; // Move to next party
                }
            }

            if ((i + 1) % 10 == 0) {
                // console.log(
                //     "Processed",
                //     i + 1,
                //     "parties.",
                //     launchedCount,
                //     "launched so far"
                // );
            }
        }

        console.log("=== PUBLIC PARTY LOAD TEST RESULTS ===");
        console.log("Total public parties created:", partyCount);
        console.log("Total parties launched:", launchedCount);
        console.log(
            "Launch success rate:",
            (launchedCount * 100) / partyCount,
            "%"
        );
        console.log("=======================================");

        // Most parties should have launched
        assertTrue(launchedCount >= (partyCount * 8) / 10); // At least 80% launch rate
    }

    function test_Load_25_PrivateParties_With_Signatures() public {
        uint256 partyCount = 25;

        console.log(
            "Creating 25 private parties with signature-based authorization..."
        );

        // Create a signer for private parties
        uint256 signerPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        address signerAddress = vm.addr(signerPrivateKey);

        uint256 totalGasUsed = 0;

        for (uint256 i = 0; i < partyCount; i++) {
            address creator = address(uint160(0xB000 + i));
            vm.deal(creator, 1 ether);

            PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
                string(abi.encodePacked("PrivateToken", vm.toString(i))),
                string(abi.encodePacked("PRIV", vm.toString(i % 100)))
            );

            uint256 gasBeforeCreate = gasleft();

            vm.prank(creator);
            uint256 partyId = partyStarter.createPrivateParty(
                metadata,
                10 ether,
                signerAddress
            );

            uint256 gasAfterCreate = gasleft();
            totalGasUsed += gasBeforeCreate - gasAfterCreate;

            assertPartyCreated(partyId, PartyTypes.PartyType.PRIVATE, creator);

            // Test contributions with signatures
            PartyTypes.Party memory party = getPartyDetails(partyId);
            PartyVenue venue = PartyVenue(payable(party.venueAddress));

            uint256 contributed = 0;
            for (uint256 j = 0; j < 10 && contributed < 10 ether; j++) {
                address contributor = address(uint160(0xA000 + i * 10 + j));
                vm.deal(contributor, 10 ether);

                uint256 contribution = 1 ether;
                uint256 maxAmount = 2 ether;
                uint256 deadline = block.timestamp + 1 hours;

                // Create signature for this contribution
                bytes32 messageHash = keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        keccak256(
                            abi.encodePacked(
                                partyId,
                                contributor,
                                maxAmount,
                                deadline
                            )
                        )
                    )
                );

                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    signerPrivateKey,
                    messageHash
                );
                bytes memory signature = abi.encodePacked(r, s, v);

                vm.prank(contributor);
                venue.contributeWithSignature{value: contribution}(
                    signature,
                    maxAmount,
                    deadline
                );
                contributed += contribution;

                if (contributed >= 10 ether) {
                    assertTrue(isPartyLaunched(partyId));
                    break;
                }
            }
        }

        uint256 averageGasPerPrivateParty = totalGasUsed / partyCount;

        console.log("=== PRIVATE PARTY LOAD TEST RESULTS ===");
        console.log("Total private parties created:", partyCount);
        console.log("Signature-based authorization used");
        console.log(
            "Average gas per private party:",
            averageGasPerPrivateParty
        );
        console.log("=========================================");

        // Gas should be reasonable for signature-based parties
        assertTrue(averageGasPerPrivateParty < 2000000); // 2M gas max for private parties
    }

    // ============ Concurrent Operations Simulation ============

    function test_Load_MixedOperations() public {
        uint256 totalOperations = 100;

        console.log("Simulating 100 mixed operations...");

        uint256 instantParties = 0;
        uint256 publicParties = 0;

        for (uint256 i = 0; i < totalOperations; i++) {
            uint256 operation = i % 3;
            address user = address(uint160(0xC000 + i));
            vm.deal(user, 20 ether);

            if (operation == 0) {
                // Create instant party
                vm.prank(user);
                partyStarter.createInstantParty{value: 1 ether}(
                    generateRandomMetadata(i)
                );
                instantParties++;
            } else if (operation == 1) {
                // Create public party
                vm.prank(user);
                partyStarter.createPublicParty(
                    generateRandomMetadata(i + 1000),
                    3 ether
                );
                publicParties++;
            } else {
                // Contribute to existing public parties
                uint256 currentPartyCount = partyStarter.partyCounter();
                if (currentPartyCount > 0) {
                    uint256 randomPartyId = (i % currentPartyCount) + 1;
                    PartyTypes.Party memory party = getPartyDetails(
                        randomPartyId
                    );

                    if (
                        party.partyType == PartyTypes.PartyType.PUBLIC &&
                        party.venueAddress != address(0) &&
                        !party.launched
                    ) {
                        PartyVenue venue = PartyVenue(
                            payable(party.venueAddress)
                        );

                        try venue.contribute{value: 1 ether}() {
                            // Contribution successful
                        } catch {
                            // Might fail if party already launched
                        }
                    }
                }
            }

            if ((i + 1) % 25 == 0) {
                console.log("Completed", i + 1, "operations");
            }
        }

        console.log("=== MIXED OPERATIONS RESULTS ===");
        console.log("Instant parties:", instantParties);
        console.log("Public parties:", publicParties);
        console.log("Final party counter:", partyStarter.partyCounter());
        console.log("=================================");

        uint256 totalPartiesCreated = instantParties + publicParties;
        assertEq(partyStarter.partyCounter(), totalPartiesCreated);
    }

    // ============ Memory and State Stress Tests ============

    function test_Load_StateGrowth_LargeScale() public {
        console.log("Testing state growth with large scale operations...");

        uint256 initialTreasuryBalance = TREASURY.balance;
        uint256 initialVaultTokens = partyVault.getTokenCount();

        // Create many parties to test state growth
        for (uint256 batch = 0; batch < 10; batch++) {
            console.log("Processing batch", batch + 1, "of 10...");

            for (uint256 i = 0; i < 20; i++) {
                address creator = address(uint160(0xD000 + batch * 20 + i));
                vm.deal(creator, 5 ether);

                vm.prank(creator);
                uint256 partyId = partyStarter.createInstantParty{
                    value: 2 ether
                }(
                    createTokenMetadata(
                        string(
                            abi.encodePacked(
                                "BatchToken",
                                vm.toString(batch),
                                vm.toString(i)
                            )
                        ),
                        string(
                            abi.encodePacked(
                                "B",
                                vm.toString(batch),
                                vm.toString(i)
                            )
                        )
                    )
                );

                // Verify party state
                PartyTypes.Party memory party = getPartyDetails(partyId);
                assertTrue(party.launched);
                assertTrue(party.tokenAddress != address(0));

                // Check user party tracking
                uint256[] memory userParties = partyStarter.getUserParties(
                    creator
                );
                assertEq(userParties.length, 1);
                assertEq(userParties[0], partyId);
            }
        }

        uint256 finalPartyCount = partyStarter.partyCounter();
        uint256 finalTreasuryBalance = TREASURY.balance;
        uint256 finalVaultTokens = partyVault.getTokenCount();

        console.log("=== STATE GROWTH TEST RESULTS ===");
        console.log("Final party count:", finalPartyCount);
        console.log(
            "Treasury balance growth:",
            finalTreasuryBalance - initialTreasuryBalance
        );
        console.log(
            "Vault token count growth:",
            finalVaultTokens - initialVaultTokens
        );
        console.log(
            "Average treasury per party:",
            (finalTreasuryBalance - initialTreasuryBalance) / finalPartyCount
        );
        console.log("===================================");

        // Verify state consistency
        assertEq(finalPartyCount, 200); // 10 batches * 20 parties
        assertEq(finalVaultTokens - initialVaultTokens, 200); // Each instant party adds 1 token type
        assertGt(finalTreasuryBalance, initialTreasuryBalance); // Should have collected significant fees

        // Test random party access
        for (uint256 i = 0; i < 10; i++) {
            uint256 randomPartyId = ((block.timestamp + i) % finalPartyCount) +
                1;
            PartyTypes.Party memory party = getPartyDetails(randomPartyId);

            assertTrue(party.launched);
            assertTrue(party.creator != address(0));
            assertTrue(party.tokenAddress != address(0));
        }
    }

    // ============ Gas Limit Boundary Tests ============

    function test_Load_NearGasLimit_SignatureOperations() public {
        console.log("Testing signature operations near gas limits...");

        // Create a signer for testing
        uint256 signerPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        address signerAddress = vm.addr(signerPrivateKey);

        uint256 gasBeforeCreate = gasleft();

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPrivateParty(
            createTokenMetadata("SignatureTest Token", "SIG"),
            10 ether,
            signerAddress
        );

        uint256 gasUsed = gasBeforeCreate - gasleft();

        console.log("Gas used for signature-based private party:", gasUsed);

        // Should be within reasonable limits
        assertTrue(gasUsed < 2000000); // 2M gas limit

        // Verify party was created correctly
        assertPartyCreated(partyId, PartyTypes.PartyType.PRIVATE, ALICE);

        PartyTypes.Party memory party = getPartyDetails(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        // Test signature-based contributions
        address contributor = address(0xE001);
        vm.deal(contributor, 10 ether);

        uint256 contribution = 1 ether;
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(partyId, contributor, maxAmount, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(contributor);
        venue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        // Verify contribution worked
        assertEq(venue.getContribution(contributor), contribution);
    }

    // ============ Rapid Sequential Operations ============

    function test_Load_RapidSequential() public {
        console.log("Testing rapid sequential operations...");

        uint256 rapidCount = 50;
        uint256 totalGasUsed = 0;

        for (uint256 i = 0; i < rapidCount; i++) {
            address creator = address(uint160(0xF000 + i));
            vm.deal(creator, 3 ether);

            uint256 gasBeforeCreate = gasleft();

            vm.prank(creator);
            uint256 partyId = partyStarter.createInstantParty{value: 1.5 ether}(
                createTokenMetadata(
                    string(abi.encodePacked("Rapid", vm.toString(i))),
                    string(abi.encodePacked("RAP", vm.toString(i % 1000)))
                )
            );

            uint256 gasAfterCreate = gasleft();
            totalGasUsed += gasBeforeCreate - gasAfterCreate;

            assertPartyLaunched(partyId);
        }

        uint256 avgGas = totalGasUsed / rapidCount;

        console.log("=== RAPID TEST RESULTS ===");
        console.log("Parties created:", rapidCount);
        console.log("Average gas:", avgGas);
        console.log("===========================");

        assertTrue(avgGas < 2000000); // Average under 2M gas
    }

    // ============ System Recovery Tests ============

    function test_Load_SystemRecovery_AfterFailures() public {
        console.log("Testing system recovery after partial failures...");

        uint256 successCount = 0;
        uint256 failureCount = 0;

        for (uint256 i = 0; i < 100; i++) {
            address creator = address(uint160(0x10000 + i));

            // Alternate between valid and invalid scenarios
            if (i % 10 == 0) {
                // Invalid scenario - no ETH balance
                vm.deal(creator, 0);

                vm.prank(creator);
                try
                    partyStarter.createInstantParty{value: 0}(
                        createDefaultMetadata()
                    )
                {
                    // Should not succeed
                    assertTrue(false, "Should have failed with 0 ETH");
                } catch {
                    failureCount++;
                }
            } else {
                // Valid scenario
                vm.deal(creator, 2 ether);

                vm.prank(creator);
                try
                    partyStarter.createInstantParty{value: 1 ether}(
                        generateRandomMetadata(i)
                    )
                returns (uint256 partyId) {
                    assertPartyLaunched(partyId);
                    successCount++;
                } catch {
                    failureCount++;
                }
            }
        }

        console.log("=== SYSTEM RECOVERY TEST RESULTS ===");
        console.log("Successful operations:", successCount);
        console.log("Failed operations:", failureCount);
        console.log(
            "Success rate:",
            (successCount * 100) / (successCount + failureCount),
            "%"
        );
        console.log(
            "Final system state is healthy:",
            partyStarter.partyCounter() == successCount
        );
        console.log("=====================================");

        // System should maintain consistency despite failures
        assertEq(partyStarter.partyCounter(), successCount);
        assertTrue(successCount > 0); // Some operations should have succeeded
        assertTrue(failureCount > 0); // Some operations should have failed as expected
    }
}
