#!/bin/bash

# LaunchDotParty Development Environment Starter
# This script starts Anvil blockchain and Otterscan block explorer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ANVIL_PORT=8545
ANVIL_CHAIN_ID=31337
OTTERSCAN_PORT=5100
DEPLOYER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

echo -e "${BLUE}🚀 Starting LaunchDotParty Development Environment${NC}"
echo "=================================================="

# Check if Docker is running (required for Otterscan)
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker to use Otterscan.${NC}"
        echo -e "${YELLOW}⚠️  You can still run Anvil without Otterscan.${NC}"
        read -p "Continue without Otterscan? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 1
    fi
    return 0
}

# Check if port is available
check_port() {
    local port=$1
    local service=$2
    
    if lsof -i :$port > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port $port is already in use (required for $service)${NC}"
        
        # Try to identify what's using the port
        local process=$(lsof -i :$port | grep LISTEN | awk '{print $1, $2}' | head -1)
        if [ ! -z "$process" ]; then
            echo -e "${BLUE}  Process using port: $process${NC}"
        fi
        
        read -p "Kill existing process and continue? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Kill processes using the port
            lsof -ti :$port | xargs kill -9 2>/dev/null || true
            sleep 2
        else
            echo -e "${RED}❌ Cannot continue with port $port occupied${NC}"
            exit 1
        fi
    fi
}

# Start Anvil blockchain
start_anvil() {
    echo -e "${YELLOW}🔧 Starting Anvil blockchain...${NC}"
    
    check_port $ANVIL_PORT "Anvil"
    
    # Kill any existing anvil processes
    pkill -f anvil || true
    sleep 1
    
    # Start Anvil
    echo -e "${BLUE}  🆕 Starting fresh blockchain on port $ANVIL_PORT${NC}"
    anvil --port $ANVIL_PORT --chain-id $ANVIL_CHAIN_ID --gas-limit 30000000 > anvil.log 2>&1 &
    
    ANVIL_PID=$!
    echo $ANVIL_PID > .anvil.pid
    
    # Wait for Anvil to be ready
    echo -e "${BLUE}  ⏳ Waiting for Anvil to be ready...${NC}"
    sleep 3
    
    # Test if Anvil is responding
    if curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:$ANVIL_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Anvil started successfully (PID: $ANVIL_PID)${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to start Anvil${NC}"
        cat anvil.log
        exit 1
    fi
}

# Start Otterscan block explorer
start_otterscan() {
    echo -e "${YELLOW}🔍 Starting Otterscan block explorer...${NC}"
    
    if ! check_docker; then
        echo -e "${YELLOW}⚠️  Skipping Otterscan (Docker not available)${NC}"
        return 1
    fi
    
    check_port $OTTERSCAN_PORT "Otterscan"
    
    # Stop any existing Otterscan container
    docker stop otterscan 2>/dev/null || true
    docker rm otterscan 2>/dev/null || true
    
    # Start Otterscan
    echo -e "${BLUE}  🐳 Starting Otterscan container...${NC}"
    docker run --rm -p $OTTERSCAN_PORT:80 --name otterscan -d otterscan/otterscan:latest > /dev/null
    
    # Wait for Otterscan to be ready
    echo -e "${BLUE}  ⏳ Waiting for Otterscan to be ready...${NC}"
    sleep 5
    
    # Test if Otterscan is responding
    if curl -s http://localhost:$OTTERSCAN_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Otterscan started successfully${NC}"
        echo $OTTERSCAN_PORT > .otterscan.port
        return 0
    else
        echo -e "${RED}❌ Failed to start Otterscan${NC}"
        return 1
    fi
}

# Deploy contracts if requested
deploy_contracts() {
    if [ "$1" = "--deploy" ]; then
        echo -e "${YELLOW}🚀 Deploying contracts...${NC}"
        sleep 2
        
        # Run the main setup script in deploy-only mode
        export PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY
        forge script script/LocalTest.s.sol --fork-url http://localhost:$ANVIL_PORT --broadcast -v
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Contracts deployed successfully${NC}"
        else
            echo -e "${RED}❌ Contract deployment failed${NC}"
            echo -e "${YELLOW}⚠️  Environment started but contracts not deployed${NC}"
        fi
    fi
}

# Print status and instructions
print_status() {
    echo -e "\n${GREEN}🎉 Development Environment Started!${NC}"
    echo "===================================="
    
    echo -e "${BLUE}🔗 Services Running:${NC}"
    echo "  • Anvil Blockchain: http://localhost:$ANVIL_PORT"
    echo "  • Chain ID: $ANVIL_CHAIN_ID"
    
    if [ -f .otterscan.port ]; then
        echo "  • Otterscan Explorer: http://localhost:$OTTERSCAN_PORT"
        echo ""
        echo -e "${YELLOW}🔍 Otterscan Setup:${NC}"
        echo "  1. Open http://localhost:$OTTERSCAN_PORT in your browser"
        echo "  2. Click the settings icon (⚙️) in the top right"
        echo "  3. Set RPC URL to: http://127.0.0.1:$ANVIL_PORT"
        echo "  4. Set Chain ID to: $ANVIL_CHAIN_ID"
        echo "  5. Click 'Save'"
    else
        echo "  • Otterscan Explorer: Not running (Docker required)"
    fi
    
    echo ""
    echo -e "${BLUE}💰 Test Accounts (each has 10,000 ETH):${NC}"
    echo "  • Account 0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    echo "    Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    echo "  • Account 1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    echo "    Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    
    echo ""
    echo -e "${BLUE}🛠️  Management Commands:${NC}"
    echo "  • Stop all: ./scripts/stop-dev-environment.sh"
    echo "  • View Anvil logs: tail -f anvil.log"
    echo "  • Deploy contracts: forge script script/LocalTest.s.sol --fork-url http://localhost:$ANVIL_PORT --broadcast"
    
    echo ""
    echo -e "${YELLOW}💡 Quick Test:${NC}"
    echo "  cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:$ANVIL_PORT"
}

# Main execution
main() {
    # Parse arguments
    DEPLOY_CONTRACTS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --deploy)
                DEPLOY_CONTRACTS=true
                shift
                ;;
            --no-otterscan)
                NO_OTTERSCAN=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --deploy        Deploy contracts after starting services"
                echo "  --no-otterscan  Skip starting Otterscan block explorer"
                echo "  -h, --help      Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Start services
    start_anvil
    
    if [ "$NO_OTTERSCAN" != "true" ]; then
        start_otterscan
    fi
    
    # Deploy contracts if requested
    if [ "$DEPLOY_CONTRACTS" = "true" ]; then
        deploy_contracts --deploy
    fi
    
    print_status
}

# Handle direct script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 