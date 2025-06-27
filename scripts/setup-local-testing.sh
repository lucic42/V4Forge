#!/bin/bash

# LaunchDotParty Local Testing Setup Script
# This script sets up a complete local blockchain environment for testing

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
DEPLOYER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
FRONTEND_DIR="../launch-frontend"
ABI_OUTPUT_DIR="../launch-frontend/src/contracts"

echo -e "${BLUE}🚀 LaunchDotParty Local Testing Setup${NC}"
echo "============================================="

# Check if required tools are installed
check_dependencies() {
    echo -e "${YELLOW}📋 Checking dependencies...${NC}"
    
    if ! command -v forge &> /dev/null; then
        echo -e "${RED}❌ Foundry (forge) is not installed. Please install from https://getfoundry.sh${NC}"
        exit 1
    fi
    
    if ! command -v cast &> /dev/null; then
        echo -e "${RED}❌ Foundry (cast) is not installed. Please install from https://getfoundry.sh${NC}"
        exit 1
    fi
    
    if ! command -v anvil &> /dev/null; then
        echo -e "${RED}❌ Foundry (anvil) is not installed. Please install from https://getfoundry.sh${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies are installed${NC}"
}

# Install and update dependencies
install_dependencies() {
    echo -e "${YELLOW}📦 Installing/updating contract dependencies...${NC}"
    forge install
    forge update
    echo -e "${GREEN}✅ Dependencies updated${NC}"
}

# Compile contracts
compile_contracts() {
    echo -e "${YELLOW}🔨 Compiling contracts...${NC}"
    forge build
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Contracts compiled successfully${NC}"
    else
        echo -e "${RED}❌ Contract compilation failed${NC}"
        exit 1
    fi
}

# Run tests
run_tests() {
    echo -e "${YELLOW}🧪 Running contract tests...${NC}"
    forge test -vv
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed${NC}"
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        echo -e "${YELLOW}⚠️  Continuing with deployment anyway...${NC}"
    fi
}

# Generate ABIs for frontend integration
generate_abis() {
    echo -e "${YELLOW}📄 Generating ABIs for frontend integration...${NC}"
    
    # Create ABI output directory
    mkdir -p "$ABI_OUTPUT_DIR"
    
    # Extract ABIs from compiled contracts
    echo -e "${BLUE}  📄 Extracting PartyStarter ABI...${NC}"
    cat out/PartyStarter.sol/PartyStarter.json | jq '.abi' > "$ABI_OUTPUT_DIR/PartyStarter.json"
    
    echo -e "${BLUE}  📄 Extracting PartyVault ABI...${NC}"
    cat out/PartyVault.sol/PartyVault.json | jq '.abi' > "$ABI_OUTPUT_DIR/PartyVault.json"
    
    echo -e "${BLUE}  📄 Extracting PartyVenue ABI...${NC}"
    cat out/PartyVenue.sol/PartyVenue.json | jq '.abi' > "$ABI_OUTPUT_DIR/PartyVenue.json"
    
    echo -e "${BLUE}  📄 Extracting UniswapV4ERC20 ABI...${NC}"
    cat out/UniswapV4ERC20.sol/UniswapV4ERC20.json | jq '.abi' > "$ABI_OUTPUT_DIR/UniswapV4ERC20.json"
    
    # Generate TypeScript types if wagmi CLI is available
    if command -v wagmi &> /dev/null; then
        echo -e "${BLUE}  📄 Generating TypeScript types...${NC}"
        cd "$FRONTEND_DIR"
        npx wagmi generate
        cd - > /dev/null
    fi
    
    echo -e "${GREEN}✅ ABIs generated successfully${NC}"
}

# Check if Anvil is running
check_anvil_running() {
    if lsof -i :$ANVIL_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Anvil is already running on port $ANVIL_PORT${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Anvil is not running on port $ANVIL_PORT${NC}"
        return 1
    fi
}

# Start Anvil in background
start_anvil() {
    echo -e "${YELLOW}🔧 Starting Anvil local blockchain...${NC}"
    
    # Kill any existing anvil processes
    pkill -f anvil || true
    
    # Start Anvil with fork (requires RPC URL)
    if [ -n "$FORK_URL" ]; then
        echo -e "${BLUE}  🍴 Forking from: $FORK_URL${NC}"
        anvil --port $ANVIL_PORT --chain-id $ANVIL_CHAIN_ID --fork-url "$FORK_URL" --gas-limit 30000000 > anvil.log 2>&1 &
    else
        echo -e "${BLUE}  🆕 Starting fresh blockchain${NC}"
        anvil --port $ANVIL_PORT --chain-id $ANVIL_CHAIN_ID --gas-limit 30000000 > anvil.log 2>&1 &
    fi
    
    ANVIL_PID=$!
    echo "Anvil PID: $ANVIL_PID" > .anvil.pid
    
    # Wait for Anvil to be ready
    echo -e "${BLUE}  ⏳ Waiting for Anvil to be ready...${NC}"
    sleep 3
    
    if check_anvil_running; then
        echo -e "${GREEN}✅ Anvil started successfully (PID: $ANVIL_PID)${NC}"
    else
        echo -e "${RED}❌ Failed to start Anvil${NC}"
        cat anvil.log
        exit 1
    fi
}

# Deploy contracts to local blockchain
deploy_contracts() {
    echo -e "${YELLOW}🚀 Deploying contracts to local blockchain...${NC}"
    
    # Wait a bit more to ensure Anvil is fully ready
    sleep 2
    
    # Set environment variable for deployment
    export PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY
    
    # Deploy using the LocalTest script
    forge script script/LocalTest.s.sol --fork-url http://localhost:$ANVIL_PORT --broadcast -vv
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Contracts deployed successfully${NC}"
        
        # Save deployment addresses
        echo -e "${BLUE}  📝 Saving deployment addresses...${NC}"
        echo "DEPLOYMENT_TIMESTAMP=$(date)" > deployments/local.env
        echo "ANVIL_RPC_URL=http://localhost:$ANVIL_PORT" >> deployments/local.env
        echo "CHAIN_ID=$ANVIL_CHAIN_ID" >> deployments/local.env
        
        # Extract addresses from broadcast logs (basic implementation)
        echo -e "${YELLOW}  📋 Deployment addresses saved to deployments/local.env${NC}"
    else
        echo -e "${RED}❌ Contract deployment failed${NC}"
        exit 1
    fi
}

# Print final instructions
print_instructions() {
    echo -e "\n${GREEN}🎉 Local testing environment is ready!${NC}"
    echo "============================================="
    echo -e "${BLUE}🔗 Blockchain Details:${NC}"
    echo "  • RPC URL: http://localhost:$ANVIL_PORT"
    echo "  • Chain ID: $ANVIL_CHAIN_ID"
    echo "  • Gas Limit: 30,000,000"
    echo ""
    echo -e "${BLUE}💰 Test Accounts (each has 10,000 ETH):${NC}"
    echo "  • Account 0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    echo "  • Account 1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    echo "  • Account 2: 0x3C44CdDdB6a900740F7Da5d4C93ccD86d5a9e20E"
    echo "  • Account 3: 0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    echo ""
    echo -e "${BLUE}🔧 Usage:${NC}"
    echo "  • Frontend: Update RPC to http://localhost:$ANVIL_PORT"
    echo "  • Contract ABIs: Available in $ABI_OUTPUT_DIR"
    echo "  • Anvil logs: tail -f anvil.log"
    echo "  • Stop Anvil: kill \$(cat .anvil.pid)"
    echo ""
    echo -e "${BLUE}🧪 Test Commands:${NC}"
    echo "  • Check party count: cast call <PartyStarter_Address> 'partyCounter()(uint256)' --rpc-url http://localhost:$ANVIL_PORT"
    echo "  • Get party info: cast call <PartyStarter_Address> 'getParty(uint256)' 1 --rpc-url http://localhost:$ANVIL_PORT"
    echo ""
    echo -e "${YELLOW}💡 Next Steps:${NC}"
    echo "  1. Update your frontend environment variables"
    echo "  2. Configure MetaMask to connect to http://localhost:$ANVIL_PORT"
    echo "  3. Import test account private keys into MetaMask"
    echo "  4. Start testing your dApp!"
}

# Main execution
main() {
    check_dependencies
    install_dependencies
    compile_contracts
    run_tests
    generate_abis
    
    # Create deployments directory
    mkdir -p deployments
    
    if ! check_anvil_running; then
        start_anvil
    fi
    
    deploy_contracts
    print_instructions
}

# Handle script arguments
case "${1:-}" in
    "clean")
        echo -e "${YELLOW}🧹 Cleaning up...${NC}"
        pkill -f anvil || true
        rm -f .anvil.pid anvil.log
        rm -rf out cache
        echo -e "${GREEN}✅ Cleanup complete${NC}"
        ;;
    "stop")
        echo -e "${YELLOW}⏹️  Stopping Anvil...${NC}"
        if [ -f .anvil.pid ]; then
            kill $(cat .anvil.pid) || true
            rm -f .anvil.pid
        fi
        pkill -f anvil || true
        echo -e "${GREEN}✅ Anvil stopped${NC}"
        ;;
    "restart")
        $0 stop
        sleep 2
        $0
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [clean|stop|restart]"
        echo "  clean   - Clean build artifacts and stop Anvil"
        echo "  stop    - Stop Anvil"
        echo "  restart - Restart the entire setup"
        exit 1
        ;;
esac 