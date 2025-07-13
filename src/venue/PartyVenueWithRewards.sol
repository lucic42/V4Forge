// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Owned} from "solmate/auth/Owned.sol";
// import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {PartyErrors} from "../types/PartyErrors.sol";

// interface IPartyStarter {
//     function launchFromVenue(uint256 partyId) external payable;
//     function getLPPosition(
//         uint256 partyId
//     ) external view returns (PartyTypes.LPPosition memory);
// }

// interface IPoolManager {
//     function collectProtocolFees(address recipient, uint256 amount) external;
// }

// interface IRewardTrackingToken {
//     function notifyTransfer(address from, address to, uint256 amount) external;
//     function getHoldingStartTime(
//         address holder
//     ) external view returns (uint256);
// }

// import {PartyTypes} from "../types/PartyTypes.sol";

// /**
//  * @title PartyVenueWithRewards
//  * @dev Enhanced PartyVenue that holds LP positions and distributes fees based on contribution and holding duration
//  * Users earn rewards proportionally to their presale contribution and how long they hold their tokens
//  */
// contract PartyVenueWithRewards is Owned, ReentrancyGuard {
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
//         address tokenAddress; // The launched token address
//         mapping(bytes32 => bool) usedSignatures;
//     }

//     struct ContributorData {
//         uint256 contributionAmount; // How much ETH they contributed
//         uint256 tokenAmount; // How many tokens they received
//         uint256 holdingStartTime; // When they started holding (for current holding period)
//         uint256 totalHoldingTime; // Cumulative holding time (excluding transfer periods)
//         uint256 lastTransferTime; // Last time they transferred tokens
//         uint256 feesClaimedTotal; // Total fees claimed so far
//         bool isCurrentlyHolding; // Whether they currently hold tokens
//         uint256 lastTokenBalance; // Last known token balance for transfer detection
//     }

//     struct LPRewardInfo {
//         uint256 totalFeesCollected; // Total LP fees collected by this venue
//         uint256 totalFeesDistributed; // Total fees distributed to contributors
//         uint256 lastFeeCollection; // Last time fees were collected
//         uint256 rewardMultiplier; // Multiplier for holding time rewards (basis points)
//         uint256 maxHoldingReward; // Maximum reward multiplier for long holding
//         uint256 holdingTimeRequired; // Time required to reach max reward (seconds)
//     }

//     PartyInfo public partyInfo;
//     LPRewardInfo public rewardInfo;
//     address public immutable partyStarter;
//     address[] public contributors;
//     mapping(address => ContributorData) public contributorData;
//     mapping(address => uint256) public contributions; // For backward compatibility

//     // Events
//     event ContributionReceived(address indexed contributor, uint256 amount);
//     event PartyLaunched(uint256 totalAmount);
//     event SignerUpdated(address indexed newSigner);
//     event TokensDistributed(address indexed contributor, uint256 tokenAmount);
//     event HoldingStatusUpdated(
//         address indexed contributor,
//         bool isHolding,
//         uint256 timestamp
//     );
//     event FeesCollected(uint256 amount, uint256 totalCollected);
//     event RewardsClaimed(
//         address indexed contributor,
//         uint256 amount,
//         uint256 holdingBonus
//     );
//     event HoldingTimeUpdated(
//         address indexed contributor,
//         uint256 totalHoldingTime
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

//     event PartyTargetReached(
//         uint256 indexed partyId,
//         uint256 finalAmount,
//         uint256 targetAmount,
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

//         // Initialize reward configuration
//         rewardInfo.rewardMultiplier = 10000; // 100% base (10000 basis points)
//         rewardInfo.maxHoldingReward = 20000; // 200% max (2x multiplier for long holders)
//         rewardInfo.holdingTimeRequired = 30 days; // 30 days to reach max reward
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
//      * @dev Distribute tokens to contributors after launch
//      */
//     function distributeTokens(
//         address contributor,
//         uint256 tokenAmount
//     ) external onlyPartyStarter {
//         ContributorData storage data = contributorData[contributor];
//         data.tokenAmount = tokenAmount;
//         data.holdingStartTime = block.timestamp;
//         data.isCurrentlyHolding = true;
//         data.lastTokenBalance = tokenAmount;

//         emit TokensDistributed(contributor, tokenAmount);
//         emit HoldingStatusUpdated(contributor, true, block.timestamp);
//     }

//     /**
//      * @dev Called by token contract when tokens are transferred
//      */
//     function notifyTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) external onlyToken {
//         if (from != address(0)) {
//             _updateHoldingStatus(from);
//         }
//         if (to != address(0)) {
//             _updateHoldingStatus(to);
//         }
//     }

//     /**
//      * @dev Update holding status based on current token balance
//      */
//     function _updateHoldingStatus(address contributor) internal {
//         ContributorData storage data = contributorData[contributor];
//         if (data.contributionAmount == 0) return; // Not a contributor

//         // Get current token balance from the token contract
//         uint256 currentBalance = 0;
//         if (partyInfo.tokenAddress != address(0)) {
//             currentBalance = IERC20(partyInfo.tokenAddress).balanceOf(
//                 contributor
//             );
//         }

//         bool wasHolding = data.isCurrentlyHolding;
//         bool isHolding = currentBalance > 0;

//         if (wasHolding && !isHolding) {
//             // User stopped holding - accumulate their holding time
//             if (data.holdingStartTime > 0) {
//                 data.totalHoldingTime +=
//                     block.timestamp -
//                     data.holdingStartTime;
//             }
//             data.isCurrentlyHolding = false;
//             data.lastTransferTime = block.timestamp;
//             emit HoldingStatusUpdated(contributor, false, block.timestamp);
//             emit HoldingTimeUpdated(contributor, data.totalHoldingTime);
//         } else if (!wasHolding && isHolding) {
//             // User started holding again
//             data.holdingStartTime = block.timestamp;
//             data.isCurrentlyHolding = true;
//             emit HoldingStatusUpdated(contributor, true, block.timestamp);
//         }

//         data.lastTokenBalance = currentBalance;
//     }

//     /**
//      * @dev Collect LP fees from the pool
//      */
//     function collectLPFees() external {
//         // This would integrate with Uniswap V4 to collect fees
//         // For now, we'll simulate fee collection from contract balance
//         uint256 newFees = address(this).balance - rewardInfo.totalFeesCollected;
//         if (newFees > 0) {
//             rewardInfo.totalFeesCollected += newFees;
//             rewardInfo.lastFeeCollection = block.timestamp;
//             emit FeesCollected(newFees, rewardInfo.totalFeesCollected);
//         }
//     }

//     /**
//      * @dev Calculate claimable rewards for a contributor
//      */
//     function getClaimableRewards(
//         address contributor
//     )
//         public
//         view
//         returns (uint256 baseReward, uint256 holdingBonus, uint256 totalReward)
//     {
//         ContributorData memory data = contributorData[contributor];
//         if (data.contributionAmount == 0 || !partyInfo.launched) {
//             return (0, 0, 0);
//         }

//         // Calculate base reward share based on contribution percentage
//         uint256 contributionShare = (data.contributionAmount * 1e18) /
//             partyInfo.currentAmount;
//         baseReward = (rewardInfo.totalFeesCollected * contributionShare) / 1e18;

//         // Calculate holding time bonus
//         uint256 currentHoldingTime = data.totalHoldingTime;
//         if (data.isCurrentlyHolding && data.holdingStartTime > 0) {
//             currentHoldingTime += block.timestamp - data.holdingStartTime;
//         }

//         // Calculate holding multiplier (0% to 100% bonus based on holding time)
//         uint256 holdingMultiplier = 0;
//         if (currentHoldingTime > 0 && rewardInfo.holdingTimeRequired > 0) {
//             holdingMultiplier =
//                 (currentHoldingTime * 10000) /
//                 rewardInfo.holdingTimeRequired;
//             if (holdingMultiplier > 10000) holdingMultiplier = 10000; // Cap at 100% bonus
//         }

//         holdingBonus = (baseReward * holdingMultiplier) / 10000;
//         totalReward = baseReward + holdingBonus;

//         // Subtract already claimed fees
//         if (totalReward > data.feesClaimedTotal) {
//             totalReward -= data.feesClaimedTotal;
//             if (totalReward > baseReward + holdingBonus) {
//                 totalReward = baseReward + holdingBonus;
//             }
//         } else {
//             totalReward = 0;
//         }
//     }

//     /**
//      * @dev Claim accumulated rewards
//      */
//     function claimRewards() external nonReentrant {
//         // Update holding status first
//         _updateHoldingStatus(msg.sender);

//         (
//             uint256 baseReward,
//             uint256 holdingBonus,
//             uint256 totalReward
//         ) = getClaimableRewards(msg.sender);

//         PartyErrors.requireNonZero(
//             totalReward,
//             PartyErrors.ErrorCode.NO_REWARDS_TO_CLAIM
//         );

//         ContributorData storage data = contributorData[msg.sender];
//         data.feesClaimedTotal += totalReward;
//         rewardInfo.totalFeesDistributed += totalReward;

//         // Transfer rewards
//         (bool success, ) = payable(msg.sender).call{value: totalReward}("");
//         require(success, "Reward transfer failed");

//         emit RewardsClaimed(msg.sender, totalReward, holdingBonus);
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
//      * @dev Update reward configuration (only creator)
//      */
//     function updateRewardConfig(
//         uint256 newMaxHoldingReward,
//         uint256 newHoldingTimeRequired
//     ) external onlyCreator {
//         rewardInfo.maxHoldingReward = newMaxHoldingReward;
//         rewardInfo.holdingTimeRequired = newHoldingTimeRequired;
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
//             emit PartyTargetReached(
//                 partyInfo.partyId,
//                 partyInfo.currentAmount,
//                 partyInfo.targetAmount,
//                 contributors.length,
//                 block.timestamp
//             );
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

//     function getContributorData(
//         address contributor
//     ) external view returns (ContributorData memory) {
//         return contributorData[contributor];
//     }

//     function getContributors() external view returns (address[] memory) {
//         return contributors;
//     }

//     function getRewardInfo() external view returns (LPRewardInfo memory) {
//         return rewardInfo;
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
