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

# Get detailed Conduit statistics
get_conduit_stats() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        return 1
    fi

    local logs=$(docker logs "$CONTAINER_NAME" --tail $LOG_LINES 2>&1)
    
    # Count Conduit-specific events
    local announced=$(echo "$logs" | grep -ci "announc" 2>/dev/null || echo "0")
    local limited=$(echo "$logs" | grep -ci "limited" 2>/dev/null || echo "0")
    local no_match=$(echo "$logs" | grep -ci "no match" 2>/dev/null || echo "0")
    local matched=$(echo "$logs" | grep -ci "matched\|match.*client" 2>/dev/null || echo "0")
    local relay=$(echo "$logs" | grep -ci "relay\|relaying\|proxying" 2>/dev/null || echo "0")
    local connected=$(echo "$logs" | grep -ci "connected.*client\|client.*connected" 2>/dev/null || echo "0")
    local disconnected=$(echo "$logs" | grep -ci "disconnect\|closed.*connection" 2>/dev/null || echo "0")
    
    # Broker communication
    local broker_contact=$(echo "$logs" | grep -ci "broker\|contacting\|registering" 2>/dev/null || echo "0")
    
    # WebRTC specific
    local webrtc_offer=$(echo "$logs" | grep -ci "offer\|sdp" 2>/dev/null || echo "0")
    local webrtc_answer=$(echo "$logs" | grep -ci "answer" 2>/dev/null || echo "0")
    local ice_candidate=$(echo "$logs" | grep -ci "ice.*candidate\|candidate.*ice" 2>/dev/null || echo "0")
    
    # Error tracking
    local errors=$(echo "$logs" | grep -c "ERROR\|error" 2>/dev/null || echo "0")
    local warnings=$(echo "$logs" | grep -c "WARN\|warning" 2>/dev/null || echo "0")
    local fatals=$(echo "$logs" | grep -c "FATAL\|fatal\|panic" 2>/dev/null || echo "0")
    
    # Data transfer indicators
    local bytes_sent=$(echo "$logs" | grep -o "sent [0-9]* bytes\|[0-9]* bytes sent" 2>/dev/null | grep -o "[0-9]*" | awk '{sum+=$1} END {print sum+0}')
    local bytes_recv=$(echo "$logs" | grep -o "received [0-9]* bytes\|[0-9]* bytes received" 2>/dev/null | grep -o "[0-9]*" | awk '{sum+=$1} END {print sum+0}')
    
    echo "$announced|$limited|$no_match|$matched|$relay|$connected|$disconnected|$broker_contact|$webrtc_offer|$webrtc_answer|$ice_candidate|$errors|$warnings|$fatals|$bytes_sent|$bytes_recv"
}

# Calculate reputation score (estimated)
calculate_reputation() {
    local announced=$1
    local limited=$2
    local no_match=$3
    local matched=$4
    local relay=$5
    local errors=$6
    
    # Reputation factors:
    # + announcements show activity
    # + limited/no_match show broker communication (good!)
    # + matched connections are excellent
    # + relay activity is the best
    # - errors hurt reputation
    
    local communication_score=$((announced + limited + no_match))
    local activity_score=$((matched * 10 + relay * 20))
    local penalty=$((errors * 2))
    
    local total=$((communication_score + activity_score - penalty))
    
    # Normalize to 0-100
    if [ $total -lt 0 ]; then
        echo "0"
    elif [ $total -gt 1000 ]; then
        echo "100"
    else
        echo $((total / 10))
    fi
}

# Determine node status
get_node_status() {
    local announced=$1
    local limited=$2
    local no_match=$3
    local matched=$4
    local relay=$5
    local broker_contact=$6
    local errors=$7
    
    if [ $relay -gt 0 ]; then
        echo "ACTIVE|Actively relaying traffic for clients"
    elif [ $matched -gt 0 ]; then
        echo "MATCHED|Matched with clients, establishing connections"
    elif [ $limited -gt 0 ] || [ $no_match -gt 0 ]; then
        echo "READY|Communicating with broker, waiting for clients"
    elif [ $announced -gt 0 ] || [ $broker_contact -gt 0 ]; then
        echo "ANNOUNCING|Registering with Psiphon network"
    elif [ $errors -gt 10 ]; then
        echo "ERROR|Experiencing errors, check logs"
    else
        echo "STARTING|Container starting up"
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
    IFS='|' read -r announced limited no_match matched relay connected disconnected broker_contact webrtc_offer webrtc_answer ice_candidate errors warnings fatals bytes_sent bytes_recv <<< "$stats"
    
    # Get status
    local status_info=$(get_node_status "$announced" "$limited" "$no_match" "$matched" "$relay" "$broker_contact" "$errors")
    local status=$(echo "$status_info" | cut -d'|' -f1)
    local status_desc=$(echo "$status_info" | cut -d'|' -f2)
    
    # Calculate reputation
    local reputation=$(calculate_reputation "$announced" "$limited" "$no_match" "$matched" "$relay" "$errors")
    
    echo -e "${BOLD}${MAGENTA}═══ Node Status ═══${NC}"
    
    # Status with color coding
    case $status in
        "ACTIVE")
            echo -e "${BOLD}Status:${NC} ${GREEN}${BOLD}● $status${NC}"
            echo -e "${GREEN}$status_desc${NC}"
            ;;
        "MATCHED")
            echo -e "${BOLD}Status:${NC} ${CYAN}${BOLD}● $status${NC}"
            echo -e "${CYAN}$status_desc${NC}"
            ;;
        "READY")
            echo -e "${BOLD}Status:${NC} ${YELLOW}${BOLD}● $status${NC}"
            echo -e "${YELLOW}$status_desc${NC}"
            ;;
        "ANNOUNCING")
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
    echo ""
}

# Display broker communication statistics
show_broker_stats() {
    local stats=$1
    IFS='|' read -r announced limited no_match matched relay connected disconnected broker_contact webrtc_offer webrtc_answer ice_candidate errors warnings fatals bytes_sent bytes_recv <<< "$stats"
    
    echo -e "${BOLD}${MAGENTA}═══ Broker Communication ═══${NC}"
    echo -e "${CYAN}●${NC} Announcements sent:     ${BOLD}$announced${NC}"
    echo -e "${CYAN}●${NC} Broker contacts:        ${BOLD}$broker_contact${NC}"
    
    # Rate limiting is GOOD - it means you're being heard!
    if [ $limited -gt 0 ]; then
        echo -e "${GREEN}●${NC} Rate limited responses: ${BOLD}${GREEN}$limited${NC} ${GREEN}✓ (Good!)${NC}"
    else
        echo -e "${YELLOW}●${NC} Rate limited responses: ${BOLD}$limited${NC}"
    fi
    
    # No match is also GOOD - broker is responding
    if [ $no_match -gt 0 ]; then
        echo -e "${GREEN}●${NC} No match responses:     ${BOLD}${GREEN}$no_match${NC} ${GREEN}✓ (Good!)${NC}"
    else
        echo -e "${YELLOW}●${NC} No match responses:     ${BOLD}$no_match${NC}"
    fi
    
    # Interpretation
    local total_responses=$((limited + no_match))
    if [ $total_responses -gt 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}✓ BROKER COMMUNICATION WORKING${NC}"
        echo -e "${GREEN}  Your node is registered and responding to broker queries${NC}"
    else
        echo ""
        echo -e "${YELLOW}${BOLD}⚠ WAITING FOR BROKER RESPONSES${NC}"
        echo -e "${YELLOW}  This is normal when just starting - be patient${NC}"
    fi
    echo ""
}

# Display connection activity
show_connection_activity() {
    local stats=$1
    IFS='|' read -r announced limited no_match matched relay connected disconnected broker_contact webrtc_offer webrtc_answer ice_candidate errors warnings fatals bytes_sent bytes_recv <<< "$stats"
    
    echo -e "${BOLD}${MAGENTA}═══ Connection Activity ═══${NC}"
    
    if [ $matched -gt 0 ] || [ $relay -gt 0 ] || [ $connected -gt 0 ]; then
        echo -e "${GREEN}${BOLD}✓ YOUR NODE IS HELPING USERS!${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}●${NC} Client matches:         ${BOLD}$matched${NC}"
    echo -e "${CYAN}●${NC} Active relays:          ${BOLD}$relay${NC}"
    echo -e "${GREEN}●${NC} Clients connected:      ${BOLD}$connected${NC}"
    echo -e "${BLUE}●${NC} Clients disconnected:   ${BOLD}$disconnected${NC}"
    
    echo ""
    echo -e "${BOLD}WebRTC Signaling:${NC}"
    echo -e "${CYAN}●${NC} Offers sent/received:   ${BOLD}$webrtc_offer${NC}"
    echo -e "${CYAN}●${NC} Answers sent/received:  ${BOLD}$webrtc_answer${NC}"
    echo -e "${CYAN}●${NC} ICE candidates:         ${BOLD}$ice_candidate${NC}"
    
    # Data transfer
    if [ $bytes_sent -gt 0 ] || [ $bytes_recv -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Data Transfer:${NC}"
        echo -e "${GREEN}●${NC} Bytes sent:             ${BOLD}$(numfmt --to=iec-i --suffix=B $bytes_sent 2>/dev/null || echo "${bytes_sent}B")${NC}"
        echo -e "${GREEN}●${NC} Bytes received:         ${BOLD}$(numfmt --to=iec-i --suffix=B $bytes_recv 2>/dev/null || echo "${bytes_recv}B")${NC}"
    fi
    echo ""
}

# Display error summary
show_error_summary() {
    local stats=$1
    IFS='|' read -r announced limited no_match matched relay connected disconnected broker_contact webrtc_offer webrtc_answer ice_candidate errors warnings fatals bytes_sent bytes_recv <<< "$stats"
    
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
            elif echo "$line" | grep -qi "limited"; then
                echo -e "${GREEN}[GOOD]${NC} ${GREEN}${line}${NC} ${GREEN}✓${NC}"
            elif echo "$line" | grep -qi "no match"; then
                echo -e "${GREEN}[GOOD]${NC} ${GREEN}${line}${NC} ${GREEN}✓${NC}"
            elif echo "$line" | grep -qi "matched\|relay\|connected.*client"; then
                echo -e "${CYAN}${BOLD}[ACTIVE]${NC} ${CYAN}${line}${NC}"
            elif echo "$line" | grep -qi "announc"; then
                echo -e "${BLUE}[INFO]${NC} ${line}"
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
    
    # Parse matched connections from first and last
    local first_matched=$(echo "$first" | cut -d'|' -f5)
    local last_matched=$(echo "$last" | cut -d'|' -f5)
    local matched_change=$((last_matched - first_matched))
    
    # Parse relay from first and last
    local first_relay=$(echo "$first" | cut -d'|' -f6)
    local last_relay=$(echo "$last" | cut -d'|' -f6)
    local relay_change=$((last_relay - first_relay))
    
    if [ $matched_change -gt 0 ]; then
        echo -e "${GREEN}●${NC} Matches increased: ${GREEN}${BOLD}+$matched_change${NC}"
    fi
    
    if [ $relay_change -gt 0 ]; then
        echo -e "${GREEN}●${NC} Relay activity increased: ${GREEN}${BOLD}+$relay_change${NC}"
    fi
    
    if [ $matched_change -eq 0 ] && [ $relay_change -eq 0 ]; then
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
            show_broker_stats "$stats"
            show_connection_activity "$stats"
            show_error_summary "$stats"
            update_history "$stats"
            show_trends
        fi
        
        # Show recent events
        show_recent_events
        
        # Helpful tips at the bottom
        echo -e "${BOLD}${BLUE}═══ Tips ═══${NC}"
        echo -e "${BLUE}●${NC} 'limited' and 'no match' messages are ${GREEN}GOOD${NC} - they mean broker communication works"
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
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Conduit container is not running!"
        log_info "Start Conduit first: cd ~/conduit && docker-compose up -d"
        exit 1
    fi
    
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Start monitoring
    monitor_loop
}

# Run main function
main
