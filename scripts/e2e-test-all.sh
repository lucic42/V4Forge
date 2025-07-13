#!/bin/bash

# E2E Test Orchestrator Script
# Runs comprehensive end-to-end tests for all party types

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ANVIL_RPC="http://localhost:8545"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test configuration defaults
DEFAULT_INSTANT_COUNT=5
DEFAULT_PUBLIC_COUNT=3
DEFAULT_PRIVATE_COUNT=2
DEFAULT_TARGET_ETH=5
DEFAULT_CONTRIBUTION_ETH=1

show_help() {
    echo -e "${CYAN}🚀 E2E Test Orchestrator for LaunchDotParty${NC}"
    echo "=============================================="
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  full          Run complete e2e test suite (default)"
    echo "  instant       Run only instant party tests"
    echo "  public        Run only public party tests"
    echo "  private       Run only private party tests"
    echo "  setup         Setup environment only"
    echo "  status        Check environment status"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --instant-count <N>     Number of instant parties (default: $DEFAULT_INSTANT_COUNT)"
    echo "  --public-count <N>      Number of public parties (default: $DEFAULT_PUBLIC_COUNT)"
    echo "  --private-count <N>     Number of private parties (default: $DEFAULT_PRIVATE_COUNT)"
    echo "  --target <ETH>          Target liquidity per party (default: $DEFAULT_TARGET_ETH)"
    echo "  --contribution <ETH>    Contribution per user (default: $DEFAULT_CONTRIBUTION_ETH)"
    echo "  --parallel              Run tests in parallel where possible"
    echo "  --cleanup               Clean up after tests"
    echo "  --no-setup              Skip environment setup"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 full                         # Full test suite with defaults"
    echo "  $0 instant --instant-count 10   # Only instant parties, 10 tests"
    echo "  $0 setup                        # Setup environment only"
    echo ""
}

check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    # Check if Anvil is running
    if ! cast chain-id --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
        echo -e "${RED}❌ Anvil is not running on $ANVIL_RPC${NC}"
        echo -e "${YELLOW}💡 Start Anvil first: ./dev.sh start${NC}"
        return 1
    fi
    
    # Check required scripts exist
    local required_scripts=(
        "e2e-test-setup.sh"
        "e2e-test-instant.sh"
        "e2e-test-public.sh"
        "e2e-test-private.sh"
        "e2e-signature-utils.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$script" ]; then
            echo -e "${RED}❌ Required script not found: $script${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
    return 0
}

run_environment_setup() {
    echo -e "\n${PURPLE}━━━ Phase 1: Environment Setup ━━━${NC}"
    
    if ! "$SCRIPT_DIR/e2e-test-setup.sh" setup; then
        echo -e "${RED}❌ Environment setup failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Environment setup completed${NC}"
    return 0
}

run_instant_tests() {
    local count="$1"
    local amount="$2"
    local parallel="$3"
    
    echo -e "\n${PURPLE}━━━ Phase 2: Instant Party Tests ━━━${NC}"
    
    local args="--count $count --amount $amount"
    if [ "$parallel" = "true" ]; then
        args="$args --parallel"
    fi
    
    if ! "$SCRIPT_DIR/e2e-test-instant.sh" $args; then
        echo -e "${RED}❌ Instant party tests failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Instant party tests completed${NC}"
    return 0
}

run_public_tests() {
    local count="$1"
    local target="$2"
    local contribution="$3"
    local contributors="$4"
    
    echo -e "\n${PURPLE}━━━ Phase 3: Public Party Tests ━━━${NC}"
    
    local args="--count $count --target $target --contribution $contribution --contributors $contributors"
    
    if ! "$SCRIPT_DIR/e2e-test-public.sh" $args; then
        echo -e "${RED}❌ Public party tests failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Public party tests completed${NC}"
    return 0
}

run_private_tests() {
    local count="$1"
    local target="$2"
    local contribution="$3"
    local contributors="$4"
    
    echo -e "\n${PURPLE}━━━ Phase 4: Private Party Tests ━━━${NC}"
    
    local args="--count $count --target $target --contribution $contribution --contributors $contributors"
    
    if ! "$SCRIPT_DIR/e2e-test-private.sh" $args; then
        echo -e "${RED}❌ Private party tests failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Private party tests completed${NC}"
    return 0
}

show_status() {
    echo -e "${CYAN}📊 E2E Test Environment Status${NC}"
    echo "================================="
    
    # Check Anvil
    if cast chain-id --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
        local block_number=$(cast block-number --rpc-url "$ANVIL_RPC" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ Anvil: Running (block: $block_number)${NC}"
    else
        echo -e "${RED}❌ Anvil: Not running${NC}"
    fi
    
    # Check wallet setup
    if [ -f "e2e-wallets.env" ]; then
        source e2e-wallets.env
        echo -e "${GREEN}✅ Wallets: ${#TEST_ADDRESSES[@]} configured${NC}"
    else
        echo -e "${RED}❌ Wallets: Not configured${NC}"
    fi
    
    # Check contract deployment
    if [ -f "deployments/local.env" ] || [ -f "broadcast/LocalTest.s.sol/31337/run-latest.json" ]; then
        echo -e "${GREEN}✅ Contracts: Deployed${NC}"
    else
        echo -e "${RED}❌ Contracts: Not deployed${NC}"
    fi
    
    # Check log files
    local log_count=$(ls -1 *-parties-*.log 2>/dev/null | wc -l)
    echo -e "${BLUE}📁 Log files: $log_count found${NC}"
}

# Main execution
main() {
    local command="${1:-full}"
    shift || true
    
    # Default parameters
    local instant_count="$DEFAULT_INSTANT_COUNT"
    local public_count="$DEFAULT_PUBLIC_COUNT"
    local private_count="$DEFAULT_PRIVATE_COUNT"
    local target_eth="$DEFAULT_TARGET_ETH"
    local contribution_eth="$DEFAULT_CONTRIBUTION_ETH"
    local parallel=false
    local cleanup=false
    local no_setup=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --instant-count)
                instant_count="$2"
                shift 2
                ;;
            --public-count)
                public_count="$2"
                shift 2
                ;;
            --private-count)
                private_count="$2"
                shift 2
                ;;
            --target)
                target_eth="$2"
                shift 2
                ;;
            --contribution)
                contribution_eth="$2"
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
            --no-setup)
                no_setup=true
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
    
    case "$command" in
        "setup")
            check_prerequisites || exit 1
            run_environment_setup || exit 1
            ;;
            
        "status")
            show_status
            ;;
            
        "instant")
            check_prerequisites || exit 1
            if [ "$no_setup" = "false" ]; then
                run_environment_setup || exit 1
            fi
            run_instant_tests "$instant_count" "$contribution_eth" "$parallel" || exit 1
            ;;
            
        "public")
            check_prerequisites || exit 1
            if [ "$no_setup" = "false" ]; then
                run_environment_setup || exit 1
            fi
            # Calculate contributors needed for target
            local contributors_needed=$((target_eth / contribution_eth + 1))
            run_public_tests "$public_count" "$target_eth" "$contribution_eth" "$contributors_needed" || exit 1
            ;;
            
        "private")
            check_prerequisites || exit 1
            if [ "$no_setup" = "false" ]; then
                run_environment_setup || exit 1
            fi
            # Calculate contributors needed for target
            local contributors_needed=$((target_eth / contribution_eth + 1))
            run_private_tests "$private_count" "$target_eth" "$contribution_eth" "$contributors_needed" || exit 1
            ;;
            
        "full")
            echo -e "${CYAN}🚀 Starting Complete E2E Test Suite${NC}"
            echo -e "${CYAN}=====================================${NC}"
            
            local start_time=$(date +%s)
            local overall_success=true
            
            # Prerequisites
            if ! check_prerequisites; then
                echo -e "${RED}❌ Prerequisites not met${NC}"
                exit 1
            fi
            
            # Setup
            if [ "$no_setup" = "false" ]; then
                if ! run_environment_setup; then
                    overall_success=false
                fi
            fi
            
            # Instant tests
            if [ "$overall_success" = "true" ]; then
                if ! run_instant_tests "$instant_count" "$contribution_eth" "$parallel"; then
                    overall_success=false
                fi
            fi
            
            # Public tests
            if [ "$overall_success" = "true" ]; then
                local contributors_needed=$((target_eth / contribution_eth + 1))
                if ! run_public_tests "$public_count" "$target_eth" "$contribution_eth" "$contributors_needed"; then
                    overall_success=false
                fi
            fi
            
            # Private tests
            if [ "$overall_success" = "true" ]; then
                local contributors_needed=$((target_eth / contribution_eth + 1))
                if ! run_private_tests "$private_count" "$target_eth" "$contribution_eth" "$contributors_needed"; then
                    overall_success=false
                fi
            fi
            
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            # Final report
            echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${CYAN}             E2E TEST EXECUTION COMPLETE${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}⏱️  Total Duration: ${duration}s${NC}"
            
            if [ "$overall_success" = "true" ]; then
                echo -e "${GREEN}🎉 Overall Result: SUCCESS${NC}"
                echo -e "${GREEN}✅ All test phases completed successfully${NC}"
                exit 0
            else
                echo -e "${RED}❌ Overall Result: FAILED${NC}"
                exit 1
            fi
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

# Check dependencies
for cmd in cast jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ '$cmd' command not found. Please install it.${NC}"
        exit 1
    fi
done

# Run main function
main "$@" 