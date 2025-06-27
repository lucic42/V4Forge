#!/bin/bash

# LaunchDotParty Development Environment Manager
# Simple wrapper for managing the local development setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show usage
show_help() {
    echo -e "${BLUE}🚀 LaunchDotParty Development Environment Manager${NC}"
    echo "=================================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  start      Start Anvil and Otterscan"
    echo "  stop       Stop all services"
    echo "  restart    Restart all services"
    echo "  status     Check service status"
    echo "  deploy     Deploy contracts to running Anvil"
    echo "  verify     Setup contract verification"
    echo "  logs       Show Anvil logs"
    echo "  clean      Stop services and clean artifacts"
    echo ""
    echo -e "${YELLOW}Start Options:${NC}"
    echo "  --deploy        Deploy contracts after starting"
    echo "  --no-otterscan  Skip Otterscan block explorer"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 start                    # Start basic environment"
    echo "  $0 start --deploy          # Start and deploy contracts"
    echo "  $0 start --no-otterscan    # Start without block explorer"
    echo "  $0 stop                    # Stop all services"
    echo "  $0 restart --deploy        # Restart and redeploy"
    echo "  $0 verify                  # Setup contract verification"
    echo ""
    echo -e "${BLUE}🔗 URLs:${NC}"
    echo "  • Anvil RPC: http://localhost:8545"
    echo "  • Otterscan: http://localhost:5100"
    echo "  • Contract Verification: http://localhost:8080/contracts.html"
}

# Check service status
check_status() {
    echo -e "${BLUE}🔍 Checking Development Environment Status${NC}"
    echo "========================================="
    
    # Check Anvil
    if lsof -i :8545 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Anvil: Running on port 8545${NC}"
        
        # Try to get block number
        if command -v cast > /dev/null 2>&1; then
            local block_number=$(cast block-number --rpc-url http://localhost:8545 2>/dev/null || echo "unknown")
            echo -e "${BLUE}   Current block: $block_number${NC}"
        fi
    else
        echo -e "${RED}❌ Anvil: Not running${NC}"
    fi
    
    # Check Otterscan
    if lsof -i :5100 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Otterscan: Running on port 5100${NC}"
        echo -e "${BLUE}   URL: http://localhost:5100${NC}"
    else
        echo -e "${RED}❌ Otterscan: Not running${NC}"
    fi
    
    # Check Docker
    if docker ps | grep -q otterscan; then
        echo -e "${GREEN}✅ Docker: Otterscan container running${NC}"
    else
        if command -v docker > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Docker: Otterscan container not running${NC}"
        else
            echo -e "${RED}❌ Docker: Not available${NC}"
        fi
    fi
    
    # Check if PID files exist
    if [ -f .anvil.pid ]; then
        local pid=$(cat .anvil.pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✅ Anvil PID file: Valid (PID: $pid)${NC}"
        else
            echo -e "${YELLOW}⚠️  Anvil PID file: Stale (PID: $pid not running)${NC}"
        fi
    fi
}

# Show logs
show_logs() {
    if [ -f anvil.log ]; then
        echo -e "${BLUE}📋 Anvil Logs (last 50 lines):${NC}"
        echo "================================"
        tail -50 anvil.log
    else
        echo -e "${YELLOW}⚠️  No Anvil log file found${NC}"
    fi
}

# Deploy contracts
deploy_contracts() {
    echo -e "${YELLOW}🚀 Deploying contracts...${NC}"
    
    # Check if Anvil is running
    if ! lsof -i :8545 > /dev/null 2>&1; then
        echo -e "${RED}❌ Anvil is not running. Start it first with: $0 start${NC}"
        exit 1
    fi
    
    # Run deployment
    export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    forge script script/LocalTest.s.sol --fork-url http://localhost:8545 --broadcast -v
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Contracts deployed successfully${NC}"
        
        # Extract deployment addresses
        echo -e "${BLUE}📋 Extracting contract addresses...${NC}"
        "$SCRIPT_DIR/extract-addresses.sh" extract
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Contract addresses extracted${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not extract addresses automatically${NC}"
        fi
    else
        echo -e "${RED}❌ Contract deployment failed${NC}"
        exit 1
    fi
}

# Main execution
main() {
    # Ensure we're in the right directory
    if [ ! -f foundry.toml ]; then
        echo -e "${RED}❌ This script must be run from the launch-contracts directory${NC}"
        exit 1
    fi
    
    case "${1:-help}" in
        "start")
            shift
            "$SCRIPT_DIR/start-dev-environment.sh" "$@"
            ;;
        "stop")
            shift
            "$SCRIPT_DIR/stop-dev-environment.sh" "$@"
            ;;
        "restart")
            shift
            echo -e "${YELLOW}🔄 Restarting development environment...${NC}"
            "$SCRIPT_DIR/stop-dev-environment.sh"
            sleep 2
            "$SCRIPT_DIR/start-dev-environment.sh" "$@"
            ;;
        "status")
            check_status
            ;;
        "logs")
            show_logs
            ;;
        "deploy")
            deploy_contracts
            ;;
        "verify")
            "$SCRIPT_DIR/configure-otterscan.sh" setup
            ;;
        "clean")
            "$SCRIPT_DIR/stop-dev-environment.sh"
            "$SCRIPT_DIR/configure-otterscan.sh" clean 2>/dev/null || true
            echo -e "${YELLOW}🧹 Additional cleanup...${NC}"
            rm -rf out cache
            echo -e "${GREEN}✅ Deep clean completed${NC}"
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Handle direct script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 