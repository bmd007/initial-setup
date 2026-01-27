#!/bin/bash

# Conduit Real-Time Monitor (Fixed Version)
# Tracking Broker Communication & Activity

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Cursor control
CURSOR_HOME='\033[H'      # Move cursor to home position
CURSOR_SAVE='\033[s'      # Save cursor position
CURSOR_RESTORE='\033[u'   # Restore cursor position
CLEAR_LINE='\033[2K'      # Clear entire line
HIDE_CURSOR='\033[?25l'   # Hide cursor
SHOW_CURSOR='\033[?25h'   # Show cursor

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-conduit}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-5}"
LOG_LINES="${LOG_LINES:-15}"
REPUTATION_TARGET=100

# Previous values for smooth transitions
PREV_CONNECTING=0
PREV_CONNECTED=0
PREV_UPLOAD=0
PREV_DOWNLOAD=0
PREV_REPUTATION=0
FIRST_RUN=true

# Detect if we're over SSH or have a proper terminal
IS_SSH=false
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ]; then
    IS_SSH=true
fi

# Check if terminal supports ANSI
HAS_ANSI=true
if [ ! -t 1 ] || [ "${TERM:-}" = "dumb" ]; then
    HAS_ANSI=false
fi

# Function to safely get numeric value with default
get_numeric() {
    local value="$1"
    local default="${2:-0}"

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Function to safely compare numeric values
safe_compare() {
    local val1="${1:-0}"
    local val2="${2:-0}"
    local operator="$3"

    # Ensure values are numeric
    val1=$(get_numeric "$val1" 0)
    val2=$(get_numeric "$val2" 0)

    case "$operator" in
        "-gt") [[ "$val1" -gt "$val2" ]] ;;
        "-ge") [[ "$val1" -ge "$val2" ]] ;;
        "-lt") [[ "$val1" -lt "$val2" ]] ;;
        "-le") [[ "$val1" -le "$val2" ]] ;;
        "-eq") [[ "$val1" -eq "$val2" ]] ;;
        "-ne") [[ "$val1" -ne "$val2" ]] ;;
        *) return 1 ;;
    esac
}

# Function to extract metrics from logs
extract_metrics() {
    local logs="$1"

    # Initialize all variables with defaults
    connecting_clients=0
    connected_clients=0
    upload_mb=0
    download_mb=0
    uptime="0s"
    error_count=0
    warning_count=0

    # Extract values using grep and sed
    if echo "$logs" | grep -q "Connecting:"; then
        connecting_clients=$(echo "$logs" | grep -o "Connecting: [0-9]*" | tail -1 | grep -o "[0-9]*" | head -1)
        connecting_clients=$(get_numeric "$connecting_clients" 0)
    fi

    if echo "$logs" | grep -q "Connected:"; then
        connected_clients=$(echo "$logs" | grep -o "Connected: [0-9]*" | tail -1 | grep -o "[0-9]*" | head -1)
        connected_clients=$(get_numeric "$connected_clients" 0)
    fi

    if echo "$logs" | grep -q "Up:"; then
        upload_mb=$(echo "$logs" | grep -o "Up: [0-9.]*" | tail -1 | grep -o "[0-9.]*" | head -1)
        upload_mb=$(get_numeric "${upload_mb%.*}" 0)
    fi

    if echo "$logs" | grep -q "Down:"; then
        download_mb=$(echo "$logs" | grep -o "Down: [0-9.]*" | tail -1 | grep -o "[0-9.]*" | head -1)
        download_mb=$(get_numeric "${download_mb%.*}" 0)
    fi

    if echo "$logs" | grep -q "Uptime:"; then
        uptime=$(echo "$logs" | grep -o "Uptime: [^|]*" | tail -1 | sed 's/Uptime: //' | xargs)
    fi

    # Count errors and warnings
    error_count=$(echo "$logs" | grep -c "\[ERROR\]" || echo "0")
    error_count=$(get_numeric "$error_count" 0)

    warning_count=$(echo "$logs" | grep -c "\[WARN\]" || echo "0")
    warning_count=$(get_numeric "$warning_count" 0)
}

# Function to calculate estimated reputation
calculate_reputation() {
    local connected="$1"
    local upload="$2"

    connected=$(get_numeric "$connected" 0)
    upload=$(get_numeric "$upload" 0)

    # Simple reputation estimation
    local rep=0

    # Reputation based on connections (max 50 points)
    if safe_compare "$connected" 0 "-gt"; then
        if safe_compare "$connected" 100 "-ge"; then
            rep=50
        else
            rep=$((connected / 2))
        fi
    fi

    # Reputation based on upload (max 50 points)
    if safe_compare "$upload" 0 "-gt"; then
        if safe_compare "$upload" 100 "-ge"; then
            rep=$((rep + 50))
        else
            rep=$((rep + upload / 2))
        fi
    fi

    echo "$rep"
}

# Function to get status indicator
get_status() {
    local connected="$1"
    local error_count="$2"

    connected=$(get_numeric "$connected" 0)
    error_count=$(get_numeric "$error_count" 0)

    if safe_compare "$connected" 0 "-gt"; then
        echo -e "${GREEN}● ACTIVE${NC}"
    elif safe_compare "$error_count" 10 "-gt"; then
        echo -e "${RED}● ERROR${NC}"
    else
        echo -e "${YELLOW}● STARTING${NC}"
    fi
}

# Function to display the dashboard
display_dashboard() {
    # On SSH or first run, use clear command for better compatibility
    # Otherwise use cursor positioning for smoother updates
    if [ "$FIRST_RUN" = true ]; then
        clear
        if [ "$HAS_ANSI" = true ]; then
            echo -e "${HIDE_CURSOR}"
        fi
        FIRST_RUN=false
    elif [ "$IS_SSH" = true ]; then
        # Over SSH, use clear for better reliability
        clear
    else
        # Local terminal, use cursor positioning
        echo -e "${CURSOR_HOME}"
    fi

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Container '${CONTAINER_NAME}' is not running!${NC}"
        echo "Press Ctrl+C to exit"
        return 1
    fi

    # Get container info
    local container_id=$(docker ps -qf "name=^${CONTAINER_NAME}$")
    local image=$(docker inspect -f '{{.Config.Image}}' "$container_id" 2>/dev/null || echo "unknown")
    local started=$(docker inspect -f '{{.State.StartedAt}}' "$container_id" 2>/dev/null | cut -d'.' -f1 || echo "unknown")

    # Get recent logs
    local logs=$(docker logs "$CONTAINER_NAME" --tail 100 2>&1)

    # Extract metrics
    extract_metrics "$logs"

    # Use previous values if current ones are empty/zero (smooths out transitions)
    if safe_compare "$connecting_clients" 0 "-eq" && safe_compare "$PREV_CONNECTING" 0 "-gt"; then
        connecting_clients=$PREV_CONNECTING
    fi
    if safe_compare "$connected_clients" 0 "-eq" && safe_compare "$PREV_CONNECTED" 0 "-gt"; then
        connected_clients=$PREV_CONNECTED
    fi

    # Update previous values for next iteration
    PREV_CONNECTING=$connecting_clients
    PREV_CONNECTED=$connected_clients
    PREV_UPLOAD=$upload_mb
    PREV_DOWNLOAD=$download_mb

    # Calculate reputation
    local reputation=$(calculate_reputation "$connected_clients" "$upload_mb")
    local reputation_percent=$((reputation * 100 / REPUTATION_TARGET))
    if safe_compare "$reputation_percent" 100 "-gt"; then
        reputation_percent=100
    fi

    PREV_REPUTATION=$reputation

    # Get status
    local status=$(get_status "$connected_clients" "$error_count")

    # Header - use simpler characters over SSH
    if [ "$IS_SSH" = true ]; then
        echo "===================================================================="
        echo "              Conduit Real-Time Monitor"
        echo "          Tracking Broker Communication & Activity"
        echo "===================================================================="
    else
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}              ${BLUE}Conduit Real-Time Monitor${NC}                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}          ${MAGENTA}Tracking Broker Communication & Activity${NC}             ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    fi
    echo ""

    # Container info
    echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
    echo -e "${BLUE}Refresh:${NC} Every ${REFRESH_INTERVAL}s | ${BLUE}Press Ctrl+C to exit${NC}"
    echo -e "${BLUE}Time:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BLUE}Uptime:${NC} Started at $started"
    echo ""

    # Node Status
    if [ "$IS_SSH" = true ]; then
        echo "---- Node Status ----"
    else
        echo -e "${MAGENTA}━━━━ Node Status ━━━━${NC}"
    fi
    echo -e "${BLUE}Status:${NC} $status"
    echo -e "${BLUE}Initializing connection to Psiphon network${NC}"
    echo ""

    # Estimated Reputation
    local bar_length=40
    local filled_length=$((reputation_percent * bar_length / 100))
    local bar=""
    for ((i=0; i<filled_length; i++)); do bar="${bar}█"; done
    for ((i=filled_length; i<bar_length; i++)); do bar="${bar}░"; done

    local rep_color=$GREEN
    if safe_compare "$reputation_percent" 30 "-lt"; then
        rep_color=$RED
    elif safe_compare "$reputation_percent" 70 "-lt"; then
        rep_color=$YELLOW
    fi

    echo -e "${BLUE}Estimated Reputation:${NC}"
    echo -e "${rep_color}${bar}${NC} ${reputation_percent}% ${YELLOW}(Starting)${NC}"
    echo ""

    # Connection Statistics
    if [ "$IS_SSH" = true ]; then
        echo "---- Connection Statistics ----"
    else
        echo -e "${MAGENTA}━━━━ Connection Statistics ━━━━${NC}"
    fi

    local status_indicator=$YELLOW
    if safe_compare "$connected_clients" 0 "-gt"; then
        status_indicator=$GREEN
    fi

    echo -e "${BLUE}⚡ CONNECTING TO PSIPHON NETWORK${NC}"
    echo ""
    echo -e "${BLUE}Current:${NC}"
    echo -e "  ${status_indicator}●${NC} Connecting clients:    ${connecting_clients}"
    echo -e "  ${status_indicator}●${NC} Connected clients:     ${connected_clients}"
    echo ""

    # Health Summary
    if [ "$IS_SSH" = true ]; then
        echo "---- Health Summary ----"
    else
        echo -e "${MAGENTA}━━━━ Health Summary ━━━━${NC}"
    fi

    local error_indicator=$GREEN
    if safe_compare "$error_count" 0 "-gt"; then
        error_indicator=$YELLOW
    fi

    echo -e "  ${error_indicator}●${NC} Errors:    ${YELLOW}(None)${NC}"
    echo -e "  ${GREEN}●${NC} Warnings:"
    echo ""

    # Trend Analysis
    if [ "$IS_SSH" = true ]; then
        echo "---- Trend Analysis ----"
    else
        echo -e "${MAGENTA}━━━━ Trend Analysis ━━━━${NC}"
    fi
    echo ""

    if [ "$IS_SSH" = true ]; then
        echo "---- Recent Events (Last ${LOG_LINES} Lines) ----"
    else
        echo -e "${MAGENTA}━━━━ Recent Events (Last ${LOG_LINES} Lines) ━━━━${NC}"
    fi

    # Display recent events with color coding
    local recent_logs=$(echo "$logs" | tail -n "$LOG_LINES")

    while IFS= read -r line; do
        if [[ "$line" =~ \[ERROR\] ]]; then
            # Check if it's a "safe" error (limited/no match)
            if [[ "$line" =~ "limited" ]] || [[ "$line" =~ "no match" ]]; then
                echo -e "${YELLOW}[INFO]${NC} ${line#*\[ERROR\]}"
            else
                echo -e "${RED}[ERROR]${NC} ${line#*\[ERROR\]}"
            fi
        elif [[ "$line" =~ \[WARN\] ]]; then
            echo -e "${YELLOW}[WARN]${NC} ${line#*\[WARN\]}"
        elif [[ "$line" =~ \[STATS\] ]]; then
            echo -e "${GREEN}[STATS]${NC} ${line#*\[STATS\]}"
        else
            echo "$line"
        fi
    done <<< "$recent_logs"

    echo ""
    if [ "$IS_SSH" = true ]; then
        echo "---- Tips ----"
    else
        echo -e "${MAGENTA}━━━━ Tips ━━━━${NC}"
    fi
    echo -e "${CYAN}💡 'limited' and 'no match' messages are normal - they mean your node is"
    echo -e "   properly announcing itself to the broker but no clients need connections yet.${NC}"
    echo ""
}

# Main loop
echo -e "${BLUE}Starting Conduit Real-Time Monitor...${NC}"
echo -e "${BLUE}Monitoring container: ${CONTAINER_NAME}${NC}"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container '${CONTAINER_NAME}' does not exist${NC}"
    exit 1
fi

# Trap Ctrl+C for clean exit
cleanup() {
    echo ""
    if [ "$HAS_ANSI" = true ]; then
        echo -e "${SHOW_CURSOR}"
    fi
    echo -e "${BLUE}Stopping monitor...${NC}"
    # Reset terminal
    tput sgr0 2>/dev/null || true
    exit 0
}
trap cleanup INT TERM

# Main monitoring loop
while true; do
    display_dashboard

    # Flush output to ensure everything is written
    # This is especially important over SSH
    if [ "$IS_SSH" = true ]; then
        # Small delay to ensure terminal catches up
        sleep 0.1
    fi

    sleep "$REFRESH_INTERVAL"
done
