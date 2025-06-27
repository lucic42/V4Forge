// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "../utils/TestBase.sol";
import {PartyLib} from "../../src/libraries/PartyLib.sol";
import {PartyTypes} from "../../src/types/PartyTypes.sol";
import {PartyVenue} from "../../src/venue/PartyVenue.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {PartyErrors} from "../../src/types/PartyErrors.sol";

contract PartyLibTest is TestBase {
    function test_CreateParty_Basic() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Test Token",
            "TEST"
        );

        PartyTypes.Party memory party = PartyLib.createParty(
            1,
            PartyTypes.PartyType.INSTANT,
            ALICE,
            metadata
        );

        assert(party.id == 1);
        assert(uint(party.partyType) == uint(PartyTypes.PartyType.INSTANT));
        assert(party.creator == ALICE);
        assert(
            keccak256(bytes(party.metadata.name)) ==
                keccak256(bytes("Test Token"))
        );
        assert(
            keccak256(bytes(party.metadata.symbol)) == keccak256(bytes("TEST"))
        );
        assert(party.tokenAddress == address(0));
        assert(party.venueAddress == address(0));
        assert(PoolId.unwrap(party.poolId) == bytes32(0));
        assert(party.totalLiquidity == 0);
        assert(!party.launched);
        assert(party.createdAt > 0);
    }

    function test_CreateInstantParty_Success() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Instant Token",
            "INST"
        );
        uint256 ethAmount = 5 ether;

        vm.expectEmit(true, true, true, true);
        emit PartyCreated(1, PartyTypes.PartyType.INSTANT, ALICE, metadata);

        PartyTypes.Party memory party = PartyLib.createInstantParty(
            1,
            ALICE,
            metadata,
            ethAmount
        );

        assertEq(party.id, 1);
        assertEq(uint(party.partyType), uint(PartyTypes.PartyType.INSTANT));
        assertEq(party.creator, ALICE);
        assertEq(party.totalLiquidity, ethAmount);
        assertFalse(party.launched);
    }

    function test_CreateInstantParty_ZeroEth_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Instant Token",
            "INST"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_AMOUNT
            )
        );
        PartyLib.createInstantParty(1, ALICE, metadata, 0);
    }

    function test_CreatePublicParty_Success() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Public Token",
            "PUB"
        );
        uint256 targetLiquidity = 10 ether;

        vm.expectEmit(true, true, true, true);
        emit PartyCreated(1, PartyTypes.PartyType.PUBLIC, ALICE, metadata);

        (PartyTypes.Party memory party, PartyVenue venue) = PartyLib
            .createPublicParty(1, ALICE, metadata, targetLiquidity);

        assertEq(party.id, 1, "Wrong party ID");
        assertEq(
            uint(party.partyType),
            uint(PartyTypes.PartyType.PUBLIC),
            "Wrong party type"
        );
        assertEq(party.creator, ALICE, "Wrong creator");
        assertEq(party.venueAddress, address(venue), "Wrong venue address");
        assertNotEq(address(venue), address(0), "Venue should be deployed");

        // Check venue configuration
        (
            uint256 partyId,
            address creator,
            uint256 targetAmount,
            uint256 currentAmount,
            bool launched,
            bool isPrivate,

        ) = venue.getPartyInfo();

        assertEq(partyId, 1, "Wrong venue party ID");
        assertEq(creator, ALICE, "Wrong venue creator");
        assertEq(targetAmount, targetLiquidity, "Wrong venue target amount");
        assertEq(currentAmount, 0, "Current amount should be zero");
        assertFalse(launched, "Venue should not be launched");
        assertFalse(isPrivate, "Public party should not be private");
    }

    function test_CreatePublicParty_ZeroTarget_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Public Token",
            "PUB"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
            )
        );
        PartyLib.createPublicParty(1, ALICE, metadata, 0);
    }

    function test_CreatePrivateParty_Success() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Private Token",
            "PRIV"
        );
        uint256 targetLiquidity = 15 ether;
        address signer = BOB;

        vm.expectEmit(true, true, true, true);
        emit PartyCreated(1, PartyTypes.PartyType.PRIVATE, ALICE, metadata);

        (PartyTypes.Party memory party, PartyVenue venue) = PartyLib
            .createPrivateParty(1, ALICE, metadata, targetLiquidity, signer);

        assertEq(party.id, 1, "Wrong party ID");
        assertEq(
            uint(party.partyType),
            uint(PartyTypes.PartyType.PRIVATE),
            "Wrong party type"
        );
        assertEq(party.creator, ALICE, "Wrong creator");
        assertEq(party.venueAddress, address(venue), "Wrong venue address");
        assertNotEq(address(venue), address(0), "Venue should be deployed");

        // Check venue configuration
        (
            uint256 partyId,
            address creator,
            uint256 targetAmount,
            ,
            bool launched,
            bool isPrivate,
            address signerAddress
        ) = venue.getPartyInfo();

        assertEq(partyId, 1, "Wrong venue party ID");
        assertEq(creator, ALICE, "Wrong venue creator");
        assertEq(targetAmount, targetLiquidity, "Wrong venue target amount");
        assertFalse(launched, "Venue should not be launched");
        assertTrue(isPrivate, "Private party should be private");
        assertEq(signerAddress, signer, "Wrong signer address");
    }

    function test_CreatePrivateParty_ZeroTarget_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Private Token",
            "PRIV"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
            )
        );
        PartyLib.createPrivateParty(1, ALICE, metadata, 0, BOB);
    }

    function test_CreatePrivateParty_ZeroSigner_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Private Token",
            "PRIV"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS
            )
        );
        PartyLib.createPrivateParty(1, ALICE, metadata, 1 ether, address(0));
    }

    function test_ValidatePartyCreation_Success() public pure {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Valid Token",
            "VALID"
        );

        // Should not revert
        PartyLib.validatePartyCreation(ALICE, metadata);
    }

    function test_ValidatePartyCreation_ZeroCreator_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Invalid Token",
            "INVALID"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.INVALID_CREATOR
            )
        );
        PartyLib.validatePartyCreation(address(0), metadata);
    }

    function test_ValidatePartyCreation_EmptyName_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "",
            "INVALID"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.EMPTY_TOKEN_NAME
            )
        );
        PartyLib.validatePartyCreation(ALICE, metadata);
    }

    function test_ValidatePartyCreation_EmptySymbol_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Invalid Token",
            ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.EMPTY_TOKEN_SYMBOL
            )
        );
        PartyLib.validatePartyCreation(ALICE, metadata);
    }

    function test_ValidatePartyCreation_LongSymbol_Reverts() public {
        PartyTypes.TokenMetadata memory metadata = createTokenMetadata(
            "Invalid Token",
            "VERYLONGSYMBOL"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.SYMBOL_TOO_LONG
            )
        );
        PartyLib.validatePartyCreation(ALICE, metadata);
    }

    // Note: updatePartyOnLaunch and addPartyToUser are tested in integration tests where storage mappings are available

    // ============ Fuzz Tests ============

    function testFuzz_CreateParty(
        uint256 partyId,
        uint8 partyTypeRaw,
        address creator,
        uint256 seed
    ) public {
        // Bound inputs
        vm.assume(creator != address(0));
        vm.assume(partyId != 0);

        PartyTypes.PartyType partyType = PartyTypes.PartyType(partyTypeRaw % 3);
        PartyTypes.TokenMetadata memory metadata = generateRandomMetadata(seed);

        PartyTypes.Party memory party = PartyLib.createParty(
            partyId,
            partyType,
            creator,
            metadata
        );

        assert(party.id == partyId);
        assert(uint(party.partyType) == uint(partyType));
        assert(party.creator == creator);
    }

    function testFuzz_ValidatePartyCreation(
        address creator,
        uint256 seed
    ) public view {
        vm.assume(creator != address(0));

        PartyTypes.TokenMetadata memory metadata = generateRandomMetadata(seed);

        // Should not revert for valid inputs
        PartyLib.validatePartyCreation(creator, metadata);
    }
}
