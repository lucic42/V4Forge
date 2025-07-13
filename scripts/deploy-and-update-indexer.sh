#!/bin/bash

# Deploy contracts and update indexer configuration
# This script deploys the complete contract suite and updates the indexer config

set -e

echo "🚀 Starting complete deployment and indexer update..."

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    echo "❌ Error: Not in launch-contracts directory"
    echo "Please run this script from the launch-contracts directory"
    exit 1
fi

# Check if Anvil is running
if ! nc -z localhost 8545; then
    echo "❌ Error: Anvil is not running on localhost:8545"
    echo "Please start Anvil first:"
    echo "anvil --fork-url \$MAINNET_RPC_URL"
    exit 1
fi

# Deploy contracts
echo "📦 Deploying contracts..."
forge script script/DeployComplete.s.sol --fork-url http://localhost:8545 --broadcast

# Check if deployment was successful
if [ ! -f "./deployments/local-addresses.json" ]; then
    echo "❌ Error: Deployment failed - addresses file not found"
    exit 1
fi

# Read deployed addresses
echo "📋 Reading deployed addresses..."
POOL_MANAGER=$(jq -r '.poolManager' ./deployments/local-addresses.json)
PARTY_STARTER=$(jq -r '.partyStarter' ./deployments/local-addresses.json)
PARTY_VAULT=$(jq -r '.partyVault' ./deployments/local-addresses.json)
WETH=$(jq -r '.weth' ./deployments/local-addresses.json)

echo "Deployed addresses:"
echo "- PoolManager: $POOL_MANAGER"
echo "- PartyStarter: $PARTY_STARTER"
echo "- PartyVault: $PARTY_VAULT"
echo "- WETH: $WETH"

# Update indexer config
echo "🔧 Updating indexer configuration..."
INDEXER_CONFIG="../launch-v4-indexer/config.yaml"

if [ ! -f "$INDEXER_CONFIG" ]; then
    echo "❌ Error: Indexer config not found at $INDEXER_CONFIG"
    exit 1
fi

# Create backup of original config
cp "$INDEXER_CONFIG" "$INDEXER_CONFIG.backup"

# Use sed to replace placeholder addresses
sed -i.tmp "s/0x0000000000000000000000000000000000000000/$PARTY_STARTER/g" "$INDEXER_CONFIG"

# Fix PoolManager address specifically
sed -i.tmp "/name: PoolManager/,/handler: /{
    s/$PARTY_STARTER/$POOL_MANAGER/
}" "$INDEXER_CONFIG"

# Clean up temp file
rm "$INDEXER_CONFIG.tmp"

echo "✅ Indexer configuration updated successfully"

# Verify the updates
echo "🔍 Verifying configuration updates..."
if grep -q "$PARTY_STARTER" "$INDEXER_CONFIG" && grep -q "$POOL_MANAGER" "$INDEXER_CONFIG"; then
    echo "✅ Configuration verification passed"
else
    echo "❌ Configuration verification failed"
    echo "Restoring backup..."
    mv "$INDEXER_CONFIG.backup" "$INDEXER_CONFIG"
    exit 1
fi

# Clean up backup
rm "$INDEXER_CONFIG.backup"

echo ""
echo "🎉 Deployment and indexer update complete!"
echo ""
echo "Next steps:"
echo "1. cd ../launch-v4-indexer"
echo "2. pnpm codegen  # Generate types from updated config"
echo "3. pnpm dev      # Start the indexer"
echo ""
echo "Your contracts are ready for testing!"
echo "PartyStarter: $PARTY_STARTER"
echo "PoolManager: $POOL_MANAGER" 