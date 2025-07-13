// SPDX-License-Identifier: MI
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";

import {PartyTypes} from "../types/PartyTypes.sol";
import {PartyErrors} from "../types/PartyErrors.sol";
import {TokenLib} from "./TokenLib.sol";
import {PoolV3Lib} from "./PoolV3Lib.sol";
import {FeeLib} from "./FeeLib.sol";
import {UniswapV3ERC20} from "../tokens/UniswapV3ERC20.sol";
import {PartyVault} from "../vault/PartyVault.sol";

/**
 * @title LaunchV3Lib
 * @dev Library for handling party launch logic with Uniswap V3
 */
library LaunchV3Lib {
    using PartyErrors for *;

    event PartySystemTokenLaunched(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        address poolAddress,
        uint256 totalLiquidity,
        uint256 timestamp
    );

    event PartyLaunched(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed poolAddress,
        uint256 totalLiquidity
    );

    // Enhanced events for comprehensive data capture
    event TokenDeployed(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed creator,
        uint256 totalSupply,
        uint256 liquidityTokens,
        uint256 creatorTokens,
        uint256 vaultTokens,
        uint256 timestamp
    );

    event PartyLaunchComplete(
        uint256 indexed partyId,
        address indexed tokenAddress,
        address indexed creator,
        address poolAddress,
        uint256 totalLiquidity,
        uint256 initialPrice,
        uint256 marketCap,
        uint256 timestamp
    );

    /**
     * @dev Execute party launch with all required steps for V3
     */
    function executePartyLaunch(
        uint256 partyId,
        uint256 ethAmount,
        PartyTypes.Party storage party,
        PartyTypes.FeeConfiguration memory feeConfig,
        PartyVault partyVault,
        IUniswapV3Factory factory,
        INonfungiblePositionManager positionManager,
        address weth
    ) external returns (PartyTypes.LPPosition memory lpPosition) {
        // Validate that required metadata is set
        require(
            bytes(party.metadata.name).length > 0 &&
                bytes(party.metadata.symbol).length > 0,
            "Required metadata not set"
        );

        // Validate metadata
        TokenLib.validateTokenMetadata(party.metadata);

        // Create token
        UniswapV3ERC20 token = TokenLib.createToken(partyId, party.metadata);

        // Mint and distribute tokens
        PartyTypes.TokenDistribution memory distribution = TokenLib
            .mintAndDistributeTokens(
                token,
                partyId,
                party.creator,
                partyVault,
                party.targetSupply
            );

        // Emit token deployment event
        emit TokenDeployed(
            partyId,
            address(token),
            party.creator,
            distribution.totalSupply, // total supply (always 1B)
            distribution.liquidityTokens,
            distribution.creatorTokens,
            distribution.vaultTokens,
            block.timestamp
        );

        // Calculate and transfer platform fees
        (uint256 platformFee, uint256 liquidityAmount) = FeeLib
            .calculatePlatformFees(ethAmount, feeConfig);

        FeeLib.transferPlatformFees(feeConfig.platformTreasury, platformFee);

        // Create pool and add liquidity using V3
        (address poolAddress, uint256 tokenId, uint128 liquidity) = PoolV3Lib
            .createPoolAndAddLiquidity(
                factory,
                positionManager,
                address(token),
                weth,
                PartyTypes.DEFAULT_FEE,
                distribution.liquidityTokens,
                liquidityAmount,
                address(this),
                partyId
            );

        // Update party state
        party.tokenAddress = address(token);
        party.poolAddress = poolAddress;
        party.totalLiquidity = liquidityAmount;
        party.launched = true;

        // Create LP position
        lpPosition = PoolV3Lib.createLPPosition(
            poolAddress,
            address(token),
            tokenId,
            PartyTypes.DEFAULT_FEE,
            liquidity
        );

        // Emit events
        emit PartySystemTokenLaunched(
            partyId,
            address(token),
            party.creator,
            party.metadata.name,
            party.metadata.symbol,
            poolAddress,
            liquidityAmount,
            block.timestamp
        );

        emit PartyLaunched(
            partyId,
            address(token),
            poolAddress,
            liquidityAmount
        );

        // Calculate initial price and market cap for comprehensive launch event
        // Note: These calculations would need to be implemented based on your pricing logic
        uint256 initialPrice = 0; // TODO: Calculate actual initial price
        uint256 marketCap = 0; // TODO: Calculate actual market cap

        // Emit comprehensive launch completion event
        emit PartyLaunchComplete(
            partyId,
            address(token),
            party.creator,
            poolAddress,
            liquidityAmount,
            initialPrice,
            marketCap,
            block.timestamp
        );
    }

    function executeOneSidedPartyLaunch(
        uint256 partyId,
        PartyTypes.Party storage party,
        PartyVault partyVault,
        IUniswapV3Factory factory,
        INonfungiblePositionManager positionManager,
        address weth
    ) external returns (PartyTypes.LPPosition memory lpPosition) {
        // Validate that required metadata is set
        require(
            bytes(party.metadata.name).length > 0 &&
                bytes(party.metadata.symbol).length > 0,
            "Required metadata not set"
        );

        // Validate metadata
        TokenLib.validateTokenMetadata(party.metadata);

        // Create token
        UniswapV3ERC20 token = TokenLib.createToken(partyId, party.metadata);

        // Mint and distribute tokens
        PartyTypes.TokenDistribution memory distribution = TokenLib
            .mintAndDistributeTokens(
                token,
                partyId,
                party.creator,
                partyVault,
                party.targetSupply
            );

        // Emit token deployment event
        emit TokenDeployed(
            partyId,
            address(token),
            party.creator,
            distribution.totalSupply, // total supply (always 1B)
            distribution.liquidityTokens,
            distribution.creatorTokens,
            distribution.vaultTokens,
            block.timestamp
        );

        // Create pool and add liquidity using V3
        (address poolAddress, uint256 tokenId, uint128 liquidity) = PoolV3Lib
            .createPoolAndAddOneSidedLiquidity(
                factory,
                positionManager,
                address(token),
                weth,
                PartyTypes.DEFAULT_FEE,
                distribution.liquidityTokens,
                address(this),
                partyId
            );

        // Update party state
        party.tokenAddress = address(token);
        party.poolAddress = poolAddress;
        party.totalLiquidity = 0; // No ETH liquidity provided initially
        party.launched = true;

        // Create LP position
        lpPosition = PoolV3Lib.createLPPosition(
            poolAddress,
            address(token),
            tokenId,
            PartyTypes.DEFAULT_FEE,
            liquidity
        );

        // Emit events
        emit PartySystemTokenLaunched(
            partyId,
            address(token),
            party.creator,
            party.metadata.name,
            party.metadata.symbol,
            poolAddress,
            0,
            block.timestamp
        );

        emit PartyLaunched(partyId, address(token), poolAddress, 0);

        // Calculate initial price and market cap for comprehensive launch event
        // Note: These calculations would need to be implemented based on your pricing logic
        uint256 initialPrice = 0; // TODO: Calculate actual initial price
        uint256 marketCap = 0; // TODO: Calculate actual market cap

        // Emit comprehensive launch completion event
        emit PartyLaunchComplete(
            partyId,
            address(token),
            party.creator,
            poolAddress,
            0,
            initialPrice,
            marketCap,
            block.timestamp
        );
    }
}
