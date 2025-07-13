// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PublicPartyVenue} from "./PublicPartyVenue.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract PartyStarterV2 is Owned {
    address public factory;
    address public positionManager;
    address public vault;

    event PartyCreated(
        address indexed partyAddress,
        address indexed partyStarter
    );

    constructor(
        address _factory,
        address _positionManager,
        address _vault
    ) Owned(msg.sender) {
        factory = _factory;
        positionManager = _positionManager;
        vault = _vault;
    }

    function createParty(
        uint256 timeout,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 maxEthContribution
    ) external returns (address) {
        PublicPartyVenue newParty = new PublicPartyVenue(
            msg.sender, // _partyStarter
            vault,
            timeout,
            ethAmount,
            tokenAmount,
            maxEthContribution,
            factory,
            positionManager
        );
        emit PartyCreated(address(newParty), msg.sender);
        return address(newParty);
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    function setPositionManager(address _positionManager) external onlyOwner {
        positionManager = _positionManager;
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }
}
