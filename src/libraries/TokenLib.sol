// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PartyTypes} from "../types/PartyTypes.sol";
import {FeeLib} from "./FeeLib.sol";
import {UniswapV3ERC20} from "../tokens/UniswapV3ERC20.sol";
import {PartyVault} from "../vault/PartyVault.sol";
import {PartyErrors} from "../types/PartyErrors.sol";

/**
 * @title TokenLib
 * @dev Library for token creation and management
 */
library TokenLib {
    event TokenCreated(
        uint256 indexed partyId,
        address indexed tokenAddress,
        string name,
        string symbol
    );

    event TokensDistributed(
        uint256 indexed partyId,
        address indexed tokenAddress,
        uint256 liquidityTokens,
        uint256 creatorTokens,
        uint256 vaultTokens
    );

    /**
     * @dev Create a new token for a party
     * @param partyId The party ID
     * @param metadata The token metadata
     * @return token The created token contract
     */
    function createToken(
        uint256 partyId,
        PartyTypes.TokenMetadata memory metadata
    ) internal returns (UniswapV3ERC20 token) {
        token = new UniswapV3ERC20(metadata.name, metadata.symbol);

        emit TokenCreated(
            partyId,
            address(token),
            metadata.name,
            metadata.symbol
        );
    }

    /**
     * @dev Mint and distribute tokens according to the party system rules
     * @param token The token contract
     * @param partyId The party ID
     * @param creator The party creator address
     * @param vault The party vault contract
     * @param targetSupply The target supply for presale (0 for instant parties)
     * @return distribution The token distribution amounts
     */
    function mintAndDistributeTokens(
        UniswapV3ERC20 token,
        uint256 partyId,
        address creator,
        PartyVault vault,
        uint256 targetSupply
    ) internal returns (PartyTypes.TokenDistribution memory distribution) {
        if (targetSupply == 0) {
            // Instant party - no presale
            distribution = FeeLib.calculateInstantTokenDistribution();
        } else {
            // Public/Private party - has presale
            distribution = FeeLib.calculateTokenDistribution(targetSupply);
        }

        // Mint tokens to appropriate addresses
        token.mint(address(this), distribution.liquidityTokens); // LP tokens to this contract
        token.mint(creator, distribution.creatorTokens); // Creator tokens
        token.mint(address(this), distribution.vaultTokens); // Vault tokens to this contract

        // For presale parties, mint presale tokens to this contract (to be distributed later)
        if (distribution.presaleTokens > 0) {
            token.mint(address(this), distribution.presaleTokens); // Presale tokens
        }

        // Transfer vault tokens to the PartyVault with party context
        token.approve(address(vault), distribution.vaultTokens);
        vault.receiveTokensFromParty(
            address(token),
            distribution.vaultTokens,
            partyId,
            creator
        );

        emit TokensDistributed(
            partyId,
            address(token),
            distribution.liquidityTokens,
            distribution.creatorTokens,
            distribution.vaultTokens
        );
    }

    /**
     * @dev Burn tokens held by the contract
     * @param token The token contract
     * @param amount The amount to burn
     */
    function burnTokens(UniswapV3ERC20 token, uint256 amount) internal {
        if (amount > 0) {
            token.burn(address(this), amount);
        }
    }

    /**
     * @dev Get token balance for a specific address
     * @param token The token contract
     * @param account The account to check
     * @return The token balance
     */
    function getTokenBalance(
        UniswapV3ERC20 token,
        address account
    ) internal view returns (uint256) {
        return token.balanceOf(account);
    }

    /**
     * @dev Validate token metadata
     * @param metadata The metadata to validate
     */
    function validateTokenMetadata(
        PartyTypes.TokenMetadata memory metadata
    ) internal pure {
        PartyErrors.requireValidState(
            bytes(metadata.name).length > 0,
            PartyErrors.ErrorCode.EMPTY_TOKEN_NAME
        );
        PartyErrors.requireValidState(
            bytes(metadata.symbol).length > 0,
            PartyErrors.ErrorCode.EMPTY_TOKEN_SYMBOL
        );
        PartyErrors.requireValidState(
            bytes(metadata.symbol).length <= 10,
            PartyErrors.ErrorCode.SYMBOL_TOO_LONG
        );
    }
}
