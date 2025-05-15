// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Airdrop.sol";

contract DeployAirdropScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address feeReceiver = 0x690C65EB2e2dd321ACe41a9865Aea3fAa98be2A5;
        uint256 initialServiceFee = 20000000000000;

        // Deploy Airdrop contract
        AirDrop airdrop = new AirDrop(payable(feeReceiver), initialServiceFee);
        console.log("Airdrop deployed at:", address(airdrop));

        vm.stopBroadcast();
    }
} 