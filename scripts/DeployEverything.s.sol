// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {WETH9} from "@uniswap/v3-periphery/contracts/test/WETH9.sol";
import {UniswapV3Factory} from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
import {NFTDescriptor} from "@uniswap/v3-periphery/contracts/libraries/NFTDescriptor.sol";
import {NonfungibleTokenPositionDescriptor} from "@uniswap/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import {MockTimeNonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/test/MockTimeNonfungiblePositionManager.sol";
import {PartyStarterV2} from "../src/PartyStarterV2.sol";
import {PublicPartyVenue} from "../src/PublicPartyVenue.sol";

contract DeployEverything is Script {
    function run()
        external
        returns (
            WETH9,
            UniswapV3Factory,
            NonfungibleTokenPositionDescriptor,
            MockTimeNonfungiblePositionManager,
            PartyStarterV2,
            PublicPartyVenue
        )
    {
        vm.startBroadcast();

        // 1. Deploy WETH9
        WETH9 weth9 = new WETH9();
        console.log("WETH9 deployed at:", address(weth9));

        // 2. Deploy UniswapV3Factory
        UniswapV3Factory factory = new UniswapV3Factory();
        console.log("UniswapV3Factory deployed at:", address(factory));

        // 3. Deploy NonfungibleTokenPositionDescriptor
        new NFTDescriptor(); // Deploy the library
        NonfungibleTokenPositionDescriptor positionDescriptor = new NonfungibleTokenPositionDescriptor(
                address(weth9),
                bytes32("ETH")
            );
        console.log(
            "NonfungibleTokenPositionDescriptor deployed at:",
            address(positionDescriptor)
        );

        // 4. Deploy NonfungiblePositionManager
        MockTimeNonfungiblePositionManager positionManager = new MockTimeNonfungiblePositionManager(
                address(factory),
                address(weth9),
                address(positionDescriptor)
            );
        console.log(
            "NonfungiblePositionManager deployed at:",
            address(positionManager)
        );

        // 5. Deploy PartyStarterV2
        address vault = address(this); // Using the script contract address as a placeholder vault
        PartyStarterV2 partyStarterV2 = new PartyStarterV2(
            address(factory),
            address(positionManager),
            vault
        );
        console.log("PartyStarterV2 deployed at:", address(partyStarterV2));

        // 6. Create a PublicPartyVenue
        uint256 timeout = block.timestamp + 1 days;
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 1000 * 1e18;
        uint256 maxEthContribution = 0.1 ether;

        address newPartyAddress = partyStarterV2.createParty(
            timeout,
            ethAmount,
            tokenAmount,
            maxEthContribution
        );
        console.log("New PublicPartyVenue created at:", newPartyAddress);

        PublicPartyVenue publicPartyVenue = PublicPartyVenue(newPartyAddress);

        vm.stopBroadcast();

        return (
            weth9,
            factory,
            positionDescriptor,
            positionManager,
            partyStarterV2,
            publicPartyVenue
        );
    }
}
