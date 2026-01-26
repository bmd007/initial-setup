#!/bin/bash

###############################################################################
# Conduit Health Check & Verification Tool
# Tests if Conduit is running properly and connecting to Psiphon network
#
# Based on: https://github.com/Psiphon-Inc/conduit
#
# Usage: ./conduit-health.sh
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
CONTAINER_NAME="conduit"
CONDUIT_DIR="$HOME/conduit"
DATA_DIR="$CONDUIT_DIR/data"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# Display header
show_header() {
    clear
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}                    ${BOLD}Conduit Health Check${NC}                                ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Time:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

# Check if container exists and is running
check_container_running() {
    log_test "Checking if Conduit container is running..."

    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Conduit container is not running"

        # Check if container exists but stopped
        if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
            log_warning "Container exists but is stopped"
            echo -e "  ${YELLOW}→${NC} Start it with: cd ~/conduit && docker-compose up -d"
        else
            log_error "Container does not exist"
            echo -e "  ${YELLOW}→${NC} Create it with: ./setup-conduit.sh YourPassword"
        fi
        return 1
    fi

    log_success "Container is running"

    # Show container uptime
    local uptime=$(docker ps --filter name="^${CONTAINER_NAME}$" --format '{{.Status}}')
    echo -e "  ${CYAN}↳${NC} Status: $uptime"
    return 0
}

# Check container resource usage
check_container_resources() {
    log_test "Checking container resource usage..."

    local stats=$(docker stats "$CONTAINER_NAME" --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}" 2>/dev/null)

    if [ -n "$stats" ]; then
        IFS='|' read -r cpu mem net <<< "$stats"
        log_success "Resource usage:"
        echo -e "  ${CYAN}↳${NC} CPU: $cpu"
        echo -e "  ${CYAN}↳${NC} Memory: $mem"
        echo -e "  ${CYAN}↳${NC} Network I/O: $net"
    else
        log_warning "Could not get resource stats"
    fi
}

# Check if data directory exists and has key
check_data_directory() {
    log_test "Checking data directory..."

    if [ ! -d "$DATA_DIR" ]; then
        log_error "Data directory not found: $DATA_DIR"
        return 1
    fi

    log_success "Data directory exists"

    # Check for identity key
    if [ -f "$DATA_DIR/conduit_key.json" ]; then
        log_success "Identity key found (conduit_key.json)"
        echo -e "  ${CYAN}↳${NC} This key maintains your Psiphon broker reputation"
        echo -e "  ${CYAN}↳${NC} Keep this file backed up and persistent!"
    else
        log_warning "Identity key not found (conduit_key.json)"
        echo -e "  ${YELLOW}→${NC} Key will be generated on first start"
        echo -e "  ${YELLOW}→${NC} Make sure data directory is persistent (volume mounted)"
    fi

    # Show data directory contents
    if [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        echo -e "  ${CYAN}↳${NC} Contents:"
        ls -lh "$DATA_DIR" | tail -n +2 | while read line; do
            echo -e "    ${NC}$line"
        done
    fi
}

# Check Psiphon configuration
check_psiphon_config() {
    log_test "Checking Psiphon configuration..."

    local config_file="$CONDUIT_DIR/psiphon_config.json"

    if [ ! -f "$config_file" ]; then
        log_error "Psiphon config not found: $config_file"
        echo -e "  ${YELLOW}→${NC} Conduit needs a Psiphon network configuration file"
        echo -e "  ${YELLOW}→${NC} Contact Psiphon team for configuration"
        echo -e "  ${YELLOW}→${NC} More info: https://github.com/Psiphon-Inc/conduit"
        return 1
    fi

    log_success "Psiphon config exists"

    # Validate JSON
    if command -v jq &> /dev/null; then
        if jq empty "$config_file" 2>/dev/null; then
            log_success "Config is valid JSON"

            # Show some config details (without revealing sensitive data)
            local keys=$(jq -r 'keys[]' "$config_file" 2>/dev/null | head -5)
            if [ -n "$keys" ]; then
                echo -e "  ${CYAN}↳${NC} Config keys found:"
                echo "$keys" | while read key; do
                    echo -e "    ${NC}- $key"
                done
            fi
        else
            log_error "Config has invalid JSON"
            return 1
        fi
    else
        log_warning "jq not available, skipping JSON validation"
    fi
}

# Check container logs for errors
check_container_logs() {
    log_test "Analyzing container logs..."

    local logs=$(docker logs "$CONTAINER_NAME" --tail 100 2>&1)

    # Count log levels
    local errors=$(echo "$logs" | grep -ci "error" || echo 0)
    local warnings=$(echo "$logs" | grep -ci "warn\|warning" || echo 0)
    local info=$(echo "$logs" | grep -ci "info\|started\|connected" || echo 0)

    if [ "$errors" -gt 0 ]; then
        log_warning "Found $errors error(s) in recent logs"
        echo -e "  ${YELLOW}→${NC} Showing last 5 errors:"
        echo "$logs" | grep -i "error" | tail -5 | while read line; do
            echo -e "    ${RED}$line${NC}"
        done
    else
        log_success "No errors in recent logs"
    fi

    if [ "$warnings" -gt 0 ]; then
        log_info "Found $warnings warning(s) in recent logs"
    fi

    echo -e "  ${CYAN}↳${NC} Log summary: $info info, $warnings warnings, $errors errors"
}

# Check Psiphon network connectivity
check_psiphon_connectivity() {
    log_test "Checking Psiphon network connectivity..."

    local logs=$(docker logs "$CONTAINER_NAME" --tail 200 2>&1)

    # Look for connection indicators
    if echo "$logs" | grep -qi "connected\|established\|tunnel"; then
        log_success "Connection indicators found in logs"

        # Show recent connection messages
        local conn_msgs=$(echo "$logs" | grep -i "connected\|established\|tunnel" | tail -3)
        if [ -n "$conn_msgs" ]; then
            echo -e "  ${CYAN}↳${NC} Recent connections:"
            echo "$conn_msgs" | while read line; do
                echo -e "    ${GREEN}$line${NC}"
            done
        fi
    else
        log_warning "No clear connection indicators in logs"
        echo -e "  ${YELLOW}→${NC} Container may still be initializing"
        echo -e "  ${YELLOW}→${NC} Check logs: docker logs conduit -f"
    fi

    # Check for broker connection
    if echo "$logs" | grep -qi "broker"; then
        log_success "Broker connection mentions found"
    else
        log_info "No broker mentions in recent logs"
    fi
}

# Check network connectivity from container
check_network_from_container() {
    log_test "Testing network connectivity from container..."

    # Test DNS resolution
    if docker exec "$CONTAINER_NAME" sh -c "nslookup google.com" >/dev/null 2>&1; then
        log_success "DNS resolution working"
    else
        log_warning "DNS resolution may have issues"
    fi

    # Test outbound connectivity
    if docker exec "$CONTAINER_NAME" sh -c "ping -c 2 8.8.8.8" >/dev/null 2>&1; then
        log_success "Outbound connectivity working"
    else
        log_warning "Outbound connectivity may have issues"
    fi
}

# Check if ports are properly configured
check_port_configuration() {
    log_test "Checking port configuration..."

    local compose_file="$CONDUIT_DIR/docker-compose.yml"

    if [ -f "$compose_file" ]; then
        local ports=$(grep -A 3 "ports:" "$compose_file" | grep -E "^\s*-" | sed 's/^[[:space:]]*- "//' | sed 's/"$//')

        if [ -n "$ports" ]; then
            log_success "Port mappings found:"
            echo "$ports" | while read port; do
                echo -e "  ${CYAN}↳${NC} $port"
            done
        else
            log_warning "No port mappings found in docker-compose.yml"
            echo -e "  ${YELLOW}→${NC} This may be intentional (host networking)"
        fi
    fi
}

# Show recent activity summary
show_activity_summary() {
    log_test "Checking recent activity..."

    local logs=$(docker logs "$CONTAINER_NAME" --since 1h 2>&1)

    if [ -z "$logs" ]; then
        log_warning "No activity in the last hour"
        return
    fi

    local lines=$(echo "$logs" | wc -l)
    log_success "Activity detected: $lines log lines in last hour"

    echo -e "  ${CYAN}↳${NC} Recent log entries (last 5):"
    echo "$logs" | tail -5 | while read line; do
        echo -e "    ${NC}$line"
    done
}

# Provide recommendations
provide_recommendations() {
    echo ""
    echo -e "${BOLD}${CYAN}═══ Recommendations ═══${NC}"

    # Check if running for first time
    if [ ! -f "$DATA_DIR/conduit_key.json" ]; then
        echo -e "${YELLOW}▸${NC} First time setup detected"
        echo -e "  • Allow time for initial key generation"
        echo -e "  • Reputation will build over time with Psiphon broker"
        echo ""
    fi

    # General recommendations
    echo -e "${BLUE}▸${NC} Monitoring commands:"
    echo -e "  • View live logs: ${CYAN}docker logs conduit -f${NC}"
    echo -e "  • Check status: ${CYAN}docker ps | grep conduit${NC}"
    echo -e "  • Resource usage: ${CYAN}docker stats conduit${NC}"
    echo ""

    echo -e "${BLUE}▸${NC} Troubleshooting:"
    echo -e "  • Restart: ${CYAN}docker restart conduit${NC}"
    echo -e "  • Full restart: ${CYAN}cd ~/conduit && docker-compose restart${NC}"
    echo -e "  • Check config: ${CYAN}cat ~/conduit/psiphon_config.json${NC}"
    echo ""

    echo -e "${BLUE}▸${NC} Important notes:"
    echo -e "  • Keep data directory persistent (contains your identity key)"
    echo -e "  • Reputation builds over time with the Psiphon broker"
    echo -e "  • More info: ${CYAN}https://github.com/Psiphon-Inc/conduit${NC}"
}

# Main health check
main() {
    show_header

    local all_checks_passed=true

    # Run all checks
    echo -e "${BOLD}${CYAN}═══ Running Health Checks ═══${NC}"
    echo ""

    if ! check_container_running; then
        all_checks_passed=false
        echo ""
        echo -e "${RED}${BOLD}Health check failed: Container not running${NC}"
        echo ""
        provide_recommendations
        exit 1
    fi
    echo ""

    check_container_resources
    echo ""

    check_data_directory
    echo ""

    check_psiphon_config
    echo ""

    check_port_configuration
    echo ""

    check_container_logs
    echo ""

    check_psiphon_connectivity
    echo ""

    check_network_from_container
    echo ""

    show_activity_summary
    echo ""

    # Final verdict
    echo -e "${BOLD}${CYAN}═══ Health Check Summary ═══${NC}"
    echo ""

    if [ "$all_checks_passed" = true ]; then
        echo -e "${GREEN}${BOLD}✓ Conduit appears to be running properly${NC}"
        echo ""
        echo -e "${CYAN}Note:${NC} Full functionality depends on:"
        echo -e "  • Valid Psiphon configuration"
        echo -e "  • Network connectivity to Psiphon infrastructure"
        echo -e "  • Broker reputation (builds over time)"
    else
        echo -e "${YELLOW}${BOLD}! Some checks indicated potential issues${NC}"
        echo -e "  Review the warnings above"
    fi

    echo ""
    provide_recommendations
}

# Run main function
main
