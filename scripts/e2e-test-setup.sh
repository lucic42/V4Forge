#!/bin/bash

# E2E Test Setup Script
# Funds wallets and prepares the environment for comprehensive testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ANVIL_RPC="http://localhost:8545"
DEPLOYER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEPLOYER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# Test wallet configuration (20 wallets with private keys)
declare -a TEST_WALLETS=(
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8:0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    "0x3C44CdDdB6a900740F7Da5d4C93ccD86d5a9e20E:0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906:0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
    "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65:0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
    "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc:0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
    "0x976EA74026E726554dB657fA54763abd0C3a0aa9:0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
    "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955:0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
    "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f:0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97"
    "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720:0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"
    "0xBcd4042DE499D14e55001CcbB24a551F3b954096:0xf214f2b2cd398c806f84e317254e0f0b801d0643303237d97a22a48e01628897"
    "0x71bE63f3384f5fb98995898A86B02Fb2426c5788:0x701b615bbdfb9de65240bc28bd21bbc0d996645a3dd57e7b12bc2bdf6f192c82"
    "0xFABB0ac9d68B0B445fB7357272Ff202C5651694a:0xa267530f49f8280200edf313ee57ce75b4fa1b7134a5b3a3a9e1a3b8e6b7b8e0"
    "0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec:0x47c99abed3324a2707c28affff1267e45918ec8c3f20b8aa892e8b065d2942dd"
    "0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097:0xc526ee95bf44d8fc405a158bb884d9d1238d99f0612e9f33d006bb0789009aaa"
    "0xcd3B766CCDd6AE721141F452C550Ca635964ce71:0x8166f546bab6da521a8369cab06c5d2b74a01e0d0b2b62b9b7fad8d1d2c8f7a3"
    "0x2546BcD3c84621e976D8185a91A922aE77ECEc30:0xea6c44ac03bff858b476bba40716402b03e41b8e97e276d1baec7c37d42484a0"
    "0xbDA5747bFD65F08deb54cb465eB87D40e51B197E:0x689af8efa8c651a91ad287602527f3af2fe9f6501a7ac4b061667b5a93e037fd"
    "0xdD2FD4581271e230360230F9337D5c0430Bf44C0:0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0"
    "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199:0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e"
    "0x09DB0a93B389bE7E02d896b9b962b1B2abE0Cd8D:0x0e64bb1a17c2bbdf7c1c7d7b4e09b1c39e0d4e0a8b1f8b5b7c9e8f5e0a2f3e4d"
)

FUNDING_AMOUNT="10" # ETH per wallet

# Functions
show_help() {
    echo -e "${BLUE}🧪 E2E Test Setup for LaunchDotParty${NC}"
    echo "============================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  setup      Fund wallets and prepare environment"
    echo "  fund       Fund test wallets only"
    echo "  status     Check wallet balances"
    echo "  clean      Reset wallet balances"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --amount <ETH>    Amount to fund each wallet (default: 10 ETH)"
    echo "  --rpc <URL>       RPC URL (default: http://localhost:8545)"
    echo ""
}

check_anvil_running() {
    if ! cast chain-id --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
        echo -e "${RED}❌ Anvil is not running on $ANVIL_RPC${NC}"
        echo -e "${YELLOW}💡 Start Anvil first: ./dev.sh start${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Anvil is running${NC}"
}

fund_wallets() {
    echo -e "${YELLOW}💰 Funding test wallets...${NC}"
    
    local funded_count=0
    local total_wallets=${#TEST_WALLETS[@]}
    
    for wallet_info in "${TEST_WALLETS[@]}"; do
        local address=$(echo "$wallet_info" | cut -d':' -f1)
        
        echo -e "${BLUE}  📤 Funding $address with $FUNDING_AMOUNT ETH...${NC}"
        
        # Fund the wallet
        cast send --private-key "$DEPLOYER_PRIVATE_KEY" \
            --rpc-url "$ANVIL_RPC" \
            --value "${FUNDING_AMOUNT}ether" \
            "$address" \
            >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            funded_count=$((funded_count + 1))
            echo -e "${GREEN}    ✅ Funded successfully${NC}"
        else
            echo -e "${RED}    ❌ Failed to fund${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Funded $funded_count/$total_wallets wallets${NC}"
}

check_wallet_balances() {
    echo -e "${YELLOW}📊 Checking wallet balances...${NC}"
    
    local total_balance=0
    local wallet_count=0
    
    for wallet_info in "${TEST_WALLETS[@]}"; do
        local address=$(echo "$wallet_info" | cut -d':' -f1)
        local balance=$(cast balance "$address" --rpc-url "$ANVIL_RPC" 2>/dev/null || echo "0")
        local balance_eth=$(cast to-unit "$balance" ether 2>/dev/null || echo "0.0")
        
        printf "  %s: %s ETH\n" "$address" "$balance_eth"
        
        # Add to total (basic addition)
        total_balance=$(echo "$total_balance + $balance_eth" | bc -l 2>/dev/null || echo "$total_balance")
        wallet_count=$((wallet_count + 1))
    done
    
    echo -e "${BLUE}📈 Total across $wallet_count wallets: $total_balance ETH${NC}"
}

save_wallet_config() {
    echo -e "${YELLOW}💾 Saving wallet configuration...${NC}"
    
    local config_file="e2e-wallets.env"
    
    cat > "$config_file" << EOF
# E2E Test Wallet Configuration
# Generated on $(date)

ANVIL_RPC="$ANVIL_RPC"
FUNDING_AMOUNT="$FUNDING_AMOUNT"

# Test Wallets (ADDRESS:PRIVATE_KEY)
TEST_WALLETS=(
EOF
    
    for wallet_info in "${TEST_WALLETS[@]}"; do
        echo "    \"$wallet_info\"" >> "$config_file"
    done
    
    cat >> "$config_file" << EOF
)

# Quick access arrays
TEST_ADDRESSES=(
EOF
    
    for wallet_info in "${TEST_WALLETS[@]}"; do
        local address=$(echo "$wallet_info" | cut -d':' -f1)
        echo "    \"$address\"" >> "$config_file"
    done
    
    cat >> "$config_file" << EOF
)

TEST_PRIVATE_KEYS=(
EOF
    
    for wallet_info in "${TEST_WALLETS[@]}"; do
        local private_key=$(echo "$wallet_info" | cut -d':' -f2)
        echo "    \"$private_key\"" >> "$config_file"
    done
    
    echo ")" >> "$config_file"
    
    echo -e "${GREEN}✅ Configuration saved to $config_file${NC}"
}

create_test_metadata() {
    echo -e "${YELLOW}📋 Creating test metadata templates...${NC}"
    
    mkdir -p e2e-test-data
    
    # Create various test metadata files
    cat > e2e-test-data/instant-metadata.json << EOF
{
    "name": "InstantTestToken",
    "symbol": "ITT",
    "description": "Test token for instant party e2e testing",
    "image": "https://example.com/instant-token.png",
    "website": "https://instant-test.com",
    "twitter": "https://twitter.com/instanttest",
    "telegram": "https://t.me/instanttest"
}
EOF
    
    cat > e2e-test-data/public-metadata.json << EOF
{
    "name": "PublicTestToken",
    "symbol": "PTT",
    "description": "Test token for public party e2e testing",
    "image": "https://example.com/public-token.png",
    "website": "https://public-test.com",
    "twitter": "https://twitter.com/publictest",
    "telegram": "https://t.me/publictest"
}
EOF
    
    cat > e2e-test-data/private-metadata.json << EOF
{
    "name": "PrivateTestToken",
    "symbol": "PRIV",
    "description": "Test token for private party e2e testing",
    "image": "https://example.com/private-token.png",
    "website": "https://private-test.com",
    "twitter": "https://twitter.com/privatetest",
    "telegram": "https://t.me/privatetest"
}
EOF
    
    echo -e "${GREEN}✅ Test metadata created in e2e-test-data/${NC}"
}

clean_wallets() {
    echo -e "${YELLOW}🧹 Cleaning wallet balances...${NC}"
    
    for wallet_info in "${TEST_WALLETS[@]}"; do
        local address=$(echo "$wallet_info" | cut -d':' -f1)
        local private_key=$(echo "$wallet_info" | cut -d':' -f2)
        
        # Get current balance
        local balance=$(cast balance "$address" --rpc-url "$ANVIL_RPC" 2>/dev/null || echo "0")
        
        if [ "$balance" != "0" ]; then
            echo -e "${BLUE}  🧹 Draining $address...${NC}"
            
            # Send all ETH back to deployer (minus gas)
            cast send --private-key "$private_key" \
                --rpc-url "$ANVIL_RPC" \
                --value "$balance" \
                "$DEPLOYER_ADDRESS" \
                >/dev/null 2>&1 || true
        fi
    done
    
    echo -e "${GREEN}✅ Wallet cleanup completed${NC}"
}

# Main execution
main() {
    local command="${1:-help}"
    shift || true
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --amount)
                FUNDING_AMOUNT="$2"
                shift 2
                ;;
            --rpc)
                ANVIL_RPC="$2"
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
        "setup")
            check_anvil_running
            fund_wallets
            save_wallet_config
            create_test_metadata
            check_wallet_balances
            echo -e "\n${GREEN}🎉 E2E test environment is ready!${NC}"
            echo -e "${BLUE}💡 Next steps:${NC}"
            echo "  1. Run: ./e2e-test-instant.sh"
            echo "  2. Run: ./e2e-test-public.sh" 
            echo "  3. Run: ./e2e-test-private.sh"
            ;;
        "fund")
            check_anvil_running
            fund_wallets
            ;;
        "status")
            check_anvil_running
            check_wallet_balances
            ;;
        "clean")
            check_anvil_running
            clean_wallets
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

# Run main function
main "$@" 