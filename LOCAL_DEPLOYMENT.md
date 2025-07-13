# Local Deployment System

This deployment system provides a complete local testing environment for your Party contracts on Anvil.

## Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Make sure you're in the contracts directory
cd /Users/lukesteimel/Desktop/launchdotparty/lib/contracts

# Run the automated deployment script
./scripts/deploy-local.sh
```

This script will:
- Start Anvil if not running
- Deploy all contracts
- Copy ABIs to your frontend
- Create an addresses file for easy access

### Option 2: Manual Deployment

```bash
# 1. Start Anvil
anvil --port 8545 --host 0.0.0.0

# 2. Deploy contracts (in another terminal)
forge script scripts/DeployLocal.s.sol:DeployLocal \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 3. Test deployment
forge script scripts/TestDeployment.s.sol:TestDeployment \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Deployed Contracts

After deployment, you'll have these contracts available:

| Contract | Address | Description |
|----------|---------|-------------|
| WETH9 | `0x5FbDB2315678afecb367f032d93F642f64180aa3` | Wrapped ETH for testing |
| MockFactory | `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512` | Mock Uniswap V3 Factory |
| MockPositionManager | `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0` | Mock Position Manager |
| PartyStarterV2 | `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9` | Your main party starter contract |
| TestPartyVenue | `0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81` | A test party venue |

## Network Configuration

- **RPC URL**: `http://localhost:8545`
- **Chain ID**: `31337`
- **Test Private Key**: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- **Test Address**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

## Frontend Integration

The deployment system automatically:

1. **Copies ABIs** to `/Users/lukesteimel/Desktop/launchdotparty/apps/frontend/src/contracts/`
2. **Creates addresses file** at `/Users/lukesteimel/Desktop/launchdotparty/apps/frontend/src/contracts/addresses.json`

### Using in Your Frontend

```javascript
// Import the addresses
import addresses from './contracts/addresses.json';

// Import the ABIs
import PartyStarterV2ABI from './contracts/PartyStarterV2.abi.json';
import PublicPartyVenueABI from './contracts/PublicPartyVenue.abi.json';

// Use with ethers.js or web3.js
const partyStarter = new ethers.Contract(
    addresses.PartyStarterV2,
    PartyStarterV2ABI,
    provider
);
```

## Available Scripts

| Script | Purpose |
|--------|---------|
| `scripts/deploy-local.sh` | Full automated deployment |
| `scripts/DeployLocal.s.sol` | Core deployment script |
| `scripts/TestDeployment.s.sol` | Test deployed contracts |
| `scripts/copy-abis.sh` | Copy ABIs to frontend |

## Contract Functionality

### PartyStarterV2

- **Create Party**: `createParty(timeout, ethAmount, tokenAmount, maxEthContribution)`
- **Owner Functions**: `setFactory()`, `setPositionManager()`, `setVault()`

### PublicPartyVenue

- **Contribute**: `contribute()` - Send ETH to join the party
- **Launch**: `launch()` - Create token and Uniswap pool
- **Claim**: `claim()` - Claim your tokens after launch
- **Refund**: `refund()` - Get refund if party fails

## Testing Your Contracts

### Using the Test Script

```bash
forge script scripts/TestDeployment.s.sol:TestDeployment \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Manual Testing with Cast

```bash
# Check PartyStarterV2 factory address
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "factory()" --rpc-url http://localhost:8545

# Create a new party
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 \
    "createParty(uint256,uint256,uint256,uint256)" \
    $(($(date +%s) + 86400)) \
    1000000000000000000 \
    1000000000000000000000 \
    100000000000000000 \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Contribute to a party
cast send 0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81 \
    "contribute()" \
    --value 0.05ether \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Troubleshooting

### Anvil Not Starting
```bash
# Kill existing anvil processes
pkill -f anvil

# Start fresh
anvil --port 8545 --host 0.0.0.0
```

### Contract Addresses Changed
The addresses are deterministic but will change if you restart Anvil. Update your frontend addresses file after each restart.

### Build Errors
```bash
# Clean and rebuild
forge clean
forge build
```

## Development Workflow

1. **Start Development**: `./scripts/deploy-local.sh`
2. **Make Changes**: Edit your contracts
3. **Redeploy**: `./scripts/deploy-local.sh` (will restart everything)
4. **Test**: Use the test script or manual testing
5. **Frontend**: The ABIs and addresses are automatically updated

## Important Notes

- **Test Environment**: This is for local testing only
- **Mock Contracts**: Uses simplified mocks for Uniswap V3 components
- **Deterministic Addresses**: Same addresses every time you deploy
- **No Persistence**: Data is lost when Anvil restarts

## Next Steps

- Add more comprehensive tests
- Implement real Uniswap V3 contracts for production-like testing
- Add integration tests with your frontend
- Set up CI/CD for automated testing 