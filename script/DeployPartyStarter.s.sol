// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PartyStarter.sol";
import "../src/vault/PartyVault.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

contract DeployPartyStarter is Script {
    PartyVault public vault;
    PartyStarter public partyStarter;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read addresses from environment variables
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying PartyStarter System ===");
        console.log("Deployer:", deployer);
        console.log("PoolManager:", poolManager);
        console.log("WETH:", weth);
        console.log("Fee Recipient:", feeRecipient);

        // Deploy PartyVault first
        vault = new PartyVault();
        console.log("PartyVault deployed at:", address(vault));

        // Deploy PartyStarter with V4 dependencies
        partyStarter = new PartyStarter(
            IPoolManager(poolManager),
            vault,
            weth,
            feeRecipient
        );
        console.log("PartyStarter deployed at:", address(partyStarter));

        // Transfer vault ownership to PartyStarter
        vault.transferOwnership(address(partyStarter));
        console.log("Vault ownership transferred to PartyStarter");

        vm.stopBroadcast();

        console.log("\n=== PartyStarter Deployment Complete ===");
        console.log("PartyVault:", address(vault));
        console.log("PartyStarter:", address(partyStarter));

        // Save addresses to file for other scripts
        string memory deploymentData = string.concat(
            "PARTY_VAULT_ADDRESS=",
            vm.toString(address(vault)),
            "\n",
            "PARTY_STARTER_ADDRESS=",
            vm.toString(address(partyStarter)),
            "\n"
        );
        vm.writeFile("deployments/addresses.env", deploymentData);
        console.log("Addresses saved to deployments/addresses.env");
    }
}
