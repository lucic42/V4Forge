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
//     function getLPPosition(
//         uint256 partyId
//     ) external view returns (PartyTypes.LPPosition memory);
// }

// /**
//  * @title PartyVenueWithRewardsFixed
//  * @dev Fixed venue contract that properly tracks original presale allocations and prevents gaming
//  *
//  * KEY FIXES:
//  * 1. Tracks original presale tokens separately from current balance
//  * 2. Locks in rewards when transfers occur (no timing manipulation)
//  * 3. Re-bought tokens don't earn rewards (only original presale allocation)
//  * 4. Uses "original-token-seconds" for accurate weighted time calculations
//  */
// contract PartyVenueWithRewardsFixed is Owned, ReentrancyGuard {
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
//         mapping(bytes32 => bool) usedSignatures;
//     }

//     struct ContributorData {
//         uint256 contributionAmount; // Original ETH contribution
//         uint256 originalTokenAllocation; // Original presale token allocation (NEVER changes)
//         uint256 currentTokensHeld; // Current tokens held (updated on transfers)
//         uint256 lastRewardSnapshot; // Last time rewards were snapshotted
//         uint256 accumulatedRewardShares; // Accumulated "token-seconds" of holding
//         uint256 rewardsLocked; // Rewards locked in from past holding periods
//         uint256 rewardsClaimed; // Total rewards already claimed
//         bool isCurrentlyHolding; // Whether currently holding any original tokens
//         uint256 distributionTimestamp; // When tokens were first distributed
//     }

//     struct RewardSnapshot {
//         uint256 timestamp;
//         uint256 totalLPFeesAtSnapshot;
//         uint256 totalRewardSharesAtSnapshot; // Total "token-seconds" across all users
//     }

//     struct LPRewardInfo {
//         uint256 totalFeesCollected;
//         uint256 totalFeesDistributed;
//         uint256 lastFeeCollection;
//         uint256 totalOriginalTokens; // Total original presale tokens distributed
//         uint256 totalRewardShares; // Total accumulated "token-seconds" across all users
//         uint256 lastGlobalSnapshot; // Last global snapshot timestamp
//     }

//     PartyInfo public partyInfo;
//     LPRewardInfo public rewardInfo;
//     address public immutable partyStarter;
//     address[] public contributors;
//     mapping(address => ContributorData) public contributorData;
//     mapping(address => uint256) public contributions; // For backward compatibility

//     // Reward snapshots for accurate calculations
//     RewardSnapshot[] public rewardSnapshots;
//     mapping(address => uint256) public lastProcessedSnapshot; // Last snapshot index processed per user

//     // Events
//     event ContributionReceived(address indexed contributor, uint256 amount);
//     event PartyLaunched(uint256 totalAmount);
//     event SignerUpdated(address indexed newSigner);
//     event TokensDistributed(
//         address indexed contributor,
//         uint256 originalAllocation
//     );
//     event OriginalTokenTransfer(
//         address indexed from,
//         address indexed to,
//         uint256 originalAmount,
//         uint256 actualAmount
//     );
//     event RewardsSnapshotted(
//         address indexed contributor,
//         uint256 accumulatedShares,
//         uint256 lockedRewards
//     );
//     event RewardsClaimed(address indexed contributor, uint256 amount);
//     event GlobalSnapshot(
//         uint256 timestamp,
//         uint256 totalFees,
//         uint256 totalShares
//     );

//     // Enhanced events for comprehensive data capture
//     event ContributionProgress(
//         uint256 indexed partyId,
//         address indexed contributor,
//         uint256 contributionAmount,
//         uint256 totalRaised,
//         uint256 targetAmount,
//         uint8 progressPercentage,
//         uint256 contributorCount,
//         uint256 timestamp
//     );

//     modifier onlyPartyStarter() {
//         PartyErrors.requireAuthorized(
//             msg.sender == partyStarter,
//             PartyErrors.ErrorCode.ONLY_PARTY_STARTER
//         );
//         _;
//     }

//     modifier onlyCreator() {
//         PartyErrors.requireAuthorized(
//             msg.sender == partyInfo.creator,
//             PartyErrors.ErrorCode.ONLY_CREATOR
//         );
//         _;
//     }

//     modifier onlyToken() {
//         PartyErrors.requireAuthorized(
//             msg.sender == partyInfo.tokenAddress,
//             PartyErrors.ErrorCode.UNAUTHORIZED
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

//         // Initialize with first snapshot
//         rewardSnapshots.push(
//             RewardSnapshot({
//                 timestamp: block.timestamp,
//                 totalLPFeesAtSnapshot: 0,
//                 totalRewardSharesAtSnapshot: 0
//             })
//         );
//         rewardInfo.lastGlobalSnapshot = block.timestamp;
//     }

//     /**
//      * @dev Set the token address after launch (called by PartyStarter)
//      */
//     function setTokenAddress(address tokenAddress) external onlyPartyStarter {
//         partyInfo.tokenAddress = tokenAddress;
//     }

//     /**
//      * @dev Contribute ETH to this party (public parties only)
//      */
//     function contribute() external payable nonReentrant {
//         PartyErrors.requireValidState(
//             !partyInfo.isPrivate,
//             PartyErrors.ErrorCode.SIGNATURE_REQUIRED
//         );
//         _contribute();
//     }

//     /**
//      * @dev Contribute with signature authorization (private parties)
//      */
//     function contributeWithSignature(
//         bytes calldata signature,
//         uint256 maxAmount,
//         uint256 deadline
//     ) external payable nonReentrant {
//         PartyErrors.requireValidState(
//             partyInfo.isPrivate,
//             PartyErrors.ErrorCode.NOT_WHITELISTED
//         );
//         PartyErrors.requireValidState(
//             block.timestamp <= deadline,
//             PartyErrors.ErrorCode.SIGNATURE_EXPIRED
//         );
//         PartyErrors.requireValidState(
//             msg.value <= maxAmount,
//             PartyErrors.ErrorCode.CONTRIBUTION_TOO_HIGH
//         );

//         // Create and verify signature
//         bytes32 messageHash = keccak256(
//             abi.encodePacked(
//                 "\x19Ethereum Signed Message:\n32",
//                 keccak256(
//                     abi.encodePacked(
//                         partyInfo.partyId,
//                         msg.sender,
//                         maxAmount,
//                         deadline
//                     )
//                 )
//             )
//         );

//         PartyErrors.requireValidState(
//             !partyInfo.usedSignatures[messageHash],
//             PartyErrors.ErrorCode.SIGNATURE_ALREADY_USED
//         );

//         address recoveredSigner = messageHash.recover(signature);
//         PartyErrors.requireValidState(
//             recoveredSigner == partyInfo.signerAddress,
//             PartyErrors.ErrorCode.INVALID_SIGNATURE
//         );

//         partyInfo.usedSignatures[messageHash] = true;
//         _processContribution();
//     }

//     /**
//      * @dev Distribute original presale tokens to contributors after launch
//      * This sets the ORIGINAL allocation that will be used for all reward calculations
//      */
//     function distributeTokens(
//         address contributor,
//         uint256 tokenAmount
//     ) external onlyPartyStarter {
//         ContributorData storage data = contributorData[contributor];
//         require(data.contributionAmount > 0, "Not a contributor");
//         require(data.originalTokenAllocation == 0, "Already distributed");

//         // Set the original allocation (this NEVER changes)
//         data.originalTokenAllocation = tokenAmount;
//         data.currentTokensHeld = tokenAmount;
//         data.distributionTimestamp = block.timestamp;
//         data.lastRewardSnapshot = block.timestamp;
//         data.isCurrentlyHolding = true;

//         // Update global tracking
//         rewardInfo.totalOriginalTokens += tokenAmount;

//         emit TokensDistributed(contributor, tokenAmount);
//     }

//     /**
//      * @dev Called by token contract when tokens are transferred
//      * Only tracks transfers that affect ORIGINAL presale tokens
//      */
//     function notifyTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) external onlyToken {
//         if (from != address(0) && from != address(this)) {
//             _handleTokenTransferFrom(from, amount);
//         }
//         if (to != address(0) && to != address(this)) {
//             _handleTokenTransferTo(to, amount);
//         }
//     }

//     /**
//      * @dev Handle tokens being transferred FROM a contributor
//      */
//     function _handleTokenTransferFrom(address from, uint256 amount) internal {
//         ContributorData storage data = contributorData[from];
//         if (data.originalTokenAllocation == 0) return; // Not an original contributor

//         // Snapshot current rewards before transfer
//         _snapshotUserRewards(from);

//         // Calculate how many original tokens are being transferred
//         uint256 currentBalance = IERC20(partyInfo.tokenAddress).balanceOf(from);
//         uint256 originalTokensTransferred = 0;

//         if (currentBalance <= data.originalTokenAllocation) {
//             // All current tokens are original tokens
//             originalTokensTransferred = amount > currentBalance
//                 ? currentBalance
//                 : amount;
//         } else {
//             // Some tokens might be re-bought, only count original tokens
//             uint256 originalTokensHeld = data.originalTokenAllocation >
//                 currentBalance
//                 ? currentBalance
//                 : data.originalTokenAllocation;
//             originalTokensTransferred = amount > originalTokensHeld
//                 ? originalTokensHeld
//                 : amount;
//         }

//         // Update current holdings
//         if (originalTokensTransferred > 0) {
//             data.currentTokensHeld = data.currentTokensHeld >
//                 originalTokensTransferred
//                 ? data.currentTokensHeld - originalTokensTransferred
//                 : 0;

//             if (data.currentTokensHeld == 0) {
//                 data.isCurrentlyHolding = false;
//             }
//         }

//         emit OriginalTokenTransfer(
//             from,
//             address(0),
//             originalTokensTransferred,
//             amount
//         );
//     }

//     /**
//      * @dev Handle tokens being transferred TO an address
//      * Re-bought tokens do NOT count toward rewards
//      */
//     function _handleTokenTransferTo(address to, uint256 amount) internal {
//         ContributorData storage data = contributorData[to];
//         if (data.originalTokenAllocation == 0) return; // Not an original contributor

//         // If they're receiving tokens back, only count up to their original allocation
//         uint256 currentBalance = IERC20(partyInfo.tokenAddress).balanceOf(to);
//         uint256 maxOriginalTokens = data.originalTokenAllocation;

//         if (currentBalance <= maxOriginalTokens) {
//             // Receiving back some of their original allocation
//             uint256 originalTokensReceived = (currentBalance + amount) >
//                 maxOriginalTokens
//                 ? maxOriginalTokens - currentBalance
//                 : amount;

//             if (originalTokensReceived > 0) {
//                 data.currentTokensHeld += originalTokensReceived;
//                 data.isCurrentlyHolding = true;
//                 data.lastRewardSnapshot = block.timestamp; // Reset snapshot time
//             }
//         }
//         // Re-bought tokens above original allocation don't affect reward tracking
//     }

//     /**
//      * @dev Snapshot a user's rewards based on their holding time
//      * This locks in rewards earned up to this point
//      */
//     function _snapshotUserRewards(address user) internal {
//         ContributorData storage data = contributorData[user];
//         if (data.originalTokenAllocation == 0 || !data.isCurrentlyHolding)
//             return;

//         uint256 holdingDuration = block.timestamp - data.lastRewardSnapshot;
//         if (holdingDuration > 0) {
//             // Calculate "token-seconds" for this holding period
//             uint256 tokenSeconds = data.currentTokensHeld * holdingDuration;
//             data.accumulatedRewardShares += tokenSeconds;
//             rewardInfo.totalRewardShares += tokenSeconds;

//             data.lastRewardSnapshot = block.timestamp;

//             emit RewardsSnapshotted(
//                 user,
//                 data.accumulatedRewardShares,
//                 data.rewardsLocked
//             );
//         }
//     }

//     /**
//      * @dev Create a global snapshot for reward calculations
//      */
//     function createGlobalSnapshot() external {
//         _createGlobalSnapshot();
//     }

//     function _createGlobalSnapshot() internal {
//         rewardSnapshots.push(
//             RewardSnapshot({
//                 timestamp: block.timestamp,
//                 totalLPFeesAtSnapshot: rewardInfo.totalFeesCollected,
//                 totalRewardSharesAtSnapshot: rewardInfo.totalRewardShares
//             })
//         );

//         rewardInfo.lastGlobalSnapshot = block.timestamp;

//         emit GlobalSnapshot(
//             block.timestamp,
//             rewardInfo.totalFeesCollected,
//             rewardInfo.totalRewardShares
//         );
//     }

//     /**
//      * @dev Collect LP fees from the pool
//      */
//     function collectLPFees() external {
//         uint256 newFees = address(this).balance - rewardInfo.totalFeesCollected;
//         if (newFees > 0) {
//             rewardInfo.totalFeesCollected += newFees;
//             rewardInfo.lastFeeCollection = block.timestamp;

//             // Create snapshot when new fees are collected
//             _createGlobalSnapshot();
//         }
//     }

//     /**
//      * @dev Calculate claimable rewards for a contributor
//      * Based on their accumulated "token-seconds" share of total fees
//      */
//     function getClaimableRewards(
//         address contributor
//     ) public view returns (uint256 claimableAmount) {
//         ContributorData memory data = contributorData[contributor];
//         if (data.originalTokenAllocation == 0) return 0;

//         // Calculate current accumulated shares (including ongoing holding)
//         uint256 totalShares = data.accumulatedRewardShares;
//         if (data.isCurrentlyHolding && data.currentTokensHeld > 0) {
//             uint256 currentHoldingDuration = block.timestamp -
//                 data.lastRewardSnapshot;
//             totalShares += data.currentTokensHeld * currentHoldingDuration;
//         }

//         // Calculate total earned rewards
//         uint256 totalEarnedRewards = 0;
//         if (rewardInfo.totalRewardShares > 0) {
//             totalEarnedRewards =
//                 (rewardInfo.totalFeesCollected * totalShares) /
//                 rewardInfo.totalRewardShares;
//         }

//         // Subtract already claimed
//         if (totalEarnedRewards > data.rewardsClaimed) {
//             claimableAmount = totalEarnedRewards - data.rewardsClaimed;
//         }

//         return claimableAmount;
//     }

//     /**
//      * @dev Claim accumulated rewards
//      * This automatically snapshots current rewards first
//      */
//     function claimRewards() external nonReentrant {
//         // Snapshot current holding period first
//         _snapshotUserRewards(msg.sender);

//         uint256 claimable = getClaimableRewards(msg.sender);
//         require(claimable > 0, "No rewards to claim");

//         ContributorData storage data = contributorData[msg.sender];
//         data.rewardsClaimed += claimable;
//         rewardInfo.totalFeesDistributed += claimable;

//         // Transfer rewards
//         (bool success, ) = payable(msg.sender).call{value: claimable}("");
//         require(success, "Reward transfer failed");

//         emit RewardsClaimed(msg.sender, claimable);
//     }

//     /**
//      * @dev Get detailed contributor information
//      */
//     function getContributorDetails(
//         address contributor
//     )
//         external
//         view
//         returns (
//             uint256 contributionAmount,
//             uint256 originalTokenAllocation,
//             uint256 currentTokensHeld,
//             uint256 accumulatedShares,
//             uint256 claimableRewards,
//             uint256 rewardsClaimed,
//             bool isCurrentlyHolding
//         )
//     {
//         ContributorData memory data = contributorData[contributor];
//         return (
//             data.contributionAmount,
//             data.originalTokenAllocation,
//             data.currentTokensHeld,
//             data.accumulatedRewardShares,
//             getClaimableRewards(contributor),
//             data.rewardsClaimed,
//             data.isCurrentlyHolding
//         );
//     }

//     /**
//      * @dev Manual launch by creator
//      */
//     function manualLaunch() external onlyCreator {
//         PartyErrors.requireValidState(
//             !partyInfo.launched,
//             PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
//         );
//         PartyErrors.requireNonZero(
//             partyInfo.currentAmount,
//             PartyErrors.ErrorCode.NO_FUNDS_RECEIVED
//         );
//         _triggerLaunch();
//     }

//     /**
//      * @dev Internal function to trigger launch
//      */
//     function _triggerLaunch() internal {
//         partyInfo.launched = true;
//         uint256 balance = address(this).balance;

//         IPartyStarter(partyStarter).launchFromVenue{value: balance}(
//             partyInfo.partyId
//         );

//         emit PartyLaunched(balance);
//     }

//     /**
//      * @dev Update signer address
//      */
//     function updateSigner(address newSigner) external onlyCreator {
//         partyInfo.signerAddress = newSigner;
//         emit SignerUpdated(newSigner);
//     }

//     /**
//      * @dev Internal contribute function
//      */
//     function _contribute() internal {
//         PartyErrors.requireValidState(
//             !partyInfo.launched,
//             PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
//         );
//         PartyErrors.requireNonZero(
//             msg.value,
//             PartyErrors.ErrorCode.ZERO_AMOUNT
//         );

//         _processContribution();
//     }

//     /**
//      * @dev Internal function to process contribution
//      */
//     function _processContribution() internal {
//         bool isFirstContribution = contributions[msg.sender] == 0;

//         if (isFirstContribution) {
//             contributors.push(msg.sender);
//         }

//         // Update contribution tracking
//         contributions[msg.sender] += msg.value;
//         contributorData[msg.sender].contributionAmount += msg.value;
//         partyInfo.currentAmount += msg.value;

//         // Calculate progress
//         uint8 progressPercentage = 0;
//         if (partyInfo.targetAmount > 0) {
//             progressPercentage = uint8(
//                 (partyInfo.currentAmount * 100) / partyInfo.targetAmount
//             );
//             if (progressPercentage > 100) progressPercentage = 100;
//         }

//         emit ContributionReceived(msg.sender, msg.value);
//         emit ContributionProgress(
//             partyInfo.partyId,
//             msg.sender,
//             msg.value,
//             partyInfo.currentAmount,
//             partyInfo.targetAmount,
//             progressPercentage,
//             contributors.length,
//             block.timestamp
//         );

//         // Check if target reached
//         if (partyInfo.currentAmount >= partyInfo.targetAmount) {
//             _triggerLaunch();
//         }
//     }

//     // View functions
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
//             address signerAddress,
//             address tokenAddress
//         )
//     {
//         return (
//             partyInfo.partyId,
//             partyInfo.creator,
//             partyInfo.targetAmount,
//             partyInfo.currentAmount,
//             partyInfo.launched,
//             partyInfo.isPrivate,
//             partyInfo.signerAddress,
//             partyInfo.tokenAddress
//         );
//     }

//     function getContributors() external view returns (address[] memory) {
//         return contributors;
//     }

//     function getRewardInfo() external view returns (LPRewardInfo memory) {
//         return rewardInfo;
//     }

//     function getSnapshotCount() external view returns (uint256) {
//         return rewardSnapshots.length;
//     }

//     function getSnapshot(
//         uint256 index
//     ) external view returns (RewardSnapshot memory) {
//         require(index < rewardSnapshots.length, "Invalid snapshot index");
//         return rewardSnapshots[index];
//     }

//     /**
//      * @dev Allow contract to receive ETH (for LP fees and contributions)
//      */
//     receive() external payable {
//         if (!partyInfo.launched) {
//             // If party not launched, treat as contribution
//             PartyErrors.requireValidState(
//                 !partyInfo.isPrivate,
//                 PartyErrors.ErrorCode.SIGNATURE_REQUIRED
//             );
//             _contribute();
//         }
//         // If party is launched, treat as LP fee collection
//     }
// }
