// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PartyTypes} from "../types/PartyTypes.sol";
// Removed V4 imports - now using V3

/**
 * @title IPartyStarter
 * @dev Interface for the main PartyStarter contract
 */
interface IPartyStarter {
    // Events
    event PartySystemTokenLaunched(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        address poolAddress,
        uint256 totalLiquidity,
        uint256 timestamp
    );

    event PartyCreated(
        uint256 indexed partyId,
        PartyTypes.PartyType indexed partyType,
        address indexed creator,
        PartyTypes.TokenMetadata metadata
    );

    event PartyLaunched(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed poolAddress,
        uint256 totalLiquidity
    );

    event VenueDeployed(uint256 indexed partyId, address indexed venueAddress);

    event FeesClaimedByDev(
        uint256 indexed partyId,
        address indexed dev,
        uint256 devAmount,
        uint256 platformAmount
    );

    // Enhanced events for comprehensive data capture
    event TokenDeployed(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed creator,
        uint256 totalSupply,
        uint256 liquidityTokens,
        uint256 creatorTokens,
        uint256 vaultTokens,
        uint256 timestamp
    );

    event PartyProgressUpdate(
        uint256 indexed partyId,
        uint256 currentAmount,
        uint256 targetAmount,
        uint256 contributorCount,
        uint8 progressPercentage,
        uint256 timestamp
    );

    event PartyLaunchComplete(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed creator,
        address poolAddress,
        uint256 totalLiquidity,
        uint256 initialPrice,
        uint256 marketCap,
        uint256 timestamp
    );

    event PartyTimeoutLaunched(
        uint256 indexed partyId,
        address indexed launcher,
        uint256 ethAmount,
        uint256 timestamp
    );

    // Main functions
    function createInstantParty(
        PartyTypes.TokenMetadata calldata metadata
    ) external payable returns (uint256 partyId);

    function createPublicParty(
        uint256 targetLiquidity,
        uint256 targetSupply,
        uint256 launchTime
    ) external returns (uint256 partyId);

    function createPrivateParty(
        uint256 targetLiquidity,
        uint256 targetSupply,
        uint256 launchTime,
        address signerAddress
    ) external returns (uint256 partyId);

    function setPartyMetadata(
        uint256 partyId,
        string[] calldata fieldNames,
        string[] calldata fieldValues
    ) external;

    function isMetadataComplete(uint256 partyId) external view returns (bool);

    function launchFromVenue(uint256 partyId) external payable;

    function claimFees(uint256 partyId) external;

    // View functions
    function getParty(
        uint256 partyId
    ) external view returns (PartyTypes.Party memory);

    function getUserParties(
        address user
    ) external view returns (uint256[] memory);

    function getLPPosition(
        uint256 partyId
    ) external view returns (PartyTypes.LPPosition memory);
}
