#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define source and destination directories
OUT_DIR="./out"
DEST_DIR="/Users/lukesteimel/Desktop/launchdotparty/apps/frontend/src/contracts"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq to run this script."
    exit 1
fi

# Function to copy ABI
copy_abi() {
    local contract_name=$1
    local contract_path=$2
    local source_file="$OUT_DIR/$contract_path/$contract_name.json"
    local dest_file="$DEST_DIR/$contract_name.abi.json"

    if [ -f "$source_file" ]; then
        echo "Copying $contract_name ABI to $dest_file"
        cat "$source_file" | jq '.abi' > "$dest_file"
    else
        echo "Error: $source_file not found. Did you run 'forge build' first?"
        exit 1
    fi
}

# Copy ABIs
copy_abi "PartyStarterV2" "PartyStarterV2.sol"
copy_abi "PublicPartyVenue" "PublicPartyVenue.sol"

echo "✅ ABIs copied successfully!" 