#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Local Deployment Process..."

# Check if Anvil is already running
if ! curl -s http://localhost:8545 > /dev/null 2>&1; then
    echo "📡 Starting Anvil..."
    anvil --port 8545 --host 0.0.0.0 &
    ANVIL_PID=$!
    
    # Wait for Anvil to start
    echo "⏳ Waiting for Anvil to start..."
    sleep 3
    
    # Check if Anvil is running
    if ! curl -s http://localhost:8545 > /dev/null 2>&1; then
        echo "❌ Failed to start Anvil"
        exit 1
    fi
    
    echo "✅ Anvil started successfully"
else
    echo "✅ Anvil is already running"
fi

# Deploy contracts
echo "📦 Deploying contracts..."
forge script scripts/DeployLocal.s.sol:DeployLocal \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Build contracts to generate ABIs
echo "🔨 Building contracts..."
forge build

# Copy ABIs to frontend
echo "📋 Copying ABIs to frontend..."
if [ -f "./scripts/copy-abis.sh" ]; then
    ./scripts/copy-abis.sh
else
    echo "⚠️  ABI copy script not found, skipping..."
fi

# Extract deployment addresses
echo "📝 Extracting deployment addresses..."
if [ -f "broadcast/DeployLocal.s.sol/31337/run-latest.json" ]; then
    echo "🎯 Deployment addresses can be found in:"
    echo "   broadcast/DeployLocal.s.sol/31337/run-latest.json"
    
    # Create a simple addresses file for easy access
    ADDRESSES_FILE="/Users/lukesteimel/Desktop/launchdotparty/apps/frontend/src/contracts/addresses.json"
    mkdir -p "$(dirname "$ADDRESSES_FILE")"
    
    echo '{
  "WETH9": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  "Factory": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  "PositionManager": "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  "PartyStarterV2": "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
  "TestPartyVenue": "0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81"
}' > "$ADDRESSES_FILE"
    
    echo "📍 Contract addresses saved to: $ADDRESSES_FILE"
fi

echo ""
echo "🎉 Local deployment complete!"
echo ""
echo "📋 Summary:"
echo "  - Anvil running on: http://localhost:8545"
echo "  - WETH9: 0x5FbDB2315678afecb367f032d93F642f64180aa3"
echo "  - Factory: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
echo "  - Position Manager: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
echo "  - PartyStarterV2: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
echo "  - Test Party Venue: 0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81"
echo ""
echo "🔧 To interact with contracts, use:"
echo "  - RPC URL: http://localhost:8545"
echo "  - Chain ID: 31337"
echo "  - Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo ""
echo "⚠️  Remember: These are test addresses and will change on each deployment!" 