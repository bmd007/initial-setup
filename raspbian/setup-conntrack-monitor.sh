#!/bin/bash

###############################################################################
# Conntrack Monitor Setup Script
# This script sets up Conntrack Monitor (Network Connection Monitor TUI) using Docker
# - Creates Docker Compose configuration
# - Sets up GeoIP database volume
# - Manages Conntrack Monitor lifecycle
#
# Conntrack Monitor: https://github.com/0xf00f00/conntrack-monitor
# Image: ghcr.io/0xf00f00/conntrack-monitor:latest
#
# Usage: ./setup-conntrack-monitor.sh <sudo_password>
# Example: ./setup-conntrack-monitor.sh MyPassword123
###############################################################################

set -euo pipefail

# Global sudo password
SUDO_PASSWORD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONNTRACK_DIR="$HOME/conntrack-monitor"

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

# Create docker-compose.yml
create_docker_compose() {
    log_info "Creating docker-compose.yml for Conntrack Monitor..."

    mkdir -p "$CONNTRACK_DIR"

    cat > "$CONNTRACK_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  conntrack-monitor:
    image: ghcr.io/0xf00f00/conntrack-monitor:latest
    container_name: conntrack-monitor

    cap_add:
      - NET_ADMIN

    privileged: true
    tty: true
    stdin_open: true

    network_mode: host

    volumes:
      - geoip-data:/usr/share/GeoIP

    environment:
      - GEOIP_DB_PATHS=/usr/share/GeoIP

    restart: unless-stopped

volumes:
  geoip-data:
    driver: local
EOF

    log_success "docker-compose.yml created at $CONNTRACK_DIR"
}

# Stop and remove existing container
remove_existing() {
    log_info "Checking for existing Conntrack Monitor installation..."

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^conntrack-monitor$'; then
        log_warning "Found existing conntrack-monitor container"

        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^conntrack-monitor$'; then
            log_info "Stopping conntrack-monitor container..."
            docker stop conntrack-monitor 2>/dev/null || true
        fi

        log_info "Removing conntrack-monitor container..."
        docker rm conntrack-monitor 2>/dev/null || true
        log_success "Existing container removed"
    fi

    # Check for docker-compose
    if [ -f "$CONNTRACK_DIR/docker-compose.yml" ]; then
        log_info "Bringing down existing docker-compose setup..."
        cd "$CONNTRACK_DIR"
        docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
        cd - > /dev/null
    fi
}

# Start Conntrack Monitor
start_conntrack_monitor() {
    log_info "Starting Conntrack Monitor..."

    cd "$CONNTRACK_DIR"

    # Pull latest image
    log_info "Pulling latest Conntrack Monitor image..."
    docker pull ghcr.io/0xf00f00/conntrack-monitor:latest

    # Start with docker-compose (detached mode)
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
    log_info "Waiting for Conntrack Monitor to start..."
    sleep 3

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q '^conntrack-monitor$'; then
        log_success "Conntrack Monitor started successfully"
    else
        log_error "Conntrack Monitor failed to start, checking logs..."
        docker logs conntrack-monitor 2>&1 | tail -20
        exit 1
    fi
}

# Display connection info
show_connection_info() {
    echo ""
    echo "=========================================="
    log_success "Conntrack Monitor Setup Complete!"
    echo "=========================================="
    echo ""
    log_info "Conntrack Monitor Details:"
    echo "  • Container: conntrack-monitor"
    echo "  • Image: ghcr.io/0xf00f00/conntrack-monitor:latest"
    echo "  • Network Mode: host (monitors host network)"
    echo "  • GeoIP Volume: geoip-data"
    echo ""
    log_info "Management Commands:"
    echo "  • View TUI (interactive): docker attach conntrack-monitor"
    echo "  • Detach from TUI: Press Ctrl+P then Ctrl+Q"
    echo "  • View logs: docker logs conntrack-monitor -f"
    echo "  • Stop: cd $CONNTRACK_DIR && docker-compose down"
    echo "  • Start: cd $CONNTRACK_DIR && docker-compose up -d"
    echo "  • Restart: docker restart conntrack-monitor"
    echo "  • Status: docker ps | grep conntrack-monitor"
    echo ""
    log_info "Interactive Usage:"
    echo "  • Attach to TUI: docker attach conntrack-monitor"
    echo "  • Run interactively: cd $CONNTRACK_DIR && docker compose run --rm conntrack-monitor"
    echo ""
    log_info "Configuration:"
    echo "  • Compose file: $CONNTRACK_DIR/docker-compose.yml"
    echo "  • GeoIP Database: Automatically downloads DB-IP Lite on first run"
    echo "  • Privileged Mode: Required for NET_ADMIN capability"
    echo ""
    log_warning "Important Notes:"
    echo "  • This is a TUI (Terminal User Interface) application"
    echo "  • GeoIP databases are automatically downloaded on first run"
    echo "  • For MaxMind GeoLite2 databases, see documentation"
    echo "  • Container runs in host network mode to monitor connections"
    echo ""
    log_info "Next Steps:"
    echo "  1. Attach to view the TUI: docker attach conntrack-monitor"
    echo "  2. Monitor your network connections in real-time"
    echo "  3. To detach without stopping: Ctrl+P then Ctrl+Q"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Conntrack Monitor Setup"
    echo "=========================================="
    echo ""

    # Check if password provided
    if [ $# -eq 0 ]; then
        log_error "Sudo password is required!"
        log_info "Usage: ./setup-conntrack-monitor.sh <sudo_password>"
        log_info "Example: ./setup-conntrack-monitor.sh MyPassword123"
        exit 1
    fi

    SUDO_PASSWORD="$1"

    # Validate password
    if ! echo "$SUDO_PASSWORD" | run_sudo -S true 2>/dev/null; then
        log_error "Invalid sudo password provided"
        exit 1
    fi
    log_success "Sudo password validated"

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

    # Create Docker Compose file
    echo ""
    create_docker_compose

    # Remove existing installation
    echo ""
    remove_existing

    # Start Conntrack Monitor
    echo ""
    start_conntrack_monitor

    # Show info
    show_connection_info
}

# Run main function
main "$@"
