// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PartyTypes} from "../types/PartyTypes.sol";
// Removed V4 imports - now using V3

/**
 * @title IPartyStarter
 * @dev Interface for the main PartyStarter contract
 */
interface IPartyStarter {
    event InstantPartyStarted(
        address indexed creator,
        uint256 indexed pair,
        string name,
        string symbol,
        string metadata
    );

    // Main functions
    function createInstantParty(
        string memory _name,
        string memory _symbol,
        string memory _metadata
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
