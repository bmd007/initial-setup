#!/bin/bash

###############################################################################
# Conduit Setup Script
# This script sets up Conduit (Psiphon's load balancer) using Docker
# - Force opens required ports
# - Creates Docker Compose configuration
# - Manages Conduit lifecycle
#
# Conduit: https://conduit.psiphon.ca/
#
# Usage: cd conduit && ./setup-conduit.sh
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDUIT_DIR="$SCRIPT_DIR"
SERVER_IP=""

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

# Sudo wrapper function
run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S "$@" 2>/dev/null || sudo "$@"
}

# Get server IP address
get_server_ip() {
    log_info "Detecting server IP address..."

    # Try to get public IP first
    SERVER_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "")

    if [ -z "$SERVER_IP" ]; then
        # Fall back to local IP
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
        log_warning "Could not determine IP, using localhost"
    else
        log_success "Server IP: $SERVER_IP"
    fi
}

check_conduit_dir() {
    log_info "Checking Conduit directory structure..."

    if [ ! -f "$CONDUIT_DIR/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found at: $CONDUIT_DIR/docker-compose.yml"
        log_error "Make sure you're running this script from the conduit directory"
        exit 1
    fi

    if [ ! -f "$CONDUIT_DIR/netdata/go.d/prometheus.conf" ]; then
        log_error "Netdata config not found at: $CONDUIT_DIR/netdata/go.d/prometheus.conf"
        exit 1
    fi

    log_success "Conduit directory structure verified"
}

# Stop and remove existing container
remove_existing() {
    log_info "Checking for existing Conduit installation..."

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^conduit$'; then
        log_warning "Found existing conduit container"

        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^conduit$'; then
            log_info "Stopping conduit container..."
            docker stop conduit 2>/dev/null || true
        fi

        log_info "Removing conduit container..."
        docker rm conduit 2>/dev/null || true
        log_success "Existing container removed"
    fi

    # Check for docker-compose
    if [ -f "$CONDUIT_DIR/docker-compose.yml" ]; then
        log_info "Bringing down existing docker-compose setup..."
        cd "$CONDUIT_DIR"
        docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
        cd - > /dev/null
    fi
}

# Start Conduit
start_conduit() {
    log_info "Starting Conduit..."

    cd "$CONDUIT_DIR"

    # Pull latest image
    log_info "Pulling latest images..."
    docker pull ghcr.io/psiphon-inc/conduit/cli:latest
    docker pull netdata/netdata:latest

    # Start with docker-compose
    log_info "Starting container..."
    if docker compose version &> /dev/null; then
        docker compose up -d
    elif command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        log_error "Neither 'docker compose' nor 'docker-compose' is available"
        exit 1
    fi

    cd - > /dev/null

    # Wait for container to start
    log_info "Waiting for Conduit to start..."
    sleep 3

    # Check if containers are running
    if docker ps --format '{{.Names}}' | grep -q '^conduit$'; then
        log_success "Conduit started successfully"
    else
        log_error "Conduit failed to start, checking logs..."
        docker logs conduit 2>&1 | tail -20
        exit 1
    fi

    if docker ps --format '{{.Names}}' | grep -q '^netdata$'; then
        log_success "Netdata started successfully"
    else
        log_warning "Netdata may not have started, check logs: docker logs netdata"
    fi
}

# Display connection info
show_connection_info() {
    echo ""
    echo "=========================================="
    log_success "Conduit with Netdata Setup Complete!"
    echo "=========================================="
    echo ""
    log_info "Access URLs:"
    echo "  • Netdata Dashboard: http://$SERVER_IP:19999"
    echo "  • Conduit Metrics: http://$SERVER_IP:9090/metrics"
    echo ""
    log_info "Netdata Features:"
    echo "  • Real-time monitoring with 1-second resolution"
    echo "  • Pre-configured Conduit metrics charts"
    echo "  • Active connections tracking"
    echo "  • Bandwidth monitoring"
    echo "  • System resource monitoring"
    echo ""
    log_info "Management Commands:"
    echo "  • View Conduit logs: docker logs conduit -f"
    echo "  • View Netdata logs: docker logs netdata -f"
    echo "  • Stop all: cd $CONDUIT_DIR && docker compose down"
    echo "  • Start all: cd $CONDUIT_DIR && docker compose up -d"
    echo "  • Restart: docker restart conduit netdata"
    echo "  • Status: docker ps"
    echo ""
}

# Main execution
main() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        log_info "Please run initial-setup.sh first to install Docker"
        exit 1
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running!"
        log_info "Starting Docker service..."
        run_sudo systemctl start docker
        sleep 2

        if ! docker info &> /dev/null; then
            log_error "Failed to start Docker"
            exit 1
        fi
    fi

    log_success "Docker is installed and running"

    # Get server IP
    get_server_ip

    # Check conduit directory structure
    echo ""
    check_conduit_dir

    # Remove existing installation
    echo ""
    remove_existing

    # Start Conduit
    echo ""
    start_conduit

    # Show info
    show_connection_info
}

# Run main function
main "$@"
