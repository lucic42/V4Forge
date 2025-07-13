// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {PartyVenueWithRewards} from "../venue/PartyVenueWithRewards.sol";
// import {VenueTrackingERC20} from "../tokens/VenueTrackingERC20.sol";
// import {VenueRewardLib} from "../libraries/VenueRewardLib.sol";
// import {PartyTypes} from "../types/PartyTypes.sol";

// /**
//  * @title PresaleRewardExample
//  * @dev Comprehensive example showing how to implement a presale with holding-based rewards
//  *
//  * HOW IT WORKS:
//  * 1. Users contribute ETH to presale via PartyVenueWithRewards
//  * 2. When presale fills/launches, tokens are distributed proportionally
//  * 3. VenueTrackingERC20 notifies venue of all token transfers
//  * 4. Venue tracks holding duration for each contributor
//  * 5. LP fees accumulate in the venue contract
//  * 6. Users can claim rewards = (contribution %) * (LP fees) * (1 + holding bonus)
//  * 7. Holding bonus increases from 0% to 100% over 30 days of holding
//  * 8. When users transfer/sell tokens, their holding timer resets
//  */
// contract PresaleRewardExample {
//     using VenueRewardLib for *;

//     PartyVenueWithRewards public venue;
//     VenueTrackingERC20 public token;

//     // Example configuration
//     uint256 public constant PRESALE_TARGET = 10 ether; // Target 10 ETH
//     uint256 public constant TOKEN_SUPPLY = 1000000 * 1e18; // 1M tokens
//     uint256 public constant MAX_HOLDING_BONUS = 10000; // 100% bonus
//     uint256 public constant HOLDING_TIME_FOR_MAX = 30 days; // 30 days for max bonus

//     address public creator;
//     bool public exampleLaunched;

//     event ExampleLaunched(address venue, address token);
//     event TokensDistributed(uint256 totalDistributed);
//     event RewardExample(
//         address user,
//         uint256 baseReward,
//         uint256 bonus,
//         uint256 total
//     );

//     constructor() {
//         creator = msg.sender;
//     }

//     /**
//      * @dev Launch the example presale system
//      */
//     function launchExample() external {
//         require(msg.sender == creator, "Only creator");
//         require(!exampleLaunched, "Already launched");

//         // 1. Deploy the venue contract
//         venue = new PartyVenueWithRewards(
//             1, // partyId
//             creator, // creator
//             PRESALE_TARGET, // target amount
//             false, // isPrivate
//             address(0) // signer (not needed for public)
//         );

//         // 2. Deploy the token contract with venue tracking
//         token = new VenueTrackingERC20(
//             "Example Token",
//             "EXAMPLE",
//             address(venue)
//         );

//         // 3. Set token address in venue
//         venue.setTokenAddress(address(token));

//         // 4. Configure reward parameters
//         venue.updateRewardConfig(
//             BASIS_POINTS + MAX_HOLDING_BONUS, // 200% max (100% base + 100% bonus)
//             HOLDING_TIME_FOR_MAX
//         );

//         exampleLaunched = true;
//         emit ExampleLaunched(address(venue), address(token));
//     }

//     /**
//      * @dev Simulate presale contributions (for testing)
//      */
//     function simulateContributions() external payable {
//         require(exampleLaunched, "Not launched");

//         // Forward contribution to venue
//         venue.contribute{value: msg.value}();
//     }

//     /**
//      * @dev Distribute tokens to all contributors after presale
//      */
//     function distributeTokens() external {
//         require(exampleLaunched, "Not launched");
//         require(msg.sender == creator, "Only creator");

//         address[] memory contributors = venue.getContributors();
//         uint256[] memory contributions = new uint256[](contributors.length);

//         // Get all contribution amounts
//         for (uint256 i = 0; i < contributors.length; i++) {
//             contributions[i] = venue.contributions(contributors[i]);
//         }

//         // Calculate token distribution
//         uint256[] memory tokenAmounts = VenueRewardLib
//             .calculateTokenDistribution(contributions, TOKEN_SUPPLY);

//         // Mint and distribute tokens
//         uint256 totalDistributed = 0;
//         for (uint256 i = 0; i < contributors.length; i++) {
//             if (tokenAmounts[i] > 0) {
//                 token.mint(contributors[i], tokenAmounts[i]);
//                 venue.distributeTokens(contributors[i], tokenAmounts[i]);
//                 totalDistributed += tokenAmounts[i];
//             }
//         }

//         emit TokensDistributed(totalDistributed);
//     }

//     /**
//      * @dev Simulate LP fee collection (for testing)
//      */
//     function simulateLPFees() external payable {
//         require(exampleLaunched, "Not launched");

//         // Send ETH to venue to simulate LP fees
//         (bool success, ) = payable(address(venue)).call{value: msg.value}("");
//         require(success, "Fee simulation failed");

//         // Trigger fee collection
//         venue.collectLPFees();
//     }

//     /**
//      * @dev Get detailed reward information for a user
//      */
//     function getUserRewardInfo(
//         address user
//     )
//         external
//         view
//         returns (
//             uint256 contributionAmount,
//             uint256 contributionPercentage,
//             uint256 tokenBalance,
//             uint256 totalHoldingTime,
//             bool isCurrentlyHolding,
//             uint256 baseReward,
//             uint256 holdingBonus,
//             uint256 totalClaimable,
//             uint256 alreadyClaimed
//         )
//     {
//         require(exampleLaunched, "Not launched");

//         // Get venue data
//         PartyVenueWithRewards.ContributorData memory data = venue
//             .getContributorData(user);
//         PartyVenueWithRewards.LPRewardInfo memory rewardInfo = venue
//             .getRewardInfo();
//         (, , , uint256 currentAmount, , , ) = venue.getPartyInfo();

//         contributionAmount = data.contributionAmount;
//         tokenBalance = token.balanceOf(user);
//         totalHoldingTime = data.totalHoldingTime;
//         isCurrentlyHolding = data.isCurrentlyHolding;
//         alreadyClaimed = data.feesClaimedTotal;

//         // Calculate contribution percentage
//         contributionPercentage = VenueRewardLib.calculateContributionPercentage(
//             contributionAmount,
//             currentAmount
//         );

//         // Calculate rewards
//         (baseReward, holdingBonus, totalClaimable) = venue.getClaimableRewards(
//             user
//         );
//     }

//     /**
//      * @dev Example: Show how rewards change based on holding time
//      */
//     function demonstrateHoldingBonus(
//         address user
//     )
//         external
//         view
//         returns (
//             uint256 currentBonus,
//             uint256 bonusIn7Days,
//             uint256 bonusIn30Days,
//             uint256 maxPossibleBonus
//         )
//     {
//         require(exampleLaunched, "Not launched");

//         PartyVenueWithRewards.ContributorData memory data = venue
//             .getContributorData(user);
//         uint256 currentHoldingTime = data.totalHoldingTime;
//         if (data.isCurrentlyHolding && data.holdingStartTime > 0) {
//             currentHoldingTime += block.timestamp - data.holdingStartTime;
//         }

//         currentBonus = VenueRewardLib.calculateHoldingBonus(
//             currentHoldingTime,
//             HOLDING_TIME_FOR_MAX
//         );

//         bonusIn7Days = VenueRewardLib.calculateHoldingBonus(
//             currentHoldingTime + 7 days,
//             HOLDING_TIME_FOR_MAX
//         );

//         bonusIn30Days = VenueRewardLib.calculateHoldingBonus(
//             currentHoldingTime + 30 days,
//             HOLDING_TIME_FOR_MAX
//         );

//         maxPossibleBonus = MAX_HOLDING_BONUS; // 100%
//     }

//     /**
//      * @dev Example: Project future rewards
//      */
//     function projectRewards(
//         address user,
//         uint256 daysToProject
//     )
//         external
//         view
//         returns (
//             uint256 currentRewards,
//             uint256 projectedRewards,
//             uint256 additionalRewards
//         )
//     {
//         require(exampleLaunched, "Not launched");

//         (, , currentRewards) = venue.getClaimableRewards(user);

//         PartyVenueWithRewards.ContributorData memory data = venue
//             .getContributorData(user);
//         uint256 currentHoldingTime = data.totalHoldingTime;
//         if (data.isCurrentlyHolding) {
//             currentHoldingTime += block.timestamp - data.holdingStartTime;
//         }

//         projectedRewards = VenueRewardLib.projectFutureRewards(
//             currentRewards,
//             currentHoldingTime,
//             currentHoldingTime + (daysToProject * 1 days),
//             HOLDING_TIME_FOR_MAX,
//             MAX_HOLDING_BONUS
//         );

//         additionalRewards = projectedRewards > currentRewards
//             ? projectedRewards - currentRewards
//             : 0;
//     }

//     /**
//      * @dev Test transfer impact on rewards
//      */
//     function simulateTransferImpact(
//         address user,
//         uint256 transferAmount
//     )
//         external
//         view
//         returns (
//             uint256 rewardsBeforeTransfer,
//             uint256 estimatedRewardsAfterTransfer,
//             uint256 rewardLoss
//         )
//     {
//         require(exampleLaunched, "Not launched");

//         // Current rewards
//         (, , rewardsBeforeTransfer) = venue.getClaimableRewards(user);

//         // Simulate what would happen if they transfer (lose holding time)
//         PartyVenueWithRewards.ContributorData memory data = venue
//             .getContributorData(user);
//         uint256 tokenBalance = token.balanceOf(user);

//         if (transferAmount >= tokenBalance) {
//             // Complete transfer - lose all future holding bonuses
//             estimatedRewardsAfterTransfer = rewardsBeforeTransfer;
//         } else {
//             // Partial transfer - keep some tokens but reset holding timer
//             // This is a simplified estimation
//             estimatedRewardsAfterTransfer = rewardsBeforeTransfer;
//         }

//         rewardLoss = rewardsBeforeTransfer > estimatedRewardsAfterTransfer
//             ? rewardsBeforeTransfer - estimatedRewardsAfterTransfer
//             : 0;
//     }

//     // Helper function for examples
//     function BASIS_POINTS() public pure returns (uint256) {
//         return 10000;
//     }

//     /**
//      * @dev Get comprehensive system status
//      */
//     function getSystemStatus()
//         external
//         view
//         returns (
//             bool launched,
//             uint256 totalContributions,
//             uint256 totalContributors,
//             uint256 totalLPFees,
//             uint256 totalRewardsClaimed,
//             address venueAddress,
//             address tokenAddress
//         )
//     {
//         launched = exampleLaunched;

//         if (launched) {
//             (, , uint256 target, uint256 current, , , ) = venue.getPartyInfo();
//             address[] memory contributors = venue.getContributors();
//             PartyVenueWithRewards.LPRewardInfo memory rewardInfo = venue
//                 .getRewardInfo();

//             totalContributions = current;
//             totalContributors = contributors.length;
//             totalLPFees = rewardInfo.totalFeesCollected;
//             totalRewardsClaimed = rewardInfo.totalFeesDistributed;
//             venueAddress = address(venue);
//             tokenAddress = address(token);
//         }
//     }

//     /**
//      * @dev Emergency functions
//      */
//     function emergencyWithdraw() external {
//         require(msg.sender == creator, "Only creator");
//         payable(creator).transfer(address(this).balance);
//     }

//     receive() external payable {
//         // Allow contract to receive ETH for testing
//     }
// }
