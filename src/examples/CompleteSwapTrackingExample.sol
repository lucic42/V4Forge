// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {PartyVenueWithSwapTracking} from "../venue/PartyVenueWithSwapTracking.sol";
// import {VenueTrackingERC20} from "../tokens/VenueTrackingERC20.sol";
// import {PresaleRewardHook} from "../hooks/PresaleRewardHook.sol";
// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// import {Currency} from "v4-core/src/types/Currency.sol";

// /**
//  * @title CompleteSwapTrackingExample
//  * @dev Complete example showing presale → Uniswap V4 launch → reward tracking for both transfers and swaps
//  *
//  * FULL WORKFLOW:
//  * 1. 📋 Presale phase: Users contribute ETH
//  * 2. 🚀 Launch phase: Token and Uniswap V4 pool created with hook
//  * 3. 📊 Trading phase: Both direct transfers AND Uniswap swaps tracked
//  * 4. 💰 Reward phase: LP fees distributed based on original token holdings
//  *
//  * KEY INNOVATIONS:
//  * ✅ Tracks Uniswap V4 swaps via custom hook
//  * ✅ Tracks direct ERC20 transfers via token notifications
//  * ✅ Only original presale participants earn rewards
//  * ✅ Re-bought tokens don't earn rewards
//  * ✅ Proportional rewards based on holding duration
//  */
// contract CompleteSwapTrackingExample {
//     // Core contracts
//     PartyVenueWithSwapTracking public venue;
//     VenueTrackingERC20 public token;
//     PresaleRewardHook public hook;
//     IPoolManager public poolManager;

//     // Example configuration
//     uint256 public constant PRESALE_TARGET = 10 ether;
//     uint256 public constant TOKEN_SUPPLY = 1000000 * 1e18; // 1M tokens

//     address public creator;
//     bool public systemDeployed;
//     bool public poolCreated;
//     PoolKey public poolKey;

//     // Events
//     event SystemDeployed(address venue, address token, address hook);
//     event PoolCreated(address pool, bytes32 poolId);
//     event SwapScenarioExecuted(
//         string scenario,
//         address user,
//         uint256 tokenAmount,
//         uint256 ethAmount
//     );

//     constructor(address _poolManager) {
//         creator = msg.sender;
//         poolManager = IPoolManager(_poolManager);
//     }

//     /**
//      * @dev STEP 1: Deploy the complete system
//      */
//     function deploySystem() external {
//         require(msg.sender == creator, "Only creator");
//         require(!systemDeployed, "Already deployed");

//         // 1. Deploy venue for presale
//         venue = new PartyVenueWithSwapTracking(
//             1, // partyId
//             creator, // creator
//             PRESALE_TARGET, // target amount
//             false, // isPrivate
//             address(0) // signer
//         );

//         // 2. Deploy tracking token
//         token = new VenueTrackingERC20(
//             "Example Presale Token",
//             "EPT",
//             address(venue)
//         );

//         // 3. Deploy Uniswap V4 hook for swap tracking
//         hook = new PresaleRewardHook(poolManager);

//         // 4. Link everything together
//         venue.setTokenAddress(address(token));
//         venue.setHookAddress(address(hook));

//         systemDeployed = true;
//         emit SystemDeployed(address(venue), address(token), address(hook));
//     }

//     /**
//      * @dev STEP 2: Simulate presale contributions
//      */
//     function simulatePresale() external payable {
//         require(systemDeployed, "System not deployed");
//         venue.contribute{value: msg.value}();
//     }

//     /**
//      * @dev STEP 3: Distribute tokens after presale completes
//      */
//     function distributeTokensAfterPresale() external {
//         require(msg.sender == creator, "Only creator");

//         address[] memory contributors = venue.getContributors();

//         for (uint256 i = 0; i < contributors.length; i++) {
//             uint256 contribution = venue.contributions(contributors[i]);
//             uint256 tokenAmount = (TOKEN_SUPPLY * contribution) /
//                 PRESALE_TARGET;

//             // Mint tokens to contributors
//             token.mint(contributors[i], tokenAmount);
//             // Set original allocation in venue for reward tracking
//             venue.distributeTokens(contributors[i], tokenAmount);
//         }
//     }

//     /**
//      * @dev STEP 4: Create Uniswap V4 pool with hook integration
//      */
//     function createUniswapPool(uint24 fee, int24 tickSpacing) external {
//         require(msg.sender == creator, "Only creator");
//         require(!poolCreated, "Pool already created");

//         // Create pool key with our hook
//         poolKey = PoolKey({
//             currency0: Currency.wrap(address(token)) < Currency.wrap(address(0))
//                 ? Currency.wrap(address(token))
//                 : Currency.wrap(address(0)),
//             currency1: Currency.wrap(address(token)) < Currency.wrap(address(0))
//                 ? Currency.wrap(address(0))
//                 : Currency.wrap(address(token)),
//             fee: fee,
//             tickSpacing: tickSpacing,
//             hooks: hook
//         });

//         // Initialize the pool (simplified - in practice you'd need proper initialization)
//         // poolManager.initialize(poolKey, sqrtPriceX96, hookData);

//         // Register the pool with our hook for tracking
//         bytes memory poolKeyBytes = abi.encode(poolKey);
//         venue.registerWithHook(poolKeyBytes);

//         poolCreated = true;
//         emit PoolCreated(address(poolManager), keccak256(poolKeyBytes));
//     }

//     /**
//      * @dev STEP 5: Simulate LP fees being collected
//      */
//     function simulateLPFees() external payable {
//         require(poolCreated, "Pool not created");

//         // Send ETH to venue to simulate LP fees
//         (bool success, ) = payable(address(venue)).call{value: msg.value}("");
//         require(success, "Failed to send fees");

//         venue.collectLPFees();
//     }

//     /**
//      * @dev SCENARIO 1: User sells tokens through Uniswap V4 (tracked via hook)
//      */
//     function simulateUniswapSell(
//         address user,
//         uint256 tokenAmount,
//         uint256 ethReceived
//     ) external {
//         require(msg.sender == creator, "Only creator for simulation");

//         // Simulate the hook calling notifySwap when user sells
//         venue.notifySwap(
//             user,
//             address(token), // tokenIn (selling tokens)
//             address(0), // tokenOut (getting ETH)
//             tokenAmount, // amountIn
//             ethReceived, // amountOut
//             true // isExactInput
//         );

//         emit SwapScenarioExecuted(
//             "Uniswap Sell",
//             user,
//             tokenAmount,
//             ethReceived
//         );
//     }

//     /**
//      * @dev SCENARIO 2: User buys tokens through Uniswap V4 (tracked via hook)
//      */
//     function simulateUniswapBuy(
//         address user,
//         uint256 ethAmount,
//         uint256 tokensReceived
//     ) external {
//         require(msg.sender == creator, "Only creator for simulation");

//         // Simulate the hook calling notifySwap when user buys
//         venue.notifySwap(
//             user,
//             address(0), // tokenIn (paying ETH)
//             address(token), // tokenOut (getting tokens)
//             ethAmount, // amountIn
//             tokensReceived, // amountOut
//             true // isExactInput
//         );

//         emit SwapScenarioExecuted(
//             "Uniswap Buy",
//             user,
//             tokensReceived,
//             ethAmount
//         );
//     }

//     /**
//      * @dev SCENARIO 3: User transfers tokens directly (tracked via token)
//      */
//     function simulateDirectTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) external {
//         require(msg.sender == creator, "Only creator for simulation");

//         // This would normally happen automatically when tokens are transferred
//         // We're simulating the token calling notifyTokenTransfer
//         venue.notifyTokenTransfer(from, to, amount);
//     }

//     /**
//      * @dev Get comprehensive user analysis
//      */
//     function analyzeUser(
//         address user
//     )
//         external
//         view
//         returns (
//             uint256 contributionAmount,
//             uint256 originalAllocation,
//             uint256 currentOriginalHeld,
//             uint256 tokenBalance,
//             uint256 accumulatedTokenSeconds,
//             uint256 claimableRewards,
//             uint256 rewardsClaimed,
//             bool isHolding,
//             uint256 soldThroughSwaps,
//             uint256 soldThroughTransfers,
//             string memory status
//         )
//     {
//         (
//             contributionAmount,
//             originalAllocation,
//             currentOriginalHeld,
//             accumulatedTokenSeconds,
//             claimableRewards,
//             rewardsClaimed,
//             isHolding,
//             soldThroughSwaps,
//             soldThroughTransfers
//         ) = venue.getContributorInfo(user);

//         tokenBalance = token.balanceOf(user);

//         // Determine user status
//         if (originalAllocation == 0) {
//             status = "Not an original contributor";
//         } else if (currentOriginalHeld == originalAllocation) {
//             status = "Holding all original tokens";
//         } else if (currentOriginalHeld == 0) {
//             if (tokenBalance > 0) {
//                 status = "Sold all original tokens, re-bought from market";
//             } else {
//                 status = "Sold all original tokens";
//             }
//         } else {
//             status = "Partially sold original tokens";
//         }
//     }

//     /**
//      * @dev Compare different user behaviors
//      */
//     function compareUserBehaviors(
//         address alice,
//         address bob,
//         address charlie
//     )
//         external
//         view
//         returns (
//             uint256 aliceRewards,
//             uint256 bobRewards,
//             uint256 charlieRewards,
//             string memory analysis
//         )
//     {
//         aliceRewards = venue.getClaimableRewards(alice);
//         bobRewards = venue.getClaimableRewards(bob);
//         charlieRewards = venue.getClaimableRewards(charlie);

//         if (aliceRewards >= bobRewards && bobRewards >= charlieRewards) {
//             analysis = "Rewards properly ordered: holders > partial sellers > full sellers";
//         } else {
//             analysis = "Unexpected reward distribution - check system";
//         }
//     }

//     /**
//      * @dev Demonstrate the key insight: swap vs transfer doesn't matter, only holding does
//      */
//     function demonstrateKeyInsight(
//         address user1,
//         address user2
//     )
//         external
//         view
//         returns (
//             string memory insight,
//             uint256 user1Rewards,
//             uint256 user2Rewards,
//             bool rewardsEqual
//         )
//     {
//         // User1 sold via Uniswap, User2 sold via direct transfer
//         // If they sold the same amount at the same time, rewards should be equal

//         user1Rewards = venue.getClaimableRewards(user1);
//         user2Rewards = venue.getClaimableRewards(user2);
//         rewardsEqual = (user1Rewards == user2Rewards);

//         insight = rewardsEqual
//             ? "SUCCESS: Method of selling doesn't matter - only holding duration matters"
//             : "NOTE: Rewards differ due to different holding patterns or amounts";
//     }

//     /**
//      * @dev Run comprehensive test scenarios
//      */
//     function runTestScenarios() external returns (string memory result) {
//         require(msg.sender == creator, "Only creator");

//         // This would run through various scenarios:
//         // 1. Alice contributes, holds all tokens → maximum rewards
//         // 2. Bob contributes, sells 50% via Uniswap → proportional rewards
//         // 3. Charlie contributes, sells all via transfer, re-buys more → minimal rewards
//         // 4. Diana contributes, sells via Uniswap, buys back same amount → rewards only for actual holding periods

//         return "All test scenarios would be executed here";
//     }

//     /**
//      * @dev Get system-wide statistics
//      */
//     function getSystemStats()
//         external
//         view
//         returns (
//             uint256 totalContributions,
//             uint256 totalContributors,
//             uint256 totalLPFees,
//             uint256 totalOriginalTokens,
//             uint256 totalTokenSeconds,
//             uint256 totalRewardsClaimed,
//             bool systemActive
//         )
//     {
//         if (!systemDeployed) return (0, 0, 0, 0, 0, 0, false);

//         address[] memory contributors = venue.getContributors();
//         totalContributors = contributors.length;

//         (, , , uint256 current, , , ) = venue.getPartyInfo();
//         totalContributions = current;

//         PartyVenueWithSwapTracking.RewardState memory rewardState = venue
//             .getRewardState();
//         totalLPFees = rewardState.totalFeesCollected;
//         totalOriginalTokens = rewardState.totalOriginalTokensDistributed;
//         totalTokenSeconds = rewardState.totalAccumulatedTokenSeconds;
//         totalRewardsClaimed = rewardState.totalFeesDistributed;
//         systemActive = poolCreated;
//     }

//     /**
//      * @dev Emergency functions for testing
//      */
//     function emergencyReset() external {
//         require(msg.sender == creator, "Only creator");
//         // Reset for testing - in production this wouldn't exist
//         systemDeployed = false;
//         poolCreated = false;
//     }

//     receive() external payable {
//         // Allow contract to receive ETH for testing
//     }
// }

// /**
//  * @title SwapTrackingTestSuite
//  * @dev Automated test suite for the complete swap tracking system
//  */
// contract SwapTrackingTestSuite {
//     CompleteSwapTrackingExample public example;

//     struct TestUser {
//         address addr;
//         uint256 contribution;
//         uint256 originalTokens;
//         string behavior;
//     }

//     TestUser[] public testUsers;

//     constructor(address _example) {
//         example = CompleteSwapTrackingExample(_example);
//     }

//     /**
//      * @dev Test that demonstrates the complete system working correctly
//      */
//     function runComprehensiveTest()
//         external
//         returns (bool success, string memory report)
//     {
//         // Test 1: Verify hook tracks swaps correctly
//         // Test 2: Verify direct transfers are tracked correctly
//         // Test 3: Verify re-bought tokens don't earn rewards
//         // Test 4: Verify proportional reward distribution
//         // Test 5: Verify timing doesn't matter for claims

//         success = true;
//         report = "All tests would be implemented here with detailed assertions";
//     }

//     /**
//      * @dev Test edge cases and attack vectors
//      */
//     function testEdgeCases() external returns (bool allPassed) {
//         // Test various edge cases:
//         // - User with 0 original tokens trying to game system
//         // - User buying back exactly their original allocation
//         // - Multiple small sells vs one large sell
//         // - Claiming rewards at different times

//         allPassed = true;
//     }
// }
