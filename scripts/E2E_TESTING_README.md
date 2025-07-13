# E2E Testing Scripts for LaunchDotParty

This directory contains comprehensive end-to-end testing scripts for the LaunchDotParty protocol, designed to test your indexer and backend on local Anvil network.

## 🚀 Quick Start

```bash
# 1. Start your development environment
./dev.sh start --deploy

# 2. Run complete e2e test suite
./scripts/e2e-test-all.sh full

# 3. Check results
./scripts/e2e-test-all.sh status
```

## 📁 Script Overview

### Core Scripts

| Script | Purpose |
|--------|---------|
| `e2e-test-setup.sh` | Fund wallets and prepare test environment |
| `e2e-test-instant.sh` | Test instant party creation and launch |
| `e2e-test-public.sh` | Test public party venues with contributions |
| `e2e-test-private.sh` | Test private party venues with signatures |
| `e2e-signature-utils.sh` | Generate authorization signatures for private parties |
| `e2e-test-all.sh` | Main orchestrator script |

### Utility Scripts

- `e2e-test-setup.sh` - Environment setup and wallet funding
- `e2e-signature-utils.sh` - Signature generation utilities

## 🧪 Test Types

### 1. Instant Parties
- Creates tokens with immediate deployment
- Tests direct ETH → deployed token flow
- Default: 5 parties with 2 ETH each

```bash
./scripts/e2e-test-instant.sh --count 10 --amount 1
```

### 2. Public Parties
- Creates venue contracts for public contributions
- Anyone can contribute until target reached
- Default: 3 parties, 5 ETH target, 8 contributors

```bash
./scripts/e2e-test-public.sh --count 5 --target 10 --contributors 5
```

### 3. Private Parties
- Creates venue contracts with signature authorization
- Only authorized wallets can contribute
- Uses EIP-191 message signing for authorization
- Default: 2 parties, 3 ETH target, 5 authorized contributors

```bash
./scripts/e2e-test-private.sh --count 3 --contributors 8
```

## 🔧 Configuration

### Wallet Setup
- **20 pre-configured test wallets** with private keys
- Each wallet funded with 10 ETH by default
- Configuration saved in `e2e-wallets.env`

### Test Parameters
- **Instant Count**: Number of instant parties to create
- **Public/Private Count**: Number of venue-based parties
- **Target ETH**: Target liquidity for venue parties
- **Contribution ETH**: Individual contribution amounts
- **Contributors**: Number of contributors per party

## 🎯 Usage Examples

### Run Full Test Suite
```bash
# Complete test with custom parameters
./scripts/e2e-test-all.sh full \
  --instant-count 8 \
  --public-count 4 \
  --private-count 3 \
  --target 8 \
  --contribution 2
```

### Individual Test Types
```bash
# Only instant parties
./scripts/e2e-test-all.sh instant --instant-count 10

# Only public parties
./scripts/e2e-test-all.sh public --public-count 5 --target 10

# Only private parties
./scripts/e2e-test-all.sh private --private-count 3
```

### Environment Management
```bash
# Setup environment only
./scripts/e2e-test-all.sh setup

# Check current status
./scripts/e2e-test-all.sh status

# Fund wallets with custom amount
./scripts/e2e-test-setup.sh fund --amount 5
```

## 🔐 Private Party Authorization

Private parties use signature-based authorization:

### Generate Signatures
```bash
# Single signature
./scripts/e2e-signature-utils.sh generate-signature \
  --party-id 1 \
  --contributor 0x742d35Cc6589C4532CE8b06cfE4c4C6F \
  --max-amount 5 \
  --signer-key 0x...

# Batch signatures
./scripts/e2e-signature-utils.sh generate-batch \
  --party-id 1 \
  --max-amount 5 \
  --signer-key 0x...
```

### Signature Format
Uses EIP-191 message format:
```
keccak256(abi.encodePacked(
  "\x19Ethereum Signed Message:\n32",
  keccak256(abi.encodePacked(partyId, contributor, maxAmount, deadline))
))
```

## 📊 Output and Logs

### Generated Files
- `e2e-wallets.env` - Wallet configuration
- `instant-parties-YYYYMMDD-HHMMSS.log` - Instant party results
- `public-parties-YYYYMMDD-HHMMSS.log` - Public party results  
- `private-parties-YYYYMMDD-HHMMSS.log` - Private party results

### Log Format
```
# PartyID:Creator:Amount/Target:Status:Timestamp
1:0x742d35Cc6589C4532CE8b06cfE4c4C6F:2:Launched:1703875200
```

## 🎛️ Advanced Options

### Parallel Execution
```bash
# Run instant tests in parallel (faster)
./scripts/e2e-test-instant.sh --parallel

# Full suite with parallel instant tests
./scripts/e2e-test-all.sh full --parallel
```

### Custom Signer for Private Parties
```bash
./scripts/e2e-test-private.sh \
  --signer-key 0x1234... \
  --deadline 7200  # 2 hours
```

### Cleanup
```bash
# Clean up test artifacts
./scripts/e2e-test-all.sh full --cleanup

# Individual cleanup
./scripts/e2e-test-instant.sh --cleanup
```

## 🔍 Debugging

### Check Prerequisites
```bash
./scripts/e2e-test-all.sh status
```

### Verify Contract Deployment
```bash
cast call $PARTY_STARTER_ADDRESS "partyCounter()" --rpc-url http://localhost:8545
```

### Check Wallet Balances
```bash
./scripts/e2e-test-setup.sh status
```

### Test Individual Components
```bash
# Test signature generation
./scripts/e2e-signature-utils.sh generate-signature \
  --party-id 1 \
  --contributor 0x... \
  --max-amount 1 \
  --signer-key 0x...

# Verify signature
./scripts/e2e-signature-utils.sh verify-signature \
  --party-id 1 \
  --contributor 0x... \
  --max-amount 1 \
  --signature 0x... \
  --expected-signer 0x...
```

## 📋 Prerequisites

### Required Tools
- **Foundry** (forge, cast, anvil)
- **jq** for JSON parsing
- **bc** for arithmetic operations (for balance calculations)

### Environment Setup
1. Anvil running on `http://localhost:8545`
2. Contracts deployed to local network
3. Sufficient ETH in deployer wallet

### Installation
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install jq (macOS)
brew install jq

# Install jq (Ubuntu)
sudo apt-get install jq
```

## 🎯 Integration Points

These scripts are designed to test:

### Indexer Integration
- Event emissions from party creation
- Contribution tracking
- Launch status updates
- Token deployment events

### Backend API Testing
- Party data persistence
- Real-time updates
- Contribution aggregation
- User wallet tracking

### Expected Events
- `PartyCreated` - Party creation
- `ContributionReceived` - Individual contributions
- `PartyLaunched` - Successful launches
- `TokenDeployed` - Token contract deployment

## 🐛 Troubleshooting

### Common Issues

**"Anvil not running"**
```bash
./dev.sh start
```

**"Contracts not deployed"**
```bash
./dev.sh deploy
```

**"Insufficient funds"**
```bash
./scripts/e2e-test-setup.sh fund --amount 10
```

**"Signature generation failed"**
- Check signer private key format
- Verify party ID exists
- Ensure contributor address is valid

### Performance Tips
- Use `--parallel` for faster instant party tests
- Reduce counts for quicker testing during development
- Use `--no-setup` to skip environment setup if already configured

## 📈 Extending the Tests

### Adding New Test Types
1. Create new script following naming pattern: `e2e-test-<type>.sh`
2. Add to `e2e-test-all.sh` orchestrator
3. Update this README

### Custom Test Scenarios
- Modify contribution amounts and patterns
- Add edge cases (zero contributions, over-funding)
- Test different signature expiration times
- Add stress testing with higher counts

---

For questions or issues, refer to the main project documentation or check the individual script help:
```bash
./scripts/e2e-test-all.sh --help
``` 