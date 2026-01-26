#!/bin/bash

# Quick test script to show what the network info display will look like

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
echo "=========================================="
echo "  Network Interface Information"
echo "=========================================="
echo ""

log_info "Hostname: $(hostname)"
echo ""

# Method 1: Using ip command (preferred on modern systems)
if command -v ip &> /dev/null; then
    log_info "Network Interfaces (using ip command):"
    echo ""

    # Get all interfaces with IP addresses
    ip -4 addr show | grep -E '^[0-9]+:|inet ' | while read -r line; do
        if [[ $line =~ ^[0-9]+:.*[[:space:]]([^:]+): ]]; then
            interface="${BASH_REMATCH[1]}"
            # Skip loopback in the interface name line
            if [[ "$interface" != "lo" ]]; then
                echo -e "${BLUE}Interface:${NC} $interface"
            fi
        elif [[ $line =~ inet[[:space:]]([0-9.]+) ]]; then
            ip_addr="${BASH_REMATCH[1]}"
            # Only show non-loopback IPs
            if [[ "$ip_addr" != "127.0.0.1" ]]; then
                echo -e "  ${GREEN}IPv4:${NC} $ip_addr"
            fi
        fi
    done

    # Also show IPv6 if available
    if ip -6 addr show | grep -q "inet6.*scope global"; then
        echo ""
        log_info "IPv6 Addresses:"
        ip -6 addr show | grep "inet6.*scope global" | while read -r line; do
            if [[ $line =~ inet6[[:space:]]([^[:space:]]+) ]]; then
                echo -e "  ${GREEN}IPv6:${NC} ${BASH_REMATCH[1]}"
            fi
        done
    fi
# Method 2: Using ifconfig (fallback for older systems)
elif command -v ifconfig &> /dev/null; then
    log_info "Network Interfaces (using ifconfig command):"
    echo ""

    ifconfig | grep -E "^[a-z]|inet " | while read -r line; do
        if [[ $line =~ ^([a-z0-9]+): ]]; then
            interface="${BASH_REMATCH[1]}"
            if [[ "$interface" != "lo" ]]; then
                echo -e "${BLUE}Interface:${NC} $interface"
            fi
        elif [[ $line =~ inet[[:space:]]([0-9.]+) ]]; then
            ip_addr="${BASH_REMATCH[1]}"
            if [[ "$ip_addr" != "127.0.0.1" ]]; then
                echo -e "  ${GREEN}IPv4:${NC} $ip_addr"
            fi
        fi
    done
# Method 3: Using hostname command (basic fallback)
else
    log_warning "Neither 'ip' nor 'ifconfig' command found, using basic method"
    echo ""
    PRIMARY_IP=$(hostname -I | awk '{print $1}')
    if [ -n "$PRIMARY_IP" ]; then
        echo -e "${GREEN}Primary IP:${NC} $PRIMARY_IP"
        echo ""
        log_info "All IPs: $(hostname -I)"
    else
        log_warning "No network interfaces with IP addresses found"
    fi
fi

echo ""
echo "=========================================="
echo ""
