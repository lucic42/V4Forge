// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./DeployWETH.s.sol";
import "./DeployV4Core.s.sol";
import "./DeployPartyStarter.s.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Starting Complete LaunchDotParty Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Starting balance:", deployer.balance / 1e18, "ETH");

        require(
            deployer.balance >= 50 ether,
            "Insufficient ETH balance for deployment"
        );

        // Step 1: Deploy WETH9
        console.log("\n1. Deploying WETH9...");
        DeployWETH wethDeployer = new DeployWETH();
        wethDeployer.run();
        address wethAddress = address(wethDeployer.weth());

        // Step 2: Deploy Uniswap V4 Core
        console.log("\n2. Deploying Uniswap V4 Core...");
        DeployV4Core v4Deployer = new DeployV4Core();
        v4Deployer.run();
        address poolManagerAddress = address(v4Deployer.poolManager());

        // Step 3: Set environment variables for PartyStarter deployment
        vm.setEnv("POOL_MANAGER_ADDRESS", vm.toString(poolManagerAddress));
        vm.setEnv("WETH_ADDRESS", vm.toString(wethAddress));

        // Step 4: Deploy PartyStarter System
        console.log("\n3. Deploying PartyStarter System...");
        DeployPartyStarter partyDeployer = new DeployPartyStarter();
        partyDeployer.run();

        // Generate comprehensive deployment summary
        string memory fullDeploymentData = string.concat(
            "# LaunchDotParty Deployment Summary\n",
            "# Deployed on Chain: ",
            vm.toString(block.chainid),
            "\n",
            "# Deployer: ",
            vm.toString(deployer),
            "\n",
            "# Block Number: ",
            vm.toString(block.number),
            "\n\n",
            "# Core Dependencies\n",
            "WETH_ADDRESS=",
            vm.toString(wethAddress),
            "\n",
            "POOL_MANAGER_ADDRESS=",
            vm.toString(poolManagerAddress),
            "\n",
            "SWAP_ROUTER_ADDRESS=",
            vm.toString(address(v4Deployer.swapRouter())),
            "\n",
            "LIQUIDITY_ROUTER_ADDRESS=",
            vm.toString(address(v4Deployer.modifyLiquidityRouter())),
            "\n\n",
            "# PartyStarter System\n",
            "PARTY_VAULT_ADDRESS=",
            vm.toString(address(partyDeployer.vault())),
            "\n",
            "PARTY_STARTER_ADDRESS=",
            vm.toString(address(partyDeployer.partyStarter())),
            "\n"
        );

        vm.writeFile("deployments/complete-deployment.env", fullDeploymentData);

        console.log("\n=== Deployment Complete! ===");
        console.log("All contracts deployed successfully!");
        console.log(
            "Deployment data saved to: deployments/complete-deployment.env"
        );
        console.log("Final deployer balance:", deployer.balance / 1e18, "ETH");

        console.log("\n=== Key Addresses ===");
        console.log("WETH:", wethAddress);
        console.log("PoolManager:", poolManagerAddress);
        console.log("SwapRouter:", address(v4Deployer.swapRouter()));
        console.log("PartyVault:", address(partyDeployer.vault()));
        console.log("PartyStarter:", address(partyDeployer.partyStarter()));

        console.log("\n=== Next Steps ===");
        console.log("1. Update your frontend config with these addresses");
        console.log("2. Update your indexer config with these addresses");
        console.log("3. Test with: make quick-test or run e2e tests");
    }
}
