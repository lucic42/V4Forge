// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Owned} from "solmate/auth/Owned.sol";
// import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {PartyErrors} from "../types/PartyErrors.sol";
// import {PartyTypes} from "../types/PartyTypes.sol";

// interface IPartyStarter {
//     function launchFromVenue(uint256 partyId) external payable;
// }

// interface IPresaleRewardHook {
//     function registerPresalePool(
//         bytes calldata poolKey,
//         address venue
//     ) external;
// }

// /**
//  * @title PartyVenueWithSwapTracking
//  * @dev Enhanced venue that tracks both direct transfers AND Uniswap V4 swaps
//  * for comprehensive reward calculation when users trade presale tokens
//  *
//  * KEY FEATURES:
//  * - Tracks direct ERC20 transfers via token notifications
//  * - Tracks Uniswap V4 swaps via hook integration
//  * - Only original presale contributors can earn rewards
//  * - Swaps and transfers both affect original token holdings proportionally
//  */
// contract PartyVenueWithSwapTracking is Owned, ReentrancyGuard {
//     using ECDSA for bytes32;
//     using PartyErrors for *;

//     struct PartyInfo {
//         uint256 partyId;
//         address creator;
//         uint256 targetAmount;
//         uint256 currentAmount;
//         bool launched;
//         bool isPrivate;
//         address signerAddress;
//         address tokenAddress;
//         address hookAddress; // Address of the Uniswap V4 hook
//         mapping(bytes32 => bool) usedSignatures;
//     }

//     struct ContributorData {
//         uint256 contributionAmount; // Original ETH contribution (immutable)
//         uint256 originalTokenAllocation; // Original presale tokens (immutable)
//         uint256 currentOriginalTokensHeld; // Current original tokens held
//         uint256 accumulatedTokenSeconds; // Accumulated "token-seconds" for rewards
//         uint256 lastUpdateTimestamp; // Last accumulation update
//         uint256 rewardsClaimed; // Total rewards claimed
//         bool isCurrentlyHolding; // Currently holding any original tokens
//         uint256 totalSoldThroughSwaps; // Total original tokens sold via swaps
//         uint256 totalSoldThroughTransfers; // Total original tokens sold via transfers
//     }

//     struct RewardState {
//         uint256 totalFeesCollected;
//         uint256 totalFeesDistributed;
//         uint256 totalOriginalTokensDistributed;
//         uint256 totalAccumulatedTokenSeconds;
//         uint256 lastFeeCollection;
//     }

//     PartyInfo public partyInfo;
//     RewardState public rewardState;
//     address public immutable partyStarter;
//     address[] public contributors;
//     mapping(address => ContributorData) public contributorData;
//     mapping(address => uint256) public contributions;

//     // Events
//     event ContributionReceived(address indexed contributor, uint256 amount);
//     event PartyLaunched(uint256 totalAmount);
//     event TokensDistributed(
//         address indexed contributor,
//         uint256 originalAllocation
//     );
//     event SwapTracked(
//         address indexed user,
//         bool isSelling,
//         uint256 tokenAmount
//     );
//     event TransferTracked(
//         address indexed from,
//         address indexed to,
//         uint256 originalTokenAmount
//     );
//     event RewardsAccumulated(address indexed contributor, uint256 tokenSeconds);
//     event RewardsClaimed(address indexed contributor, uint256 amount);
//     event FeesCollected(uint256 newFees, uint256 totalFees);
//     event HookRegistered(address indexed hook);

//     modifier onlyPartyStarter() {
//         require(msg.sender == partyStarter, "Only PartyStarter");
//         _;
//     }

//     modifier onlyCreator() {
//         require(msg.sender == partyInfo.creator, "Only creator");
//         _;
//     }

//     modifier onlyTokenOrHook() {
//         require(
//             msg.sender == partyInfo.tokenAddress ||
//                 msg.sender == partyInfo.hookAddress,
//             "Only token or hook"
//         );
//         _;
//     }

//     constructor(
//         uint256 _partyId,
//         address _creator,
//         uint256 _targetAmount,
//         bool _isPrivate,
//         address _signerAddress
//     ) Owned(_creator) {
//         partyStarter = msg.sender;
//         partyInfo.partyId = _partyId;
//         partyInfo.creator = _creator;
//         partyInfo.targetAmount = _targetAmount;
//         partyInfo.isPrivate = _isPrivate;
//         partyInfo.signerAddress = _signerAddress;
//     }

//     /**
//      * @dev Set the token address after launch
//      */
//     function setTokenAddress(address tokenAddress) external onlyPartyStarter {
//         partyInfo.tokenAddress = tokenAddress;
//     }

//     /**
//      * @dev Set the hook address for swap tracking
//      */
//     function setHookAddress(address hookAddress) external onlyCreator {
//         partyInfo.hookAddress = hookAddress;
//         emit HookRegistered(hookAddress);
//     }

//     /**
//      * @dev Register this venue with the Uniswap V4 hook for swap tracking
//      */
//     function registerWithHook(bytes calldata poolKey) external onlyCreator {
//         require(partyInfo.hookAddress != address(0), "Hook not set");
//         IPresaleRewardHook(partyInfo.hookAddress).registerPresalePool(
//             poolKey,
//             address(this)
//         );
//     }

//     /**
//      * @dev Contribute ETH to presale
//      */
//     function contribute() external payable nonReentrant {
//         require(!partyInfo.isPrivate, "Private party requires signature");
//         _processContribution();
//     }

//     /**
//      * @dev Distribute original presale tokens
//      */
//     function distributeTokens(
//         address contributor,
//         uint256 tokenAmount
//     ) external onlyPartyStarter {
//         ContributorData storage data = contributorData[contributor];
//         require(data.contributionAmount > 0, "Not a contributor");
//         require(data.originalTokenAllocation == 0, "Already distributed");

//         data.originalTokenAllocation = tokenAmount;
//         data.currentOriginalTokensHeld = tokenAmount;
//         data.lastUpdateTimestamp = block.timestamp;
//         data.isCurrentlyHolding = true;

//         rewardState.totalOriginalTokensDistributed += tokenAmount;

//         emit TokensDistributed(contributor, tokenAmount);
//     }

//     /**
//      * @dev Called by token contract for direct transfers
//      */
//     function notifyTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) external onlyTokenOrHook {
//         if (from != address(0)) {
//             _updateAccumulation(from);
//         }
//         if (to != address(0)) {
//             _updateAccumulation(to);
//         }

//         if (from != address(0)) {
//             _handleDirectTransferFrom(from, amount);
//         }
//         if (to != address(0)) {
//             _handleDirectTransferTo(to, amount);
//         }
//     }

//     /**
//      * @dev Called by Uniswap V4 hook for swap notifications
//      */
//     function notifySwap(
//         address user,
//         address tokenIn,
//         address tokenOut,
//         uint256 amountIn,
//         uint256 amountOut,
//         bool isExactInput
//     ) external onlyTokenOrHook {
//         // Only process swaps from original contributors
//         if (contributorData[user].originalTokenAllocation == 0) return;

//         _updateAccumulation(user);

//         bool isSelling = tokenIn == partyInfo.tokenAddress;
//         uint256 tokenAmount = isSelling ? amountIn : amountOut;

//         if (isSelling) {
//             _handleSwapSell(user, tokenAmount);
//         } else {
//             _handleSwapBuy(user, tokenAmount);
//         }

//         emit SwapTracked(user, isSelling, tokenAmount);
//     }

//     /**
//      * @dev Handle selling tokens through Uniswap V4
//      */
//     function _handleSwapSell(address user, uint256 tokenAmount) internal {
//         ContributorData storage data = contributorData[user];

//         // Calculate how many of these are original tokens
//         uint256 originalTokensSold = _calculateOriginalTokensInAmount(
//             user,
//             tokenAmount
//         );

//         if (originalTokensSold > 0) {
//             data.currentOriginalTokensHeld -= originalTokensSold;
//             data.totalSoldThroughSwaps += originalTokensSold;

//             if (data.currentOriginalTokensHeld == 0) {
//                 data.isCurrentlyHolding = false;
//             }
//         }
//     }

//     /**
//      * @dev Handle buying tokens through Uniswap V4
//      */
//     function _handleSwapBuy(address user, uint256 tokenAmount) internal {
//         ContributorData storage data = contributorData[user];

//         // User can only "regain" up to their original allocation
//         uint256 maxCanRegain = data.originalTokenAllocation -
//             data.currentOriginalTokensHeld;
//         uint256 originalTokensRegained = tokenAmount > maxCanRegain
//             ? maxCanRegain
//             : tokenAmount;

//         if (originalTokensRegained > 0) {
//             data.currentOriginalTokensHeld += originalTokensRegained;
//             data.isCurrentlyHolding = true;
//             data.lastUpdateTimestamp = block.timestamp; // Reset accumulation timer
//         }
//     }

//     /**
//      * @dev Handle direct token transfers FROM a user
//      */
//     function _handleDirectTransferFrom(address from, uint256 amount) internal {
//         ContributorData storage data = contributorData[from];
//         if (data.originalTokenAllocation == 0) return;

//         uint256 originalTokensTransferred = _calculateOriginalTokensInAmount(
//             from,
//             amount
//         );

//         if (originalTokensTransferred > 0) {
//             data.currentOriginalTokensHeld -= originalTokensTransferred;
//             data.totalSoldThroughTransfers += originalTokensTransferred;

//             if (data.currentOriginalTokensHeld == 0) {
//                 data.isCurrentlyHolding = false;
//             }

//             emit TransferTracked(from, address(0), originalTokensTransferred);
//         }
//     }

//     /**
//      * @dev Handle direct token transfers TO a user
//      */
//     function _handleDirectTransferTo(address to, uint256 amount) internal {
//         ContributorData storage data = contributorData[to];
//         if (data.originalTokenAllocation == 0) return;

//         // Can only regain up to original allocation
//         uint256 maxCanRegain = data.originalTokenAllocation -
//             data.currentOriginalTokensHeld;
//         uint256 originalTokensRegained = amount > maxCanRegain
//             ? maxCanRegain
//             : amount;

//         if (originalTokensRegained > 0) {
//             data.currentOriginalTokensHeld += originalTokensRegained;
//             data.isCurrentlyHolding = true;
//             data.lastUpdateTimestamp = block.timestamp;

//             emit TransferTracked(address(0), to, originalTokensRegained);
//         }
//     }

//     /**
//      * @dev Calculate how many "original tokens" are involved in a transfer/swap
//      * This handles the case where user has more tokens than their original allocation
//      */
//     function _calculateOriginalTokensInAmount(
//         address user,
//         uint256 amount
//     ) internal view returns (uint256) {
//         ContributorData memory data = contributorData[user];
//         uint256 currentBalance = IERC20(partyInfo.tokenAddress).balanceOf(user);

//         // If current balance <= original held, all tokens being moved are original tokens
//         if (currentBalance <= data.currentOriginalTokensHeld) {
//             return amount > currentBalance ? currentBalance : amount;
//         }

//         // If user has more tokens than original allocation, only count original tokens
//         uint256 originalTokensInBalance = data.currentOriginalTokensHeld;
//         return
//             amount > originalTokensInBalance ? originalTokensInBalance : amount;
//     }

//     /**
//      * @dev Update token-seconds accumulation
//      */
//     function _updateAccumulation(address contributor) internal {
//         ContributorData storage data = contributorData[contributor];
//         if (data.originalTokenAllocation == 0 || !data.isCurrentlyHolding)
//             return;

//         uint256 timeElapsed = block.timestamp - data.lastUpdateTimestamp;
//         if (timeElapsed > 0 && data.currentOriginalTokensHeld > 0) {
//             uint256 tokenSeconds = data.currentOriginalTokensHeld * timeElapsed;
//             data.accumulatedTokenSeconds += tokenSeconds;
//             rewardState.totalAccumulatedTokenSeconds += tokenSeconds;

//             emit RewardsAccumulated(contributor, tokenSeconds);
//         }

//         data.lastUpdateTimestamp = block.timestamp;
//     }

//     /**
//      * @dev Collect LP fees
//      */
//     function collectLPFees() external {
//         uint256 currentBalance = address(this).balance;
//         uint256 newFees = currentBalance - rewardState.totalFeesCollected;

//         if (newFees > 0) {
//             rewardState.totalFeesCollected = currentBalance;
//             rewardState.lastFeeCollection = block.timestamp;
//             emit FeesCollected(newFees, currentBalance);
//         }
//     }

//     /**
//      * @dev Calculate claimable rewards
//      */
//     function getClaimableRewards(
//         address contributor
//     ) public view returns (uint256) {
//         ContributorData memory data = contributorData[contributor];
//         if (data.originalTokenAllocation == 0) return 0;

//         uint256 totalTokenSeconds = data.accumulatedTokenSeconds;
//         if (data.isCurrentlyHolding && data.currentOriginalTokensHeld > 0) {
//             uint256 timeElapsed = block.timestamp - data.lastUpdateTimestamp;
//             totalTokenSeconds += data.currentOriginalTokensHeld * timeElapsed;
//         }

//         if (rewardState.totalAccumulatedTokenSeconds == 0) return 0;

//         uint256 totalEarned = (rewardState.totalFeesCollected *
//             totalTokenSeconds) / rewardState.totalAccumulatedTokenSeconds;

//         if (totalEarned > data.rewardsClaimed) {
//             return totalEarned - data.rewardsClaimed;
//         }

//         return 0;
//     }

//     /**
//      * @dev Claim rewards
//      */
//     function claimRewards() external nonReentrant {
//         _updateAccumulation(msg.sender);

//         uint256 claimable = getClaimableRewards(msg.sender);
//         require(claimable > 0, "No rewards to claim");

//         contributorData[msg.sender].rewardsClaimed += claimable;
//         rewardState.totalFeesDistributed += claimable;

//         (bool success, ) = payable(msg.sender).call{value: claimable}("");
//         require(success, "Transfer failed");

//         emit RewardsClaimed(msg.sender, claimable);
//     }

//     /**
//      * @dev Check if address is an original contributor (for hook interface)
//      */
//     function isOriginalContributor(address user) external view returns (bool) {
//         return contributorData[user].originalTokenAllocation > 0;
//     }

//     /**
//      * @dev Get original token address (for hook interface)
//      */
//     function getOriginalTokenAddress() external view returns (address) {
//         return partyInfo.tokenAddress;
//     }

//     /**
//      * @dev Get comprehensive contributor information
//      */
//     function getContributorInfo(
//         address contributor
//     )
//         external
//         view
//         returns (
//             uint256 contributionAmount,
//             uint256 originalAllocation,
//             uint256 currentOriginalHeld,
//             uint256 accumulatedTokenSeconds,
//             uint256 claimableRewards,
//             uint256 rewardsClaimed,
//             bool isHolding,
//             uint256 soldThroughSwaps,
//             uint256 soldThroughTransfers
//         )
//     {
//         ContributorData memory data = contributorData[contributor];
//         return (
//             data.contributionAmount,
//             data.originalTokenAllocation,
//             data.currentOriginalTokensHeld,
//             data.accumulatedTokenSeconds,
//             getClaimableRewards(contributor),
//             data.rewardsClaimed,
//             data.isCurrentlyHolding,
//             data.totalSoldThroughSwaps,
//             data.totalSoldThroughTransfers
//         );
//     }

//     /**
//      * @dev Manual launch by creator
//      */
//     function manualLaunch() external onlyCreator {
//         require(!partyInfo.launched, "Already launched");
//         require(partyInfo.currentAmount > 0, "No funds");
//         _triggerLaunch();
//     }

//     function _triggerLaunch() internal {
//         partyInfo.launched = true;
//         uint256 balance = address(this).balance;
//         IPartyStarter(partyStarter).launchFromVenue{value: balance}(
//             partyInfo.partyId
//         );
//         emit PartyLaunched(balance);
//     }

//     function _processContribution() internal {
//         require(!partyInfo.launched, "Already launched");
//         require(msg.value > 0, "Zero amount");

//         bool isFirstContribution = contributions[msg.sender] == 0;
//         if (isFirstContribution) {
//             contributors.push(msg.sender);
//         }

//         contributions[msg.sender] += msg.value;
//         contributorData[msg.sender].contributionAmount += msg.value;
//         partyInfo.currentAmount += msg.value;

//         emit ContributionReceived(msg.sender, msg.value);

//         if (partyInfo.currentAmount >= partyInfo.targetAmount) {
//             _triggerLaunch();
//         }
//     }

//     // View functions
//     function getContributors() external view returns (address[] memory) {
//         return contributors;
//     }

//     function getPartyInfo()
//         external
//         view
//         returns (
//             uint256 partyId,
//             address creator,
//             uint256 targetAmount,
//             uint256 currentAmount,
//             bool launched,
//             bool isPrivate,
//             address tokenAddress,
//             address hookAddress
//         )
//     {
//         return (
//             partyInfo.partyId,
//             partyInfo.creator,
//             partyInfo.targetAmount,
//             partyInfo.currentAmount,
//             partyInfo.launched,
//             partyInfo.isPrivate,
//             partyInfo.tokenAddress,
//             partyInfo.hookAddress
//         );
//     }

//     function getRewardState() external view returns (RewardState memory) {
//         return rewardState;
//     }

//     receive() external payable {
//         if (!partyInfo.launched && !partyInfo.isPrivate) {
//             _processContribution();
//         }
//     }
// }
