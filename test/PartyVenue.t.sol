// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PartyVenue} from "../src/venue/PartyVenue.sol";
import {PartyTypes} from "../src/types/PartyTypes.sol";
import {PartyErrors} from "../src/types/PartyErrors.sol";

// Mock PartyStarter for testing
contract MockPartyStarter {
    bool public shouldRevert;
    uint256 public lastPartyId;
    uint256 public lastValue;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function launchFromVenue(uint256 partyId) external payable {
        if (shouldRevert) {
            revert("Mock revert");
        }
        lastPartyId = partyId;
        lastValue = msg.value;
    }

    receive() external payable {}
}

contract PartyVenueTest is Test {
    PartyVenue public publicVenue;
    PartyVenue public privateVenue;
    MockPartyStarter public mockPartyStarter;

    address public creator = address(0x1234);
    address public user1 = address(0x5678);
    address public user2 = address(0x9abc);
    address public user3 = address(0xdef0);
    address public signer; // Will be set from private key
    address public unauthorizedUser = address(0x2222);

    uint256 public signerPrivateKey =
        0x1234567890123456789012345678901234567890123456789012345678901234;

    uint256 public constant PARTY_ID = 1;
    uint256 public constant TARGET_AMOUNT = 5 ether;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event PartyLaunched(uint256 totalAmount);
    event SignerUpdated(address indexed newSigner);

    function setUp() public {
        // Derive signer address from private key
        signer = vm.addr(signerPrivateKey);

        // Deploy mock PartyStarter
        mockPartyStarter = new MockPartyStarter();

        // Deploy venues from mock PartyStarter context
        vm.startPrank(address(mockPartyStarter));

        // Create public venue
        publicVenue = new PartyVenue(
            PARTY_ID,
            creator,
            TARGET_AMOUNT,
            false, // not private
            address(0) // no signer for public parties
        );

        // Create private venue with signature-based authorization
        privateVenue = new PartyVenue(
            PARTY_ID + 1,
            creator,
            TARGET_AMOUNT,
            true, // private
            signer // signer address for private parties
        );

        vm.stopPrank();

        // Give ETH to test users
        vm.deal(creator, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(unauthorizedUser, 10 ether);
    }

    function testDeployment() public {
        // Test public venue deployment
        (
            uint256 partyId,
            address venueCreator,
            uint256 targetAmount,
            uint256 currentAmount,
            bool launched,
            bool isPrivate,
            address signerAddress
        ) = publicVenue.getPartyInfo();

        assertEq(partyId, PARTY_ID);
        assertEq(venueCreator, creator);
        assertEq(targetAmount, TARGET_AMOUNT);
        assertEq(currentAmount, 0);
        assertEq(launched, false);
        assertEq(isPrivate, false);
        assertEq(signerAddress, address(0));
        assertEq(publicVenue.partyStarter(), address(mockPartyStarter));
        assertEq(publicVenue.owner(), creator);

        // Test private venue deployment
        (
            partyId,
            venueCreator,
            targetAmount,
            currentAmount,
            launched,
            isPrivate,
            signerAddress
        ) = privateVenue.getPartyInfo();

        assertEq(partyId, PARTY_ID + 1);
        assertEq(venueCreator, creator);
        assertEq(targetAmount, TARGET_AMOUNT);
        assertEq(currentAmount, 0);
        assertEq(launched, false);
        assertEq(isPrivate, true);
        assertEq(signerAddress, signer);
    }

    function testContributeToPublicVenue() public {
        uint256 contribution = 1 ether;

        vm.startPrank(user1);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit ContributionReceived(user1, contribution);

        // Contribute
        publicVenue.contribute{value: contribution}();

        vm.stopPrank();

        // Check state
        (, , , uint256 currentAmount, bool launched, , ) = publicVenue
            .getPartyInfo();
        assertEq(currentAmount, contribution);
        assertEq(launched, false);
        assertEq(publicVenue.getContribution(user1), contribution);

        // Check contributors list
        address[] memory contributors = publicVenue.getContributors();
        assertEq(contributors.length, 1);
        assertEq(contributors[0], user1);
    }

    function testContributeToPrivateVenueRequiresSignature() public {
        vm.startPrank(user1);

        // Direct contribute should fail for private parties
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.SIGNATURE_REQUIRED
            )
        );
        privateVenue.contribute{value: 1 ether}();

        vm.stopPrank();
    }

    function testContributeWithValidSignature() public {
        uint256 contribution = 1 ether;
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Create message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        PARTY_ID + 1, // private venue party ID
                        user1,
                        maxAmount,
                        deadline
                    )
                )
            )
        );

        // Sign the message with the signer's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit ContributionReceived(user1, contribution);

        // Contribute with signature
        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        vm.stopPrank();

        // Check state
        (, , , uint256 currentAmount, bool launched, , ) = privateVenue
            .getPartyInfo();
        assertEq(currentAmount, contribution);
        assertEq(launched, false);
        assertEq(privateVenue.getContribution(user1), contribution);
    }

    function testContributeWithInvalidSignature() public {
        uint256 contribution = 1 ether;
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Create message hash with wrong signer
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID + 1, user1, maxAmount, deadline)
                )
            )
        );

        // Sign with wrong private key (different key instead of signer key)
        uint256 wrongPrivateKey = 0x9999999999999999999999999999999999999999999999999999999999999999;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.INVALID_SIGNATURE
            )
        );
        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        vm.stopPrank();
    }

    function testContributeWithExpiredSignature() public {
        uint256 contribution = 1 ether;
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp - 1; // Expired

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID + 1, user1, maxAmount, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.SIGNATURE_EXPIRED
            )
        );
        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        vm.stopPrank();
    }

    function testContributeExceedsAuthorizedAmount() public {
        uint256 contribution = 3 ether; // More than authorized
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID + 1, user1, maxAmount, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.CONTRIBUTION_TOO_HIGH
            )
        );
        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        vm.stopPrank();
    }

    function testSignatureReplayPrevention() public {
        uint256 contribution = 1 ether;
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID + 1, user1, maxAmount, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);

        // First use should succeed
        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        // Second use should fail
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.SIGNATURE_ALREADY_USED
            )
        );
        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        vm.stopPrank();
    }

    function testUpdateSigner() public {
        address newSigner = address(0x3333);

        vm.startPrank(creator);

        vm.expectEmit(true, true, true, true);
        emit SignerUpdated(newSigner);

        privateVenue.updateSigner(newSigner);

        vm.stopPrank();

        // Check signer was updated
        (, , , , , , address signerAddress) = privateVenue.getPartyInfo();
        assertEq(signerAddress, newSigner);
    }

    function testUpdateSignerByNonCreator() public {
        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ONLY_CREATOR
            )
        );
        privateVenue.updateSigner(address(0x3333));

        vm.stopPrank();
    }

    function testAutoLaunchWhenTargetReached() public {
        uint256 contribution = TARGET_AMOUNT;
        uint256 maxAmount = TARGET_AMOUNT;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID + 1, user1, maxAmount, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit ContributionReceived(user1, contribution);

        vm.expectEmit(true, true, true, true);
        emit PartyLaunched(contribution);

        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        vm.stopPrank();

        // Check party is launched
        (, , , uint256 currentAmount, bool launched, , ) = privateVenue
            .getPartyInfo();
        assertEq(currentAmount, contribution);
        assertEq(launched, true);
    }

    function testManualLaunchByCreator() public {
        uint256 partialAmount = 2 ether; // Less than target

        // Add some contributions with signature
        uint256 maxAmount = 3 ether;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID + 1, user1, maxAmount, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);
        privateVenue.contributeWithSignature{value: partialAmount}(
            signature,
            maxAmount,
            deadline
        );
        vm.stopPrank();

        // Manual launch by creator
        vm.startPrank(creator);

        vm.expectEmit(true, true, true, true);
        emit PartyLaunched(partialAmount);

        privateVenue.manualLaunch();

        vm.stopPrank();

        // Check party is launched
        (, , , uint256 currentAmount, bool launched, , ) = privateVenue
            .getPartyInfo();
        assertEq(currentAmount, partialAmount);
        assertEq(launched, true);
    }

    function testReceiveFunctionPublicVenue() public {
        uint256 contribution = 1 ether;

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit ContributionReceived(user1, contribution);

        // Send ETH directly to trigger receive()
        (bool success, ) = address(publicVenue).call{value: contribution}("");
        require(success, "Transfer failed");

        vm.stopPrank();

        // Check contribution was recorded
        assertEq(publicVenue.getContribution(user1), contribution);
        (, , , uint256 currentAmount, , , ) = publicVenue.getPartyInfo();
        assertEq(currentAmount, contribution);
    }

    function testReceiveFunctionPrivateVenueReverts() public {
        vm.startPrank(user1);

        // Send ETH directly to trigger receive() - should fail for private venue
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.SIGNATURE_REQUIRED
            )
        );
        (bool success, ) = address(privateVenue).call{value: 1 ether}("");

        vm.stopPrank();
    }

    function testSignatureForPublicPartyReverts() public {
        uint256 contribution = 1 ether;
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID, user1, maxAmount, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.NOT_WHITELISTED
            )
        );
        publicVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );

        vm.stopPrank();
    }

    function testIsSignatureUsed() public {
        uint256 contribution = 1 ether;
        uint256 maxAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(PARTY_ID + 1, user1, maxAmount, deadline)
                )
            )
        );

        // Check signature not used initially
        assertEq(privateVenue.isSignatureUsed(messageHash), false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            messageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);
        privateVenue.contributeWithSignature{value: contribution}(
            signature,
            maxAmount,
            deadline
        );
        vm.stopPrank();

        // Check signature is now used
        assertEq(privateVenue.isSignatureUsed(messageHash), true);
    }
}
