# LaunchDotParty Development Scripts

This directory contains scripts to manage your local development environment for LaunchDotParty.

## Quick Start

The simplest way to get started is with the `dev.sh` script:

```bash
# Start everything (Anvil + Otterscan)
./scripts/dev.sh start

# Start with contracts deployed
./scripts/dev.sh start --deploy

# Check status
./scripts/dev.sh status

# Stop everything
./scripts/dev.sh stop
```

## Available Scripts

### 🚀 `dev.sh` - Main Development Manager

The primary script for managing your development environment.

```bash
./scripts/dev.sh <command> [options]
```

**Commands:**
- `start` - Start Anvil blockchain and Otterscan block explorer
- `stop` - Stop all services
- `restart` - Restart all services  
- `status` - Check what's running
- `deploy` - Deploy contracts to running Anvil
- `verify` - Setup contract verification with source code
- `logs` - Show Anvil logs
- `clean` - Stop services and clean all artifacts

**Start Options:**
- `--deploy` - Deploy contracts after starting services
- `--no-otterscan` - Skip starting the block explorer

**Examples:**
```bash
./scripts/dev.sh start                    # Basic start
./scripts/dev.sh start --deploy          # Start + deploy contracts
./scripts/dev.sh start --no-otterscan    # Start without block explorer
./scripts/dev.sh restart --deploy        # Restart + redeploy
```

### 🔧 `start-dev-environment.sh` - Environment Starter

Starts both Anvil blockchain and Otterscan block explorer.

```bash
./scripts/start-dev-environment.sh [OPTIONS]
```

**Features:**
- ✅ Starts Anvil on port 8545 (chain ID 31337)
- ✅ Starts Otterscan on port 5100 (if Docker available)
- ✅ Checks for port conflicts
- ✅ Validates services are running
- ✅ Optional contract deployment

### 🛑 `stop-dev-environment.sh` - Environment Stopper

Cleanly stops all development services.

```bash
./scripts/stop-dev-environment.sh [OPTIONS]
```

**Features:**
- ✅ Stops Anvil blockchain
- ✅ Stops Otterscan Docker container  
- ✅ Cleans up PID files and logs
- ✅ Force stop option (`--force`)

### 📋 `setup-local-testing.sh` - Complete Setup

The original comprehensive setup script that includes contract compilation, testing, and deployment.

```bash
./scripts/setup-local-testing.sh [clean|stop|restart]
```

## Service Details

### Anvil Blockchain
- **URL:** http://localhost:8545
- **Chain ID:** 31337
- **Gas Limit:** 30,000,000 
- **Pre-funded Accounts:** 10 accounts with 10,000 ETH each

### Otterscan Block Explorer
- **URL:** http://localhost:5100
- **Requirements:** Docker must be running
- **Configuration:** Set RPC to `http://127.0.0.1:8545`, Chain ID to `31337`

### Contract Verification
- **Verification Page:** http://localhost:8080/contracts.html
- **Address Summary:** http://localhost:8080/addresses.html
- **Features:** Source code, ABI, deployed addresses
- **Auto-generated:** After deployment with `--deploy` flag

### Test Accounts

The following accounts are pre-funded with 10,000 ETH:

```
Account 0:
Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Account 1:  
Address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

## Troubleshooting

### Port Already in Use
If you get port conflicts:
```bash
# Check what's using the ports
lsof -i :8545  # Anvil
lsof -i :5100  # Otterscan

# Force stop everything
./scripts/dev.sh stop --force
```

### Docker Issues
If Otterscan won't start:
```bash
# Check Docker status
docker info

# Start Docker Desktop and try again
./scripts/dev.sh start --no-otterscan  # Skip Otterscan if needed
```

### Contract Deployment Fails
```bash
# Check Anvil is running
./scripts/dev.sh status

# Check logs for errors
./scripts/dev.sh logs

# Try deploying manually
./scripts/dev.sh deploy
```

### Clean Start
If things get messy:
```bash
# Nuclear option - clean everything
./scripts/dev.sh clean
./scripts/dev.sh start --deploy
```

## Integration with Frontend

The scripts automatically generate ABIs for frontend integration in `../launch-frontend/src/contracts/`.

Your frontend should connect to:
- **RPC URL:** `http://localhost:8545`
- **Chain ID:** `31337`

## File Structure

```
scripts/
├── README.md                    # This file
├── dev.sh                      # Main development manager
├── start-dev-environment.sh    # Start services
├── stop-dev-environment.sh     # Stop services  
├── configure-otterscan.sh      # Contract verification setup
├── extract-addresses.sh        # Extract deployment addresses
└── setup-local-testing.sh      # Complete setup (original)
```

## Contract Verification Workflow

### Automatic Verification (Recommended)
```bash
# Deploy contracts with automatic verification
./scripts/dev.sh start --deploy

# Or deploy and verify separately
./scripts/dev.sh deploy
./scripts/dev.sh verify
```

### Manual Verification Steps
```bash
# 1. Compile contracts
forge build

# 2. Deploy contracts
./scripts/dev.sh deploy

# 3. Extract addresses
./scripts/extract-addresses.sh extract

# 4. Setup verification
./scripts/configure-otterscan.sh setup

# 5. View results
open http://localhost:8080/contracts.html
```

### Verification Features
- ✅ **Source Code Display** - View the full Solidity source
- ✅ **ABI Extraction** - Complete contract interface  
- ✅ **Address Mapping** - Deployed contract addresses
- ✅ **Local Web Interface** - Beautiful verification pages
- ✅ **Copy/Paste Ready** - Easy address copying
- ✅ **Otterscan Integration** - Direct links to explorer

## Tips

1. **Always use `./scripts/dev.sh`** for daily development
2. **Use `status` command** to check what's running
3. **Use `logs` command** to debug issues
4. **Docker Desktop** must be running for Otterscan
5. **MetaMask setup:** Add http://localhost:8545 as custom network with Chain ID 31337
6. **Contract verification** happens automatically with `--deploy` flag 