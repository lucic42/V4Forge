// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {ExponentialLaunchpad} from "../src/ExponentialLaunchpad.sol";

contract DeployExponentialLaunchpad is Script {
    address public poolManagerAddress;
    address public tokenAddress;

    // The flags that need to be set in the hook's address
    // Based on your ExponentialLaunchpad.getHookPermissions()
    uint160 constant REQUIRED_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
    );

    // Flag mask for Uniswap V4 hooks (bottom 14 bits)
    uint160 constant FLAGS_MASK = 0x3FFF;

    function run() public {
        // Read deployment parameters
        poolManagerAddress = address(0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408);
        tokenAddress = address(0x036CbD53842c5426634e7929541eC2318f3dCF7e);

        // Calculate initialization code with constructor arguments
        bytes memory initCode = abi.encodePacked(
            type(ExponentialLaunchpad).creationCode, abi.encode(IPoolManager(poolManagerAddress), tokenAddress)
        );

        console.log("Searching for valid salt...");

        // Find a salt that gives us an address with the correct flags
        bytes32 salt = findValidSalt(initCode, REQUIRED_FLAGS);
        console.log("Found valid salt:", vm.toString(salt));

        // Calculate the expected contract address
        address predictedAddress = predictDeterministicAddress(salt, initCode);
        console.log("Predicted deployment address:", predictedAddress);
        console.log("Address flags:", uint160(predictedAddress) & FLAGS_MASK);

        // Begin broadcasting transactions
        vm.startBroadcast();

        // Deploy using CREATE2 with our found salt
        ExponentialLaunchpad hook = new ExponentialLaunchpad{salt: salt}(IPoolManager(poolManagerAddress), tokenAddress);

        // Verify the deployment worked as expected
        require(address(hook) == predictedAddress, "Deployed address mismatch");

        console.log("ExponentialLaunchpad deployed at:", address(hook));
        console.log("Deployed address flags:", uint160(address(hook)) & FLAGS_MASK);

        // Verify the flags match what we need
        require(
            (uint160(address(hook)) & FLAGS_MASK) == REQUIRED_FLAGS, "Deployed address flags don't match required flags"
        );

        vm.stopBroadcast();
    }
}
