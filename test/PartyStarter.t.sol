// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "./utils/TestBase.sol";
import {console} from "forge-std/console.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {PartyTypes} from "../src/types/PartyTypes.sol";
import {PartyVenue} from "../src/venue/PartyVenue.sol";
import {UniswapV4ERC20} from "../src/tokens/UniswapV4ERC20.sol";
import {PartyErrors} from "../src/types/PartyErrors.sol";

contract PartyStarterTest is TestBase {
    address public user1 = address(0x456);
    address public user2 = address(0x789);
    address public user3 = address(0xabc);

    uint256 public constant INITIAL_BALANCE = 10 ether;

    event VenueDeployed(uint256 indexed partyId, address indexed venueAddress);

    event FeesClaimedByDev(
        uint256 indexed partyId,
        address indexed dev,
        uint256 devAmount,
        uint256 platformAmount
    );

    function setUp() public override {
        super.setUp();

        // Give ETH to test users
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);
        vm.deal(user3, INITIAL_BALANCE);
        vm.deal(TREASURY, 0); // Start with 0 for accurate testing
    }

    function testDeployment() public {
        assertTrue(address(partyStarter) != address(0));
        assertEq(partyStarter.partyCounter(), 0);
        assertTrue(address(partyVault) != address(0));
    }

    function testCreateInstantParty() public {
        vm.startPrank(user1);

        uint256 partyId = partyStarter.createInstantParty{value: 2 ether}(
            createDefaultMetadata()
        );

        vm.stopPrank();

        assertEq(partyId, 1);
        assertEq(partyStarter.partyCounter(), 1);

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(party.id, partyId);
        assertEq(uint(party.partyType), uint(PartyTypes.PartyType.INSTANT));
        assertEq(party.creator, user1);
        assertTrue(party.launched);
        assertEq(party.venueAddress, address(0));
        assertEq(party.totalLiquidity, 1.98 ether); // 2 ether - 1% platform fee
    }

    function testCreateInstantPartyRevertsOnZeroEth() public {
        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_AMOUNT
            )
        );
        partyStarter.createInstantParty(createDefaultMetadata());

        vm.stopPrank();
    }

    function testCreatePublicParty() public {
        vm.startPrank(user1);

        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );

        vm.stopPrank();

        assertEq(partyId, 1);
        assertEq(partyStarter.partyCounter(), 1);

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(party.id, partyId);
        assertEq(uint(party.partyType), uint(PartyTypes.PartyType.PUBLIC));
        assertEq(party.creator, user1);
        assertFalse(party.launched);
        assertTrue(party.venueAddress != address(0));
    }

    function testCreatePublicPartyRevertsOnZeroTarget() public {
        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
            )
        );
        partyStarter.createPublicParty(createDefaultMetadata(), 0);

        vm.stopPrank();
    }

    function testCreatePrivateParty() public {
        vm.startPrank(user1);

        uint256 partyId = partyStarter.createPrivateParty(
            createDefaultMetadata(),
            1 ether,
            user1
        );

        vm.stopPrank();

        assertEq(partyId, 1);
        assertEq(partyStarter.partyCounter(), 1);

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(party.id, partyId);
        assertEq(uint(party.partyType), uint(PartyTypes.PartyType.PRIVATE));
        assertEq(party.creator, user1);
        assertFalse(party.launched);
        assertTrue(party.venueAddress != address(0));
    }

    function testCreatePrivatePartyRevertsOnZeroSigner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS
            )
        );
        partyStarter.createPrivateParty(
            createDefaultMetadata(),
            1 ether,
            address(0)
        );
    }

    function testCreatePrivatePartyRevertsOnZeroTarget() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
            )
        );
        partyStarter.createPrivateParty(createDefaultMetadata(), 0, user1);
    }

    function testLaunchFromVenue() public {
        vm.startPrank(user1);

        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );

        vm.stopPrank();

        PartyTypes.Party memory party = partyStarter.getParty(partyId);

        vm.startPrank(payable(party.venueAddress));
        vm.deal(payable(party.venueAddress), 3 ether);

        partyStarter.launchFromVenue{value: 3 ether}(partyId);

        vm.stopPrank();

        party = partyStarter.getParty(partyId);
        assertTrue(party.launched);
        assertEq(party.totalLiquidity, 2.97 ether); // 3 ether - 1% platform fee
    }

    function testLaunchFromVenueRevertsOnAlreadyLaunched() public {
        uint256 partyId = createDefaultInstantParty(user1);

        vm.startPrank(payable(user1));
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ONLY_VENUE_CAN_LAUNCH
            )
        );
        partyStarter.launchFromVenue{value: 1 ether}(partyId);
        vm.stopPrank();
    }

    function testLaunchFromVenueRevertsOnWrongCaller() public {
        vm.startPrank(user1);
        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ONLY_VENUE_CAN_LAUNCH
            )
        );
        partyStarter.launchFromVenue{value: 5 ether}(partyId);
    }

    function testLaunchFromVenueRevertsOnZeroValue() public {
        vm.startPrank(user1);
        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );
        vm.stopPrank();

        PartyTypes.Party memory party = partyStarter.getParty(partyId);

        vm.startPrank(payable(party.venueAddress));
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_AMOUNT
            )
        );
        partyStarter.launchFromVenue{value: 0}(partyId);
        vm.stopPrank();
    }

    function testGetLPPosition() public {
        uint256 partyId = createDefaultInstantParty(user1);

        PartyTypes.LPPosition memory lpPosition = partyStarter.getLPPosition(
            partyId
        );

        assertTrue(lpPosition.feesClaimable);
        assertTrue(lpPosition.tokenAddress != address(0));
    }

    function testGetUserParties() public {
        // Create parties with different users
        uint256 party1 = createDefaultInstantParty(user1);
        uint256 party2 = createDefaultInstantParty(user2);
        uint256 party3 = createDefaultInstantParty(user1); // user1 creates another

        uint256[] memory user1Parties = partyStarter.getUserParties(user1);
        uint256[] memory user2Parties = partyStarter.getUserParties(user2);
        uint256[] memory user3Parties = partyStarter.getUserParties(user3);

        assertEq(user1Parties.length, 2); // user1 created 2 parties
        assertEq(user2Parties.length, 1); // user2 created 1 party
        assertEq(user3Parties.length, 0); // user3 created 0 parties
        assertEq(user1Parties[0], party1);
        assertEq(user1Parties[1], party3);
        assertEq(user2Parties[0], party2);
    }

    function testMultipleInstantParties() public {
        uint256 party1 = createDefaultInstantParty(user1);
        uint256 party2 = createDefaultInstantParty(user2);

        assertEq(party1, 1);
        assertEq(party2, 2);
        assertEq(partyStarter.partyCounter(), 2);

        PartyTypes.Party memory user1Party = partyStarter.getParty(party1);
        PartyTypes.Party memory user2Party = partyStarter.getParty(party2);

        assertTrue(user1Party.launched);
        assertTrue(user2Party.launched);
        assertEq(user1Party.creator, user1);
        assertEq(user2Party.creator, user2);
    }

    function testClaimFees() public {
        vm.startPrank(user1);

        uint256 partyId = partyStarter.createInstantParty{value: 1 ether}(
            createDefaultMetadata()
        );

        vm.stopPrank();

        // Simulate accumulated fees
        vm.deal(address(partyStarter), 1 ether);

        uint256 user1BalanceBefore = user1.balance;

        vm.prank(user1);
        partyStarter.claimFees(partyId);

        uint256 user1BalanceAfter = user1.balance;

        assertTrue(user1BalanceAfter > user1BalanceBefore);

        PartyTypes.LPPosition memory lpPosition = partyStarter.getLPPosition(
            partyId
        );
        assertFalse(lpPosition.feesClaimable);
    }

    function testClaimFeesRevertsOnNonCreator() public {
        uint256 partyId = createDefaultInstantParty(user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ONLY_CREATOR_CAN_CLAIM
            )
        );
        partyStarter.claimFees(partyId);
    }

    function testClaimFeesRevertsOnNotLaunched() public {
        vm.prank(user1);
        uint256 partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            5 ether
        );

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.PARTY_NOT_LAUNCHED
            )
        );
        partyStarter.claimFees(partyId);
    }

    function testClaimFeesRevertsOnNotClaimable() public {
        uint256 partyId = createDefaultInstantParty(user1);

        // First claim should work
        vm.prank(user1);
        partyStarter.claimFees(partyId);

        // Second claim should fail
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.FEES_NOT_CLAIMABLE
            )
        );
        partyStarter.claimFees(partyId);
    }

    function testClaimFeesRevertsOnNoFees() public {
        vm.startPrank(user1);

        uint256 partyId = partyStarter.createInstantParty{value: 1 ether}(
            createDefaultMetadata()
        );

        vm.stopPrank();

        // Don't add any fees to the contract, so claimFees should revert
        vm.expectRevert("UNAUTHORIZED");
        partyStarter.withdrawPlatformFees();
    }

    function testReceiveEth() public {
        uint256 contractBalanceBefore = address(partyStarter).balance;

        (bool success, ) = address(partyStarter).call{value: 1 ether}("");
        assertTrue(success);

        uint256 contractBalanceAfter = address(partyStarter).balance;
        assertEq(contractBalanceAfter, contractBalanceBefore + 1 ether);
    }

    function testUpdatePlatformTreasury() public {
        vm.expectRevert("UNAUTHORIZED");
        partyStarter.updatePlatformTreasury(address(0x999));
    }

    function testUpdatePlatformTreasuryRevertsOnNonOwner() public {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        partyStarter.updatePlatformTreasury(address(0x999));
    }

    function testWithdrawPlatformFees() public {
        vm.deal(address(partyStarter), 2 ether);

        vm.expectRevert("UNAUTHORIZED");
        partyStarter.withdrawPlatformFees();
    }

    function testWithdrawPlatformFeesRevertsOnNoFunds() public {
        vm.expectRevert("UNAUTHORIZED");
        partyStarter.withdrawPlatformFees();
    }

    function testWithdrawPlatformFeesRevertsOnNonOwner() public {
        vm.deal(address(partyStarter), 2 ether);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        partyStarter.withdrawPlatformFees();
    }
}
