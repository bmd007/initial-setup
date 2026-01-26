#!/bin/bash

###############################################################################
# Conduit Connection Monitor
# Real-time visualization of Conduit connections with IP geolocation
#
# Features:
# - Shows active connections
# - Displays source IP addresses
# - Geographic location lookup (city, country)
# - Connection statistics
# - Live updates
#
# Usage: ./conduit-monitor.sh [refresh_interval]
# Example: ./conduit-monitor.sh 5  # Update every 5 seconds
###############################################################################

set -euo pipefail

# Configuration
REFRESH_INTERVAL="${1:-3}"  # Default 3 seconds
CONTAINER_NAME="conduit"
LOG_LINES=1000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Stats file (temporary)
STATS_FILE="/tmp/conduit-monitor-stats.txt"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get IP geolocation information
get_ip_location() {
    local ip=$1

    # Skip local/private IPs
    if [[ $ip =~ ^127\. ]] || [[ $ip =~ ^192\.168\. ]] || [[ $ip =~ ^10\. ]] || [[ $ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo "LOCAL"
        return
    fi

    # Try to get location from ip-api.com (free, no key required)
    local location
    location=$(curl -s --max-time 2 "http://ip-api.com/json/${ip}?fields=status,country,countryCode,city,lat,lon" 2>/dev/null)

    if [ -n "$location" ] && echo "$location" | jq -e '.status == "success"' >/dev/null 2>&1; then
        local city=$(echo "$location" | jq -r '.city // "Unknown"')
        local country=$(echo "$location" | jq -r '.country // "Unknown"')
        local country_code=$(echo "$location" | jq -r '.countryCode // "??"')
        local lat=$(echo "$location" | jq -r '.lat // "0"')
        local lon=$(echo "$location" | jq -r '.lon // "0"')

        echo "${city}, ${country} (${country_code}) [${lat},${lon}]"
    else
        echo "Unknown"
    fi
}

# Extract IPs from container logs
extract_connection_ips() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container '${CONTAINER_NAME}' is not running"
        return 1
    fi

    # Get recent logs and extract IP addresses
    # This regex captures IPv4 addresses from connection logs
    docker logs "$CONTAINER_NAME" --tail $LOG_LINES 2>&1 | \
        grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | \
        grep -v '^127\.' | \
        sort | uniq -c | sort -rn
}

# Get connection statistics
get_connection_stats() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        return 1
    fi

    local logs=$(docker logs "$CONTAINER_NAME" --tail $LOG_LINES 2>&1)

    # Count different types of events (adjust patterns based on actual Conduit logs)
    local total_connections=$(echo "$logs" | grep -c "connection\|connect\|established" 2>/dev/null || echo "0")
    local active_connections=$(docker exec "$CONTAINER_NAME" sh -c "netstat -an 2>/dev/null | grep -c ESTABLISHED" 2>/dev/null || echo "0")

    # Track incoming connection requests
    local incoming_requests=$(echo "$logs" | grep -ci "request\|incoming\|accept\|client" 2>/dev/null || echo "0")
    local successful_accepts=$(echo "$logs" | grep -ci "accepted\|connected" 2>/dev/null || echo "0")

    local errors=$(echo "$logs" | grep -c "error\|Error\|ERROR" 2>/dev/null || echo "0")
    local warnings=$(echo "$logs" | grep -c "warning\|Warning\|WARN" 2>/dev/null || echo "0")

    echo "$total_connections|$active_connections|$errors|$warnings|$incoming_requests|$successful_accepts"
}

# Display header
show_header() {
    clear
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}                    ${BOLD}Conduit Connection Monitor${NC}                          ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
    echo -e "${BLUE}Refresh:${NC} Every ${REFRESH_INTERVAL}s | ${BLUE}Press Ctrl+C to exit${NC}"
    echo -e "${BLUE}Time:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

# Display statistics summary
show_stats() {
    local stats=$1
    IFS='|' read -r total active errors warnings incoming_req successful <<< "$stats"

    echo -e "${BOLD}${MAGENTA}═══ Connection Statistics ═══${NC}"
    echo -e "${GREEN}●${NC} Total Connections (logged): ${BOLD}$total${NC}"
    echo -e "${GREEN}●${NC} Active Connections: ${BOLD}$active${NC}"
    echo -e "${CYAN}●${NC} Incoming Requests: ${BOLD}$incoming_req${NC}"
    echo -e "${CYAN}●${NC} Successful Accepts: ${BOLD}$successful${NC}"
    echo -e "${YELLOW}●${NC} Warnings: ${BOLD}$warnings${NC}"
    echo -e "${RED}●${NC} Errors: ${BOLD}$errors${NC}"

    # Show if receiving requests
    if [ "$incoming_req" -gt 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}✓ RECEIVING CONNECTION REQUESTS${NC}"
    else
        echo ""
        echo -e "${YELLOW}${BOLD}⚠ NO CONNECTION REQUESTS DETECTED${NC}"
        echo -e "${YELLOW}  This may be normal for new nodes (reputation building)${NC}"
    fi
    echo ""
}

# Display connection table
show_connections() {
    echo -e "${BOLD}${MAGENTA}═══ Active Source IPs ═══${NC}"
    echo -e "${BOLD}Count   IP Address       Location${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────${NC}"

    local count=0
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        local conn_count=$(echo "$line" | awk '{print $1}')
        local ip=$(echo "$line" | awk '{print $2}')

        # Get cached location or fetch new
        local cache_key="${ip}"
        local location=""

        if [ -f "$STATS_FILE" ] && grep -q "^${cache_key}|" "$STATS_FILE" 2>/dev/null; then
            location=$(grep "^${cache_key}|" "$STATS_FILE" | cut -d'|' -f2)
        else
            location=$(get_ip_location "$ip")
            echo "${cache_key}|${location}" >> "$STATS_FILE"
        fi

        # Color code based on location
        local ip_color=$GREEN
        if [ "$location" = "LOCAL" ]; then
            ip_color=$YELLOW
        elif [ "$location" = "Unknown" ]; then
            ip_color=$RED
        fi

        printf "${BOLD}%-7s${NC} ${ip_color}%-15s${NC} %s\n" "$conn_count" "$ip" "$location"

        count=$((count + 1))
        if [ $count -ge 20 ]; then
            echo -e "${YELLOW}... (showing top 20)${NC}"
            break
        fi
    done
}

# Display world map visualization (ASCII art)
show_map_visualization() {
    echo ""
    echo -e "${BOLD}${MAGENTA}═══ Geographic Distribution ═══${NC}"

    # Count connections by country
    if [ -f "$STATS_FILE" ]; then
        local countries=$(cut -d'|' -f2 "$STATS_FILE" | grep -oE '\([A-Z]{2}\)' | sort | uniq -c | sort -rn | head -10)

        if [ -n "$countries" ]; then
            echo -e "${BOLD}Top Countries:${NC}"
            while IFS= read -r line; do
                if [ -z "$line" ]; then
                    continue
                fi
                local count=$(echo "$line" | awk '{print $1}')
                local country=$(echo "$line" | awk '{print $2}')
                local bar=$(printf '█%.0s' $(seq 1 $((count > 20 ? 20 : count))))
                printf "${GREEN}%-6s${NC} ${CYAN}%-30s${NC}\n" "$country" "$bar $count"
            done <<< "$countries"
        else
            echo -e "${YELLOW}No geographic data available yet${NC}"
        fi
    fi
}

# Display recent connection requests
show_connection_requests() {
    echo ""
    echo -e "${BOLD}${MAGENTA}═══ Recent Connection Requests ═══${NC}"

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        local requests=$(docker logs "$CONTAINER_NAME" --tail 50 2>&1 | grep -i "request\|incoming\|accept\|client" | tail -10)

        if [ -n "$requests" ]; then
            echo "$requests" | while IFS= read -r line; do
                # Highlight different types of requests
                if echo "$line" | grep -qi "accept\|connected"; then
                    echo -e "${GREEN}✓${NC} ${line}"
                elif echo "$line" | grep -qi "request\|incoming"; then
                    echo -e "${CYAN}→${NC} ${line}"
                elif echo "$line" | grep -qi "reject\|denied"; then
                    echo -e "${RED}✗${NC} ${line}"
                else
                    echo -e "${NC}  ${line}"
                fi
            done
        else
            echo -e "${YELLOW}No connection requests in recent logs${NC}"
            echo -e "${YELLOW}Note: New Conduit nodes need time to build reputation${NC}"
            echo -e "${YELLOW}      It may take hours/days before receiving requests${NC}"
        fi
    fi
}

# Display recent connection activity
show_recent_activity() {
    echo ""
    echo -e "${BOLD}${MAGENTA}═══ Recent Activity (Last 10 Events) ═══${NC}"

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker logs "$CONTAINER_NAME" --tail 10 2>&1 | while IFS= read -r line; do
            # Color code log levels
            if echo "$line" | grep -qi "error"; then
                echo -e "${RED}${line}${NC}"
            elif echo "$line" | grep -qi "warn"; then
                echo -e "${YELLOW}${line}${NC}"
            elif echo "$line" | grep -qi "info"; then
                echo -e "${BLUE}${line}${NC}"
            else
                echo -e "${NC}${line}"
            fi
        done
    fi
}

# Main monitoring loop
monitor_loop() {
    # Install jq if not available (needed for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found, installing..."
        sudo apt-get update -qq && sudo apt-get install -y jq
    fi

    # Clean up old stats file
    rm -f "$STATS_FILE"

    log_info "Starting Conduit monitor..."
    log_info "Analyzing container logs and connections..."
    sleep 2

    while true; do
        # Display header
        show_header

        # Get and display statistics
        local stats=$(get_connection_stats)
        if [ -n "$stats" ]; then
            show_stats "$stats"
        fi

        # Extract and display connections
        local connections=$(extract_connection_ips)
        if [ -n "$connections" ]; then
            echo "$connections" | show_connections
        else
            echo -e "${YELLOW}No connections found in recent logs${NC}"
        fi

        # Show geographic distribution
        show_map_visualization

        # Show connection requests
        show_connection_requests

        # Show recent activity
        show_recent_activity

        # Wait for next refresh
        sleep "$REFRESH_INTERVAL"
    done
}

# Cleanup on exit
cleanup() {
    echo ""
    log_info "Cleaning up..."
    rm -f "$STATS_FILE"
    echo -e "${GREEN}Monitor stopped${NC}"
    exit 0
}

# Main execution
main() {
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Conduit container is not running!"
        log_info "Start Conduit first: cd ~/conduit && docker-compose up -d"
        exit 1
    fi

    # Set up signal handlers
    trap cleanup SIGINT SIGTERM

    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed!"
        log_info "Install it with: sudo apt-get install -y curl"
        exit 1
    fi

    # Start monitoring
    monitor_loop
}

# Run main function
main
