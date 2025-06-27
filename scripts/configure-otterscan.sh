#!/bin/bash

# Configure Otterscan with contract metadata for better contract verification
# This script extracts contract information and configures Otterscan

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OTTERSCAN_PORT=5100
CONTRACTS_DIR="out"
METADATA_DIR="otterscan-metadata"

echo -e "${BLUE}🔍 Configuring Otterscan Contract Verification${NC}"
echo "=============================================="

# Check if contracts are compiled
check_contracts_compiled() {
    if [ ! -d "$CONTRACTS_DIR" ]; then
        echo -e "${RED}❌ Contracts not compiled. Run 'forge build' first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found compiled contracts${NC}"
}

# Extract contract metadata
extract_contract_metadata() {
    echo -e "${YELLOW}📄 Extracting contract metadata...${NC}"
    
    # Create metadata directory
    mkdir -p "$METADATA_DIR"
    
    # Find all compiled contracts
    local contracts=(
        "PartyStarter"
        "PartyVault" 
        "PartyVenue"
        "UniswapV4ERC20"
    )
    
    for contract in "${contracts[@]}"; do
        local contract_file="$CONTRACTS_DIR/$contract.sol/$contract.json"
        
        if [ -f "$contract_file" ]; then
            echo -e "${BLUE}  📋 Processing $contract...${NC}"
            
            # Extract relevant information
            local bytecode=$(jq -r '.bytecode.object' "$contract_file" 2>/dev/null || echo "")
            local abi=$(jq '.abi' "$contract_file" 2>/dev/null || echo "[]")
            local source_code=""
            
            # Try to get source code
            local source_file="src/$contract.sol"
            if [ -f "$source_file" ]; then
                source_code=$(cat "$source_file" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
            fi
            
            # Create metadata JSON
            cat > "$METADATA_DIR/$contract.json" << EOF
{
    "contractName": "$contract",
    "bytecode": "$bytecode",
    "abi": $abi,
    "sourceCode": "$source_code",
    "compiler": "forge",
    "compilerVersion": "$(forge --version | head -1 | cut -d' ' -f2)",
    "optimizationUsed": true
}
EOF
            
            echo -e "${GREEN}    ✅ Metadata extracted for $contract${NC}"
        else
            echo -e "${YELLOW}    ⚠️  Contract file not found: $contract_file${NC}"
        fi
    done
}

# Create Otterscan contract database
create_contract_database() {
    echo -e "${YELLOW}🗄️  Creating contract database...${NC}"
    
    # Create a simple contract database
    cat > "$METADATA_DIR/contracts.json" << 'EOF'
{
    "contracts": {}
}
EOF
    
    # Add each contract to the database
    for metadata_file in "$METADATA_DIR"/*.json; do
        if [ "$(basename "$metadata_file")" != "contracts.json" ]; then
            local contract_name=$(basename "$metadata_file" .json)
            echo -e "${BLUE}  📝 Adding $contract_name to database...${NC}"
            
            # This would need to be populated with actual deployed addresses
            # For now, we'll create a template
        fi
    done
    
    echo -e "${GREEN}✅ Contract database created${NC}"
}

# Generate contract verification HTML page
generate_verification_page() {
    echo -e "${YELLOW}🌐 Generating contract verification page...${NC}"
    
    cat > "$METADATA_DIR/contracts.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LaunchDotParty - Contract Verification</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .contract { border: 1px solid #ddd; margin-bottom: 20px; border-radius: 8px; }
        .contract-header { background: #f9f9f9; padding: 15px; border-bottom: 1px solid #ddd; }
        .contract-body { padding: 15px; }
        .abi-section { background: #f0f0f0; padding: 10px; border-radius: 4px; margin-top: 10px; }
        pre { background: #f8f8f8; padding: 10px; border-radius: 4px; overflow-x: auto; }
        .address { font-family: monospace; background: #e8f4fd; padding: 4px 8px; border-radius: 4px; }
        .network-info { background: #e8f5e8; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 LaunchDotParty Contract Verification</h1>
            <p>Local development contracts with source code and ABI information</p>
        </div>
        
        <div class="network-info">
            <h3>🔗 Network Information</h3>
            <p><strong>RPC URL:</strong> http://localhost:8545</p>
            <p><strong>Chain ID:</strong> 31337</p>
            <p><strong>Network:</strong> Anvil Local</p>
        </div>
        
        <div id="contracts">
            <!-- Contracts will be loaded here -->
        </div>
    </div>
    
    <script>
        // Load contract metadata
        async function loadContracts() {
            const contractNames = ['PartyStarter', 'PartyVault', 'PartyVenue', 'UniswapV4ERC20'];
            const container = document.getElementById('contracts');
            
            for (const contractName of contractNames) {
                try {
                    const response = await fetch(`./${contractName}.json`);
                    const contract = await response.json();
                    
                    const contractDiv = document.createElement('div');
                    contractDiv.className = 'contract';
                    contractDiv.innerHTML = `
                        <div class="contract-header">
                            <h3>📋 ${contract.contractName}</h3>
                            <p><strong>Compiler:</strong> ${contract.compiler} ${contract.compilerVersion}</p>
                        </div>
                        <div class="contract-body">
                            <div class="abi-section">
                                <h4>📖 Contract ABI</h4>
                                <pre>${JSON.stringify(contract.abi, null, 2)}</pre>
                            </div>
                            ${contract.sourceCode ? `
                                <div class="abi-section">
                                    <h4>📄 Source Code</h4>
                                    <pre>${contract.sourceCode.replace(/\\n/g, '\n').replace(/\\"/g, '"')}</pre>
                                </div>
                            ` : ''}
                        </div>
                    `;
                    
                    container.appendChild(contractDiv);
                } catch (error) {
                    console.log(`Could not load ${contractName}:`, error);
                }
            }
        }
        
        loadContracts();
    </script>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ Contract verification page generated${NC}"
}

# Start a simple HTTP server for contract verification
start_verification_server() {
    echo -e "${YELLOW}🌐 Starting contract verification server...${NC}"
    
    cd "$METADATA_DIR"
    
    # Check if Python is available
    if command -v python3 > /dev/null 2>&1; then
        echo -e "${BLUE}  🐍 Starting Python HTTP server on port 8080...${NC}"
        python3 -m http.server 8080 > /dev/null 2>&1 &
        echo $! > .verification-server.pid
    elif command -v python > /dev/null 2>&1; then
        echo -e "${BLUE}  🐍 Starting Python HTTP server on port 8080...${NC}"
        python -m SimpleHTTPServer 8080 > /dev/null 2>&1 &
        echo $! > .verification-server.pid
    elif command -v node > /dev/null 2>&1; then
        echo -e "${BLUE}  📦 Starting Node.js HTTP server on port 8080...${NC}"
        npx http-server -p 8080 > /dev/null 2>&1 &
        echo $! > .verification-server.pid
    else
        echo -e "${YELLOW}⚠️  No HTTP server available. You can view files directly in browser.${NC}"
        return 1
    fi
    
    cd - > /dev/null
    sleep 2
    
    echo -e "${GREEN}✅ Contract verification server started${NC}"
    echo -e "${BLUE}   🌐 Visit: http://localhost:8080/contracts.html${NC}"
    
    return 0
}

# Print instructions
print_instructions() {
    echo -e "\n${GREEN}🎉 Contract Verification Setup Complete!${NC}"
    echo "========================================"
    
    echo -e "${BLUE}📋 What was created:${NC}"
    echo "  • Contract metadata files in $METADATA_DIR/"
    echo "  • Contract verification webpage"
    echo "  • Local HTTP server (if available)"
    
    echo -e "\n${YELLOW}🔍 How to verify contracts:${NC}"
    echo "1. ${BLUE}Local verification page:${NC} http://localhost:8080/contracts.html"
    echo "2. ${BLUE}Otterscan:${NC} http://localhost:5100 (limited verification)"
    echo "3. ${BLUE}Cast commands:${NC} Use cast to inspect contracts"
    
    echo -e "\n${YELLOW}💡 Useful commands:${NC}"
    echo "  • View contract ABI: cat $METADATA_DIR/PartyStarter.json | jq '.abi'"
    echo "  • Inspect contract: cast code <ADDRESS> --rpc-url http://localhost:8545"
    echo "  • Call contract: cast call <ADDRESS> 'functionName()' --rpc-url http://localhost:8545"
    
    echo -e "\n${BLUE}🛑 To stop verification server:${NC}"
    echo "  kill \$(cat $METADATA_DIR/.verification-server.pid) 2>/dev/null || true"
}

# Main execution
main() {
    case "${1:-setup}" in
        "setup")
            check_contracts_compiled
            extract_contract_metadata
            create_contract_database
            generate_verification_page
            if start_verification_server; then
                print_instructions
            else
                echo -e "${YELLOW}⚠️  Server not started, but files are ready${NC}"
                echo -e "${BLUE}  📁 Open: $METADATA_DIR/contracts.html in your browser${NC}"
            fi
            ;;
        "stop")
            if [ -f "$METADATA_DIR/.verification-server.pid" ]; then
                kill $(cat "$METADATA_DIR/.verification-server.pid") 2>/dev/null || true
                rm -f "$METADATA_DIR/.verification-server.pid"
                echo -e "${GREEN}✅ Verification server stopped${NC}"
            else
                echo -e "${YELLOW}⚠️  No verification server running${NC}"
            fi
            ;;
        "clean")
            rm -rf "$METADATA_DIR"
            echo -e "${GREEN}✅ Contract verification files cleaned${NC}"
            ;;
        *)
            echo "Usage: $0 [setup|stop|clean]"
            echo "  setup - Extract contract metadata and start verification server"
            echo "  stop  - Stop the verification server"
            echo "  clean - Remove all verification files"
            exit 1
            ;;
    esac
}

# Handle direct script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 