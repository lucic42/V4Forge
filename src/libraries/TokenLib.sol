// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PartyTypes} from "../types/PartyTypes.sol";
import {FeeLib} from "./FeeLib.sol";
import {UniswapV4ERC20} from "../tokens/UniswapV4ERC20.sol";
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
    ) internal returns (UniswapV4ERC20 token) {
        token = new UniswapV4ERC20(metadata.name, metadata.symbol);

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
     * @return distribution The token distribution amounts
     */
    function mintAndDistributeTokens(
        UniswapV4ERC20 token,
        uint256 partyId,
        address creator,
        PartyVault vault
    ) internal returns (PartyTypes.TokenDistribution memory distribution) {
        distribution = FeeLib.calculateTokenDistribution();

        // Mint tokens to appropriate addresses
        token.mint(address(this), distribution.liquidityTokens); // LP tokens to this contract
        token.mint(creator, distribution.creatorTokens); // Creator tokens
        token.mint(address(this), distribution.vaultTokens); // Vault tokens to this contract

        // Transfer vault tokens to the PartyVault
        token.approve(address(vault), distribution.vaultTokens);
        vault.receiveTokens(address(token), distribution.vaultTokens);

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
    function burnTokens(UniswapV4ERC20 token, uint256 amount) internal {
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
        UniswapV4ERC20 token,
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
