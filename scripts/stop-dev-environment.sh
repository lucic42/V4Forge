#!/bin/bash

# LaunchDotParty Development Environment Stopper
# This script stops Anvil blockchain and Otterscan block explorer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping LaunchDotParty Development Environment${NC}"
echo "================================================="

# Stop Anvil blockchain
stop_anvil() {
    echo -e "${YELLOW}🔧 Stopping Anvil blockchain...${NC}"
    
    # Kill by PID if available
    if [ -f .anvil.pid ]; then
        local pid=$(cat .anvil.pid)
        if kill "$pid" 2>/dev/null; then
            echo -e "${GREEN}✅ Anvil stopped (PID: $pid)${NC}"
        else
            echo -e "${YELLOW}⚠️  Anvil process $pid not found (already stopped?)${NC}"
        fi
        rm -f .anvil.pid
    fi
    
    # Kill any remaining anvil processes
    local anvil_pids=$(pgrep -f "anvil" 2>/dev/null || true)
    if [ ! -z "$anvil_pids" ]; then
        echo -e "${BLUE}  🔍 Found additional Anvil processes: $anvil_pids${NC}"
        echo "$anvil_pids" | xargs kill 2>/dev/null || true
        echo -e "${GREEN}✅ Additional Anvil processes terminated${NC}"
    fi
    
    # Clean up log file
    if [ -f anvil.log ]; then
        rm -f anvil.log
        echo -e "${BLUE}  🧹 Cleaned up anvil.log${NC}"
    fi
}

# Stop Otterscan block explorer
stop_otterscan() {
    echo -e "${YELLOW}🔍 Stopping Otterscan block explorer...${NC}"
    
    # Stop Docker container
    if docker ps | grep -q otterscan; then
        docker stop otterscan > /dev/null 2>&1
        echo -e "${GREEN}✅ Otterscan container stopped${NC}"
    else
        echo -e "${YELLOW}⚠️  Otterscan container not running${NC}"
    fi
    
    # Remove the port tracking file
    if [ -f .otterscan.port ]; then
        rm -f .otterscan.port
        echo -e "${BLUE}  🧹 Cleaned up otterscan tracking file${NC}"
    fi
}

# Clean up deployment artifacts
cleanup_artifacts() {
    echo -e "${YELLOW}🧹 Cleaning up artifacts...${NC}"
    
    # Remove any deployment tracking files
    if [ -d deployments ]; then
        rm -f deployments/local.env
        echo -e "${BLUE}  🗑️  Removed local deployment config${NC}"
    fi
    
    # Remove any temporary files
    rm -f .anvil.pid .otterscan.port
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Check if services are still running
check_services() {
    echo -e "${YELLOW}🔍 Checking service status...${NC}"
    
    local services_running=false
    
    # Check Anvil
    if lsof -i :8545 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Something is still running on port 8545 (Anvil port)${NC}"
        services_running=true
    fi
    
    # Check Otterscan
    if lsof -i :5100 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Something is still running on port 5100 (Otterscan port)${NC}"
        services_running=true
    fi
    
    # Check Docker containers
    if docker ps | grep -q otterscan; then
        echo -e "${YELLOW}⚠️  Otterscan Docker container is still running${NC}"
        services_running=true
    fi
    
    if [ "$services_running" = false ]; then
        echo -e "${GREEN}✅ All services stopped successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Some services may still be running${NC}"
        echo -e "${BLUE}  💡 Use 'lsof -i :8545' and 'lsof -i :5100' to investigate${NC}"
    fi
}

# Force stop everything
force_stop() {
    echo -e "${RED}💥 Force stopping all services...${NC}"
    
    # Kill all anvil processes
    pkill -f anvil 2>/dev/null || true
    
    # Stop all Docker containers with otterscan in the name
    docker ps -q --filter "name=otterscan" | xargs -r docker stop > /dev/null 2>&1
    docker ps -aq --filter "name=otterscan" | xargs -r docker rm > /dev/null 2>&1
    
    # Kill processes on specific ports
    lsof -ti :8545 | xargs -r kill -9 2>/dev/null || true
    lsof -ti :5100 | xargs -r kill -9 2>/dev/null || true
    
    # Clean up all files
    rm -f .anvil.pid .otterscan.port anvil.log
    rm -f deployments/local.env 2>/dev/null || true
    
    echo -e "${GREEN}✅ Force stop completed${NC}"
}

# Print final status
print_status() {
    echo -e "\n${GREEN}🎉 Development Environment Stopped!${NC}"
    echo "===================================="
    echo -e "${BLUE}📋 What was stopped:${NC}"
    echo "  • Anvil blockchain (port 8545)"
    echo "  • Otterscan block explorer (port 5100)"
    echo "  • All associated processes and containers"
    echo ""
    echo -e "${BLUE}🗑️  Cleaned up:${NC}"
    echo "  • Process ID files"
    echo "  • Log files"
    echo "  • Temporary deployment configs"
    echo ""
    echo -e "${YELLOW}💡 To start again:${NC}"
    echo "  ./scripts/start-dev-environment.sh"
    echo "  ./scripts/start-dev-environment.sh --deploy"
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force_stop
                exit 0
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --force    Force stop all services (more aggressive)"
                echo "  -h, --help Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Regular stop sequence
    stop_anvil
    stop_otterscan
    cleanup_artifacts
    check_services
    print_status
}

# Handle direct script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 