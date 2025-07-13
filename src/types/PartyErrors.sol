// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PartyErrors
 * @dev Centralized error definitions for the Party system
 * Using custom errors instead of revert strings to reduce contract size
 * while maintaining debuggability
 */
library PartyErrors {
    enum ErrorCode {
        // General errors (0-9)
        ZERO_ADDRESS, // 0
        ZERO_AMOUNT, // 1
        INVALID_INPUT, // 2
        UNAUTHORIZED, // 3
        ALREADY_EXISTS, // 4
        // Party creation errors (10-19)
        INVALID_CREATOR, // 10
        EMPTY_TOKEN_NAME, // 11
        EMPTY_TOKEN_SYMBOL, // 12
        SYMBOL_TOO_LONG, // 13
        ZERO_TARGET_LIQUIDITY, // 14
        ZERO_SIGNER_ADDRESS, // 15
        // Launch errors (20-29)
        PARTY_NOT_LAUNCHED, // 20
        PARTY_ALREADY_LAUNCHED, // 21
        ONLY_VENUE_CAN_LAUNCH, // 22
        NO_FUNDS_RECEIVED, // 23
        INSUFFICIENT_BALANCE, // 24
        // Fee errors (30-39)
        ONLY_CREATOR_CAN_CLAIM, // 30
        FEES_NOT_CLAIMABLE, // 31
        FEES_ALREADY_CLAIMED, // 32
        NO_FEES_TO_WITHDRAW, // 33
        INVALID_FEE_CONFIG, // 34
        // Venue errors (40-49)
        VENUE_ALREADY_LAUNCHED, // 40
        NOT_WHITELISTED, // 41
        SIGNATURE_REQUIRED, // 42
        INVALID_SIGNATURE, // 43
        SIGNATURE_EXPIRED, // 44
        SIGNATURE_ALREADY_USED, // 45
        CONTRIBUTION_TOO_HIGH, // 46
        ALREADY_CONTRIBUTED, // 47
        // Access control errors (50-59)
        ONLY_OWNER, // 50
        ONLY_CREATOR, // 51
        ONLY_PARTY_STARTER, // 52
        // Token errors (60-69)
        TOKEN_NOT_CREATED, // 60
        INVALID_TOKEN_AMOUNT, // 61
        TRANSFER_FAILED, // 62
        // Pool errors (70-79)
        POOL_CREATION_FAILED, // 70
        INVALID_POOL_CONFIG, // 71
        LIQUIDITY_ADD_FAILED, // 72
        // Metadata errors (80-89)
        METADATA_ALREADY_SET, // 80
        INVALID_ARRAY_LENGTH, // 81
        NOT_REFUNDABLE, // 82
        ALREADY_REFUNDABLE, // 83
        // Supply errors (90-99)
        INVALID_TARGET_SUPPLY, // 90
        SUPPLY_OUT_OF_RANGE, // 91
        // Launch time errors (100-109)
        INVALID_LAUNCH_TIME, // 100
        LAUNCH_TIME_NOT_REACHED, // 101
        // Refund errors (110-119)
        ALREADY_REFUNDED // 110
    }

    // Custom errors with error codes for easy debugging
    error PartyError(ErrorCode code);
    error PartyErrorWithValue(ErrorCode code, uint256 value);
    error PartyErrorWithAddress(ErrorCode code, address addr);
    error PartyErrorWithData(ErrorCode code, bytes data);

    // Helper functions for common error patterns
    function requireNonZero(uint256 value, ErrorCode code) internal pure {
        if (value == 0) revert PartyError(code);
    }

    function requireNonZeroAddress(address addr, ErrorCode code) internal pure {
        if (addr == address(0)) revert PartyError(code);
    }

    function requireAuthorized(bool condition, ErrorCode code) internal pure {
        if (!condition) revert PartyError(code);
    }

    function requireValidState(bool condition, ErrorCode code) internal pure {
        if (!condition) revert PartyError(code);
    }
}

/**
 * @title ErrorCodeHelper
 * @dev Helper contract for off-chain error code resolution
 * This can be used by frontends to display user-friendly error messages
 */
contract ErrorCodeHelper {
    using PartyErrors for *;

    function getErrorMessage(
        PartyErrors.ErrorCode code
    ) external pure returns (string memory) {
        if (code == PartyErrors.ErrorCode.ZERO_ADDRESS)
            return "Zero address not allowed";
        if (code == PartyErrors.ErrorCode.ZERO_AMOUNT)
            return "Amount must be greater than zero";
        if (code == PartyErrors.ErrorCode.INVALID_INPUT)
            return "Invalid input provided";
        if (code == PartyErrors.ErrorCode.UNAUTHORIZED)
            return "Unauthorized access";
        if (code == PartyErrors.ErrorCode.ALREADY_EXISTS)
            return "Resource already exists";

        if (code == PartyErrors.ErrorCode.INVALID_CREATOR)
            return "Invalid creator address";
        if (code == PartyErrors.ErrorCode.EMPTY_TOKEN_NAME)
            return "Token name cannot be empty";
        if (code == PartyErrors.ErrorCode.EMPTY_TOKEN_SYMBOL)
            return "Token symbol cannot be empty";
        if (code == PartyErrors.ErrorCode.SYMBOL_TOO_LONG)
            return "Token symbol too long (max 10 chars)";
        if (code == PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY)
            return "Target liquidity must be greater than zero";
        if (code == PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS)
            return "Signer address cannot be zero";

        if (code == PartyErrors.ErrorCode.PARTY_NOT_LAUNCHED)
            return "Party not launched yet";
        if (code == PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED)
            return "Party already launched";
        if (code == PartyErrors.ErrorCode.ONLY_VENUE_CAN_LAUNCH)
            return "Only venue can trigger launch";
        if (code == PartyErrors.ErrorCode.NO_FUNDS_RECEIVED)
            return "No funds received";
        if (code == PartyErrors.ErrorCode.INSUFFICIENT_BALANCE)
            return "Insufficient balance";

        if (code == PartyErrors.ErrorCode.ONLY_CREATOR_CAN_CLAIM)
            return "Only creator can claim fees";
        if (code == PartyErrors.ErrorCode.FEES_NOT_CLAIMABLE)
            return "Fees not claimable";
        if (code == PartyErrors.ErrorCode.FEES_ALREADY_CLAIMED)
            return "Fees already claimed";
        if (code == PartyErrors.ErrorCode.NO_FEES_TO_WITHDRAW)
            return "No fees to withdraw";
        if (code == PartyErrors.ErrorCode.INVALID_FEE_CONFIG)
            return "Invalid fee configuration";

        if (code == PartyErrors.ErrorCode.VENUE_ALREADY_LAUNCHED)
            return "Venue already launched";
        if (code == PartyErrors.ErrorCode.NOT_WHITELISTED)
            return "Address not whitelisted";
        if (code == PartyErrors.ErrorCode.SIGNATURE_REQUIRED)
            return "Valid signature required";
        if (code == PartyErrors.ErrorCode.INVALID_SIGNATURE)
            return "Invalid signature provided";
        if (code == PartyErrors.ErrorCode.SIGNATURE_EXPIRED)
            return "Signature has expired";
        if (code == PartyErrors.ErrorCode.SIGNATURE_ALREADY_USED)
            return "Signature already used";
        if (code == PartyErrors.ErrorCode.CONTRIBUTION_TOO_HIGH)
            return "Contribution exceeds maximum allowed";

        if (code == PartyErrors.ErrorCode.ONLY_OWNER)
            return "Only owner can perform this action";
        if (code == PartyErrors.ErrorCode.ONLY_CREATOR)
            return "Only creator can perform this action";
        if (code == PartyErrors.ErrorCode.ONLY_PARTY_STARTER)
            return "Only PartyStarter can call this";

        if (code == PartyErrors.ErrorCode.TOKEN_NOT_CREATED)
            return "Token not created";
        if (code == PartyErrors.ErrorCode.INVALID_TOKEN_AMOUNT)
            return "Invalid token amount";
        if (code == PartyErrors.ErrorCode.TRANSFER_FAILED)
            return "Token transfer failed";

        if (code == PartyErrors.ErrorCode.POOL_CREATION_FAILED)
            return "Pool creation failed";
        if (code == PartyErrors.ErrorCode.INVALID_POOL_CONFIG)
            return "Invalid pool configuration";
        if (code == PartyErrors.ErrorCode.LIQUIDITY_ADD_FAILED)
            return "Adding liquidity failed";

        if (code == PartyErrors.ErrorCode.METADATA_ALREADY_SET)
            return "Metadata field already set";
        if (code == PartyErrors.ErrorCode.INVALID_ARRAY_LENGTH)
            return "Array lengths must match and be non-empty";

        if (code == PartyErrors.ErrorCode.INVALID_TARGET_SUPPLY)
            return "Invalid target supply amount";
        if (code == PartyErrors.ErrorCode.SUPPLY_OUT_OF_RANGE)
            return "Supply must be between 100M and 900M tokens";

        if (code == PartyErrors.ErrorCode.INVALID_LAUNCH_TIME)
            return "Launch time must be in the future";
        if (code == PartyErrors.ErrorCode.LAUNCH_TIME_NOT_REACHED)
            return "Launch time has not been reached yet";

        return "Unknown error code";
    }
}
