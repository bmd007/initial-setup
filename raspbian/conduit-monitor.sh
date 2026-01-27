#!/bin/bash

###############################################################################
# Conduit Real-Time Monitor
# Adapted for actual Conduit behavior and log patterns
#
# Features:
# - Shows broker communication status
# - Tracks announcement cycles
# - Monitors reputation building
# - Displays actual connection events
# - Real-time statistics
#
# Usage: ./conduit-monitor-adapted.sh [refresh_interval]
# Example: ./conduit-monitor-adapted.sh 5  # Update every 5 seconds
###############################################################################

set -euo pipefail

# Configuration
REFRESH_INTERVAL="${1:-5}"  # Default 5 seconds
CONTAINER_NAME="conduit"
LOG_LINES=2000

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
HISTORY_FILE="/tmp/conduit-monitor-history.txt"

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

# Get detailed Conduit statistics from real STATS logs
get_conduit_stats() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        return 1
    fi

    local logs=$(docker logs "$CONTAINER_NAME" --tail $LOG_LINES 2>&1)

    # Parse the latest STATS line
    # Format: [STATS] Connecting: X | Connected: Y | Up: Z | Down: W | Uptime: T
    local latest_stats=$(echo "$logs" | grep "\[STATS\]" | tail -1)

    local connecting=0
    local connected=0
    local up_bytes=0
    local down_bytes=0
    local uptime="0s"

    if [ -n "$latest_stats" ]; then
        # Extract Connecting count
        connecting=$(echo "$latest_stats" | grep -o "Connecting: [0-9]*" | grep -o "[0-9]*" || echo "0")

        # Extract Connected count
        connected=$(echo "$latest_stats" | grep -o "Connected: [0-9]*" | grep -o "[0-9]*" || echo "0")

        # Extract upload (convert to bytes)
        local up_raw=$(echo "$latest_stats" | grep -o "Up: [^|]*" | sed 's/Up: //' | xargs)
        up_bytes=$(parse_bytes "$up_raw")

        # Extract download (convert to bytes)
        local down_raw=$(echo "$latest_stats" | grep -o "Down: [^|]*" | sed 's/Down: //' | xargs)
        down_bytes=$(parse_bytes "$down_raw")

        # Extract uptime
        uptime=$(echo "$latest_stats" | grep -o "Uptime: [^|]*" | sed 's/Uptime: //' | xargs || echo "0s")
    fi

    # Check for connection status
    local psiphon_connected=$(echo "$logs" | grep -c "\[OK\] Connected to Psiphon network" 2>/dev/null || echo "0")

    # Count total STATS entries (activity indicator)
    local stats_count=$(echo "$logs" | grep -c "\[STATS\]" 2>/dev/null || echo "0")

    # Historical peak connections (from all STATS lines)
    local peak_connecting=$(echo "$logs" | grep "\[STATS\]" | grep -o "Connecting: [0-9]*" | grep -o "[0-9]*" | sort -rn | head -1 || echo "0")
    local peak_connected=$(echo "$logs" | grep "\[STATS\]" | grep -o "Connected: [0-9]*" | grep -o "[0-9]*" | sort -rn | head -1 || echo "0")

    # Error tracking
    local errors=$(echo "$logs" | grep -c "ERROR\|error" 2>/dev/null || echo "0")
    local warnings=$(echo "$logs" | grep -c "WARN\|warning" 2>/dev/null || echo "0")
    local fatals=$(echo "$logs" | grep -c "FATAL\|fatal\|panic" 2>/dev/null || echo "0")

    echo "$connecting|$connected|$up_bytes|$down_bytes|$uptime|$psiphon_connected|$stats_count|$peak_connecting|$peak_connected|$errors|$warnings|$fatals"
}

# Parse bandwidth strings to bytes
parse_bytes() {
    local str="$1"

    if [ -z "$str" ] || [ "$str" = "0 B" ]; then
        echo "0"
        return
    fi

    # Extract number and unit
    local num=$(echo "$str" | grep -o "^[0-9.]*")
    local unit=$(echo "$str" | grep -o "[A-Z]*B$")

    if [ -z "$num" ]; then
        echo "0"
        return
    fi

    # Convert to bytes
    case "$unit" in
        "B")
            echo "$num" | awk '{printf "%.0f", $1}'
            ;;
        "KB")
            echo "$num" | awk '{printf "%.0f", $1 * 1024}'
            ;;
        "MB")
            echo "$num" | awk '{printf "%.0f", $1 * 1024 * 1024}'
            ;;
        "GB")
            echo "$num" | awk '{printf "%.0f", $1 * 1024 * 1024 * 1024}'
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Calculate reputation score based on actual activity
calculate_reputation() {
    local connecting=$1
    local connected=$2
    local up_bytes=$3
    local down_bytes=$4
    local peak_connecting=$5
    local peak_connected=$6
    local errors=$7

    # Reputation factors:
    # + connected clients (most important)
    # + data transfer activity
    # + peak connections reached
    # + connecting attempts (shows you're being tried)
    # - errors hurt reputation

    local connected_score=$((connected * 20))
    local peak_score=$((peak_connected * 10))
    local connecting_score=$((connecting / 2))
    local transfer_score=0

    # Data transfer is a strong positive signal
    if [ $down_bytes -gt 1048576 ]; then  # > 1MB
        transfer_score=30
    elif [ $down_bytes -gt 10240 ]; then  # > 10KB
        transfer_score=15
    elif [ $down_bytes -gt 0 ]; then
        transfer_score=5
    fi

    local penalty=$((errors * 2))

    local total=$((connected_score + peak_score + connecting_score + transfer_score - penalty))

    # Normalize to 0-100
    if [ $total -lt 0 ]; then
        echo "0"
    elif [ $total -gt 100 ]; then
        echo "100"
    else
        echo "$total"
    fi
}

# Determine node status based on actual activity
get_node_status() {
    local connecting=$1
    local connected=$2
    local up_bytes=$3
    local down_bytes=$4
    local psiphon_connected=$5
    local errors=$6

    # Determine status based on actual activity
    if [ $connected -gt 0 ]; then
        if [ $down_bytes -gt 10240 ]; then  # > 10KB transferred
            echo "ACTIVE|Actively serving $connected client(s) - transferring data!"
        else
            echo "CONNECTED|$connected client(s) connected, establishing data flow"
        fi
    elif [ $connecting -gt 0 ]; then
        echo "CONNECTING|$connecting client(s) connecting - waiting for handshake"
    elif [ $psiphon_connected -gt 0 ]; then
        echo "READY|Connected to Psiphon - waiting for clients"
    elif [ $errors -gt 10 ]; then
        echo "ERROR|Experiencing errors, check logs"
    else
        echo "STARTING|Initializing connection to Psiphon network"
    fi
}

# Display header
show_header() {
    clear
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}                  ${BOLD}Conduit Real-Time Monitor${NC}                            ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}║${NC}              ${BLUE}Tracking Broker Communication & Activity${NC}                    ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
    echo -e "${BLUE}Refresh:${NC} Every ${REFRESH_INTERVAL}s | ${BLUE}Press Ctrl+C to exit${NC}"
    echo -e "${BLUE}Time:${NC} $(date '+%Y-%m-%d %H:%M:%S')"

    # Get uptime
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        local started=$(docker inspect -f '{{.State.StartedAt}}' conduit 2>/dev/null | cut -d'.' -f1)
        local uptime=$(docker inspect -f '{{.State.StartedAt}}' conduit 2>/dev/null)
        if [ -n "$started" ]; then
            echo -e "${BLUE}Uptime:${NC} Started at $started"
        fi
    fi
    echo ""
}

# Display node status dashboard
show_node_status() {
    local stats=$1
    IFS='|' read -r connecting connected up_bytes down_bytes uptime psiphon_connected stats_count peak_connecting peak_connected errors warnings fatals <<< "$stats"

    # Get status
    local status_info=$(get_node_status "$connecting" "$connected" "$up_bytes" "$down_bytes" "$psiphon_connected" "$errors")
    local status=$(echo "$status_info" | cut -d'|' -f1)
    local status_desc=$(echo "$status_info" | cut -d'|' -f2)

    # Calculate reputation
    local reputation=$(calculate_reputation "$connecting" "$connected" "$up_bytes" "$down_bytes" "$peak_connecting" "$peak_connected" "$errors")

    echo -e "${BOLD}${MAGENTA}═══ Node Status ═══${NC}"

    # Status with color coding
    case $status in
        "ACTIVE")
            echo -e "${BOLD}Status:${NC} ${GREEN}${BOLD}● $status${NC}"
            echo -e "${GREEN}$status_desc${NC}"
            ;;
        "CONNECTED")
            echo -e "${BOLD}Status:${NC} ${CYAN}${BOLD}● $status${NC}"
            echo -e "${CYAN}$status_desc${NC}"
            ;;
        "CONNECTING")
            echo -e "${BOLD}Status:${NC} ${YELLOW}${BOLD}● $status${NC}"
            echo -e "${YELLOW}$status_desc${NC}"
            ;;
        "READY")
            echo -e "${BOLD}Status:${NC} ${BLUE}${BOLD}● $status${NC}"
            echo -e "${BLUE}$status_desc${NC}"
            ;;
        "ERROR")
            echo -e "${BOLD}Status:${NC} ${RED}${BOLD}● $status${NC}"
            echo -e "${RED}$status_desc${NC}"
            ;;
        *)
            echo -e "${BOLD}Status:${NC} ${BLUE}${BOLD}● $status${NC}"
            echo -e "${BLUE}$status_desc${NC}"
            ;;
    esac

    # Reputation bar
    echo ""
    echo -e "${BOLD}Estimated Reputation:${NC}"
    local bar_length=$((reputation / 5))
    local bar=$(printf '█%.0s' $(seq 1 $bar_length))
    local empty=$(printf '░%.0s' $(seq 1 $((20 - bar_length))))

    if [ $reputation -ge 70 ]; then
        echo -e "${GREEN}${bar}${NC}${empty} ${BOLD}${reputation}%${NC} ${GREEN}(Excellent)${NC}"
    elif [ $reputation -ge 40 ]; then
        echo -e "${YELLOW}${bar}${NC}${empty} ${BOLD}${reputation}%${NC} ${YELLOW}(Building)${NC}"
    else
        echo -e "${RED}${bar}${NC}${empty} ${BOLD}${reputation}%${NC} ${RED}(Starting)${NC}"
    fi

    # Show uptime from STATS
    if [ -n "$uptime" ] && [ "$uptime" != "0s" ]; then
        echo -e "${CYAN}●${NC} Conduit Uptime: ${BOLD}$uptime${NC}"
    fi
    echo ""
}

# Display broker communication statistics
show_connection_stats() {
    local stats=$1
    IFS='|' read -r connecting connected up_bytes down_bytes uptime psiphon_connected stats_count peak_connecting peak_connected errors warnings fatals <<< "$stats"

    echo -e "${BOLD}${MAGENTA}═══ Connection Statistics ═══${NC}"

    # Psiphon connection status
    if [ $psiphon_connected -gt 0 ]; then
        echo -e "${GREEN}${BOLD}✓ CONNECTED TO PSIPHON NETWORK${NC}"
        echo ""
    else
        echo -e "${YELLOW}${BOLD}⚠ CONNECTING TO PSIPHON NETWORK${NC}"
        echo ""
    fi

    # Current connections
    echo -e "${BOLD}Current:${NC}"
    echo -e "${CYAN}●${NC} Connecting clients:     ${BOLD}$connecting${NC}"
    echo -e "${GREEN}●${NC} Connected clients:      ${BOLD}$connected${NC}"

    # Peak connections
    if [ $peak_connecting -gt 0 ] || [ $peak_connected -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Peak (this session):${NC}"
        echo -e "${CYAN}●${NC} Peak connecting:        ${BOLD}$peak_connecting${NC}"
        echo -e "${GREEN}●${NC} Peak connected:         ${BOLD}$peak_connected${NC}"
    fi

    # Data transfer
    if [ $up_bytes -gt 0 ] || [ $down_bytes -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Data Transfer:${NC}"
        # Format bytes with fallback if numfmt not available
        local up_formatted=$(numfmt --to=iec-i --suffix=B $up_bytes 2>/dev/null || echo "${up_bytes}B")
        local down_formatted=$(numfmt --to=iec-i --suffix=B $down_bytes 2>/dev/null || echo "${down_bytes}B")
        echo -e "${GREEN}●${NC} Uploaded:               ${BOLD}${up_formatted}${NC}"
        echo -e "${GREEN}●${NC} Downloaded:             ${BOLD}${down_formatted}${NC}"

        # Show if actively transferring data
        if [ $down_bytes -gt 10240 ]; then
            echo ""
            echo -e "${GREEN}${BOLD}✓ ACTIVELY TRANSFERRING DATA${NC}"
            echo -e "${GREEN}  Your node is helping users bypass censorship!${NC}"
        fi
    fi

    # STATS activity indicator
    if [ $stats_count -gt 0 ]; then
        echo ""
        echo -e "${BLUE}●${NC} Stats updates:          ${BOLD}$stats_count${NC} (activity indicator)"
    fi

    echo ""
}

# Display error summary
show_error_summary() {
    local stats=$1
    IFS='|' read -r connecting connected up_bytes down_bytes uptime psiphon_connected stats_count peak_connecting peak_connected errors warnings fatals <<< "$stats"

    echo -e "${BOLD}${MAGENTA}═══ Health Summary ═══${NC}"

    if [ $fatals -gt 0 ]; then
        echo -e "${RED}${BOLD}✗ CRITICAL ERRORS: $fatals${NC}"
        echo -e "${RED}  Check logs immediately!${NC}"
    elif [ $errors -gt 20 ]; then
        echo -e "${RED}●${NC} Errors:   ${BOLD}${RED}$errors${NC} ${RED}(High - investigate)${NC}"
    elif [ $errors -gt 0 ]; then
        echo -e "${YELLOW}●${NC} Errors:   ${BOLD}$errors${NC} ${YELLOW}(Some errors normal)${NC}"
    else
        echo -e "${GREEN}●${NC} Errors:   ${BOLD}$errors${NC} ${GREEN}(None)${NC}"
    fi

    if [ $warnings -gt 50 ]; then
        echo -e "${YELLOW}●${NC} Warnings: ${BOLD}$warnings${NC} ${YELLOW}(High)${NC}"
    else
        echo -e "${BLUE}●${NC} Warnings: ${BOLD}$warnings${NC}"
    fi

    echo ""
}

# Show recent log events with smart filtering
show_recent_events() {
    echo -e "${BOLD}${MAGENTA}═══ Recent Events (Last 15 Lines) ═══${NC}"

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker logs "$CONTAINER_NAME" --tail 15 2>&1 | while IFS= read -r line; do
            # Color code based on content
            if echo "$line" | grep -qi "fatal\|panic"; then
                echo -e "${RED}${BOLD}[FATAL]${NC} ${RED}${line}${NC}"
            elif echo "$line" | grep -qi "error"; then
                echo -e "${RED}[ERROR]${NC} ${line}"
            elif echo "$line" | grep -qi "warn"; then
                echo -e "${YELLOW}[WARN]${NC} ${line}"
            elif echo "$line" | grep -qi "\[STATS\]"; then
                # Highlight STATS lines in cyan
                echo -e "${CYAN}[STATS]${NC} ${line}"
            elif echo "$line" | grep -qi "\[OK\] Connected to Psiphon"; then
                echo -e "${GREEN}${BOLD}[OK]${NC} ${GREEN}${line}${NC}"
            elif echo "$line" | grep -qi "Starting.*Conduit"; then
                echo -e "${BLUE}[START]${NC} ${line}"
            else
                echo -e "${NC}${line}"
            fi
        done
    fi
    echo ""
}

# Track historical trends
update_history() {
    local stats=$1
    local timestamp=$(date +%s)

    echo "$timestamp|$stats" >> "$HISTORY_FILE"

    # Keep only last 1000 entries
    tail -1000 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null || true
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null || true
}

# Show trend analysis
show_trends() {
    if [ ! -f "$HISTORY_FILE" ]; then
        return
    fi

    local entries=$(wc -l < "$HISTORY_FILE")
    if [ $entries -lt 10 ]; then
        return
    fi

    echo -e "${BOLD}${MAGENTA}═══ Trend Analysis ═══${NC}"

    # Get first and last entry
    local first=$(head -1 "$HISTORY_FILE")
    local last=$(tail -1 "$HISTORY_FILE")

    # Parse connecting from first and last (field 2)
    local first_connecting=$(echo "$first" | cut -d'|' -f2)
    local last_connecting=$(echo "$last" | cut -d'|' -f2)
    local connecting_change=$((last_connecting - first_connecting))

    # Parse connected from first and last (field 3)
    local first_connected=$(echo "$first" | cut -d'|' -f3)
    local last_connected=$(echo "$last" | cut -d'|' -f3)
    local connected_change=$((last_connected - first_connected))

    # Parse down_bytes from first and last (field 5)
    local first_down=$(echo "$first" | cut -d'|' -f5)
    local last_down=$(echo "$last" | cut -d'|' -f5)
    local down_change=$((last_down - first_down))

    if [ $connected_change -gt 0 ]; then
        echo -e "${GREEN}●${NC} Connected clients increased: ${GREEN}${BOLD}+$connected_change${NC}"
    fi

    if [ $connecting_change -gt 0 ]; then
        echo -e "${CYAN}●${NC} Connecting clients increased: ${CYAN}${BOLD}+$connecting_change${NC}"
    fi

    if [ $down_change -gt 10240 ]; then  # > 10KB
        local down_formatted=$(numfmt --to=iec-i --suffix=B $down_change 2>/dev/null || echo "${down_change}B")
        echo -e "${GREEN}●${NC} Data transferred: ${GREEN}${BOLD}+$down_formatted${NC}"
    fi

    if [ $connected_change -eq 0 ] && [ $down_change -eq 0 ]; then
        echo -e "${YELLOW}●${NC} Waiting for first connections..."
        echo -e "${YELLOW}  Keep your node running to build reputation${NC}"
    fi

    echo ""
}

# Main monitoring loop
monitor_loop() {
    # Clean up old files
    rm -f "$STATS_FILE"

    log_info "Starting Conduit Real-Time Monitor..."
    log_info "Analyzing Conduit-specific logs and behavior..."
    sleep 2

    while true; do
        # Display header
        show_header

        # Get and display statistics
        local stats=$(get_conduit_stats)
        if [ -n "$stats" ]; then
            show_node_status "$stats"
            show_connection_stats "$stats"
            show_error_summary "$stats"
            update_history "$stats"
            show_trends
        fi

        # Show recent events
        show_recent_events

        # Helpful tips at the bottom
        echo -e "${BOLD}${BLUE}═══ Tips ═══${NC}"
        echo -e "${BLUE}●${NC} Monitor the ${CYAN}[STATS]${NC} lines to see real-time activity"
        echo -e "${BLUE}●${NC} ${GREEN}Connected > 0${NC} means users are being helped right now!"
        echo -e "${BLUE}●${NC} It can take hours or days before your first client connection"
        echo -e "${BLUE}●${NC} Keep your node running 24/7 to build reputation"
        echo -e "${BLUE}●${NC} High uptime = better reputation = more connections"

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
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM

    # Start monitoring
    monitor_loop
}

# Run main function
main
