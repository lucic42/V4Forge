#!/bin/bash

# E2E Test Script for Instant Parties
# Tests instant party creation and launch

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
    if [ -n "$WETH_ADDRESS" ]; then
        echo -e "${GREEN}✅ Using WETH at: $WETH_ADDRESS${NC}"
    fi
    if [ -n "$POOL_MANAGER_ADDRESS" ]; then
        echo -e "${GREEN}✅ Using PoolManager at: $POOL_MANAGER_ADDRESS${NC}"
    fi
}

show_help() {
    echo -e "${BLUE}⚡ E2E Test for Instant Parties${NC}"
    echo "================================="
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --count <N>        Number of instant parties to create (default: 5)"
    echo "  --amount <ETH>     ETH amount for each party (default: 2)"
    echo "  --parallel         Run tests in parallel (faster)"
    echo "  --cleanup          Clean up after tests"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0                           # Create 5 instant parties with 2 ETH each"
    echo "  $0 --count 10 --amount 1     # Create 10 instant parties with 1 ETH each"
    echo "  $0 --parallel                # Run tests in parallel"
    echo ""
}

# Create instant party (simplified for testing with SimplePartyStarter)
create_instant_party() {
    local creator_key="$1"
    local creator_address="$2"
    local amount_eth="$3"
    local party_name="$4"
    local party_symbol="$5"
    local log_file="${6:-instant-parties-$(date +%Y%m%d).log}"
    
    echo -e "${YELLOW}⚡ Creating instant party: $party_name ($party_symbol)${NC}"
    echo "  Creator: $creator_address"
    echo "  Amount: $amount_eth ETH"
    
    # Test basic contract interaction first
    echo -e "${BLUE}  🔍 Testing contract accessibility...${NC}"
    local pool_manager_addr=$(cast call "$PARTY_STARTER_ADDRESS" "poolManager()" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✅ Contract accessible, PoolManager: $pool_manager_addr${NC}"
    else
        echo -e "${RED}  ❌ Contract not accessible${NC}"
        return 1
    fi
    
    # Create instant party (simplified interface)
    echo -e "${BLUE}  📤 Sending transaction...${NC}"
    local tx_result=$(cast send --private-key "$creator_key" \
        --rpc-url "$ANVIL_RPC" \
        --value "${amount_eth}ether" \
        --json \
        "$PARTY_STARTER_ADDRESS" \
        "createInstantParty()" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$tx_result" ]; then
        # Extract transaction hash from JSON result
        local tx_hash=$(echo "$tx_result" | jq -r '.transactionHash' 2>/dev/null)
        
        echo -e "${GREEN}  ✅ Transaction submitted: $tx_hash${NC}"
        
        # Check transaction status directly from the result
        local status=$(echo "$tx_result" | jq -r '.status' 2>/dev/null)
        if [ "$status" = "0x1" ]; then
            echo -e "${GREEN}  ✅ Transaction successful${NC}"
            
            # Get transaction receipt details from the result
            local gas_used=$(echo "$tx_result" | jq -r '.gasUsed' 2>/dev/null)
            local block_number=$(echo "$tx_result" | jq -r '.blockNumber' 2>/dev/null)
            
            echo -e "${BLUE}  📊 Transaction Details:${NC}"
            echo "    Hash: $tx_hash"
            echo "    Creator: $creator_address"
            echo "    Amount: $amount_eth ETH"
            echo "    Gas Used: $gas_used"
            echo "    Block: $block_number"
            echo "    Status: Success"
            
            # Store party info for later analysis
            echo "simplified:$creator_address:$amount_eth:$tx_hash:$(date +%s):$gas_used" >> "$log_file"
            
            return 0
        else
            echo -e "${RED}  ❌ Transaction reverted (status: $status)${NC}"
            return 1
        fi
    else
        echo -e "${RED}  ❌ Failed to submit transaction${NC}"
        echo -e "${YELLOW}  💡 Checking account balance...${NC}"
        local balance=$(cast balance "$creator_address" --rpc-url "$ANVIL_RPC" 2>/dev/null)
        echo "    Balance: $balance wei ($(cast to-unit "$balance" ether 2>/dev/null || echo "?") ETH)"
        return 1
    fi
}

# Run instant party tests
run_instant_tests() {
    local count="$1"
    local amount_eth="$2"
    local parallel="$3"
    
    echo -e "${YELLOW}⚡ Running Instant Party E2E Tests${NC}"
    echo "====================================="
    echo "  Parties to create: $count"
    echo "  Amount per party: $amount_eth ETH"
    echo "  Mode: $([ "$parallel" = "true" ] && echo "Parallel" || echo "Sequential")"
    echo ""
    
    local success_count=0
    local total_gas_used=0
    local start_time=$(date +%s)
    
    # Create log file
    local log_file="instant-parties-$(date +%Y%m%d-%H%M%S).log"
    echo "# Instant Party Test Results" > "$log_file"
    echo "# Generated on $(date)" >> "$log_file"
    echo "# PartyID:Creator:Amount:TxHash:Timestamp" >> "$log_file"
    
    if [ "$parallel" = "true" ]; then
        echo -e "${BLUE}🚀 Running tests in parallel...${NC}"
        
        # Create temporary files to track results
        local results_dir="/tmp/instant-party-results-$$"
        mkdir -p "$results_dir"
        
        # Create background jobs
        for i in $(seq 1 $count); do
            local wallet_index=$((i % ${#TEST_ADDRESSES[@]}))
            local creator_address="${TEST_ADDRESSES[$wallet_index]}"
            local creator_key="${TEST_PRIVATE_KEYS[$wallet_index]}"
            local party_name="InstantToken$i"
            local party_symbol="IT$i"
            
            # Run in background and write result to file
            (
                # Use unique log file for this process
                local process_log_file="instant-parties-$(date +%Y%m%d)-process-$i.log"
                if create_instant_party "$creator_key" "$creator_address" "$amount_eth" "$party_name" "$party_symbol" "$process_log_file"; then
                    echo "success" > "$results_dir/result_$i"
                else
                    echo "failed" > "$results_dir/result_$i"
                fi
            ) &
            
            # Limit concurrent jobs
            if [ $((i % 5)) -eq 0 ]; then
                wait
            fi
        done
        
        # Wait for all background jobs
        wait
        
        # Count successes from result files
        for i in $(seq 1 $count); do
            if [ -f "$results_dir/result_$i" ] && [ "$(cat "$results_dir/result_$i")" = "success" ]; then
                success_count=$((success_count + 1))
            fi
        done
        
        # Merge individual process log files into main log file
        for i in $(seq 1 $count); do
            local process_log_file="instant-parties-$(date +%Y%m%d)-process-$i.log"
            if [ -f "$process_log_file" ]; then
                cat "$process_log_file" >> "$log_file"
                rm -f "$process_log_file"
            fi
        done
        
        # Clean up temporary files
        rm -rf "$results_dir"
        
    else
        echo -e "${BLUE}🏃 Running tests sequentially...${NC}"
        
        for i in $(seq 1 $count); do
            local wallet_index=$((i % ${#TEST_ADDRESSES[@]}))
            local creator_address="${TEST_ADDRESSES[$wallet_index]}"
            local creator_key="${TEST_PRIVATE_KEYS[$wallet_index]}"
            local party_name="InstantToken$i"
            local party_symbol="IT$i"
            
            echo -e "\n${BLUE}--- Test $i/$count ---${NC}"
            
            if create_instant_party "$creator_key" "$creator_address" "$amount_eth" "$party_name" "$party_symbol"; then
                success_count=$((success_count + 1))
            fi
            
            # Add delay between sequential tests
            sleep 1
        done
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Final summary
    echo -e "\n${GREEN}🎉 Instant Party Tests Complete${NC}"
    echo "================================="
    echo "  Total parties: $count"
    echo "  Successful: $success_count"
    echo "  Failed: $((count - success_count))"
    echo "  Duration: ${duration}s"
    echo "  Log file: $log_file"
    
    # Check final party counter
    local final_counter=$(cast call "$PARTY_STARTER_ADDRESS" "partyCounter()" --rpc-url "$ANVIL_RPC" 2>/dev/null || echo "0")
    echo "  Final party counter: $final_counter"
    
    # Analyze results
    if [ -f "$log_file" ]; then
        local log_entries=$(grep -v "^#" "$log_file" | wc -l)
        echo "  Logged entries: $log_entries"
    fi
    
    if [ $success_count -eq $count ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Some tests failed${NC}"
        return 1
    fi
}

# Verify contract state (simplified for SimplePartyStarter)
verify_party_states() {
    echo -e "${YELLOW}🔍 Verifying contract state...${NC}"
    
    # Test basic contract functions
    echo -e "${BLUE}  📋 Testing contract functions...${NC}"
    
    local pool_manager=$(cast call "$PARTY_STARTER_ADDRESS" "poolManager()" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✅ poolManager(): $pool_manager${NC}"
    else
        echo -e "${RED}  ❌ Failed to call poolManager()${NC}"
    fi
    
    local weth_addr=$(cast call "$PARTY_STARTER_ADDRESS" "weth()" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✅ weth(): $weth_addr${NC}"
    else
        echo -e "${RED}  ❌ Failed to call weth()${NC}"
    fi
    
    local vault_addr=$(cast call "$PARTY_STARTER_ADDRESS" "partyVault()" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✅ partyVault(): $vault_addr${NC}"
    else
        echo -e "${RED}  ❌ Failed to call partyVault()${NC}"
    fi
    
    local hook_addr=$(cast call "$PARTY_STARTER_ADDRESS" "swapLimitHook()" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✅ swapLimitHook(): $hook_addr${NC}"
    else
        echo -e "${RED}  ❌ Failed to call swapLimitHook()${NC}"
    fi
    
    # Check contract balance
    local contract_balance=$(cast balance "$PARTY_STARTER_ADDRESS" --rpc-url "$ANVIL_RPC" 2>/dev/null)
    if [ $? -eq 0 ]; then
        local balance_eth=$(cast to-unit "$contract_balance" ether 2>/dev/null || echo "?")
        echo -e "${GREEN}  ✅ Contract balance: $balance_eth ETH${NC}"
    else
        echo -e "${RED}  ❌ Failed to get contract balance${NC}"
    fi
    
    echo -e "${BLUE}📊 Contract verification complete${NC}"
}

# Cleanup function
cleanup_test_data() {
    echo -e "${YELLOW}🧹 Cleaning up test data...${NC}"
    
    # Remove old log files (keep latest 5)
    ls -t instant-parties-*.log 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Main execution
main() {
    local count=5
    local amount_eth=2
    local parallel=false
    local cleanup=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --count)
                count="$2"
                shift 2
                ;;
            --amount)
                amount_eth="$2"
                shift 2
                ;;
            --parallel)
                parallel=true
                shift
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
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
        echo -e "${RED}❌ Count must be a positive integer${NC}"
        exit 1
    fi
    
    if ! [[ "$amount_eth" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}❌ Amount must be a valid number${NC}"
        exit 1
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
    
    # Run tests
    if run_instant_tests "$count" "$amount_eth" "$parallel"; then
        echo -e "\n${BLUE}🔍 Running post-test verification...${NC}"
        verify_party_states
        
        if [ "$cleanup" = "true" ]; then
            cleanup_test_data
        fi
        
        echo -e "\n${GREEN}🎉 Instant party e2e tests completed successfully!${NC}"
    else
        echo -e "\n${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

# Check dependencies
if ! command -v cast &> /dev/null; then
    echo -e "${RED}❌ 'cast' command not found. Please install Foundry.${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ 'jq' command not found. Please install jq.${NC}"
    exit 1
fi

# Run main function
main "$@" 