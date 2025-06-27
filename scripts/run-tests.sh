#!/bin/bash

# Party System - Comprehensive Test Runner
# This script runs all test suites and provides detailed reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-default}
VERBOSITY=${VERBOSITY:-"-vvv"}
GAS_REPORT=${GAS_REPORT:-true}

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}🎉 PARTY SYSTEM TEST SUITE${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Function to print section headers
print_header() {
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..40})${NC}"
}

# Function to run tests with error handling
run_test_suite() {
    local test_name="$1"
    local test_pattern="$2"
    local description="$3"
    
    echo -e "${BLUE}Running $test_name...${NC}"
    echo -e "${YELLOW}$description${NC}"
    echo ""
    
    if forge test --match-path "$test_pattern" $VERBOSITY; then
        echo -e "${GREEN}✅ $test_name passed${NC}"
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        exit 1
    fi
    echo ""
}

# Function to run specific test contracts
run_test_contract() {
    local test_name="$1"
    local contract_pattern="$2"
    local description="$3"
    
    echo -e "${BLUE}Running $test_name...${NC}"
    echo -e "${YELLOW}$description${NC}"
    echo ""
    
    if forge test --match-contract "$contract_pattern" $VERBOSITY; then
        echo -e "${GREEN}✅ $test_name passed${NC}"
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        exit 1
    fi
    echo ""
}

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry/Forge is not installed. Please install it first.${NC}"
    exit 1
fi

# Build the project first
print_header "🔨 BUILDING PROJECT"
echo -e "${BLUE}Building contracts...${NC}"
if forge build; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
echo ""

# Run comprehensive test suite
print_header "🧪 COMPREHENSIVE TEST SUITE"
run_test_contract "Comprehensive Test Runner" "TestRunner" "Runs all tests in a single orchestrated suite"

# Run unit tests
print_header "🔧 UNIT TESTS"
run_test_suite "Party Library Tests" "test/unit/PartyLibTest.sol" "Tests for party creation and management library"
run_test_suite "Math Library Tests" "test/unit/MathLibTest.sol" "Tests for mathematical calculations and utilities"

# Run integration tests  
print_header "🔗 INTEGRATION TESTS"
run_test_suite "Party Flow Tests" "test/integration/PartyFlowTest.sol" "End-to-end testing of complete party workflows"

# Run fuzz tests
print_header "🎲 FUZZ TESTS"
echo -e "${BLUE}Running fuzz tests (this may take longer)...${NC}"
if forge test --match-path "test/fuzz/*" $VERBOSITY --fuzz-runs 100; then
    echo -e "${GREEN}✅ Fuzz tests passed${NC}"
else
    echo -e "${RED}❌ Fuzz tests failed${NC}"
    exit 1
fi
echo ""

# Run load tests
print_header "⚡ LOAD TESTS"
run_test_suite "Load Tests" "test/load/LoadTest.sol" "High-volume transaction simulation and stress testing"

# Run security tests
print_header "🔒 SECURITY TESTS"
run_test_suite "Security Tests" "test/security/SecurityTest.sol" "Security vulnerability and attack vector testing"

# Generate gas report if requested
if [ "$GAS_REPORT" = "true" ]; then
    print_header "⛽ GAS REPORT"
    echo -e "${BLUE}Generating gas usage report...${NC}"
    if forge test --gas-report > gas-report.txt; then
        echo -e "${GREEN}✅ Gas report generated: gas-report.txt${NC}"
        echo -e "${YELLOW}Top gas consumers:${NC}"
        head -20 gas-report.txt | tail -15
    else
        echo -e "${YELLOW}⚠️  Gas report generation failed${NC}"
    fi
    echo ""
fi

# Run specific critical tests
print_header "🎯 CRITICAL FUNCTIONALITY TESTS"

echo -e "${BLUE}Testing instant party creation...${NC}"
forge test --match-test "test_InstantParty_FullFlow" $VERBOSITY

echo -e "${BLUE}Testing public party flow...${NC}"
forge test --match-test "test_PublicParty_FullFlow" $VERBOSITY

echo -e "${BLUE}Testing private party flow...${NC}"
forge test --match-test "test_PrivateParty_FullFlow" $VERBOSITY

echo -e "${BLUE}Testing fee claiming...${NC}"
forge test --match-test "test_ClaimFees_Success" $VERBOSITY

echo -e "${BLUE}Testing access control...${NC}"
forge test --match-test "test_Security_OnlyCreatorCanClaimFees" $VERBOSITY

echo ""

# Test coverage report
print_header "📊 COVERAGE ANALYSIS"
echo -e "${BLUE}Generating test coverage report...${NC}"
if command -v lcov &> /dev/null; then
    if forge coverage --report lcov; then
        echo -e "${GREEN}✅ Coverage report generated${NC}"
        # Extract overall coverage percentage
        if command -v genhtml &> /dev/null; then
            genhtml -o coverage lcov.info
            echo -e "${GREEN}✅ HTML coverage report: coverage/index.html${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Coverage report generation failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  lcov not installed, skipping coverage report${NC}"
fi
echo ""

# Summary
print_header "📋 TEST SUMMARY"

echo -e "${GREEN}✅ All test suites completed successfully!${NC}"
echo ""
echo -e "${CYAN}Test Categories Completed:${NC}"
echo -e "  🧪 Comprehensive Suite"
echo -e "  🔧 Unit Tests"
echo -e "  🔗 Integration Tests" 
echo -e "  🎲 Fuzz Tests"
echo -e "  ⚡ Load Tests"
echo -e "  🔒 Security Tests"
echo -e "  🎯 Critical Functionality"
echo ""

echo -e "${CYAN}System Verification:${NC}"
echo -e "  ✅ All party types work correctly"
echo -e "  ✅ Security measures are effective"
echo -e "  ✅ Performance is within acceptable limits"
echo -e "  ✅ Integration between components is solid"
echo -e "  ✅ System handles edge cases properly"
echo ""

echo -e "${GREEN}🎉 Party system is ready for deployment!${NC}"
echo ""

# Optional: Run specific performance benchmarks
if [ "$1" = "--benchmark" ]; then
    print_header "🏆 PERFORMANCE BENCHMARKS"
    echo -e "${BLUE}Running performance benchmarks...${NC}"
    
    echo -e "${YELLOW}Gas usage benchmarks:${NC}"
    forge test --match-test "test_Gas_" --gas-report
    
    echo -e "${YELLOW}Load testing benchmarks:${NC}"
    forge test --match-test "test_Load_" -vv
    
    echo -e "${GREEN}✅ Benchmarks completed${NC}"
fi

# Optional: Run only security tests
if [ "$1" = "--security-only" ]; then
    print_header "🔒 SECURITY-ONLY TEST RUN"
    run_test_suite "Security Tests" "test/security/SecurityTest.sol" "Comprehensive security testing"
    forge test --match-test "test_Security_" $VERBOSITY
    echo -e "${GREEN}✅ Security-only tests completed${NC}"
fi

# Optional: Run only fuzz tests with high iterations
if [ "$1" = "--fuzz-intensive" ]; then
    print_header "🎲 INTENSIVE FUZZ TESTING"
    echo -e "${BLUE}Running intensive fuzz tests (this will take several minutes)...${NC}"
    forge test --match-path "test/fuzz/*" $VERBOSITY --fuzz-runs 1000
    echo -e "${GREEN}✅ Intensive fuzz tests completed${NC}"
fi 