#!/bin/bash

# Extract deployed contract addresses from forge broadcast logs
# This script parses the broadcast logs to get actual deployment addresses

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BROADCAST_DIR="broadcast"
METADATA_DIR="otterscan-metadata"
CHAIN_ID="31337"

echo -e "${BLUE}📋 Extracting Deployed Contract Addresses${NC}"
echo "=========================================="

# Find the latest broadcast run
find_latest_broadcast() {
    local latest_run=""
    local broadcast_path="$BROADCAST_DIR/LocalTest.s.sol/$CHAIN_ID"
    
    if [ -d "$broadcast_path" ]; then
        # Find the latest run directory
        latest_run=$(ls -t "$broadcast_path" | grep "run-" | head -1)
        
        if [ -n "$latest_run" ]; then
            echo "$broadcast_path/$latest_run"
            return 0
        fi
    fi
    
    echo ""
    return 1
}

# Extract addresses from broadcast JSON
extract_addresses() {
    local broadcast_run="$1"
    local run_latest="$broadcast_run/run-latest.json"
    
    if [ ! -f "$run_latest" ]; then
        echo -e "${RED}❌ No deployment broadcast found at $run_latest${NC}"
        return 1
    fi
    
    echo -e "${BLUE}  📄 Reading deployment data from $run_latest${NC}"
    
    # Create addresses file
    cat > "$METADATA_DIR/addresses.json" << 'EOF'
{
    "network": "local",
    "chainId": 31337,
    "contracts": {},
    "deploymentTimestamp": "",
    "deploymentBlock": 0
}
EOF
    
    # Extract deployment timestamp and block
    local timestamp=$(jq -r '.timestamp' "$run_latest" 2>/dev/null || echo "$(date +%s)")
    local start_block=$(jq -r '.transactions[0].receipt.blockNumber' "$run_latest" 2>/dev/null || echo "0")
    
    # Update metadata
    jq --arg ts "$timestamp" --argjson block "$start_block" \
       '.deploymentTimestamp = $ts | .deploymentBlock = $block' \
       "$METADATA_DIR/addresses.json" > "$METADATA_DIR/addresses.tmp" && \
       mv "$METADATA_DIR/addresses.tmp" "$METADATA_DIR/addresses.json"
    
    # Extract contract addresses
    local contracts_found=false
    
    # Look for contract creation transactions
    while IFS= read -r line; do
        local contract_name=$(echo "$line" | jq -r '.contractName' 2>/dev/null || echo "")
        local contract_address=$(echo "$line" | jq -r '.contractAddress' 2>/dev/null || echo "")
        
        if [ "$contract_name" != "null" ] && [ "$contract_name" != "" ] && \
           [ "$contract_address" != "null" ] && [ "$contract_address" != "" ]; then
            
            echo -e "${GREEN}  ✅ Found $contract_name at $contract_address${NC}"
            
            # Add to addresses.json
            jq --arg name "$contract_name" --arg addr "$contract_address" \
               '.contracts[$name] = $addr' \
               "$METADATA_DIR/addresses.json" > "$METADATA_DIR/addresses.tmp" && \
               mv "$METADATA_DIR/addresses.tmp" "$METADATA_DIR/addresses.json"
            
            contracts_found=true
        fi
    done < <(jq -c '.transactions[]? | select(.transactionType == "CREATE")' "$run_latest" 2>/dev/null || echo "")
    
    if [ "$contracts_found" = false ]; then
        echo -e "${YELLOW}⚠️  No contract deployments found in broadcast logs${NC}"
        echo -e "${BLUE}  💡 Make sure contracts are deployed with --broadcast flag${NC}"
        return 1
    fi
    
    return 0
}

# Update contract metadata with addresses
update_contract_metadata() {
    echo -e "${YELLOW}🔄 Updating contract metadata with addresses...${NC}"
    
    if [ ! -f "$METADATA_DIR/addresses.json" ]; then
        echo -e "${RED}❌ No addresses found. Extract addresses first.${NC}"
        return 1
    fi
    
    # Read addresses
    while IFS= read -r contract_entry; do
        local name=$(echo "$contract_entry" | jq -r '.key')
        local address=$(echo "$contract_entry" | jq -r '.value')
        
        if [ -f "$METADATA_DIR/$name.json" ]; then
            echo -e "${BLUE}  📝 Adding address to $name metadata...${NC}"
            
            # Add address to contract metadata
            jq --arg addr "$address" '.address = $addr' \
               "$METADATA_DIR/$name.json" > "$METADATA_DIR/$name.tmp" && \
               mv "$METADATA_DIR/$name.tmp" "$METADATA_DIR/$name.json"
        fi
    done < <(jq -r '.contracts | to_entries[] | {key: .key, value: .value}' "$METADATA_DIR/addresses.json" 2>/dev/null)
    
    echo -e "${GREEN}✅ Contract metadata updated with addresses${NC}"
}

# Create a summary page with all addresses
create_address_summary() {
    echo -e "${YELLOW}📄 Creating address summary...${NC}"
    
    cat > "$METADATA_DIR/addresses.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LaunchDotParty - Deployed Contracts</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .contract { background: #f9f9f9; padding: 15px; margin-bottom: 15px; border-radius: 8px; border-left: 4px solid #007cba; }
        .address { font-family: monospace; background: #e8f4fd; padding: 8px 12px; border-radius: 4px; word-break: break-all; }
        .network-info { background: #e8f5e8; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
        .copy-btn { background: #007cba; color: white; border: none; padding: 5px 10px; border-radius: 4px; cursor: pointer; margin-left: 10px; }
        .copy-btn:hover { background: #005a87; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📋 LaunchDotParty Deployed Contracts</h1>
            <p>Contract addresses for your local development environment</p>
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
        
        <div style="margin-top: 30px; padding: 15px; background: #f0f8ff; border-radius: 8px;">
            <h3>🛠️ Useful Commands</h3>
            <pre style="background: #f8f8f8; padding: 10px; border-radius: 4px;">
# Check contract code
cast code &lt;ADDRESS&gt; --rpc-url http://localhost:8545

# Call a view function
cast call &lt;ADDRESS&gt; "functionName()" --rpc-url http://localhost:8545

# Send a transaction
cast send &lt;ADDRESS&gt; "functionName()" --private-key &lt;KEY&gt; --rpc-url http://localhost:8545
            </pre>
        </div>
    </div>
    
    <script>
        async function loadAddresses() {
            try {
                const response = await fetch('./addresses.json');
                const data = await response.json();
                const container = document.getElementById('contracts');
                
                Object.entries(data.contracts).forEach(([name, address]) => {
                    const contractDiv = document.createElement('div');
                    contractDiv.className = 'contract';
                    contractDiv.innerHTML = `
                        <h3>📋 ${name}</h3>
                        <div class="address">
                            ${address}
                            <button class="copy-btn" onclick="copyToClipboard('${address}')">Copy</button>
                        </div>
                        <p style="margin-top: 10px;">
                            <a href="http://localhost:5100/address/${address}" target="_blank">View on Otterscan</a>
                        </p>
                    `;
                    container.appendChild(contractDiv);
                });
                
                // Add deployment info
                if (data.deploymentTimestamp) {
                    const date = new Date(parseInt(data.deploymentTimestamp) * 1000);
                    const infoDiv = document.createElement('div');
                    infoDiv.style.marginTop = '20px';
                    infoDiv.style.padding = '15px';
                    infoDiv.style.background = '#fff3cd';
                    infoDiv.style.borderRadius = '8px';
                    infoDiv.innerHTML = `
                        <h4>📅 Deployment Info</h4>
                        <p><strong>Deployed:</strong> ${date.toLocaleString()}</p>
                        <p><strong>Starting Block:</strong> ${data.deploymentBlock}</p>
                    `;
                    container.appendChild(infoDiv);
                }
            } catch (error) {
                document.getElementById('contracts').innerHTML = '<p>❌ Could not load contract addresses</p>';
                console.error('Error loading addresses:', error);
            }
        }
        
        function copyToClipboard(text) {
            navigator.clipboard.writeText(text).then(() => {
                // Simple feedback
                event.target.textContent = 'Copied!';
                setTimeout(() => {
                    event.target.textContent = 'Copy';
                }, 2000);
            });
        }
        
        loadAddresses();
    </script>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ Address summary created${NC}"
}

# Print extracted addresses
print_addresses() {
    if [ -f "$METADATA_DIR/addresses.json" ]; then
        echo -e "\n${GREEN}🎉 Contract Addresses Extracted!${NC}"
        echo "================================="
        
        echo -e "${BLUE}📋 Deployed Contracts:${NC}"
        jq -r '.contracts | to_entries[] | "  • \(.key): \(.value)"' "$METADATA_DIR/addresses.json" 2>/dev/null
        
        echo -e "\n${YELLOW}🔗 View Addresses:${NC}"
        echo "  • Summary page: http://localhost:8080/addresses.html"
        echo "  • JSON file: $METADATA_DIR/addresses.json"
        
        echo -e "\n${YELLOW}💡 Next steps:${NC}"
        echo "  • Use './scripts/dev.sh verify' to setup contract verification"
        echo "  • View contracts on Otterscan: http://localhost:5100"
    else
        echo -e "${RED}❌ No addresses extracted${NC}"
    fi
}

# Main execution
main() {
    case "${1:-extract}" in
        "extract")
            # Ensure metadata directory exists
            mkdir -p "$METADATA_DIR"
            
            # Find and process broadcast logs
            local broadcast_run=$(find_latest_broadcast)
            if [ -n "$broadcast_run" ]; then
                echo -e "${GREEN}✅ Found broadcast run: $broadcast_run${NC}"
                if extract_addresses "$broadcast_run"; then
                    update_contract_metadata
                    create_address_summary
                    print_addresses
                else
                    echo -e "${RED}❌ Failed to extract addresses${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}❌ No deployment broadcast found${NC}"
                echo -e "${BLUE}💡 Deploy contracts first with: ./scripts/dev.sh deploy${NC}"
                exit 1
            fi
            ;;
        "clean")
            rm -f "$METADATA_DIR/addresses.json" "$METADATA_DIR/addresses.html"
            echo -e "${GREEN}✅ Address files cleaned${NC}"
            ;;
        *)
            echo "Usage: $0 [extract|clean]"
            echo "  extract - Extract addresses from deployment broadcasts"
            echo "  clean   - Remove extracted address files"
            exit 1
            ;;
    esac
}

# Handle direct script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 