#!/bin/bash

###############################################################################
# Portainer Setup Script
# This script manages Portainer installation and deployment
# - Checks if Portainer is running
# - Completely removes existing Portainer installation
# - Frees up required ports (9000, 9443)
# - Deploys fresh Portainer instance
#
# Usage: ./setup-portainer.sh [sudo_password]
# Example: ./setup-portainer.sh MyPassword123
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

# Check if port is in use and kill the process
check_and_free_port() {
    local port=$1
    local port_name=$2

    log_info "Checking if port $port is available..."

    # Check if lsof is available
    if ! command -v lsof &> /dev/null; then
        log_warning "lsof not found, installing..."
        run_sudo apt-get install -y lsof
    fi

    # Check if port is in use
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Port $port is already in use by another process"

        local pid
        local process_name
        pid=$(lsof -Pi :$port -sTCP:LISTEN -t 2>/dev/null | head -n 1)

        if [ -z "$pid" ]; then
            log_error "Could not determine PID for port $port"
            # Try alternative method with netstat
            pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | head -n 1)
        fi

        if [ -z "$pid" ]; then
            log_error "Failed to find process using port $port"
            return 1
        fi

        process_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")

        log_warning "Process using port $port: $process_name (PID: $pid)"
        log_info "Killing process $pid to free port $port..."

        # Try regular kill first
        run_sudo kill $pid 2>/dev/null || true
        sleep 1

        # If still running, force kill
        if ps -p $pid > /dev/null 2>&1; then
            log_info "Process still running, forcing kill..."
            run_sudo kill -9 $pid 2>/dev/null || true
            sleep 2
        fi

        # Verify port is freed
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_error "Failed to free port $port - process may have restarted or is protected"

            # One more attempt - find and kill again
            local new_pid
            new_pid=$(lsof -Pi :$port -sTCP:LISTEN -t 2>/dev/null | head -n 1)
            if [ -n "$new_pid" ]; then
                log_warning "Found process restarted with PID: $new_pid, killing again..."
                run_sudo kill -9 $new_pid 2>/dev/null || true
                sleep 2
            fi

            # Final check
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                log_error "Port $port is still in use. Please manually stop the process and try again."
                return 1
            fi
        fi

        log_success "Port $port freed successfully"
        return 0
    else
        log_success "Port $port is available"
        return 0
    fi
}

# Free required ports
free_portainer_ports() {
    log_info "Freeing required ports for Portainer..."

    local ports_freed=true

    if ! check_and_free_port 9000 "Portainer HTTP"; then
        ports_freed=false
        log_error "Could not free port 9000"
    fi

    if ! check_and_free_port 9443 "Portainer HTTPS"; then
        ports_freed=false
        log_error "Could not free port 9443"
    fi

    if [ "$ports_freed" = false ]; then
        log_error "Failed to free required ports. Cannot proceed with Portainer installation."
        echo ""
        log_info "Troubleshooting steps:"
        echo "  1. Check what's using the ports: sudo lsof -i :9000 -i :9443"
        echo "  2. Manually stop the service"
        echo "  3. Try running this script again"
        exit 1
    fi

    log_success "All required ports are available"
}

# Stop and remove existing Portainer
remove_portainer() {
    log_info "Checking for existing Portainer installation..."

    # Check if Portainer container exists
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^portainer$'; then
        log_warning "Found existing Portainer container"

        # Stop if running
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^portainer$'; then
            log_info "Stopping Portainer container..."
            docker stop portainer 2>/dev/null || true
        fi

        # Remove container
        log_info "Removing Portainer container..."
        docker rm portainer 2>/dev/null || true
        log_success "Portainer container removed"
    else
        log_info "No existing Portainer container found"
    fi

    # Check if running via docker-compose
    PORTAINER_DIR="$HOME/portainer"
    if [ -f "$PORTAINER_DIR/docker-compose.yml" ]; then
        log_info "Found docker-compose setup, bringing it down..."
        cd "$PORTAINER_DIR"
        if docker compose version &> /dev/null; then
            docker compose down 2>/dev/null || true
        elif command -v docker-compose &> /dev/null; then
            docker-compose down 2>/dev/null || true
        fi
        cd - > /dev/null
        log_success "Docker-compose stack stopped"
    fi

    # Check for Portainer volume
    if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q 'portainer_data'; then
        log_warning "Found Portainer data volume"
        read -p "Remove Portainer data volume? This will delete all settings (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing Portainer data volume..."
            docker volume rm portainer_data 2>/dev/null || true
            log_success "Portainer data volume removed"
        else
            log_info "Keeping Portainer data volume"
        fi
    fi
}

# Show what's using Portainer ports
show_port_usage() {
    log_info "Checking port usage..."
    echo ""

    if command -v lsof &> /dev/null; then
        for port in 9000 9443; do
            if lsof -Pi :$port -sTCP:LISTEN >/dev/null 2>&1; then
                echo "Port $port:"
                lsof -Pi :$port -sTCP:LISTEN 2>/dev/null | grep -v "^COMMAND" || true
            else
                echo "Port $port: Available"
            fi
        done
    elif command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null | grep -E ":(9000|9443) " || echo "Ports 9000 and 9443: Available"
    else
        log_warning "Neither lsof nor netstat available, cannot check port usage"
    fi
    echo ""
}

# Install Portainer
install_portainer() {
    log_info "Installing Portainer..."

    # Create directory for Portainer
    PORTAINER_DIR="$HOME/portainer"
    mkdir -p "$PORTAINER_DIR"

    # Create docker-compose.yml
    log_info "Creating Portainer docker-compose.yml..."
    cat > "$PORTAINER_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "9000:9000"      # HTTP Web UI
      - "9443:9443"      # HTTPS Web UI
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    environment:
      - TZ=UTC

volumes:
  portainer_data:
    driver: local
EOF

    log_success "Portainer docker-compose.yml created at $PORTAINER_DIR"

    # Start Portainer
    log_info "Starting Portainer container..."
    cd "$PORTAINER_DIR"

    if docker compose version &> /dev/null; then
        docker compose up -d
    elif command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        log_error "Neither 'docker compose' nor 'docker-compose' is available"
        return 1
    fi

    cd - > /dev/null

    log_success "Portainer started successfully"

    # Get IP address
    IP_ADDR=$(hostname -I | awk '{print $1}')

    echo ""
    log_success "Portainer is now accessible at:"
    echo "  • HTTP:  http://${IP_ADDR}:9000"
    echo "  • HTTPS: https://${IP_ADDR}:9443"
    echo ""
    log_info "Note: On first access, you'll need to create an admin account (within 5 minutes)"
    log_info "Portainer compose file location: $PORTAINER_DIR/docker-compose.yml"
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Portainer Setup Script"
    echo "=========================================="
    echo ""

    # Check if password provided
    if [ $# -eq 0 ]; then
        log_error "Sudo password is required!"
        log_info "Usage: ./setup-portainer.sh <sudo_password>"
        log_info "Example: ./setup-portainer.sh MyPassword123"
        exit 1
    fi

    SUDO_PASSWORD="$1"

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Please do not run this script as root or with sudo"
        log_info "Run as normal user with: ./setup-portainer.sh <your_sudo_password>"
        exit 1
    fi

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
        log_info "Please start Docker service: sudo systemctl start docker"
        exit 1
    fi

    log_success "Docker is installed and running"

    # Show what's using the ports
    echo ""
    show_port_usage

    # Remove existing Portainer
    echo ""
    remove_portainer

    # Free up required ports
    echo ""
    free_portainer_ports

    # Install Portainer
    echo ""
    install_portainer

    echo ""
    echo "=========================================="
    log_success "Portainer Setup Complete!"
    echo "=========================================="
    echo ""
}

# Run main function
main "$@"
