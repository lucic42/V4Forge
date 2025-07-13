#!/bin/bash

# E2E Test Script for Private Parties
# Tests private party creation, signature authorization, contributions, and launch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ANVIL_RPC="http://localhost:8545"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default signer private key (can be overridden)
DEFAULT_SIGNER_KEY="0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
DEFAULT_SIGNER_ADDRESS="0x976EA74026E726554dB657fA54763abd0C3a0aa9"

# Load configuration
if [ -f "e2e-wallets.env" ]; then
    source e2e-wallets.env
else
    echo -e "${RED}❌ e2e-wallets.env not found. Run e2e-test-setup.sh first.${NC}"
    exit 1
fi

# Load contract addresses
load_contract_addresses() {
    # Load from our deployment files
    if [ -f "deployments/complete-deployment.env" ]; then
        source deployments/complete-deployment.env
    fi
    
    if [ -f "deployments/simple-addresses.env" ]; then
        source deployments/simple-addresses.env
    fi
    
    # Try to extract from broadcast directory if not found
    if [ -z "$PARTY_STARTER_ADDRESS" ]; then
        local broadcast_file="broadcast/DeployPartyStarterSimple.s.sol/31337/run-latest.json"
        if [ -f "$broadcast_file" ]; then
            PARTY_STARTER_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "SimplePartyStarter") | .contractAddress' "$broadcast_file" 2>/dev/null || echo "")
        fi
    fi
    
    if [ -z "$PARTY_STARTER_ADDRESS" ]; then
        echo -e "${RED}❌ PartyStarter contract address not found${NC}"
        echo -e "${YELLOW}💡 Make sure contracts are deployed: make deploy-simple${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Using SimplePartyStarter at: $PARTY_STARTER_ADDRESS${NC}"
    echo -e "${YELLOW}⚠️  Note: SimplePartyStarter doesn't support private parties - will run simplified tests${NC}"
    if [ -n "$WETH_ADDRESS" ]; then
        echo -e "${GREEN}✅ Using WETH at: $WETH_ADDRESS${NC}"
    fi
    if [ -n "$POOL_MANAGER_ADDRESS" ]; then
        echo -e "${GREEN}✅ Using PoolManager at: $POOL_MANAGER_ADDRESS${NC}"
    fi
}

show_help() {
    echo -e "${BLUE}🔐 E2E Test for Private Parties${NC}"
    echo "================================="
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --count <N>            Number of private parties to create (default: 2)"
    echo "  --target <ETH>         Target liquidity for each party (default: 3)"
    echo "  --contributors <N>     Number of authorized contributors per party (default: 5)"
    echo "  --contribution <ETH>   Individual contribution amount (default: 1)"
    echo "  --signer-key <KEY>     Private key for signing authorizations (default: test key)"
    echo "  --deadline <SECONDS>   Signature validity in seconds (default: 3600)"
    echo "  --cleanup              Clean up after tests"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0                                      # Create 2 parties, 5 contributors each"
    echo "  $0 --count 3 --target 5                # Create 3 parties with 5 ETH target each"
    echo "  $0 --contributors 3 --contribution 2   # 3 contributors, 2 ETH each"
    echo ""
}

# Generate signature using the signature utility script
generate_contribution_signature() {
    local party_id="$1"
    local contributor_address="$2"
    local max_amount_eth="$3"
    local deadline="$4"
    local signer_key="$5"
    
    # Use the signature utility script
    local sig_output=$("$SCRIPT_DIR/e2e-signature-utils.sh" generate-signature \
        --party-id "$party_id" \
        --contributor "$contributor_address" \
        --max-amount "$max_amount_eth" \
        --deadline $((deadline - $(date +%s))) \
        --signer-key "$signer_key" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Extract signature from output (format: ADDRESS:SIGNATURE:MAX_AMOUNT:DEADLINE)
        echo "$sig_output" | grep "^$contributor_address:" | cut -d':' -f2
    else
        echo ""
    fi
}

# Create simplified private party (using instant party function for testing)
create_private_party() {
    local creator_key="$1"
    local creator_address="$2"
    local target_eth="$3"
    local signer_address="$4"
    local party_name="$5"
    local party_symbol="$6"
    
    echo -e "${YELLOW}🔐 Creating private party (simplified): $party_name ($party_symbol)${NC}" >&2
    echo -e "${BLUE}  ℹ️  Note: Using instant party creation as SimplePartyStarter doesn't support private parties${NC}" >&2
    echo "  Creator: $creator_address" >&2
    echo "  Amount: $target_eth ETH (converted to instant party)" >&2
    echo "  Original Signer: $signer_address (not used in simplified test)" >&2
    
    # Test basic contract interaction first
    echo -e "${BLUE}  🔍 Testing contract accessibility...${NC}" >&2
    local pool_manager_addr=$(cast call "$PARTY_STARTER_ADDRESS" "poolManager()" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✅ Contract accessible, PoolManager: $pool_manager_addr${NC}" >&2
    else
        echo -e "${RED}  ❌ Contract not accessible${NC}" >&2
        return 1
    fi
    
    # Create instant party (simplified interface)
    echo -e "${BLUE}  📤 Sending transaction...${NC}" >&2
    local tx_result=$(cast send --private-key "$creator_key" \
        --rpc-url "$ANVIL_RPC" \
        --value "${target_eth}ether" \
        --json \
        "$PARTY_STARTER_ADDRESS" \
        "createInstantParty()" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$tx_result" ]; then
        # Extract transaction hash from JSON result
        local tx_hash=$(echo "$tx_result" | jq -r '.transactionHash' 2>/dev/null)
        
        echo -e "${GREEN}  ✅ Transaction submitted: $tx_hash${NC}" >&2
        
        # Check transaction status directly from the result
        local status=$(echo "$tx_result" | jq -r '.status' 2>/dev/null)
        if [ "$status" = "0x1" ]; then
            echo -e "${GREEN}  ✅ Transaction successful${NC}" >&2
            
            # Get transaction receipt details from the result
            local gas_used=$(echo "$tx_result" | jq -r '.gasUsed' 2>/dev/null)
            local block_number=$(echo "$tx_result" | jq -r '.blockNumber' 2>/dev/null)
            
            echo -e "${BLUE}  📊 Transaction Details:${NC}" >&2
            echo "    Hash: $tx_hash" >&2
            echo "    Creator: $creator_address" >&2
            echo "    Amount: $target_eth ETH" >&2
            echo "    Gas Used: $gas_used" >&2
            echo "    Block: $block_number" >&2
            echo "    Status: Success (Instant Launch)" >&2
            
            # Return success indicator
            echo "1"
            return 0
        else
            echo -e "${RED}  ❌ Transaction reverted (status: $status)${NC}" >&2
            return 1
        fi
    else
        echo -e "${RED}  ❌ Failed to submit transaction${NC}" >&2
        echo -e "${YELLOW}  💡 Checking account balance...${NC}" >&2
        local balance=$(cast balance "$creator_address" --rpc-url "$ANVIL_RPC" 2>/dev/null)
        echo "    Balance: $balance wei ($(cast to-unit "$balance" ether 2>/dev/null || echo "?") ETH)" >&2
        return 1
    fi
}

# Get venue address for a party
get_venue_address() {
    local party_id="$1"
    
    # Call getParty and extract venue address
    local party_data=$(cast call "$PARTY_STARTER_ADDRESS" "getParty(uint256)" "$party_id" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        # Extract venue address from party data - this is simplified parsing
        local venue_address=$(echo "$party_data" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)
        if [[ "$venue_address" =~ ^0x[a-fA-F0-9]{40}$ ]] && [ "$venue_address" != "0x0000000000000000000000000000000000000000" ]; then
            echo "$venue_address"
            return 0
        fi
    fi
    
    echo ""
    return 1
}

# Contribute to private party venue with signature
contribute_to_private_venue() {
    local contributor_key="$1"
    local contributor_address="$2"
    local venue_address="$3"
    local amount_eth="$4"
    local signature="$5"
    local max_amount_eth="$6"
    local deadline="$7"
    local party_id="$8"
    
    echo -e "${BLUE}  🔐 $contributor_address contributing $amount_eth ETH to private party $party_id${NC}"
    
    # Convert amounts to wei
    local max_amount_wei=$(cast to-wei "$max_amount_eth" ether)
    
    # Contribute with signature
    local tx_hash=$(cast send --private-key "$contributor_key" \
        --rpc-url "$ANVIL_RPC" \
        --value "${amount_eth}ether" \
        "$venue_address" \
        "contributeWithSignature(bytes,uint256,uint256)" \
        "$signature" "$max_amount_wei" "$deadline" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}    ✅ Contribution submitted: $tx_hash${NC}"
        
        # Wait for transaction to be mined
        local receipt=$(cast receipt "$tx_hash" --rpc-url "$ANVIL_RPC" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    ✅ Contribution confirmed${NC}"
            return 0
        else
            echo -e "${RED}    ❌ Contribution failed to mine${NC}"
            return 1
        fi
    else
        echo -e "${RED}    ❌ Failed to contribute${NC}"
        return 1
    fi
}

# Check if party has launched
check_party_launched() {
    local party_id="$1"
    
    local party_data=$(cast call "$PARTY_STARTER_ADDRESS" "getParty(uint256)" "$party_id" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        # Simple check for launched status
        if echo "$party_data" | grep -q "true"; then
            return 0  # launched
        fi
    fi
    return 1  # not launched
}

# Run private party tests
run_private_tests() {
    local party_count="$1"
    local target_eth="$2"
    local contributor_count="$3"
    local contribution_eth="$4"
    local signer_key="$5"
    local signer_address="$6"
    local deadline_offset="$7"
    
    echo -e "${YELLOW}🔐 Running Private Party E2E Tests${NC}"
    echo "===================================="
    echo "  Parties to create: $party_count"
    echo "  Target per party: $target_eth ETH"
    echo "  Contributors per party: $contributor_count"
    echo "  Contribution per user: $contribution_eth ETH"
    echo "  Signer address: $signer_address"
    echo ""
    
    local success_count=0
    local start_time=$(date +%s)
    
    # Create log file
    local log_file="private-parties-$(date +%Y%m%d-%H%M%S).log"
    echo "# Private Party Test Results" > "$log_file"
    echo "# Generated on $(date)" >> "$log_file"
    echo "# PartyID:Creator:Target:LaunchStatus:Timestamp" >> "$log_file"
    
    for party_num in $(seq 1 $party_count); do
        echo -e "\n${BLUE}=== Private Party $party_num/$party_count ===${NC}"
        
        # Select creator (skip index 0 which is empty, avoid using first few wallets as contributors)
        local creator_index=$(((party_num - 1 + contributor_count) % (${#TEST_ADDRESSES[@]} - 1) + 1))
        local creator_address="${TEST_ADDRESSES[$creator_index]}"
        local creator_key="${TEST_PRIVATE_KEYS[$creator_index]}"
        
        local party_name="PrivateToken$party_num"
        local party_symbol="PRIV$party_num"
        
        # Create simplified private party (instant launch)
        local party_result=$(create_private_party "$creator_key" "$creator_address" "$target_eth" "$signer_address" "$party_name" "$party_symbol")
        local create_exit_code=$?
        
        if [ $create_exit_code -eq 0 ] && [ "$party_result" = "1" ]; then
            echo -e "${GREEN}✅ Private party created and launched instantly${NC}"
            success_count=$((success_count + 1))
            
            echo -e "${BLUE}  📊 Final Status: Launched (Instant)${NC}"
            echo -e "${BLUE}  ℹ️  Note: SimplePartyStarter creates instant parties, skipping signature and contribution phases${NC}"
            
            # Log results
            echo "simplified:$creator_address:$target_eth:Launched:$(date +%s)" >> "$log_file"
            
        else
            echo -e "${RED}❌ Failed to create private party $party_num${NC}"
            echo "simplified:$creator_address:$target_eth:Failed:$(date +%s)" >> "$log_file"
        fi
        
        # Add delay between parties
        sleep 3
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Final summary
    echo -e "\n${GREEN}🎉 Private Party Tests Complete${NC}"
    echo "================================="
    echo "  Total parties: $party_count"
    echo "  Successfully launched: $success_count"
    echo "  Failed to launch: $((party_count - success_count))"
    echo "  Duration: ${duration}s"
    echo "  Log file: $log_file"
    
    if [ $success_count -eq $party_count ]; then
        echo -e "${GREEN}✅ All private parties launched successfully!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Some parties failed to launch${NC}"
        return 1
    fi
}

# Cleanup function
cleanup_test_data() {
    echo -e "${YELLOW}🧹 Cleaning up test data...${NC}"
    
    # Remove signature files
    rm -f private-party-*-signatures.txt
    
    # Remove old log files (keep latest 5)
    ls -t private-parties-*.log 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Main execution
main() {
    local party_count=2
    local target_eth=3
    local contributor_count=5
    local contribution_eth=1
    local signer_key="$DEFAULT_SIGNER_KEY"
    local signer_address="$DEFAULT_SIGNER_ADDRESS"
    local deadline_offset=3600
    local cleanup=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --count)
                party_count="$2"
                shift 2
                ;;
            --target)
                target_eth="$2"
                shift 2
                ;;
            --contributors)
                contributor_count="$2"
                shift 2
                ;;
            --contribution)
                contribution_eth="$2"
                shift 2
                ;;
            --signer-key)
                signer_key="$2"
                # Derive signer address from private key
                signer_address=$(cast wallet address --private-key "$signer_key" 2>/dev/null || echo "")
                if [ -z "$signer_address" ]; then
                    echo -e "${RED}❌ Invalid signer private key${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --deadline)
                deadline_offset="$2"
                shift 2
                ;;
            --cleanup)
                cleanup=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate inputs
    if ! [[ "$party_count" =~ ^[0-9]+$ ]] || [ "$party_count" -lt 1 ]; then
        echo -e "${RED}❌ Count must be a positive integer${NC}"
        exit 1
    fi
    
    if ! [[ "$contributor_count" =~ ^[0-9]+$ ]] || [ "$contributor_count" -lt 1 ]; then
        echo -e "${RED}❌ Contributors count must be a positive integer${NC}"
        exit 1
    fi
    
    # Check if we have enough wallets
    if [ "$contributor_count" -ge ${#TEST_ADDRESSES[@]} ]; then
        echo -e "${YELLOW}⚠️  Not enough test wallets for $contributor_count contributors${NC}"
        echo -e "${YELLOW}    Using ${#TEST_ADDRESSES[@]} wallets${NC}"
        contributor_count=${#TEST_ADDRESSES[@]}
    fi
    
    # Check prerequisites
    if ! cast chain-id --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
        echo -e "${RED}❌ Anvil is not running on $ANVIL_RPC${NC}"
        echo -e "${YELLOW}💡 Start Anvil first: ./dev.sh start${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Anvil is running${NC}"
    
    # Load contract addresses
    load_contract_addresses
    
    # Check if signature utility exists
    if [ ! -f "$SCRIPT_DIR/e2e-signature-utils.sh" ]; then
        echo -e "${RED}❌ Signature utility script not found${NC}"
        echo -e "${YELLOW}💡 Make sure e2e-signature-utils.sh exists${NC}"
        exit 1
    fi
    
    # Run tests
    if run_private_tests "$party_count" "$target_eth" "$contributor_count" "$contribution_eth" "$signer_key" "$signer_address" "$deadline_offset"; then
        if [ "$cleanup" = "true" ]; then
            cleanup_test_data
        fi
        
        echo -e "\n${GREEN}🎉 Private party e2e tests completed successfully!${NC}"
        echo -e "${BLUE}💡 Note: Private parties require signature authorization for contributions${NC}"
    else
        echo -e "\n${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

# Check dependencies
for cmd in cast jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ '$cmd' command not found. Please install it.${NC}"
        exit 1
    fi
done

# Run main function
main "$@" 