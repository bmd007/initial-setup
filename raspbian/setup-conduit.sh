#!/bin/bash

###############################################################################
# Conduit Setup Script
# This script sets up Conduit (Psiphon's load balancer) using Docker
# - Force opens required ports
# - Creates Docker Compose configuration
# - Manages Conduit lifecycle
#
# Conduit: https://conduit.psiphon.ca/
# Image: ghcr.io/ssmirr/conduit/conduit:latest
#
# Usage: ./setup-conduit.sh <sudo_password> [port]
# Example: ./setup-conduit.sh MyPassword123 8080
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
CONDUIT_DIR="$HOME/conduit"
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

# Create docker-compose.yml
create_docker_compose() {
    log_info "Creating docker-compose.yml for Conduit..."

    mkdir -p "$CONDUIT_DIR"

    cat > "$CONDUIT_DIR/docker-compose.yml" << EOF
services:
  conduit:
    image: ghcr.io/ssmirr/conduit/conduit:latest
    container_name: conduit

    command: ["start", "-b", "1024", "-m", "10"]

    volumes:
      - conduit-data:/home/conduit/data

    restart: unless-stopped

    environment:
      - TZ=UTC

    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"

volumes:
  conduit-data:
    driver: local
EOF

    log_success "docker-compose.yml created at $CONDUIT_DIR"
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

# Configure firewall to allow Conduit port
configure_firewall() {
    log_info "Configuring firewall for Conduit..."

    # Check if UFW is installed and active
    if command -v ufw &> /dev/null; then
        if run_sudo ufw status 2>/dev/null | grep -q "Status: active"; then
            log_info "UFW is active, adding rule for port $CONDUIT_PORT..."
            run_sudo ufw allow $CONDUIT_PORT/tcp comment 'Conduit' 2>/dev/null || true
            log_success "Firewall rule added"
        else
            log_info "UFW is not active, skipping firewall configuration"
        fi
    else
        log_info "UFW not installed, skipping firewall configuration"
    fi
}

# Start Conduit
start_conduit() {
    log_info "Starting Conduit..."

    cd "$CONDUIT_DIR"

    # Pull latest image
    log_info "Pulling latest Conduit image..."
    docker pull ghcr.io/ssmirr/conduit/conduit:latest

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

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q '^conduit$'; then
        log_success "Conduit started successfully"
    else
        log_error "Conduit failed to start, checking logs..."
        docker logs conduit 2>&1 | tail -20
        exit 1
    fi
}

# Display connection info
show_connection_info() {
    echo ""
    echo "=========================================="
    log_success "Conduit Setup Complete!"
    echo "=========================================="
    echo ""
    log_info "Management Commands:"
    echo "  • View logs: docker logs conduit -f"
    echo "  • Stop: cd $CONDUIT_DIR && docker-compose down"
    echo "  • Start: cd $CONDUIT_DIR && docker-compose up -d"
    echo "  • Restart: docker restart conduit"
    echo "  • Status: docker ps | grep conduit"
    echo ""
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Conduit Setup"
    echo "=========================================="
    echo ""

    # Check if password provided
    if [ $# -eq 0 ]; then
        log_error "Sudo password is required!"
        log_info "Usage: ./setup-conduit.sh <sudo_password> [port]"
        log_info "Example: ./setup-conduit.sh MyPassword123"
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

    # Get server IP
    get_server_ip

    # Create Docker Compose file
    echo ""
    create_docker_compose

    # Remove existing installation
    echo ""
    remove_existing

    # Configure firewall
    echo ""
    configure_firewall

    # Start Conduit
    echo ""
    start_conduit

    # Show info
    show_connection_info
}

# Run main function
main "$@"
