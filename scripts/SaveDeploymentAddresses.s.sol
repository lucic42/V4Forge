// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract SaveDeploymentAddresses is Script {
    function run() external {
        // Read the latest deployment data
        string memory deploymentData = vm.readFile(
            "broadcast/DeployLocal.s.sol/31337/run-latest.json"
        );

        // For now, we'll just log the addresses. In a real implementation,
        // you'd parse the JSON and extract the contract addresses
        console.log("Deployment data saved to broadcast directory");
        console.log(
            "You can find the addresses in: broadcast/DeployLocal.s.sol/31337/run-latest.json"
        );
    }
}
