// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "./utils/TestBase.sol";
import {console} from "forge-std/console.sol";
import {PartyTypes} from "../src/types/PartyTypes.sol";
import {PartyVenue} from "../src/venue/PartyVenue.sol";
import {PartyStarter} from "../src/PartyStarter.sol";
import {IPartyStarter} from "../src/interfaces/IPartyStarter.sol";

/**
 * @title TestRunner
 * @dev Comprehensive test suite runner for the party system
 *
 * This contract orchestrates all tests and provides detailed reporting.
 * Run with: forge test --match-contract TestRunner -vvv
 */
contract TestRunner is TestBase {
    function test_RunAllTests() public {
        console.log("========================================");
        console.log("PARTY SYSTEM COMPREHENSIVE TEST SUITE");
        console.log("========================================");

        runBasicFunctionalityTests();
        runSecurityTests();
        runPerformanceTests();
        runIntegrationTests();

        console.log("\n========================================");
        console.log("ALL TESTS COMPLETED SUCCESSFULLY");
        console.log("========================================");
    }

    function runBasicFunctionalityTests() internal {
        console.log("\nRUNNING BASIC FUNCTIONALITY TESTS...");

        test_BasicFunctionality_InstantParty();
        test_BasicFunctionality_PublicParty();
        test_BasicFunctionality_PrivateParty();
        test_BasicFunctionality_FeeClaiming();

        console.log("Basic functionality tests passed");
    }

    function runSecurityTests() internal {
        console.log("\nRUNNING SECURITY TESTS...");

        test_Security_AccessControl();
        test_Security_ReentrancyProtection();
        test_Security_InputValidation();
        test_Security_FeeManipulation();

        console.log("Security tests passed");
    }

    function runPerformanceTests() internal {
        console.log("\nRUNNING PERFORMANCE TESTS...");

        test_Performance_GasEfficiency();
        test_Performance_HighVolumeOperations();
        test_Performance_StateScaling();

        console.log("Performance tests passed");
    }

    function runIntegrationTests() internal {
        console.log("\nRUNNING INTEGRATION TESTS...");

        test_Integration_FullPartyLifecycle();
        test_Integration_MultiUserScenarios();
        test_Integration_SystemConsistency();

        console.log("Integration tests passed");
    }

    // ============ Basic Functionality Tests ============

    function test_BasicFunctionality_InstantParty() internal {
        console.log("  Testing instant party creation...");

        uint256 ethAmount = 2 ether;
        vm.deal(ALICE, ethAmount + 1 ether);

        startMeasureGas();
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createInstantParty{value: ethAmount}(
            createTokenMetadata("Test Instant", "INST")
        );
        endMeasureGas();

        // Verify instant party
        assertPartyCreated(partyId, PartyTypes.PartyType.INSTANT, ALICE);
        assertPartyLaunched(partyId);

        // Verify token creation and distribution
        PartyTypes.Party memory party = getPartyDetails(partyId);
        assertTokenCreated(party.tokenAddress, "Test Instant");

        printGasReport("Instant Party Creation");
    }

    function test_BasicFunctionality_PublicParty() internal {
        console.log("  Testing public party with contributions...");

        // Create public party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            createTokenMetadata("Test Public", "PUB"),
            5 ether
        );

        assertPartyCreated(partyId, PartyTypes.PartyType.PUBLIC, ALICE);
        assertFalse(isPartyLaunched(partyId));

        // Contribute to launch
        PartyTypes.Party memory party = getPartyDetails(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        vm.deal(BOB, 6 ether);
        vm.prank(BOB);
        venue.contribute{value: 5 ether}();

        // Should auto-launch
        assertTrue(isPartyLaunched(partyId));
    }

    function test_BasicFunctionality_PrivateParty() internal {
        console.log("  Testing private party with signature authorization...");

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPrivateParty(
            createTokenMetadata("Test Private", "PRIV"),
            3 ether,
            ALICE
        );

        assertPartyCreated(partyId, PartyTypes.PartyType.PRIVATE, ALICE);

        // Test signature-based authorization
        PartyTypes.Party memory party = getPartyDetails(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        // Create a signature for BOB to contribute
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        partyId,
                        BOB,
                        uint256(5 ether),
                        block.timestamp + 1 hours
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash); // Use Alice's private key (assuming key 1)
        bytes memory signature = abi.encodePacked(r, s, v);

        // Authorized user can contribute with signature
        vm.deal(BOB, 4 ether);
        vm.prank(BOB);
        venue.contributeWithSignature{value: 3 ether}(
            signature,
            5 ether,
            block.timestamp + 1 hours
        );

        assertTrue(isPartyLaunched(partyId));
    }

    function test_BasicFunctionality_FeeClaiming() internal {
        console.log("  Testing fee claiming mechanism...");

        uint256 partyId = createDefaultInstantParty(ALICE);

        // Simulate accumulated fees
        vm.deal(address(partyStarter), 10 ether);

        uint256 aliceBalanceBefore = ALICE.balance;

        vm.prank(ALICE);
        partyStarter.claimFees(partyId);

        uint256 aliceBalanceAfter = ALICE.balance;
        assertGt(aliceBalanceAfter, aliceBalanceBefore, "Should receive fees");

        // Verify cannot claim twice
        vm.prank(ALICE);
        vm.expectRevert("Fees already claimed or not available");
        partyStarter.claimFees(partyId);
    }

    // ============ Security Tests ============

    function test_Security_AccessControl() internal {
        console.log("  Testing access control mechanisms...");

        uint256 partyId = createDefaultInstantParty(ALICE);

        // Only creator can claim fees
        vm.prank(BOB);
        vm.expectRevert("Only creator can claim fees");
        partyStarter.claimFees(partyId);

        // Only owner can update configuration
        PartyTypes.FeeConfiguration memory newConfig = PartyTypes
            .FeeConfiguration({
                platformFeeBPS: 200,
                vaultFeeBPS: 200,
                devFeeShare: 60,
                platformTreasury: address(0x5555)
            });

        vm.prank(ALICE);
        vm.expectRevert("UNAUTHORIZED");
        partyStarter.updateFeeConfiguration(newConfig);
    }

    function test_Security_ReentrancyProtection() internal {
        console.log("  Testing reentrancy protection...");

        // Deploy malicious contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(partyStarter);
        vm.deal(address(attacker), 5 ether);

        uint256 initialPartyCount = partyStarter.partyCounter();

        // Attempt reentrancy
        try attacker.attackInstantParty{value: 2 ether}() {
            // Should only create one party, not multiple
            assertEq(partyStarter.partyCounter(), initialPartyCount + 1);
        } catch {
            // Revert is also acceptable
        }
    }

    function test_Security_InputValidation() internal {
        console.log("  Testing input validation...");

        // Test various invalid inputs
        vm.prank(ALICE);
        vm.expectRevert("Must send ETH for liquidity");
        partyStarter.createInstantParty{value: 0}(createDefaultMetadata());

        vm.prank(ALICE);
        vm.expectRevert("Target liquidity must be greater than 0");
        partyStarter.createPublicParty(createDefaultMetadata(), 0);

        // Invalid metadata
        vm.prank(ALICE);
        vm.expectRevert("Token name cannot be empty");
        partyStarter.createInstantParty{value: 1 ether}(
            createTokenMetadata("", "INVALID")
        );
    }

    function test_Security_FeeManipulation() internal {
        console.log("  Testing fee calculation accuracy...");

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 10 ether;
        amounts[2] = 100 ether;

        for (uint256 i = 0; i < amounts.length; i++) {
            address creator = address(uint160(0x8000 + i));
            vm.deal(creator, amounts[i] + 1 ether);

            uint256 treasuryBefore = TREASURY.balance;

            vm.prank(creator);
            uint256 partyId = partyStarter.createInstantParty{
                value: amounts[i]
            }(generateRandomMetadata(i));

            // Verify fee calculation
            uint256 expectedFee = (amounts[i] * PartyTypes.PLATFORM_FEE_BPS) /
                10000;
            uint256 actualFee = TREASURY.balance - treasuryBefore;
            assertEq(actualFee, expectedFee, "Fee calculation mismatch");

            PartyTypes.Party memory party = getPartyDetails(partyId);
            assertEq(party.totalLiquidity, amounts[i] - expectedFee);
        }
    }

    // ============ Performance Tests ============

    function test_Performance_GasEfficiency() internal {
        console.log("  Testing gas efficiency...");

        // Test instant party gas usage
        vm.deal(ALICE, 5 ether);

        startMeasureGas();
        vm.prank(ALICE);
        partyStarter.createInstantParty{value: 2 ether}(
            createDefaultMetadata()
        );
        uint256 gasUsed = endMeasureGas();

        assertTrue(gasUsed < 2000000, "Gas usage too high for instant party");
        printGasReport("Instant Party Gas Test");

        // Test public party gas usage
        startMeasureGas();
        vm.prank(BOB);
        partyStarter.createPublicParty(createDefaultMetadata(), 5 ether);
        gasUsed = endMeasureGas();

        assertTrue(gasUsed < 1500000, "Gas usage too high for public party");
        printGasReport("Public Party Gas Test");
    }

    function test_Performance_HighVolumeOperations() internal {
        console.log("  Testing high volume operations...");

        uint256 partyCount = 20; // Reduced for test efficiency
        uint256 totalGasUsed = 0;

        for (uint256 i = 0; i < partyCount; i++) {
            address creator = address(uint160(0x7000 + i));
            vm.deal(creator, 3 ether);

            uint256 gasBefore = gasleft();

            vm.prank(creator);
            partyStarter.createInstantParty{value: 1 ether}(
                generateRandomMetadata(i)
            );

            totalGasUsed += gasBefore - gasleft();
        }

        uint256 avgGas = totalGasUsed / partyCount;
        assertTrue(
            avgGas < 2000000,
            "Average gas too high for volume operations"
        );

        console.log("    Created", partyCount, "parties with avg gas:", avgGas);
    }

    function test_Performance_StateScaling() internal {
        console.log("  Testing state scaling...");

        uint256 initialPartyCount = partyStarter.partyCounter();

        // Create multiple parties to test state growth
        for (uint256 i = 0; i < 10; i++) {
            address creator = address(uint160(0x6000 + i));
            vm.deal(creator, 3 ether);

            vm.prank(creator);
            partyStarter.createInstantParty{value: 1 ether}(
                generateRandomMetadata(i + 100)
            );
        }

        // Verify state consistency
        assertEq(partyStarter.partyCounter(), initialPartyCount + 10);

        // Test random access to verify state integrity
        for (uint256 i = 0; i < 5; i++) {
            uint256 randomPartyId = initialPartyCount + i + 1;
            PartyTypes.Party memory party = getPartyDetails(randomPartyId);
            assertTrue(party.launched, "Party should be launched");
            assertTrue(party.tokenAddress != address(0), "Token should exist");
        }
    }

    // ============ Integration Tests ============

    function test_Integration_FullPartyLifecycle() internal {
        console.log("  Testing full party lifecycle...");

        // Create public party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            createTokenMetadata("Lifecycle Test", "LIFE"),
            4 ether
        );

        // Multiple contributors
        PartyTypes.Party memory party = getPartyDetails(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        vm.deal(BOB, 3 ether);
        vm.deal(CHARLIE, 3 ether);

        vm.prank(BOB);
        venue.contribute{value: 2 ether}();

        vm.prank(CHARLIE);
        venue.contribute{value: 2 ether}();

        // Should launch automatically
        assertTrue(isPartyLaunched(partyId));

        // Verify final state
        party = getPartyDetails(partyId);
        assertTrue(party.tokenAddress != address(0));
        assertGt(party.totalLiquidity, 0);
    }

    function test_Integration_MultiUserScenarios() internal {
        console.log("  Testing multi-user scenarios...");

        address[] memory users = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            users[i] = address(uint160(0x5000 + i));
            vm.deal(users[i], 10 ether);
        }

        // Each user creates a different type of party
        for (uint256 i = 0; i < 5; i++) {
            if (i % 3 == 0) {
                // Instant party
                vm.prank(users[i]);
                partyStarter.createInstantParty{value: 1 ether}(
                    generateRandomMetadata(i + 200)
                );
            } else if (i % 3 == 1) {
                // Public party
                vm.prank(users[i]);
                partyStarter.createPublicParty(
                    generateRandomMetadata(i + 300),
                    3 ether
                );
            } else {
                // Private party
                vm.prank(users[i]);
                partyStarter.createPrivateParty(
                    generateRandomMetadata(i + 400),
                    2 ether,
                    users[i]
                );
            }
        }

        // Verify all users have parties
        for (uint256 i = 0; i < 5; i++) {
            uint256[] memory userParties = partyStarter.getUserParties(
                users[i]
            );
            assertEq(userParties.length, 1, "Each user should have one party");
        }
    }

    function test_Integration_SystemConsistency() internal {
        console.log("  Testing system consistency...");

        uint256 initialTreasuryBalance = TREASURY.balance;
        uint256 initialVaultTokens = partyVault.getTokenCount();
        uint256 initialPartyCount = partyStarter.partyCounter();

        // Perform mixed operations
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(0x4000 + i));
            vm.deal(user, 5 ether);

            if (i % 2 == 0) {
                // Create instant party
                vm.prank(user);
                partyStarter.createInstantParty{value: 1 ether}(
                    generateRandomMetadata(i + 500)
                );
            } else {
                // Create public party and contribute
                vm.prank(user);
                uint256 partyId = partyStarter.createPublicParty(
                    generateRandomMetadata(i + 600),
                    2 ether
                );

                // Contribute to launch it
                PartyTypes.Party memory party = getPartyDetails(partyId);
                PartyVenue venue = PartyVenue(payable(party.venueAddress));

                vm.prank(user);
                venue.contribute{value: 2 ether}();
            }
        }

        // Verify system consistency
        uint256 finalPartyCount = partyStarter.partyCounter();
        uint256 finalTreasuryBalance = TREASURY.balance;
        uint256 finalVaultTokens = partyVault.getTokenCount();

        assertEq(
            finalPartyCount,
            initialPartyCount + 10,
            "Party count should increase by 10"
        );
        assertGt(
            finalTreasuryBalance,
            initialTreasuryBalance,
            "Treasury should collect fees"
        );
        assertGt(
            finalVaultTokens,
            initialVaultTokens,
            "Vault should receive tokens"
        );

        // console.log(
        //     "    Final state - Parties:",
        //     finalPartyCount,
        //     "Treasury:",
        //     finalTreasuryBalance,
        //     "Vault tokens:",
        //     finalVaultTokens
        // );
    }
}

// ============ Reentrancy Test Contract ============

contract ReentrancyAttacker {
    IPartyStarter public partyStarter;
    bool public hasAttacked = false;

    constructor(IPartyStarter _partyStarter) {
        partyStarter = _partyStarter;
    }

    function attackInstantParty() external payable {
        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: "Attack Token",
            symbol: "ATK",
            description: "Reentrancy attack test",
            image: "",
            website: "",
            twitter: "",
            telegram: ""
        });

        partyStarter.createInstantParty{value: msg.value}(metadata);
    }

    receive() external payable {
        if (!hasAttacked && address(this).balance > 1 ether) {
            hasAttacked = true;
            try
                partyStarter.createInstantParty{value: 1 ether}(
                    PartyTypes.TokenMetadata({
                        name: "Reentrancy Token",
                        symbol: "REEN",
                        description: "Reentrancy attempt",
                        image: "",
                        website: "",
                        twitter: "",
                        telegram: ""
                    })
                )
            {
                // Should not succeed
            } catch {
                // Expected to fail
            }
        }
    }
}
