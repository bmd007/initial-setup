#!/bin/bash

###############################################################################
# Raspbian Initial Setup Script
# This script performs initial setup on a fresh Raspbian installation
# - Updates and upgrades system packages
# - Installs zsh and Oh My Zsh with themes
# - Installs latest Java and configures environment
# - Configures network (Ethernet priority + WiFi failover)
# - Installs Docker and Docker Compose
#
# Note: For Portainer installation, use setup-portainer.sh separately
#
# Usage: ./initial-setup.sh <sudo_password>
# Example: ./initial-setup.sh MyPassword123
###############################################################################

# Note: Script is idempotent - safe to run multiple times
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Global run_sudo password (if provided)
SUDO_PASSWORD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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


# Display network interface information
display_network_info() {
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
    echo ""

    ip route | grep default

    echo ""
    echo "=========================================="
    echo ""
}

# Check if running on Raspbian/Raspberry Pi OS
check_system() {
    log_info "Checking system compatibility..."
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot determine OS. /etc/os-release not found."
        exit 1
    fi

    . /etc/os-release
    if [[ ! "$ID" =~ ^(raspbian|debian)$ ]] && [[ "$NAME" != *"Raspberry Pi"* ]]; then
        log_warning "This script is designed for Raspbian/Raspberry Pi OS. Current OS: $NAME"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    log_success "System check passed"
}

###############################################################################
# 1. Update and Upgrade System
###############################################################################
update_system() {
    log_info "Starting system update and upgrade..."

    run_sudo apt-get update -y
    log_success "Package list updated"

    run_sudo apt-get upgrade -y
    log_success "Packages upgraded"

    run_sudo apt-get dist-upgrade -y
    log_success "Distribution upgrade completed"

    run_sudo apt-get autoremove -y
    run_sudo apt-get autoclean -y
    log_success "Cleanup completed"
}

# Install essential tools
install_essential_tools() {
    log_info "Installing essential tools..."

    # Check if jq is already installed
    if command -v jq &> /dev/null; then
        log_warning "jq already installed: $(jq --version)"
    else
        log_info "Installing jq (JSON processor)..."
        run_sudo apt-get install -y jq
        log_success "jq installed"
    fi

    # Check if lsof is already installed
    if command -v lsof &> /dev/null; then
        log_warning "lsof already installed"
    else
        log_info "Installing lsof (list open files)..."
        run_sudo apt-get install -y lsof
        log_success "lsof installed"
    fi

    log_success "Essential tools installed"
}

###############################################################################
# 2. Install zsh and Oh My Zsh
###############################################################################
install_zsh() {
    log_info "Installing zsh..."

    # Check if already installed
    if command -v zsh &> /dev/null; then
        log_warning "zsh already installed: $(zsh --version)"
    else
        # Install zsh and dependencies
        run_sudo apt-get install -y zsh git curl wget
        log_success "zsh installed"

        # Verify installation
        if ! command -v zsh &> /dev/null; then
            log_error "zsh installation failed"
            exit 1
        fi
    fi

    log_info "zsh version: $(zsh --version)"
}

install_oh_my_zsh() {
    log_info "Installing Oh My Zsh..."

    # Install Oh My Zsh (unattended)
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        # Backup existing .zshrc if it exists
        if [ -f "$HOME/.zshrc" ]; then
            BACKUP_FILE="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
            log_warning "Backing up existing .zshrc to $BACKUP_FILE"
            cp "$HOME/.zshrc" "$BACKUP_FILE"
        fi

        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        log_success "Oh My Zsh installed"
    else
        log_warning "Oh My Zsh already installed, skipping..."
    fi
}

install_zsh_themes_and_plugins() {
    log_info "Installing popular zsh themes and plugins..."

    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # Install Powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        log_info "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
        log_success "Powerlevel10k installed"
    else
        log_warning "Powerlevel10k already installed, skipping..."
    fi

    # Install zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        log_success "zsh-autosuggestions installed"
    else
        log_warning "zsh-autosuggestions already installed, skipping..."
    fi

    # Install zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        log_success "zsh-syntax-highlighting installed"
    else
        log_warning "zsh-syntax-highlighting already installed, skipping..."
    fi

    # Install zsh-completions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
        log_info "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
        log_success "zsh-completions installed"
    else
        log_warning "zsh-completions already installed, skipping..."
    fi

    log_success "All themes and plugins checked"
}

configure_zshrc() {
    log_info "Configuring .zshrc..."

    # Create .zshrc if it doesn't exist
    if [ ! -f "$HOME/.zshrc" ]; then
        cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
    fi

    # Update theme to Powerlevel10k (only if not already set)
    if ! grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"; then
        sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
        log_success "Theme updated to Powerlevel10k"
    else
        log_warning "Powerlevel10k theme already configured"
    fi

    # Update plugins (only if not already set correctly)
    if ! grep -q 'plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting zsh-completions)' "$HOME/.zshrc"; then
        sed -i.bak 's/^plugins=.*/plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' "$HOME/.zshrc"
        log_success "Plugins updated"
    else
        log_warning "Plugins already configured"
    fi

    # Add fpath for completions (only if not already added)
    if ! grep -q "fpath+=\${ZSH_CUSTOM" "$HOME/.zshrc"; then
        sed -i.bak '/^source \$ZSH\/oh-my-zsh.sh/i fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src' "$HOME/.zshrc"
        log_success "Completion path added"
    else
        log_warning "Completion path already configured"
    fi

    log_success ".zshrc configuration complete"
}

change_default_shell() {
    log_info "Changing default shell to zsh..."

    # Change shell to zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)"
        log_success "Default shell changed to zsh (will take effect on next login)"
    else
        log_warning "Default shell is already zsh"
    fi
}

###############################################################################
# 3. Install Java
###############################################################################
install_java() {
    log_info "Checking Java installation..."

    # Check if Java is already installed
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        log_warning "Java already installed: $JAVA_VERSION"
        return 0
    fi

    log_info "Installing Java..."

    # Install OpenJDK (latest available for Raspbian)
    # For Raspbian 64-bit, we'll install OpenJDK 17 (LTS) or the latest available
    run_sudo apt-get install -y default-jdk

    # Also try to install OpenJDK 17 specifically if available
    run_sudo apt-get install -y openjdk-17-jdk 2>/dev/null || log_warning "OpenJDK 17 not available, using default JDK"

    log_success "Java installed"

    # Verify Java installation
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        log_info "Java version: $JAVA_VERSION"
    else
        log_error "Java installation failed"
        exit 1
    fi
}

configure_java_environment() {
    log_info "Configuring Java environment variables..."

    # Find Java home
    JAVA_HOME_PATH=$(readlink -f /usr/bin/java | sed "s:/bin/java::")

    if [ -z "$JAVA_HOME_PATH" ]; then
        log_error "Could not determine JAVA_HOME"
        exit 1
    fi

    log_info "JAVA_HOME will be set to: $JAVA_HOME_PATH"

    # Add to .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "JAVA_HOME" "$HOME/.zshrc"; then
            log_info "Adding JAVA_HOME to .zshrc..."
            cat >> "$HOME/.zshrc" << EOF

# Java Environment Variables
export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
            log_success "JAVA_HOME added to .zshrc"
        else
            log_warning "JAVA_HOME already exists in .zshrc"
        fi
    fi

    # Add to /etc/environment for system-wide access
    if ! run_sudo grep -q "JAVA_HOME" /etc/environment; then
        log_info "Adding JAVA_HOME to /etc/environment..."
        echo "JAVA_HOME=\"$JAVA_HOME_PATH\"" | run_sudo tee -a /etc/environment > /dev/null
        log_success "JAVA_HOME added to /etc/environment"
    else
        log_warning "JAVA_HOME already exists in /etc/environment"
    fi

    # Create/update /etc/profile.d/java.sh for system-wide PATH
    log_info "Creating /etc/profile.d/java.sh..."
    run_sudo tee /etc/profile.d/java.sh > /dev/null << EOF
# Java Environment Variables
export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
    run_sudo chmod +x /etc/profile.d/java.sh
    log_success "Java environment configured system-wide"

    # Export for current session
    export JAVA_HOME="$JAVA_HOME_PATH"
    export PATH="$JAVA_HOME/bin:$PATH"

    log_success "Java environment variables configured"
}

###############################################################################
# 4. Configure Network (Ethernet Priority + WiFi Failover)
###############################################################################
configure_network_priority() {
    log_info "Configuring network priority (Ethernet > WiFi)..."

    # Create dhcpcd configuration to prioritize Ethernet over WiFi
    run_sudo tee /etc/dhcpcd.conf.d/40-network-priority.conf > /dev/null << 'EOF'
# Network Interface Priority Configuration
# Ethernet (eth0) is preferred over WiFi (wlan0)

# Set interface priority - lower metric = higher priority
interface eth0
metric 100

interface wlan0
metric 200
EOF

    log_success "Network priority configured (Ethernet preferred over WiFi)"
}

configure_wifi() {
    log_info "Configuring WiFi connection..."

    # Check if wifi-config.txt exists
    WIFI_CONFIG_FILE="$HOME/wifi-config.txt"

    if [ ! -f "$WIFI_CONFIG_FILE" ]; then
        log_info "Creating WiFi configuration template..."
        cat > "$WIFI_CONFIG_FILE" << 'EOF'
# WiFi Configuration File
# Edit this file with your WiFi credentials
# Format: One WiFi network per line
# SSID=YourNetworkName
# PASSWORD=YourPassword
#
# Example:
# SSID=MyHomeWiFi
# PASSWORD=MySecurePassword123
#
# Multiple networks (will try in order):
# SSID=HomeNetwork
# PASSWORD=HomePass123
# SSID=WorkNetwork
# PASSWORD=WorkPass456

SSID=
PASSWORD=
EOF
        log_warning "WiFi config template created at: $WIFI_CONFIG_FILE"
        log_info "Please edit $WIFI_CONFIG_FILE with your WiFi credentials"
        log_info "Then run this script again to apply WiFi settings"
        return 0
    fi

    # Read WiFi credentials from file
    log_info "Reading WiFi credentials from $WIFI_CONFIG_FILE..."

    # Parse the config file
    SSID=$(grep -E "^SSID=" "$WIFI_CONFIG_FILE" | head -n 1 | cut -d'=' -f2-)
    PASSWORD=$(grep -E "^PASSWORD=" "$WIFI_CONFIG_FILE" | head -n 1 | cut -d'=' -f2-)

    # Check if credentials are provided
    if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
        log_warning "WiFi SSID or PASSWORD not set in $WIFI_CONFIG_FILE"
        log_info "Please edit the file and run the script again"
        return 0
    fi

    log_info "Configuring WiFi: $SSID"

    # Configure WiFi using wpa_supplicant
    log_info "Setting up wpa_supplicant configuration..."

    # Generate PSK hash for better security
    PSK=$(wpa_passphrase "$SSID" "$PASSWORD" | grep -E "^\s+psk=" | cut -d'=' -f2)

    # Create wpa_supplicant configuration
    run_sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null << EOF

# WiFi Network configured by initial-setup.sh on $(date)
network={
    ssid="$SSID"
    psk=$PSK
    priority=10
    id_str="configured_by_script"
}
EOF

    log_success "WiFi configured: $SSID"
    log_info "WiFi will connect automatically if Ethernet is not available"

    # Restart networking to apply changes
    log_info "Restarting WiFi interface..."
    run_sudo wpa_cli -i wlan0 reconfigure 2>/dev/null || true

    # Check if WiFi connected
    sleep 3
    if ip addr show wlan0 | grep -q "inet "; then
        WIFI_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        log_success "WiFi connected! IP: $WIFI_IP"
    else
        log_info "WiFi configured but not currently connected (Ethernet may be active)"
    fi
}

show_network_status() {
    log_info "Current network status:"
    echo ""

    # Check Ethernet
    if ip link show eth0 2>/dev/null | grep -q "state UP"; then
        ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d'/' -f1 2>/dev/null)
        if [ -n "$ETH_IP" ]; then
            echo -e "  ${GREEN}✓ Ethernet (eth0):${NC} Connected - $ETH_IP ${BLUE}[PRIMARY]${NC}"
        else
            echo -e "  ${YELLOW}○ Ethernet (eth0):${NC} Cable connected, waiting for IP"
        fi
    else
        echo -e "  ${YELLOW}○ Ethernet (eth0):${NC} Not connected"
    fi

    # Check WiFi
    if ip link show wlan0 2>/dev/null | grep -q "state UP"; then
        WIFI_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d'/' -f1 2>/dev/null)
        WIFI_SSID=$(iwgetid -r 2>/dev/null)
        if [ -n "$WIFI_IP" ]; then
            echo -e "  ${GREEN}✓ WiFi (wlan0):${NC} Connected to '$WIFI_SSID' - $WIFI_IP ${BLUE}[BACKUP]${NC}"
        else
            echo -e "  ${YELLOW}○ WiFi (wlan0):${NC} Enabled, not connected"
        fi
    else
        echo -e "  ${YELLOW}○ WiFi (wlan0):${NC} Not enabled"
    fi

    echo ""
    log_info "Priority: Ethernet (metric 100) > WiFi (metric 200)"
}

###############################################################################
# 5. Install Docker, Docker Compose, and Portainer
###############################################################################
install_docker() {
    log_info "Checking Docker installation..."

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        log_warning "Docker already installed: $DOCKER_VERSION"

        # Still ensure user is in docker group
        if groups "$USER" | grep -q '\bdocker\b'; then
            log_warning "User already in docker group"
        else
            log_info "Adding current user to docker group..."
            run_sudo usermod -aG docker "$USER"
            log_success "User added to docker group (logout and login for changes to take effect)"
        fi

        # Ensure Docker service is enabled
        run_sudo systemctl enable docker 2>/dev/null || true
        run_sudo systemctl start docker 2>/dev/null || true

        return 0
    fi

    log_info "Installing Docker..."

    # Remove old versions if they exist
    log_info "Removing old Docker versions if present..."
    run_sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install prerequisites
    log_info "Installing Docker prerequisites..."
    run_sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Download and run Docker installation script
    log_info "Downloading and running Docker installation script..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    run_sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    log_success "Docker installed"

    # Verify Docker installation
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        log_info "Docker version: $DOCKER_VERSION"
    else
        log_error "Docker installation failed"
        exit 1
    fi

    # Add current user to docker group
    log_info "Adding current user to docker group..."
    run_sudo usermod -aG docker "$USER"
    log_success "User added to docker group (logout and login for changes to take effect)"

    # Enable Docker service
    log_info "Enabling Docker service..."
    run_sudo systemctl enable docker
    run_sudo systemctl start docker
    log_success "Docker service enabled and started"
}

install_docker_compose() {
    log_info "Checking Docker Compose installation..."

    # Docker Compose is now included as a plugin with Docker
    # But we'll also install the standalone version for compatibility

    # Check if docker-compose plugin is available
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version)
        log_warning "Docker Compose plugin already available: $COMPOSE_VERSION"
    fi

    # Check if standalone docker-compose is already installed
    if command -v docker-compose &> /dev/null && [ -f /usr/local/bin/docker-compose ]; then
        COMPOSE_VERSION_OUTPUT=$(docker-compose --version)
        log_warning "Docker Compose standalone already installed: $COMPOSE_VERSION_OUTPUT"
        return 0
    fi

    # Install docker-compose-plugin
    log_info "Installing docker-compose-plugin..."
    run_sudo apt-get install -y docker-compose-plugin 2>/dev/null || log_warning "docker-compose-plugin not available in repository"

    # Install standalone docker-compose for backward compatibility
    log_info "Installing standalone docker-compose..."

    # Get latest version from GitHub
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$COMPOSE_VERSION" ]; then
        log_warning "Could not determine latest Docker Compose version, using v2.24.5"
        COMPOSE_VERSION="v2.24.5"
    fi

    log_info "Installing Docker Compose $COMPOSE_VERSION..."

    # Determine architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        COMPOSE_ARCH="aarch64"
    elif [ "$ARCH" = "armv7l" ]; then
        COMPOSE_ARCH="armv7"
    else
        COMPOSE_ARCH="$ARCH"
    fi

    run_sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
    run_sudo chmod +x /usr/local/bin/docker-compose

    # Create symbolic link
    run_sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || true

    log_success "Docker Compose installed"

    # Verify installation
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION_OUTPUT=$(docker-compose --version)
        log_info "Docker Compose version: $COMPOSE_VERSION_OUTPUT"
    fi
}


###############################################################################
# Main Execution
###############################################################################
main() {
    echo ""
    echo "=========================================="
    echo "  Raspbian Initial Setup Script"
    echo "=========================================="
    echo ""

    # Check if password provided
    if [ $# -eq 0 ]; then
        log_error "Sudo password is required!"
        log_info "Usage: ./initial-setup.sh <sudo_password>"
        log_info "Example: ./initial-setup.sh MyPassword123"
        exit 1
    fi

    SUDO_PASSWORD="$1"

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Please do not run this script as root or with sudo"
        log_info "Run as normal user with: ./initial-setup.sh <your_sudo_password>"
        exit 1
    fi

    # Validate the password works
    if ! echo "$SUDO_PASSWORD" | run_sudo -S true 2>/dev/null; then
        log_error "Invalid sudo password provided"
        exit 1
    fi
    log_success "Sudo password validated"

    # Display network information first
    display_network_info

    # System check
    check_system

    echo ""
    log_info "Starting installation process..."
    echo ""

    # 1. Update system
    log_info "=== Step 1/5: Updating System ==="
    update_system
    install_essential_tools
    echo ""

    # 2. Install zsh and Oh My Zsh
    log_info "=== Step 2/5: Installing zsh and Oh My Zsh ==="
    install_zsh
    install_oh_my_zsh
    install_zsh_themes_and_plugins
    configure_zshrc
    change_default_shell
    echo ""

    # 3. Install Java
    log_info "=== Step 3/5: Installing Java ==="
    install_java
    configure_java_environment
    echo ""

    # 4. Configure Network (Ethernet + WiFi)
    log_info "=== Step 4/5: Configuring Network ==="
    configure_network_priority
    configure_wifi
    show_network_status
    echo ""

    # 5. Install Docker
    log_info "=== Step 5/5: Installing Docker and Docker Compose ==="
    install_docker
    install_docker_compose
    echo ""

    # Summary
    echo "=========================================="
    log_success "Installation Complete!"
    echo "=========================================="
    echo ""
    log_info "Summary of installed software:"
    echo "  • System: Updated and upgraded"
    echo "  • Essential tools: jq, lsof"
    echo "  • zsh: $(zsh --version 2>&1 | head -n 1)"
    echo "  • Oh My Zsh: Installed with Powerlevel10k theme"
    echo "  • Java: $(java -version 2>&1 | head -n 1)"
    echo "  • Docker: $(docker --version)"
    echo "  • Docker Compose: $(docker-compose --version 2>/dev/null || echo 'plugin version')"
    echo ""
    log_warning "Important notes:"
    echo "  1. Please log out and log back in for shell changes to take effect"
    echo "  2. Docker group membership requires re-login to take effect"
    echo "  3. Run 'p10k configure' to configure Powerlevel10k theme"
    echo "  4. JAVA_HOME is set to: $JAVA_HOME"
    echo ""
    log_info "To install Portainer (Docker management UI), run:"
    echo "  ./setup-portainer.sh YourSudoPassword"
    echo ""
    log_info "You can now start using your configured Raspbian system!"
    echo ""
}

# Run main function with command line arguments
main "$@"
