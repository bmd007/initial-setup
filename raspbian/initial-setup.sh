#!/bin/bash

###############################################################################
# Raspbian Initial Setup Script
# This script performs initial setup on a fresh Raspbian installation
# - Updates and upgrades system packages
# - Installs zsh and Oh My Zsh with themes
# - Installs latest Java and configures environment
# - Installs Docker and Docker Compose
###############################################################################

set -e  # Exit on error

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

    sudo apt-get update -y
    log_success "Package list updated"

    sudo apt-get upgrade -y
    log_success "Packages upgraded"

    sudo apt-get dist-upgrade -y
    log_success "Distribution upgrade completed"

    sudo apt-get autoremove -y
    sudo apt-get autoclean -y
    log_success "Cleanup completed"
}

###############################################################################
# 2. Install zsh and Oh My Zsh
###############################################################################
install_zsh() {
    log_info "Installing zsh..."

    # Install zsh and dependencies
    sudo apt-get install -y zsh git curl wget
    log_success "zsh installed"

    # Check zsh installation
    if ! command -v zsh &> /dev/null; then
        log_error "zsh installation failed"
        exit 1
    fi

    log_info "zsh version: $(zsh --version)"
}

install_oh_my_zsh() {
    log_info "Installing Oh My Zsh..."

    # Backup existing .zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
        log_warning "Backing up existing .zshrc to .zshrc.backup"
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi

    # Install Oh My Zsh (unattended)
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
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
    fi

    # Install zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        log_success "zsh-autosuggestions installed"
    fi

    # Install zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        log_success "zsh-syntax-highlighting installed"
    fi

    # Install zsh-completions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
        log_info "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
        log_success "zsh-completions installed"
    fi

    log_success "All themes and plugins installed"
}

configure_zshrc() {
    log_info "Configuring .zshrc..."

    # Create .zshrc if it doesn't exist
    if [ ! -f "$HOME/.zshrc" ]; then
        cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
    fi

    # Update theme to Powerlevel10k
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"

    # Update plugins
    sed -i 's/^plugins=.*/plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' "$HOME/.zshrc"

    # Add fpath for completions
    if ! grep -q "fpath+=\${ZSH_CUSTOM" "$HOME/.zshrc"; then
        sed -i '/^source \$ZSH\/oh-my-zsh.sh/i fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src' "$HOME/.zshrc"
    fi

    log_success ".zshrc configured"
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
    log_info "Installing Java..."

    # Install OpenJDK (latest available for Raspbian)
    # For Raspbian 64-bit, we'll install OpenJDK 17 (LTS) or the latest available
    sudo apt-get install -y default-jdk

    # Also try to install OpenJDK 17 specifically if available
    sudo apt-get install -y openjdk-17-jdk || log_warning "OpenJDK 17 not available, using default JDK"

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
    if ! sudo grep -q "JAVA_HOME" /etc/environment; then
        log_info "Adding JAVA_HOME to /etc/environment..."
        echo "JAVA_HOME=\"$JAVA_HOME_PATH\"" | sudo tee -a /etc/environment > /dev/null
        log_success "JAVA_HOME added to /etc/environment"
    else
        log_warning "JAVA_HOME already exists in /etc/environment"
    fi

    # Create/update /etc/profile.d/java.sh for system-wide PATH
    log_info "Creating /etc/profile.d/java.sh..."
    sudo tee /etc/profile.d/java.sh > /dev/null << EOF
# Java Environment Variables
export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
    sudo chmod +x /etc/profile.d/java.sh
    log_success "Java environment configured system-wide"

    # Export for current session
    export JAVA_HOME="$JAVA_HOME_PATH"
    export PATH="$JAVA_HOME/bin:$PATH"

    log_success "Java environment variables configured"
}

###############################################################################
# 4. Install Docker, Docker Compose, and Portainer
###############################################################################
install_docker() {
    log_info "Installing Docker..."

    # Remove old versions if they exist
    log_info "Removing old Docker versions if present..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install prerequisites
    log_info "Installing Docker prerequisites..."
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Download and run Docker installation script
    log_info "Downloading and running Docker installation script..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
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
    sudo usermod -aG docker "$USER"
    log_success "User added to docker group (logout and login for changes to take effect)"

    # Enable Docker service
    log_info "Enabling Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
    log_success "Docker service enabled and started"
}

install_docker_compose() {
    log_info "Installing Docker Compose..."

    # Docker Compose is now included as a plugin with Docker
    # But we'll also install the standalone version for compatibility

    # Check if docker-compose plugin is available
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version)
        log_success "Docker Compose plugin already available: $COMPOSE_VERSION"
    fi

    # Install docker-compose-plugin
    log_info "Installing docker-compose-plugin..."
    sudo apt-get install -y docker-compose-plugin || log_warning "docker-compose-plugin not available in repository"

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

    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Create symbolic link
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || true

    log_success "Docker Compose installed"

    # Verify installation
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION_OUTPUT=$(docker-compose --version)
        log_info "Docker Compose version: $COMPOSE_VERSION_OUTPUT"
    fi
}

install_portainer() {
    log_info "Installing Portainer..."

    # Create directory for Portainer
    PORTAINER_DIR="$HOME/portainer"
    mkdir -p "$PORTAINER_DIR"

    # Create docker-compose.yml for Portainer
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

    # Start Portainer using docker-compose
    log_info "Starting Portainer container..."
    cd "$PORTAINER_DIR"

    # Use docker-compose or docker compose depending on what's available
    if docker compose version &> /dev/null; then
        sudo docker compose up -d
    elif command -v docker-compose &> /dev/null; then
        sudo docker-compose up -d
    else
        log_error "Neither 'docker compose' nor 'docker-compose' is available"
        return 1
    fi

    cd - > /dev/null

    log_success "Portainer installed and started"

    # Get the IP address
    IP_ADDR=$(hostname -I | awk '{print $1}')

    log_info "Portainer is accessible at:"
    echo "  • HTTP:  http://${IP_ADDR}:9000"
    echo "  • HTTPS: https://${IP_ADDR}:9443"
    echo ""
    log_info "Note: On first access, you'll need to create an admin account"
    log_info "Portainer compose file location: $PORTAINER_DIR/docker-compose.yml"
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

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Please do not run this script as root or with sudo"
        log_info "The script will request sudo privileges when needed"
        exit 1
    fi

    # System check
    check_system

    # Update sudo timestamp
    sudo -v

    echo ""
    log_info "Starting installation process..."
    echo ""

    # 1. Update system
    log_info "=== Step 1/4: Updating System ==="
    update_system
    echo ""

    # 2. Install zsh and Oh My Zsh
    log_info "=== Step 2/4: Installing zsh and Oh My Zsh ==="
    install_zsh
    install_oh_my_zsh
    install_zsh_themes_and_plugins
    configure_zshrc
    change_default_shell
    echo ""

    # 3. Install Java
    log_info "=== Step 3/4: Installing Java ==="
    install_java
    configure_java_environment
    echo ""

    # 4. Install Docker
    log_info "=== Step 4/4: Installing Docker, Docker Compose, and Portainer ==="
    install_docker
    install_docker_compose
    install_portainer
    echo ""

    # Summary
    echo "=========================================="
    log_success "Installation Complete!"
    echo "=========================================="
    echo ""
    log_info "Summary of installed software:"
    echo "  • System: Updated and upgraded"
    echo "  • zsh: $(zsh --version 2>&1 | head -n 1)"
    echo "  • Oh My Zsh: Installed with Powerlevel10k theme"
    echo "  • Java: $(java -version 2>&1 | head -n 1)"
    echo "  • Docker: $(docker --version)"
    echo "  • Docker Compose: $(docker-compose --version 2>/dev/null || echo 'plugin version')"
    echo "  • Portainer: Installed and running"
    echo ""
    log_warning "Important notes:"
    echo "  1. Please log out and log back in for shell changes to take effect"
    echo "  2. Docker group membership requires re-login to take effect"
    echo "  3. Run 'p10k configure' to configure Powerlevel10k theme"
    echo "  4. JAVA_HOME is set to: $JAVA_HOME"
    echo "  5. Portainer web UI: http://$(hostname -I | awk '{print $1}'):9000"
    echo ""
    log_info "You can now start using your configured Raspbian system!"
    echo ""
}

# Run main function
main
