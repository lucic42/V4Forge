// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolDonateTest} from "v4-core/src/test/PoolDonateTest.sol";
import {PoolTakeTest} from "v4-core/src/test/PoolTakeTest.sol";
import {PoolClaimsTest} from "v4-core/src/test/PoolClaimsTest.sol";

contract DeployV4Core is Script {
    PoolManager public poolManager;
    PoolSwapTest public swapRouter;
    PoolModifyLiquidityTest public modifyLiquidityRouter;
    PoolDonateTest public donateRouter;
    PoolTakeTest public takeRouter;
    PoolClaimsTest public claimsRouter;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying Uniswap V4 Core Contracts ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        // Deploy PoolManager (core contract)
        poolManager = new PoolManager(500000); // 500k gas limit
        console.log("PoolManager deployed at:", address(poolManager));

        // Deploy test routers for interaction
        swapRouter = new PoolSwapTest(poolManager);
        console.log("SwapRouter deployed at:", address(swapRouter));

        modifyLiquidityRouter = new PoolModifyLiquidityTest(poolManager);
        console.log(
            "ModifyLiquidityRouter deployed at:",
            address(modifyLiquidityRouter)
        );

        donateRouter = new PoolDonateTest(poolManager);
        console.log("DonateRouter deployed at:", address(donateRouter));

        takeRouter = new PoolTakeTest(poolManager);
        console.log("TakeRouter deployed at:", address(takeRouter));

        claimsRouter = new PoolClaimsTest(poolManager);
        console.log("ClaimsRouter deployed at:", address(claimsRouter));

        vm.stopBroadcast();

        console.log("\n=== V4 Core Deployment Complete ===");
        console.log(
            "Next: Update your environment variables and deploy your contracts"
        );
    }
}
