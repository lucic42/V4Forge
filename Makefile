# LaunchDotParty Development Makefile
# Provides convenient targets for all development, testing, and deployment tasks

.PHONY: help dev test e2e deploy clean status

# Configuration
SCRIPTS_DIR := scripts
ANVIL_RPC := http://localhost:8545
ANVIL_CHAIN_ID := 31337

# E2E Test Configuration
E2E_INSTANT_COUNT := 5
E2E_PUBLIC_COUNT := 3
E2E_PRIVATE_COUNT := 2
E2E_TARGET_ETH := 5
E2E_CONTRIBUTION_ETH := 1

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
NC := \033[0m

##@ Help
help: ## Display this help message
	@echo "$(BLUE)🚀 LaunchDotParty Development Makefile$(NC)"
	@echo "======================================"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(YELLOW)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development Environment
dev-start: ## Start Anvil and Otterscan
	@echo "$(YELLOW)🚀 Starting development environment...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh start

dev-start-deploy: ## Start environment and deploy contracts
	@echo "$(YELLOW)🚀 Starting development environment with deployment...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh start --deploy

dev-stop: ## Stop all development services
	@echo "$(YELLOW)⏹️  Stopping development environment...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh stop

dev-restart: ## Restart development environment
	@echo "$(YELLOW)🔄 Restarting development environment...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh restart

dev-status: ## Check development environment status
	@echo "$(BLUE)📊 Development environment status:$(NC)"
	@$(SCRIPTS_DIR)/dev.sh status

dev-logs: ## Show Anvil logs
	@echo "$(BLUE)📋 Anvil logs:$(NC)"
	@$(SCRIPTS_DIR)/dev.sh logs

dev-clean: ## Stop services and clean artifacts
	@echo "$(YELLOW)🧹 Deep cleaning development environment...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh clean

##@ Contract Deployment
deploy-v4: ## Deploy Uniswap V4 core contracts
	@echo "$(YELLOW)🚀 Deploying Uniswap V4 core contracts...$(NC)"
	@if ! pgrep -f "anvil" > /dev/null; then echo "$(RED)❌ Anvil not running. Start with 'make dev-start'$(NC)"; exit 1; fi
	@PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script script/DeployV4Core.s.sol:DeployV4Core --broadcast --rpc-url $(ANVIL_RPC) --legacy

deploy-weth: ## Deploy WETH9 for testing
	@echo "$(YELLOW)🚀 Deploying WETH9...$(NC)"
	@if ! pgrep -f "anvil" > /dev/null; then echo "$(RED)❌ Anvil not running. Start with 'make dev-start'$(NC)"; exit 1; fi
	@PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script script/DeployWETH.s.sol:DeployWETH --broadcast --rpc-url $(ANVIL_RPC) --legacy

deploy-party: ## Deploy PartyStarter system (requires V4 and WETH deployed first)
	@echo "$(YELLOW)🚀 Deploying PartyStarter system...$(NC)"
	@if ! pgrep -f "anvil" > /dev/null; then echo "$(RED)❌ Anvil not running. Start with 'make dev-start'$(NC)"; exit 1; fi
	@mkdir -p deployments
	@if [ ! -f deployments/complete-deployment.env ]; then echo "$(RED)❌ V4 dependencies not found. Run 'make deploy-dependencies' first$(NC)"; exit 1; fi
	@source deployments/complete-deployment.env && \
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	POOL_MANAGER_ADDRESS=$$POOL_MANAGER_ADDRESS WETH_ADDRESS=$$WETH_ADDRESS \
	forge script script/DeployPartyStarter.s.sol:DeployPartyStarter --broadcast --rpc-url $(ANVIL_RPC) --legacy

deploy-party-simple: ## Deploy simplified PartyStarter system without complex hooks
	@echo "$(YELLOW)🚀 Deploying Simple PartyStarter system...$(NC)"
	@if ! pgrep -f "anvil" > /dev/null; then echo "$(RED)❌ Anvil not running. Start with 'make dev-start'$(NC)"; exit 1; fi
	@mkdir -p deployments
	@if [ ! -f deployments/complete-deployment.env ]; then echo "$(RED)❌ V4 dependencies not found. Run 'make deploy-dependencies' first$(NC)"; exit 1; fi
	@source deployments/complete-deployment.env && \
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	POOL_MANAGER_ADDRESS=$$POOL_MANAGER_ADDRESS WETH_ADDRESS=$$WETH_ADDRESS \
	forge script script/DeployPartyStarterSimple.s.sol:DeployPartyStarterSimple --broadcast --rpc-url $(ANVIL_RPC) --legacy

deploy-dependencies: deploy-weth deploy-v4 ## Deploy all V4 dependencies (WETH + V4 Core)
	@echo "$(GREEN)✅ V4 dependencies deployed successfully!$(NC)"

deploy-simple: deploy-dependencies deploy-party-simple ## Deploy V4 + Simple PartyStarter (recommended for testing)
	@echo "$(GREEN)✅ Simple system deployed! Ready for testing.$(NC)"
	@echo "$(BLUE)📋 Deployed contracts:$(NC)"
	@if [ -f deployments/complete-deployment.env ]; then cat deployments/complete-deployment.env | grep -E '^[A-Z_]+_ADDRESS=' | sort; fi
	@if [ -f deployments/simple-addresses.env ]; then cat deployments/simple-addresses.env | grep -E '^[A-Z_]+_ADDRESS=' | sort; fi

deploy-all: ## Deploy complete LaunchDotParty system (V4 + PartyStarter)
	@echo "$(YELLOW)🚀 Deploying complete LaunchDotParty system...$(NC)"
	@if ! pgrep -f "anvil" > /dev/null; then echo "$(RED)❌ Anvil not running. Start with 'make dev-start'$(NC)"; exit 1; fi
	@mkdir -p deployments
	@PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script script/DeployAll.s.sol:DeployAll --broadcast --rpc-url $(ANVIL_RPC) --legacy
	@echo "$(GREEN)✅ Complete system deployed! Check deployments/complete-deployment.env for addresses$(NC)"

deploy: deploy-all ## Alias for deploy-all

deploy-verify: deploy ## Deploy contracts and setup verification
	@echo "$(YELLOW)🔧 Setting up contract verification...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh verify 2>/dev/null || echo "$(YELLOW)⚠️  Verification setup skipped (optional)$(NC)"

extract-addresses: ## Extract deployed contract addresses
	@echo "$(BLUE)📋 Extracting contract addresses...$(NC)"
	@if [ -f deployments/complete-deployment.env ]; then \
		echo "$(GREEN)📋 Contract addresses from latest deployment:$(NC)"; \
		cat deployments/complete-deployment.env | grep -E '^[A-Z_]+_ADDRESS=' | sort; \
	else \
		echo "$(RED)❌ No deployment found. Run 'make deploy' first$(NC)"; \
	fi

update-indexer: deploy ## Deploy contracts and update indexer
	@echo "$(YELLOW)🔄 Deploying and updating indexer...$(NC)"
	@$(SCRIPTS_DIR)/deploy-and-update-indexer.sh

##@ Testing
test: ## Run Foundry tests
	@echo "$(YELLOW)🧪 Running Foundry tests...$(NC)"
	@$(SCRIPTS_DIR)/run-tests.sh

test-setup: ## Setup local testing environment
	@echo "$(YELLOW)🔧 Setting up local testing environment...$(NC)"
	@$(SCRIPTS_DIR)/setup-local-testing.sh

test-unit: ## Run unit tests only
	@echo "$(YELLOW)🧪 Running unit tests...$(NC)"
	@$(SCRIPTS_DIR)/run-tests.sh unit

test-integration: ## Run integration tests only
	@echo "$(YELLOW)🧪 Running integration tests...$(NC)"
	@$(SCRIPTS_DIR)/run-tests.sh integration

test-fuzz: ## Run fuzz tests
	@echo "$(YELLOW)🎲 Running fuzz tests...$(NC)"
	@$(SCRIPTS_DIR)/run-tests.sh fuzz

test-gas: ## Run gas benchmark tests
	@echo "$(YELLOW)⛽ Running gas benchmark tests...$(NC)"
	@$(SCRIPTS_DIR)/run-tests.sh gas

##@ E2E Testing
e2e: ## Run complete E2E test suite
	@echo "$(PURPLE)🎯 Running complete E2E test suite...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-all.sh full \
		--instant-count $(E2E_INSTANT_COUNT) \
		--public-count $(E2E_PUBLIC_COUNT) \
		--private-count $(E2E_PRIVATE_COUNT) \
		--target $(E2E_TARGET_ETH) \
		--contribution $(E2E_CONTRIBUTION_ETH)

e2e-setup: ## Setup E2E testing environment
	@echo "$(YELLOW)🔧 Setting up E2E testing environment...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-all.sh setup

e2e-status: ## Check E2E environment status
	@echo "$(BLUE)📊 E2E environment status:$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-all.sh status

e2e-instant: ## Run instant party E2E tests
	@echo "$(PURPLE)⚡ Running instant party E2E tests...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-all.sh instant --instant-count $(E2E_INSTANT_COUNT)

e2e-public: ## Run public party E2E tests
	@echo "$(PURPLE)👥 Running public party E2E tests...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-all.sh public \
		--public-count $(E2E_PUBLIC_COUNT) \
		--target $(E2E_TARGET_ETH) \
		--contribution $(E2E_CONTRIBUTION_ETH)

e2e-private: ## Run private party E2E tests
	@echo "$(PURPLE)🔐 Running private party E2E tests...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-all.sh private \
		--private-count $(E2E_PRIVATE_COUNT) \
		--target $(E2E_TARGET_ETH) \
		--contribution $(E2E_CONTRIBUTION_ETH)

e2e-parallel: ## Run E2E tests with parallel execution
	@echo "$(PURPLE)🚀 Running E2E tests in parallel mode...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-all.sh full --parallel \
		--instant-count $(E2E_INSTANT_COUNT) \
		--public-count $(E2E_PUBLIC_COUNT) \
		--private-count $(E2E_PRIVATE_COUNT)

e2e-custom: ## Run E2E tests with custom parameters (use E2E_* variables)
	@echo "$(PURPLE)🎛️  Running custom E2E tests...$(NC)"
	@echo "  Instant: $(E2E_INSTANT_COUNT) parties"
	@echo "  Public: $(E2E_PUBLIC_COUNT) parties ($(E2E_TARGET_ETH) ETH target)"
	@echo "  Private: $(E2E_PRIVATE_COUNT) parties ($(E2E_TARGET_ETH) ETH target)"
	@echo "  Contribution: $(E2E_CONTRIBUTION_ETH) ETH per user"
	@$(SCRIPTS_DIR)/e2e-test-all.sh full \
		--instant-count $(E2E_INSTANT_COUNT) \
		--public-count $(E2E_PUBLIC_COUNT) \
		--private-count $(E2E_PRIVATE_COUNT) \
		--target $(E2E_TARGET_ETH) \
		--contribution $(E2E_CONTRIBUTION_ETH)

##@ E2E Utilities
e2e-fund-wallets: ## Fund E2E test wallets
	@echo "$(YELLOW)💰 Funding E2E test wallets...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-setup.sh fund

e2e-wallet-status: ## Check E2E wallet balances
	@echo "$(BLUE)📊 E2E wallet balances:$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-setup.sh status

e2e-clean-wallets: ## Reset E2E wallet balances
	@echo "$(YELLOW)🧹 Cleaning E2E wallet balances...$(NC)"
	@$(SCRIPTS_DIR)/e2e-test-setup.sh clean

e2e-generate-signatures: ## Generate signatures for private party testing
	@echo "$(BLUE)🔐 Generating test signatures...$(NC)"
	@$(SCRIPTS_DIR)/e2e-signature-utils.sh generate-batch \
		--party-id 1 \
		--max-amount $(E2E_CONTRIBUTION_ETH) \
		--signer-key 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e

##@ Infrastructure
otterscan-setup: ## Setup Otterscan block explorer
	@echo "$(YELLOW)🔧 Setting up Otterscan...$(NC)"
	@$(SCRIPTS_DIR)/configure-otterscan.sh setup

otterscan-start: ## Start Otterscan
	@echo "$(YELLOW)🚀 Starting Otterscan...$(NC)"
	@$(SCRIPTS_DIR)/configure-otterscan.sh start

otterscan-stop: ## Stop Otterscan
	@echo "$(YELLOW)⏹️  Stopping Otterscan...$(NC)"
	@$(SCRIPTS_DIR)/configure-otterscan.sh stop

otterscan-clean: ## Clean Otterscan setup
	@echo "$(YELLOW)🧹 Cleaning Otterscan...$(NC)"
	@$(SCRIPTS_DIR)/configure-otterscan.sh clean

##@ Quick Actions
quick-start: dev-start deploy e2e-setup ## Quick start: Start env, deploy V4+PartyStarter, setup E2E
	@echo "$(GREEN)✅ Quick start complete! Ready for testing.$(NC)"
	@echo "$(BLUE)📋 Deployed contracts:$(NC)"
	@$(MAKE) extract-addresses

quick-test: test e2e-instant ## Quick test: Run unit tests and instant E2E tests
	@echo "$(GREEN)✅ Quick tests complete!$(NC)"

full-test: test e2e ## Full test suite: All unit tests + complete E2E
	@echo "$(GREEN)✅ Full test suite complete!$(NC)"

##@ Cleanup
clean: ## Clean all artifacts and stop services
	@echo "$(YELLOW)🧹 Cleaning all artifacts...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh clean
	@$(SCRIPTS_DIR)/e2e-test-setup.sh clean 2>/dev/null || true
	@rm -f *.log 2>/dev/null || true
	@rm -f e2e-wallets.env 2>/dev/null || true
	@rm -f *-parties-*.log 2>/dev/null || true
	@rm -f private-party-*-signatures.txt 2>/dev/null || true

clean-logs: ## Clean only log files
	@echo "$(YELLOW)🧹 Cleaning log files...$(NC)"
	@rm -f *.log 2>/dev/null || true
	@rm -f *-parties-*.log 2>/dev/null || true
	@rm -f private-party-*-signatures.txt 2>/dev/null || true

##@ Status & Info
status: ## Show comprehensive status
	@echo "$(BLUE)📊 LaunchDotParty Development Status$(NC)"
	@echo "====================================="
	@$(SCRIPTS_DIR)/dev.sh status
	@echo ""
	@$(SCRIPTS_DIR)/e2e-test-all.sh status

info: ## Show configuration info
	@echo "$(BLUE)ℹ️  LaunchDotParty Configuration$(NC)"
	@echo "=================================="
	@echo "Anvil RPC: $(ANVIL_RPC)"
	@echo "Chain ID: $(ANVIL_CHAIN_ID)"
	@echo ""
	@echo "$(BLUE)E2E Test Configuration:$(NC)"
	@echo "Instant Parties: $(E2E_INSTANT_COUNT)"
	@echo "Public Parties: $(E2E_PUBLIC_COUNT)"
	@echo "Private Parties: $(E2E_PRIVATE_COUNT)"
	@echo "Target ETH: $(E2E_TARGET_ETH)"
	@echo "Contribution ETH: $(E2E_CONTRIBUTION_ETH)"

logs: ## Show recent logs
	@echo "$(BLUE)📋 Recent logs:$(NC)"
	@echo "==============="
	@if [ -f anvil.log ]; then echo "$(YELLOW)Anvil logs:$(NC)"; tail -10 anvil.log; echo ""; fi
	@if ls *-parties-*.log 1> /dev/null 2>&1; then echo "$(YELLOW)E2E test logs:$(NC)"; ls -la *-parties-*.log; fi

##@ Advanced
stress-test: ## Run stress tests with higher counts
	@echo "$(PURPLE)💪 Running stress tests...$(NC)"
	@$(MAKE) e2e-custom \
		E2E_INSTANT_COUNT=20 \
		E2E_PUBLIC_COUNT=10 \
		E2E_PRIVATE_COUNT=5 \
		E2E_TARGET_ETH=10 \
		E2E_CONTRIBUTION_ETH=2

mini-test: ## Run minimal tests for quick verification
	@echo "$(PURPLE)🏃 Running minimal tests...$(NC)"
	@$(MAKE) e2e-custom \
		E2E_INSTANT_COUNT=2 \
		E2E_PUBLIC_COUNT=1 \
		E2E_PRIVATE_COUNT=1 \
		E2E_TARGET_ETH=3 \
		E2E_CONTRIBUTION_ETH=1

ci-test: ## Run CI-friendly test suite
	@echo "$(PURPLE)🤖 Running CI test suite...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh start --deploy
	@$(MAKE) test
	@$(MAKE) mini-test
	@$(SCRIPTS_DIR)/dev.sh stop

##@ Custom E2E Examples
# Example: make e2e-custom E2E_INSTANT_COUNT=10 E2E_TARGET_ETH=8
# Example: make stress-test
# Example: make mini-test

# Default target
.DEFAULT_GOAL := help 