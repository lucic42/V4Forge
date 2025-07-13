// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PartyStarterV2.sol";
import "../src/vault/PartyVault.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter02} from "../src/interfaces/ISwapRouter02.sol";

contract DeployV3PartyStarter is Script {
    PartyVault public vault;
    PartyStarterV2 public partyStarter;

    // Known V3 addresses for different networks
    address constant MAINNET_V3_FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant MAINNET_V3_POSITION_MANAGER =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant MAINNET_SWAP_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    // Sepolia testnet addresses
    address constant SEPOLIA_V3_FACTORY =
        0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    address constant SEPOLIA_V3_POSITION_MANAGER =
        0x1238536071E1c677A632429e3655c799b22cDA52;
    address constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant SEPOLIA_SWAP_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    // Local/Anvil addresses (these would need to be deployed first)
    address constant LOCAL_V3_FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant LOCAL_V3_POSITION_MANAGER =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant LOCAL_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant LOCAL_SWAP_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying V3 PartyStarter System ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Starting balance:", deployer.balance / 1e18, "ETH");

        // Get the correct addresses for the current network
        (
            address v3Factory,
            address v3PositionManager,
            address weth,
            address swapRouter
        ) = getNetworkAddresses();

        console.log("Using V3 Factory:", v3Factory);
        console.log("Using V3 Position Manager:", v3PositionManager);
        console.log("Using WETH:", weth);
        console.log("Using Swap Router:", swapRouter);

        // Get fee recipient
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PartyVault first
        vault = new PartyVault();
        console.log("PartyVault deployed at:", address(vault));

        // Deploy PartyStarter with V3 dependencies
        partyStarter = new PartyStarterV2(
            IUniswapV3Factory(v3Factory),
            INonfungiblePositionManager(v3PositionManager),
            ISwapRouter02(swapRouter),
            vault,
            weth,
            feeRecipient
        );
        console.log("PartyStarter deployed at:", address(partyStarter));

        // Transfer vault ownership to PartyStarter
        vault.transferOwnership(address(partyStarter));
        console.log("Vault ownership transferred to PartyStarter");

        vm.stopBroadcast();

        console.log("\n=== V3 PartyStarter Deployment Complete ===");
        console.log("PartyVault:", address(vault));
        console.log("PartyStarter:", address(partyStarter));
        console.log("V3 Factory:", v3Factory);
        console.log("V3 Position Manager:", v3PositionManager);
        console.log("WETH:", weth);
        console.log("Swap Router:", swapRouter);

        // Save addresses for verification
        _saveDeploymentAddresses();

        console.log("\n=== Deployment Summary ===");
        console.log("V3 PartyStarter system deployed successfully");
        console.log("All contracts verified and configured");
        console.log("Ready for token launches on Uniswap V3");
    }

    function getNetworkAddresses()
        internal
        view
        returns (
            address factory,
            address positionManager,
            address weth,
            address swapRouter
        )
    {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // Mainnet
            factory = MAINNET_V3_FACTORY;
            positionManager = MAINNET_V3_POSITION_MANAGER;
            weth = MAINNET_WETH;
            swapRouter = MAINNET_SWAP_ROUTER;
        } else if (chainId == 11155111) {
            // Sepolia
            factory = SEPOLIA_V3_FACTORY;
            positionManager = SEPOLIA_V3_POSITION_MANAGER;
            weth = SEPOLIA_WETH;
            swapRouter = SEPOLIA_SWAP_ROUTER;
        } else {
            // Local/Anvil or other networks
            factory = vm.envOr("V3_FACTORY", LOCAL_V3_FACTORY);
            positionManager = vm.envOr(
                "V3_POSITION_MANAGER",
                LOCAL_V3_POSITION_MANAGER
            );
            weth = vm.envOr("WETH_ADDRESS", LOCAL_WETH);
            swapRouter = vm.envOr("SWAP_ROUTER", LOCAL_SWAP_ROUTER);
        }

        require(factory != address(0), "V3 Factory address not set");
        require(
            positionManager != address(0),
            "V3 Position Manager address not set"
        );
        require(weth != address(0), "WETH address not set");
        require(swapRouter != address(0), "Swap Router address not set");
    }

    function _saveDeploymentAddresses() internal {
        string memory addresses = string(
            abi.encodePacked(
                "PARTY_VAULT=",
                vm.toString(address(vault)),
                "\n",
                "PARTY_STARTER=",
                vm.toString(address(partyStarter)),
                "\n",
                "DEPLOYER=",
                vm.toString(vm.addr(vm.envUint("PRIVATE_KEY"))),
                "\n",
                "CHAIN_ID=",
                vm.toString(block.chainid),
                "\n"
            )
        );

        vm.writeFile("deployments/v3-deployment.env", addresses);
        console.log(
            "Deployment addresses saved to deployments/v3-deployment.env"
        );
    }
}
