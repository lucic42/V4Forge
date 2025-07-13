// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/vault/PartyVault.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import "../test/utils/MockValidHook.sol";

// Simplified PartyStarter for deployment without complex hooks
contract SimplePartyStarter {
    IPoolManager public immutable poolManager;
    PartyVault public immutable partyVault;
    MockValidHook public immutable swapLimitHook;
    address public immutable weth;
    address public immutable platformTreasury;

    constructor(
        IPoolManager _poolManager,
        PartyVault _partyVault,
        address _weth,
        address _platformTreasury
    ) {
        poolManager = _poolManager;
        partyVault = _partyVault;
        weth = _weth;
        platformTreasury = _platformTreasury;

        // Deploy mock hook (no address validation required)
        swapLimitHook = new MockValidHook(_poolManager);
    }

    // Minimal functions for testing
    function createInstantParty() external payable returns (uint256) {
        // Simplified implementation for testing
        return 1;
    }

    receive() external payable {}
}

contract DeployPartyStarterSimple is Script {
    PartyVault public vault;
    SimplePartyStarter public partyStarter;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read addresses from environment variables
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying Simple PartyStarter System ===");
        console.log("Deployer:", deployer);
        console.log("PoolManager:", poolManager);
        console.log("WETH:", weth);
        console.log("Fee Recipient:", feeRecipient);

        // Deploy PartyVault first
        vault = new PartyVault();
        console.log("PartyVault deployed at:", address(vault));

        // Deploy SimplePartyStarter with V4 dependencies
        partyStarter = new SimplePartyStarter(
            IPoolManager(poolManager),
            vault,
            weth,
            feeRecipient
        );
        console.log("SimplePartyStarter deployed at:", address(partyStarter));

        // Transfer vault ownership to PartyStarter
        vault.transferOwnership(address(partyStarter));
        console.log("Vault ownership transferred to SimplePartyStarter");

        vm.stopBroadcast();

        console.log("\n=== Simple PartyStarter Deployment Complete ===");
        console.log("PartyVault:", address(vault));
        console.log("SimplePartyStarter:", address(partyStarter));

        // Save addresses to file for other scripts
        string memory deploymentData = string.concat(
            "PARTY_VAULT_ADDRESS=",
            vm.toString(address(vault)),
            "\n",
            "PARTY_STARTER_ADDRESS=",
            vm.toString(address(partyStarter)),
            "\n"
        );
        vm.writeFile("deployments/simple-addresses.env", deploymentData);
        console.log("Addresses saved to deployments/simple-addresses.env");
    }
}
