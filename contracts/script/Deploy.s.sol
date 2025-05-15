// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/UniswapV4ERC20.sol";
import "../src/Airdrop.sol";
import "../src/ExponentialLaunchpad.sol";
import "../src/DutchAuctionLaunchPad.sol";

contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // // Deploy ERC20 token first
        // UniswapV4ERC20 token = new UniswapV4ERC20(arg1, arg2);
        // console.log("UniswapV4ERC20 deployed at:", address(token));

        address feeReceiver = 0x690C65EB2e2dd321ACe41a9865Aea3fAa98be2A5;
        uint256 initialServiceFee = 20000000000000;

        // Deploy Airdrop contract
        AirDrop airdrop = new AirDrop(payable(feeReceiver), initialServiceFee);
        console.log("Airdrop deployed at:", address(airdrop));

        // Deploy Exponential Launchpad
        ExponentialLaunchpad expLaunchpad = new ExponentialLaunchpad(arg1, arg2);
        console.log("ExponentialLaunchpad deployed at:", address(expLaunchpad));

        // Deploy Dutch Auction Launchpad
        DutchAuctionLaunchPad dutchLaunchpad = new DutchAuctionLaunchPad(IPoolManager(address(token)));
        console.log("DutchAuctionLaunchPad deployed at:", address(dutchLaunchpad));

        vm.stopBroadcast();
    }
}
