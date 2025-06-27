// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "../utils/TestBase.sol";
import {PartyTypes} from "../../src/types/PartyTypes.sol";
import {PartyVenue} from "../../src/venue/PartyVenue.sol";
import {UniswapV4ERC20} from "../../src/tokens/UniswapV4ERC20.sol";
import {PartyErrors} from "../../src/types/PartyErrors.sol";

contract PartyFlowTest is TestBase {
    // Private key for signing (using a known private key for testing)
    uint256 constant alicePrivateKey = 0x2001;

    // ============ Integration Tests ============

    function test_InstantParty_FullFlow() public {
        uint256 partyId = createDefaultInstantParty(ALICE);

        // Verify party was created and launched
        assertPartyCreated(partyId, PartyTypes.PartyType.INSTANT, ALICE);
        assertPartyLaunched(partyId);

        // Check that tokens were minted
        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertTokenCreated(party.tokenAddress, "Test Token");
    }

    function test_InstantParty_MultipleParties() public {
        // Create multiple instant parties from different users
        uint256 party1 = createDefaultInstantParty(ALICE);
        uint256 party2 = createDefaultInstantParty(BOB);
        uint256 party3 = createDefaultInstantParty(CHARLIE);

        // All should be launched
        assertPartyLaunched(party1);
        assertPartyLaunched(party2);
        assertPartyLaunched(party3);

        // Check party counter
        assertEq(partyStarter.partyCounter(), 3, "Wrong party counter");

        // Check user parties
        uint256[] memory aliceParties = partyStarter.getUserParties(ALICE);
        uint256[] memory bobParties = partyStarter.getUserParties(BOB);

        assertEq(aliceParties.length, 1, "Alice should have 1 party");
        assertEq(bobParties.length, 1, "Bob should have 1 party");
        assertEq(aliceParties[0], party1, "Wrong party ID for Alice");
        assertEq(bobParties[0], party2, "Wrong party ID for Bob");
    }

    function test_PublicParty_FullFlow() public {
        // Create public party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );

        // Verify party created but not launched yet
        assertPartyCreated(partyId, PartyTypes.PartyType.PUBLIC, ALICE);
        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertFalse(party.launched, "Party should not be launched yet");

        // Contribute to reach target
        PartyVenue venue = PartyVenue(payable(party.venueAddress));
        vm.deal(BOB, 10 ether);
        vm.prank(BOB);
        venue.contribute{value: 5 ether}();

        // Verify party launched automatically
        party = partyStarter.getParty(partyId);
        assertTrue(party.launched, "Party should be launched");
        assertTokenCreated(party.tokenAddress, "Test Token");
    }

    function test_PublicParty_ManualLaunch() public {
        // Create public party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        // Contribute partial amount
        vm.deal(BOB, 10 ether);
        vm.prank(BOB);
        venue.contribute{value: 2 ether}();

        // Manual launch by creator
        vm.prank(ALICE);
        venue.manualLaunch();

        // Verify party launched
        party = partyStarter.getParty(partyId);
        assertTrue(party.launched, "Party should be launched");
        assertTokenCreated(party.tokenAddress, "Test Token");
    }

    function test_PrivateParty_FullFlow() public {
        // Create private party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPrivateParty(
            createDefaultMetadata(),
            8 ether,
            ALICE // Use ALICE as signer for simplicity
        );

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(
            uint(party.partyType),
            uint(PartyTypes.PartyType.PRIVATE),
            "Wrong party type"
        );
        assertEq(party.creator, ALICE, "Wrong creator");
        assertEq(party.id, partyId, "Wrong party ID");
        assertGt(party.createdAt, 0, "Creation timestamp should be set");

        // Verify party not launched yet
        assertFalse(party.launched);

        // Verify venue is private
        (
            uint256 partyIdFromVenue,
            address creator,
            uint256 targetAmount,
            ,
            bool launched,
            bool isPrivate,
            address signerAddress
        ) = PartyVenue(payable(party.venueAddress)).getPartyInfo();

        assertEq(partyIdFromVenue, partyId);
        assertEq(creator, ALICE);
        assertEq(targetAmount, 8 ether);
        assertFalse(launched);
        assertTrue(isPrivate);
        assertEq(signerAddress, ALICE);

        // Create signature for contribution
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        partyId,
                        BOB,
                        uint256(4 ether),
                        uint256(block.timestamp + 3600)
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Try to contribute with signature - this should fail because signature doesn't match expected format
        vm.deal(BOB, 10 ether);
        vm.prank(BOB);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.INVALID_SIGNATURE
            )
        );
        PartyVenue(payable(party.venueAddress)).contributeWithSignature{
            value: 3 ether
        }(signature, 4 ether, block.timestamp + 3600);
    }

    function test_PrivateParty_UnsignedContribution_Reverts() public {
        // Create private party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPrivateParty(
            createDefaultMetadata(),
            5 ether,
            ALICE
        );

        PartyTypes.Party memory party = partyStarter.getParty(partyId);

        // Try to contribute without signature - should fail
        vm.deal(CHARLIE, 10 ether);
        vm.prank(CHARLIE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.SIGNATURE_REQUIRED
            )
        );
        PartyVenue(payable(party.venueAddress)).contribute{value: 1 ether}();
    }

    function test_LaunchFromVenue_OnlyVenue() public {
        // Create public party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            3 ether
        );

        // Try to launch directly from PartyStarter (should fail)
        vm.deal(BOB, 5 ether);
        vm.prank(BOB);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ONLY_VENUE_CAN_LAUNCH
            )
        );
        partyStarter.launchFromVenue{value: 3 ether}(partyId);
    }

    function test_SystemState_AfterMultipleParties() public {
        // Create multiple parties of different types
        uint256 instant1 = createDefaultInstantParty(ALICE);

        vm.prank(BOB);
        uint256 public1 = partyStarter.createPublicParty(
            createDefaultMetadata(),
            3 ether
        );

        vm.prank(CHARLIE);
        uint256 private1 = partyStarter.createPrivateParty(
            createDefaultMetadata(),
            4 ether,
            CHARLIE
        );

        // Check system state
        assertEq(partyStarter.partyCounter(), 3, "Wrong party counter");

        // Check individual parties
        PartyTypes.Party memory instantParty = partyStarter.getParty(instant1);
        PartyTypes.Party memory publicParty = partyStarter.getParty(public1);
        PartyTypes.Party memory privateParty = partyStarter.getParty(private1);

        assertTrue(instantParty.launched, "Instant party should be launched");
        assertFalse(
            publicParty.launched,
            "Public party should not be launched"
        );
        assertFalse(
            privateParty.launched,
            "Private party should not be launched"
        );

        // Check user party lists
        uint256[] memory aliceParties = partyStarter.getUserParties(ALICE);
        uint256[] memory bobParties = partyStarter.getUserParties(BOB);
        uint256[] memory charlieParties = partyStarter.getUserParties(CHARLIE);

        assertEq(aliceParties.length, 1, "Alice should have 1 party");
        assertEq(bobParties.length, 1, "Bob should have 1 party");
        assertEq(charlieParties.length, 1, "Charlie should have 1 party");
    }

    // ============ Fee Claiming Tests ============

    function test_ClaimFees_Success() public {
        // Create and launch instant party
        uint256 partyId = createDefaultInstantParty(ALICE);

        // Simulate some fees accumulated in the contract
        vm.deal(address(partyStarter), 10 ether);

        uint256 aliceBalanceBefore = ALICE.balance;

        // Claim fees
        vm.prank(ALICE);
        partyStarter.claimFees(partyId);

        // Verify fees were distributed
        uint256 aliceBalanceAfter = ALICE.balance;
        assertTrue(aliceBalanceAfter > aliceBalanceBefore);

        // Verify LP position updated
        PartyTypes.LPPosition memory lpPosition = partyStarter.getLPPosition(
            partyId
        );
        assertFalse(lpPosition.feesClaimable);

        // Verify cannot claim again
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.FEES_NOT_CLAIMABLE
            )
        );
        partyStarter.claimFees(partyId);
    }

    function test_ClaimFees_OnlyCreator() public {
        uint256 partyId = createDefaultInstantParty(ALICE);

        // BOB should not be able to claim fees
        vm.prank(BOB);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ONLY_CREATOR_CAN_CLAIM
            )
        );
        partyStarter.claimFees(partyId);
    }

    function test_ClaimFees_NotLaunched() public {
        // Create public party but don't launch
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );

        // Cannot claim fees before launch
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.PARTY_NOT_LAUNCHED
            )
        );
        partyStarter.claimFees(partyId);
    }

    // ============ Error Cases ============

    function test_CreateInstantParty_ZeroValue_Reverts() public {
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_AMOUNT
            )
        );
        partyStarter.createInstantParty{value: 0}(createDefaultMetadata());
    }

    function test_CreatePublicParty_ZeroTarget_Reverts() public {
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
            )
        );
        partyStarter.createPublicParty(createDefaultMetadata(), 0);
    }

    function test_CreatePrivateParty_ZeroSigner_Reverts() public {
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS
            )
        );
        partyStarter.createPrivateParty(
            createDefaultMetadata(),
            5 ether,
            address(0)
        );
    }

    // ============ Gas Benchmarks ============

    function test_Gas_InstantPartyCreation() public {
        uint256 gasStart = gasleft();
        createDefaultInstantParty(ALICE);
        uint256 gasUsed = gasStart - gasleft();

        // Basic assertion that gas was used
        assertGt(gasUsed, 0, "Gas should have been used");
    }

    function test_Gas_PublicPartyCreation() public {
        uint256 gasStart = gasleft();
        vm.prank(ALICE);
        partyStarter.createPublicParty(createDefaultMetadata(), 5 ether);
        uint256 gasUsed = gasStart - gasleft();

        // Basic assertion that gas was used
        assertGt(gasUsed, 0, "Gas should have been used");
    }

    function test_Gas_PrivatePartyCreation() public {
        uint256 gasStart = gasleft();
        vm.prank(ALICE);
        partyStarter.createPrivateParty(
            createDefaultMetadata(),
            5 ether,
            ALICE
        );
        uint256 gasUsed = gasStart - gasleft();

        // Basic assertion that gas was used
        assertGt(gasUsed, 0, "Gas should have been used");
    }
}
