# Raspbian Initial Setup Script

A comprehensive bash script to set up a fresh Raspbian (Raspberry Pi OS) installation with all essential development tools.

## Features

This script automates the following setup tasks:

### 1. System Update & Upgrade
- Updates package lists
- Upgrades all installed packages
- Performs distribution upgrade
- Cleans up unnecessary packages

### 2. Zsh & Oh My Zsh Installation
- Installs zsh shell
- Installs Oh My Zsh framework
- Installs popular themes:
  - **Powerlevel10k** - A fast, flexible, and feature-rich theme
- Installs useful plugins:
  - `git` - Git aliases and functions
  - `docker` - Docker completion
  - `docker-compose` - Docker Compose completion
  - `zsh-autosuggestions` - Command suggestions based on history
  - `zsh-syntax-highlighting` - Syntax highlighting for commands
  - `zsh-completions` - Additional completion definitions
- Sets zsh as the default shell

### 3. Java Installation & Configuration
- Installs the latest OpenJDK available for Raspbian 64-bit
- Configures `JAVA_HOME` environment variable
- Updates `PATH` to include Java binaries
- Adds configuration to:
  - `~/.zshrc` (user-specific)
  - `/etc/environment` (system-wide)
  - `/etc/profile.d/java.sh` (system-wide PATH)

### 4. Docker & Docker Compose Installation
- Removes old Docker versions (if present)
- Installs Docker using the official installation script from docker.com
- Installs Docker Compose (both plugin and standalone versions)
- Adds current user to the docker group
- Enables Docker service to start on boot

## Prerequisites

- Fresh Raspbian (Raspberry Pi OS) 64-bit installation
- Internet connection
- Non-root user with sudo privileges

## Usage

### 1. Download the script

```bash
# Clone the repository or download the script directly
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/raspbian/initial-setup.sh
```

Or if you have the repository:

```bash
cd initial-setup/raspbian
```

### 2. Make the script executable

```bash
chmod +x initial-setup.sh
```

### 3. Run the script

```bash
./initial-setup.sh
```

**Important:** Do NOT run with `sudo`. The script will request sudo privileges when needed.

### 4. Post-installation steps

After the script completes:

1. **Log out and log back in** for shell changes to take effect
2. **Run Powerlevel10k configuration** (optional but recommended):
   ```bash
   p10k configure
   ```
3. **Test Docker** (after re-login):
   ```bash
   docker run hello-world
   ```

## What Gets Installed

| Software | Version | Notes |
|----------|---------|-------|
| zsh | Latest from apt | New default shell |
| Oh My Zsh | Latest | With custom themes and plugins |
| Java (OpenJDK) | Latest available (17+ on recent Raspbian) | With JAVA_HOME configured |
| Docker | Latest from docker.com | Installed via official script |
| Docker Compose | Latest | Both plugin and standalone |

## Customization

### Changing the zsh theme

Edit `~/.zshrc` and change the `ZSH_THEME` line:

```bash
ZSH_THEME="robbyrussell"  # or any other theme
```

Popular alternatives include:
- `agnoster`
- `robbyrussell` (default)
- `af-magic`
- `avit`

### Adding more zsh plugins

Edit `~/.zshrc` and add plugins to the `plugins` array:

```bash
plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting zsh-completions colored-man-pages sudo)
```

### Changing Java version

To install a specific Java version:

```bash
sudo apt-cache search openjdk  # See available versions
sudo apt-get install openjdk-17-jdk  # Install specific version
sudo update-alternatives --config java  # Select default version
```

Then update JAVA_HOME in `~/.zshrc`.

## Troubleshooting

### Shell doesn't change to zsh

If the shell doesn't change automatically:

```bash
chsh -s $(which zsh)
```

Then log out and log back in.

### Docker permission denied

If you get "permission denied" errors with Docker:

```bash
# Verify you're in the docker group
groups

# If not, add yourself
sudo usermod -aG docker $USER

# Log out and log back in
```

### JAVA_HOME not set

If JAVA_HOME is not set after installation:

```bash
# For current session
source ~/.zshrc

# Or log out and log back in
```

### Oh My Zsh theme not loading

```bash
# Reload zsh configuration
source ~/.zshrc

# Or restart your terminal
```

## Script Behavior

- ✅ Safe to run multiple times (idempotent where possible)
- ✅ Backs up existing `.zshrc` before modifications
- ✅ Colored output for better readability
- ✅ Error handling with `set -e`
- ✅ Verification steps after each installation
- ✅ Detailed logging of all operations

## Security Notes

- The script uses official installation methods from trusted sources
- Docker installation script is from `get.docker.com` (official Docker)
- Oh My Zsh installation script is from the official GitHub repository
- All packages are installed from official Raspbian/Debian repositories

## License

This script is provided as-is for personal use.

## Contributing

Feel free to submit issues or pull requests with improvements!

## Support

For Raspbian-specific issues, consult the [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/).

For tool-specific issues:
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [Docker Documentation](https://docs.docker.com/)
- [OpenJDK](https://openjdk.org/)
