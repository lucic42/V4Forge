#!/bin/bash

# E2E Signature Utilities
# Generates authorization signatures for private party contributions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ANVIL_RPC="http://localhost:8545"

show_help() {
    echo -e "${BLUE}🔐 E2E Signature Utilities for Private Parties${NC}"
    echo "=================================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  generate-signature    Generate a single signature"
    echo "  generate-batch        Generate signatures for multiple contributors"
    echo "  verify-signature      Verify a signature"
    echo ""
    echo -e "${YELLOW}Generate Signature Options:${NC}"
    echo "  --party-id <ID>       Party ID (required)"
    echo "  --contributor <ADDR>  Contributor address (required)"
    echo "  --max-amount <ETH>    Maximum contribution amount (required)"
    echo "  --deadline <SECONDS>  Deadline in seconds from now (default: 3600)"
    echo "  --signer-key <KEY>    Signer private key (required)"
    echo ""
    echo -e "${YELLOW}Generate Batch Options:${NC}"
    echo "  --party-id <ID>       Party ID (required)"
    echo "  --max-amount <ETH>    Maximum contribution amount for all (required)"
    echo "  --deadline <SECONDS>  Deadline in seconds from now (default: 3600)"
    echo "  --signer-key <KEY>    Signer private key (required)"
    echo "  --contributors <FILE> File with contributor addresses (one per line)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # Generate single signature"
    echo "  $0 generate-signature --party-id 1 --contributor 0x123... --max-amount 5 --signer-key 0xabc..."
    echo ""
    echo "  # Generate batch signatures"
    echo "  $0 generate-batch --party-id 1 --max-amount 5 --signer-key 0xabc... --contributors addresses.txt"
    echo ""
    echo -e "${YELLOW}Output Format:${NC}"
    echo "  Signatures are output as: ADDRESS:SIGNATURE:MAX_AMOUNT:DEADLINE"
}

# Generate keccak256 hash using cast
generate_message_hash() {
    local party_id="$1"
    local contributor="$2"
    local max_amount="$3"
    local deadline="$4"
    
    # Convert ETH amount to wei
    local max_amount_wei=$(cast to-wei "$max_amount" ether)
    
    # Create the inner hash: keccak256(abi.encodePacked(partyId, contributor, maxAmount, deadline))
    local inner_hash=$(cast keccak "$(printf '%064x%040x%064x%064x' \
        "$party_id" \
        "${contributor#0x}" \
        "$max_amount_wei" \
        "$deadline")")
    
    # Create the EIP-191 message hash
    local message_prefix="\x19Ethereum Signed Message:\n32"
    local message_hash=$(cast keccak "$(printf '%s%s' "$message_prefix" "$inner_hash")")
    
    echo "$message_hash"
}

# Generate signature for a single contributor
generate_single_signature() {
    local party_id="$1"
    local contributor="$2"
    local max_amount="$3"
    local deadline="$4"
    local signer_key="$5"
    
    # Generate message hash
    local message_hash=$(generate_message_hash "$party_id" "$contributor" "$max_amount" "$deadline")
    
    # Sign the message hash
    local signature=$(cast wallet sign --private-key "$signer_key" "$message_hash" 2>/dev/null)
    
    if [ -z "$signature" ]; then
        echo -e "${RED}❌ Failed to generate signature${NC}" >&2
        return 1
    fi
    
    echo "$signature"
}

# Verify a signature
verify_signature() {
    local party_id="$1"
    local contributor="$2"
    local max_amount="$3"
    local deadline="$4"
    local signature="$5"
    local expected_signer="$6"
    
    # Generate message hash
    local message_hash=$(generate_message_hash "$party_id" "$contributor" "$max_amount" "$deadline")
    
    # Recover signer from signature
    local recovered_signer=$(cast wallet recover "$message_hash" "$signature" 2>/dev/null)
    
    if [ -z "$recovered_signer" ]; then
        echo -e "${RED}❌ Failed to recover signer from signature${NC}" >&2
        return 1
    fi
    
    # Convert to lowercase for comparison
    recovered_signer=$(echo "$recovered_signer" | tr '[:upper:]' '[:lower:]')
    expected_signer=$(echo "$expected_signer" | tr '[:upper:]' '[:lower:]')
    
    if [ "$recovered_signer" = "$expected_signer" ]; then
        echo -e "${GREEN}✅ Signature is valid${NC}"
        echo "  Party ID: $party_id"
        echo "  Contributor: $contributor"
        echo "  Max Amount: $max_amount ETH"
        echo "  Deadline: $deadline ($(date -d "@$deadline" 2>/dev/null || echo "Invalid timestamp"))"
        echo "  Signer: $recovered_signer"
        return 0
    else
        echo -e "${RED}❌ Signature is invalid${NC}"
        echo "  Expected signer: $expected_signer"
        echo "  Recovered signer: $recovered_signer"
        return 1
    fi
}

# Create contribution data for cast call
create_contribution_data() {
    local signature="$1"
    local max_amount="$2"
    local deadline="$3"
    
    # Convert ETH to wei
    local max_amount_wei=$(cast to-wei "$max_amount" ether)
    
    # Create the function call data for contributeWithSignature
    local function_sig="contributeWithSignature(bytes,uint256,uint256)"
    local encoded_data=$(cast calldata "$function_sig" "$signature" "$max_amount_wei" "$deadline")
    
    echo "$encoded_data"
}

# Main execution
main() {
    local command="${1:-help}"
    shift || true
    
    # Default values
    local party_id=""
    local contributor=""
    local max_amount=""
    local deadline_offset="3600" # 1 hour
    local signer_key=""
    local contributors_file=""
    local signature=""
    local expected_signer=""
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --party-id)
                party_id="$2"
                shift 2
                ;;
            --contributor)
                contributor="$2"
                shift 2
                ;;
            --max-amount)
                max_amount="$2"
                shift 2
                ;;
            --deadline)
                deadline_offset="$2"
                shift 2
                ;;
            --signer-key)
                signer_key="$2"
                shift 2
                ;;
            --contributors)
                contributors_file="$2"
                shift 2
                ;;
            --signature)
                signature="$2"
                shift 2
                ;;
            --expected-signer)
                expected_signer="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    case "$command" in
        "generate-signature")
            # Validate required parameters
            if [ -z "$party_id" ] || [ -z "$contributor" ] || [ -z "$max_amount" ] || [ -z "$signer_key" ]; then
                echo -e "${RED}❌ Missing required parameters${NC}"
                echo -e "${YELLOW}Required: --party-id, --contributor, --max-amount, --signer-key${NC}"
                exit 1
            fi
            
            # Calculate deadline timestamp
            local deadline=$(($(date +%s) + deadline_offset))
            
            echo -e "${YELLOW}🔐 Generating signature...${NC}"
            echo "  Party ID: $party_id"
            echo "  Contributor: $contributor"
            echo "  Max Amount: $max_amount ETH"
            echo "  Deadline: $deadline ($(date -d "@$deadline" 2>/dev/null || echo "Unknown"))"
            
            local signature=$(generate_single_signature "$party_id" "$contributor" "$max_amount" "$deadline" "$signer_key")
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Signature generated successfully${NC}"
                echo ""
                echo -e "${BLUE}📋 Signature Data:${NC}"
                echo "$contributor:$signature:$max_amount:$deadline"
                echo ""
                echo -e "${BLUE}📋 Cast Command to Contribute:${NC}"
                local max_amount_wei=$(cast to-wei "$max_amount" ether)
                echo "cast send --private-key <CONTRIBUTOR_KEY> --rpc-url $ANVIL_RPC --value ${max_amount}ether <VENUE_ADDRESS> \"contributeWithSignature(bytes,uint256,uint256)\" \"$signature\" \"$max_amount_wei\" \"$deadline\""
            else
                exit 1
            fi
            ;;
            
        "generate-batch")
            # Validate required parameters
            if [ -z "$party_id" ] || [ -z "$max_amount" ] || [ -z "$signer_key" ]; then
                echo -e "${RED}❌ Missing required parameters${NC}"
                echo -e "${YELLOW}Required: --party-id, --max-amount, --signer-key${NC}"
                exit 1
            fi
            
            # Use contributors from file or default test wallets
            local contributors_list=()
            if [ -n "$contributors_file" ] && [ -f "$contributors_file" ]; then
                while IFS= read -r line; do
                    if [ -n "$line" ] && [[ "$line" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                        contributors_list+=("$line")
                    fi
                done < "$contributors_file"
            else
                # Use test wallets from e2e-wallets.env if available
                if [ -f "e2e-wallets.env" ]; then
                    source e2e-wallets.env
                    contributors_list=("${TEST_ADDRESSES[@]}")
                else
                    echo -e "${RED}❌ No contributors file provided and e2e-wallets.env not found${NC}"
                    exit 1
                fi
            fi
            
            if [ ${#contributors_list[@]} -eq 0 ]; then
                echo -e "${RED}❌ No valid contributors found${NC}"
                exit 1
            fi
            
            # Calculate deadline timestamp
            local deadline=$(($(date +%s) + deadline_offset))
            
            echo -e "${YELLOW}🔐 Generating batch signatures...${NC}"
            echo "  Party ID: $party_id"
            echo "  Max Amount: $max_amount ETH"
            echo "  Deadline: $deadline ($(date -d "@$deadline" 2>/dev/null || echo "Unknown"))"
            echo "  Contributors: ${#contributors_list[@]}"
            echo ""
            
            local success_count=0
            local output_file="signatures-party-${party_id}-$(date +%s).txt"
            
            # Generate signatures for each contributor
            for contributor in "${contributors_list[@]}"; do
                echo -e "${BLUE}  🔐 Generating for $contributor...${NC}"
                
                local signature=$(generate_single_signature "$party_id" "$contributor" "$max_amount" "$deadline" "$signer_key")
                
                if [ $? -eq 0 ]; then
                    echo "$contributor:$signature:$max_amount:$deadline" >> "$output_file"
                    success_count=$((success_count + 1))
                    echo -e "${GREEN}    ✅ Success${NC}"
                else
                    echo -e "${RED}    ❌ Failed${NC}"
                fi
            done
            
            echo ""
            echo -e "${GREEN}✅ Generated $success_count/${#contributors_list[@]} signatures${NC}"
            echo -e "${BLUE}📁 Signatures saved to: $output_file${NC}"
            ;;
            
        "verify-signature")
            # Validate required parameters
            if [ -z "$party_id" ] || [ -z "$contributor" ] || [ -z "$max_amount" ] || [ -z "$signature" ] || [ -z "$expected_signer" ]; then
                echo -e "${RED}❌ Missing required parameters${NC}"
                echo -e "${YELLOW}Required: --party-id, --contributor, --max-amount, --signature, --expected-signer${NC}"
                exit 1
            fi
            
            # Calculate deadline timestamp
            local deadline=$(($(date +%s) + deadline_offset))
            
            echo -e "${YELLOW}🔍 Verifying signature...${NC}"
            verify_signature "$party_id" "$contributor" "$max_amount" "$deadline" "$signature" "$expected_signer"
            ;;
            
        "help"|"-h"|"--help")
            show_help
            ;;
            
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Check if cast is available
if ! command -v cast &> /dev/null; then
    echo -e "${RED}❌ 'cast' command not found. Please install Foundry.${NC}"
    exit 1
fi

# Run main function
main "$@" 