// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {DutchAuctionLaunchPad} from "src/DutchAuctionLaunchpad.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

contract DeployDutchAuctionLaunchpad is Script {
    function run() public {
        // Begin recording transactions to broadcast
        vm.startBroadcast();

        // Address of the deployed Uniswap V4 Pool Manager
        address poolManagerAddress = address(0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408); // V4 PoolManager address

        // Define hook flags - same as in your test
        uint160 flags =
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG);

        // Find a salt for our hook deployment using HookMiner
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this), flags, type(DutchAuctionLaunchPad).creationCode, abi.encode(address(poolManagerAddress))
        );

        console.log("Found salt for hook deployment:", uint256(salt));
        console.log("Predicted hook address:", hookAddress);

        // Deploy the hook with the calculated salt
        DutchAuctionLaunchPad hook = new DutchAuctionLaunchPad(IPoolManager(poolManagerAddress));

        // Verify hook address matches predicted address
        require(address(hook) == hookAddress, "DutchAuctionLaunchPad: hook address mismatch");

        console.log("DutchAuctionLaunchPad deployed at:", address(hook));

        vm.stopBroadcast();
    }
}
