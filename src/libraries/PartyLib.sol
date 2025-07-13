// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {PartyTypes} from "../types/PartyTypes.sol";
// import {PartyErrors} from "../types/PartyErrors.sol";
// import {PartyVenue} from "../venue/PartyVenue.sol";
// import {PoolId} from "v4-core/src/types/PoolId.sol";

// /**
//  * @title PartyLib
//  * @dev Library for party creation and management logic
//  */
// library PartyLib {
//     using PartyErrors for *;

//     event PartyCreated(
//         uint256 indexed partyId,
//         PartyTypes.PartyType indexed partyType,
//         address indexed creator,
//         PartyTypes.TokenMetadata metadata
//     );

//     event VenueDeployed(uint256 indexed partyId, address indexed venueAddress);

//     /**
//      * @dev Create a new party structure
//      * @param partyId The unique party ID
//      * @param partyType The type of party (instant, public, private)
//      * @param creator The party creator address
//      * @param metadata The token metadata
//      * @return party The created party structure
//      */
//     function createParty(
//         uint256 partyId,
//         PartyTypes.PartyType partyType,
//         address creator,
//         PartyTypes.TokenMetadata memory metadata
//     ) internal returns (PartyTypes.Party memory party) {
//         party = PartyTypes.Party({
//             id: partyId,
//             partyType: partyType,
//             creator: creator,
//             metadata: metadata,
//             tokenAddress: address(0), // Set later during launch
//             venueAddress: address(0), // Set during venue deployment if needed
//             poolId: PoolId.wrap(bytes32(0)), // Set during launch
//             totalLiquidity: 0, // Set during launch
//             launched: false,
//             createdAt: block.timestamp
//         });
//     }

//     /**
//      * @dev Create and configure an instant party
//      * @param partyId The unique party ID
//      * @param creator The party creator address
//      * @param metadata The token metadata
//      * @param ethAmount The ETH amount sent for liquidity
//      * @return party The created party structure
//      */
//     function createInstantParty(
//         uint256 partyId,
//         address creator,
//         PartyTypes.TokenMetadata memory metadata,
//         uint256 ethAmount
//     ) internal returns (PartyTypes.Party memory party) {
//         PartyErrors.requireNonZero(
//             ethAmount,
//             PartyErrors.ErrorCode.ZERO_AMOUNT
//         );

//         party = createParty(
//             partyId,
//             PartyTypes.PartyType.INSTANT,
//             creator,
//             metadata
//         );
//         party.totalLiquidity = ethAmount;

//         emit PartyCreated(
//             partyId,
//             PartyTypes.PartyType.INSTANT,
//             creator,
//             metadata
//         );
//     }

//     /**
//      * @dev Create and configure a public party with venue
//      * @param partyId The unique party ID
//      * @param creator The party creator address
//      * @param metadata The token metadata
//      * @param targetLiquidity The target liquidity amount
//      * @return party The created party structure
//      * @return venue The deployed venue contract
//      */
//     function createPublicParty(
//         uint256 partyId,
//         address creator,
//         PartyTypes.TokenMetadata memory metadata,
//         uint256 targetLiquidity
//     ) internal returns (PartyTypes.Party memory party, PartyVenue venue) {
//         PartyErrors.requireNonZero(
//             targetLiquidity,
//             PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
//         );

//         party = createParty(
//             partyId,
//             PartyTypes.PartyType.PUBLIC,
//             creator,
//             metadata
//         );

//         // Deploy venue contract
//         venue = new PartyVenue(
//             partyId,
//             creator,
//             targetLiquidity,
//             false, // not private
//             address(0) // no signer for public parties
//         );

//         party.venueAddress = address(venue);

//         emit PartyCreated(
//             partyId,
//             PartyTypes.PartyType.PUBLIC,
//             creator,
//             metadata
//         );
//         emit VenueDeployed(partyId, address(venue));
//     }

//     /**
//      * @dev Create and configure a public party with venue (without metadata)
//      * @param partyId The unique party ID
//      * @param creator The party creator address
//      * @param targetLiquidity The target liquidity amount
//      * @param targetSupply The target token supply for presale
//      * @param launchTime The timestamp when anyone can launch the party
//      * @return party The created party structure
//      * @return venue The deployed venue contract
//      */
//     function createPublicPartyWithoutMetadata(
//         uint256 partyId,
//         address creator,
//         uint256 targetLiquidity,
//         uint256 targetSupply,
//         uint256 launchTime
//     ) internal returns (PartyTypes.Party memory party, PartyVenue venue) {
//         PartyErrors.requireNonZero(
//             targetLiquidity,
//             PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
//         );

//         // Create empty metadata
//         PartyTypes.TokenMetadata memory emptyMetadata;

//         party = createParty(
//             partyId,
//             PartyTypes.PartyType.PUBLIC,
//             creator,
//             emptyMetadata
//         );

//         party.targetSupply = targetSupply;
//         party.timeoutDeadline = launchTime;

//         // Deploy venue contract
//         venue = new PartyVenue(
//             partyId,
//             creator,
//             targetLiquidity,
//             false, // not private
//             address(0), // no signer for public parties
//             launchTime // timeout deadline
//         );

//         party.venueAddress = address(venue);

//         emit PartyCreated(
//             partyId,
//             PartyTypes.PartyType.PUBLIC,
//             creator,
//             emptyMetadata
//         );
//         emit VenueDeployed(partyId, address(venue));
//     }

//     /**
//      * @dev Create and configure a private party with venue and signature-based authorization
//      * @param partyId The unique party ID
//      * @param creator The party creator address
//      * @param metadata The token metadata
//      * @param targetLiquidity The target liquidity amount
//      * @param signerAddress The signer address for signature verification
//      * @return party The created party structure
//      * @return venue The deployed venue contract
//      */
//     function createPrivateParty(
//         uint256 partyId,
//         address creator,
//         PartyTypes.TokenMetadata memory metadata,
//         uint256 targetLiquidity,
//         address signerAddress
//     ) internal returns (PartyTypes.Party memory party, PartyVenue venue) {
//         PartyErrors.requireNonZero(
//             targetLiquidity,
//             PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
//         );
//         PartyErrors.requireNonZeroAddress(
//             signerAddress,
//             PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS
//         );

//         party = createParty(
//             partyId,
//             PartyTypes.PartyType.PRIVATE,
//             creator,
//             metadata
//         );

//         // Deploy venue contract with signature-based authorization only
//         venue = new PartyVenue(
//             partyId,
//             creator,
//             targetLiquidity,
//             true, // private
//             signerAddress
//         );

//         party.venueAddress = address(venue);

//         emit PartyCreated(
//             partyId,
//             PartyTypes.PartyType.PRIVATE,
//             creator,
//             metadata
//         );
//         emit VenueDeployed(partyId, address(venue));
//     }

//     /**
//      * @dev Create and configure a private party with venue and signature-based authorization (without metadata)
//      * @param partyId The unique party ID
//      * @param creator The party creator address
//      * @param targetLiquidity The target liquidity amount
//      * @param targetSupply The target token supply for presale
//      * @param launchTime The timestamp when anyone can launch the party
//      * @param signerAddress The signer address for signature verification
//      * @return party The created party structure
//      * @return venue The deployed venue contract
//      */
//     function createPrivatePartyWithoutMetadata(
//         uint256 partyId,
//         address creator,
//         uint256 targetLiquidity,
//         uint256 targetSupply,
//         uint256 launchTime,
//         address signerAddress
//     ) internal returns (PartyTypes.Party memory party, PartyVenue venue) {
//         PartyErrors.requireNonZero(
//             targetLiquidity,
//             PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
//         );
//         PartyErrors.requireNonZeroAddress(
//             signerAddress,
//             PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS
//         );

//         // Create empty metadata
//         PartyTypes.TokenMetadata memory emptyMetadata;

//         party = createParty(
//             partyId,
//             PartyTypes.PartyType.PRIVATE,
//             creator,
//             emptyMetadata
//         );

//         // Set target supply for presale and timeout deadline
//         party.targetSupply = targetSupply;
//         party.timeoutDeadline = launchTime;

//         // Deploy venue contract with signature-based authorization only
//         venue = new PartyVenue(
//             partyId,
//             creator,
//             targetLiquidity,
//             true, // private
//             signerAddress,
//             launchTime // timeout deadline
//         );

//         party.venueAddress = address(venue);

//         emit PartyCreated(
//             partyId,
//             PartyTypes.PartyType.PRIVATE,
//             creator,
//             emptyMetadata
//         );
//         emit VenueDeployed(partyId, address(venue));
//     }

//     /**
//      * @dev Update party state when launching
//      * @param party The party to update
//      * @param tokenAddress The created token address
//      * @param poolId The created pool ID
//      * @param totalLiquidity The total liquidity amount
//      */
//     function updatePartyOnLaunch(
//         PartyTypes.Party storage party,
//         address tokenAddress,
//         PoolId poolId,
//         uint256 totalLiquidity
//     ) internal {
//         party.tokenAddress = tokenAddress;
//         party.poolId = poolId;
//         party.totalLiquidity = totalLiquidity;
//         party.launched = true;
//     }

//     /**
//      * @dev Validate party creation parameters
//      * @param creator The creator address
//      * @param metadata The token metadata
//      */
//     function validatePartyCreation(
//         address creator,
//         PartyTypes.TokenMetadata memory metadata
//     ) internal pure {
//         PartyErrors.requireNonZeroAddress(
//             creator,
//             PartyErrors.ErrorCode.INVALID_CREATOR
//         );
//         PartyErrors.requireValidState(
//             bytes(metadata.name).length > 0,
//             PartyErrors.ErrorCode.EMPTY_TOKEN_NAME
//         );
//         PartyErrors.requireValidState(
//             bytes(metadata.symbol).length > 0,
//             PartyErrors.ErrorCode.EMPTY_TOKEN_SYMBOL
//         );
//         PartyErrors.requireValidState(
//             bytes(metadata.symbol).length <= 10,
//             PartyErrors.ErrorCode.SYMBOL_TOO_LONG
//         );
//     }

//     /**
//      * @dev Add a party to user's party list
//      * @param userParties The mapping of user parties
//      * @param user The user address
//      * @param partyId The party ID to add
//      */
//     function addPartyToUser(
//         mapping(address => uint256[]) storage userParties,
//         address user,
//         uint256 partyId
//     ) internal {
//         userParties[user].push(partyId);
//     }
// }
