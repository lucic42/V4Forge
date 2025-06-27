// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PartyTypes} from "../types/PartyTypes.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";

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
        PoolId poolId,
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
        PoolId indexed poolId,
        uint256 totalLiquidity
    );

    event VenueDeployed(uint256 indexed partyId, address indexed venueAddress);

    event FeesClaimedByDev(
        uint256 indexed partyId,
        address indexed dev,
        uint256 devAmount,
        uint256 platformAmount
    );

    // Main functions
    function createInstantParty(
        PartyTypes.TokenMetadata calldata metadata
    ) external payable returns (uint256 partyId);

    function createPublicParty(
        PartyTypes.TokenMetadata calldata metadata,
        uint256 targetLiquidity
    ) external returns (uint256 partyId);

    function createPrivateParty(
        PartyTypes.TokenMetadata calldata metadata,
        uint256 targetLiquidity,
        address signerAddress
    ) external returns (uint256 partyId);

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
