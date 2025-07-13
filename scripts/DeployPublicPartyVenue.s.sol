// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PublicPartyVenue} from "../src/PublicPartyVenue.sol";

contract DeployPublicPartyVenue is Script {
    function run() external returns (PublicPartyVenue) {
        // These are placeholder values.
        // You can replace them with the actual values for your deployment,
        // or load them from environment variables.
        address partyStarter = msg.sender;
        address vault = vm.envAddress("VAULT_ADDRESS");
        uint256 timeout = block.timestamp + 1 days;
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 1000 * 1e18;
        uint256 maxEthContribution = 0.1 ether;
        address factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Uniswap V3 Factory
        address positionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; // Uniswap V3 NonfungiblePositionManager

        vm.startBroadcast();
        PublicPartyVenue publicPartyVenue = new PublicPartyVenue(
            partyStarter,
            vault,
            timeout,
            ethAmount,
            tokenAmount,
            maxEthContribution,
            factory,
            positionManager
        );
        vm.stopBroadcast();
        return publicPartyVenue;
    }
}
