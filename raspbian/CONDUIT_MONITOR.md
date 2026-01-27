# Conduit Monitor Script - Fixed Version

## What Was Wrong?

The original `conduit-monitor.sh` script had multiple "unary operator expected" errors on lines 214, 331, 357, 372, 375, 377, and 383. These errors occur when bash tries to perform numeric comparisons on empty or uninitialized variables.

### Example of the Problem:

```bash
# BAD - causes "unary operator expected" if $connecting_clients is empty
if [ $connecting_clients -gt 0 ]; then
    echo "Has connections"
fi

# When $connecting_clients is empty, bash sees:
# if [  -gt 0 ]; then    <- This is invalid syntax
```

## Key Fixes Applied

### 1. Safe Numeric Extraction with Defaults

```bash
# New helper function
get_numeric() {
    local value="$1"
    local default="${2:-0}"
    
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Usage - always returns a valid number
connecting_clients=$(get_numeric "$connecting_clients" 0)
```

### 2. Safe Comparison Function

```bash
# New helper function for safe comparisons
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
        # ... etc
    esac
}

# Usage - never causes unary operator errors
if safe_compare "$connected_clients" 0 "-gt"; then
    echo "Has connections"
fi
```

### 3. Variable Initialization

All variables are initialized with safe defaults at the start of `extract_metrics()`:

```bash
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
    
    # ... then extract values
}
```

### 4. Better Error Handling

Added proper error handling throughout:

```bash
# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Container '${CONTAINER_NAME}' is not running!${NC}"
    return 1
fi
```

### 5. Improved "Error" Message Handling

The script now correctly identifies that "limited" and "no match" are NOT actual errors:

```bash
while IFS= read -r line; do
    if [[ "$line" =~ \[ERROR\] ]]; then
        # Check if it's a "safe" error (limited/no match)
        if [[ "$line" =~ "limited" ]] || [[ "$line" =~ "no match" ]]; then
            echo -e "${YELLOW}[INFO]${NC} ${line#*\[ERROR\]}"
        else
            echo -e "${RED}[ERROR]${NC} ${line#*\[ERROR\]}"
        fi
    # ... etc
done
```

## Installation

### Option 1: Replace Your Existing Script

```bash
# Backup your current script
cp conduit-monitor.sh conduit-monitor.sh.backup

# Download the fixed version
# (Upload the conduit-monitor-fixed.sh file to your Raspberry Pi)

# Replace it
mv conduit-monitor-fixed.sh conduit-monitor.sh
chmod +x conduit-monitor.sh
```

### Option 2: Run Alongside

```bash
# Keep both versions
chmod +x conduit-monitor-fixed.sh

# Run the fixed version
./conduit-monitor-fixed.sh
```

## Usage

### Basic Usage

```bash
./conduit-monitor-fixed.sh
```

### Custom Container Name

```bash
CONTAINER_NAME=my-conduit ./conduit-monitor-fixed.sh
```

### Custom Refresh Interval

```bash
REFRESH_INTERVAL=10 ./conduit-monitor-fixed.sh
```

### All Options

```bash
CONTAINER_NAME=conduit \
REFRESH_INTERVAL=5 \
LOG_LINES=20 \
./conduit-monitor-fixed.sh
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTAINER_NAME` | `conduit` | Docker container name to monitor |
| `REFRESH_INTERVAL` | `5` | Seconds between dashboard updates |
| `LOG_LINES` | `15` | Number of recent log lines to display |

## Understanding the Output

### Status Indicators

- **● ACTIVE** (Green) - Container is running and has active connections
- **● STARTING** (Yellow) - Container is running but no connections yet (normal)
- **● ERROR** (Red) - Container has genuine errors (not "limited"/"no match")

### "Limited" and "No Match" Messages

These are **NOT errors** despite being marked as `[ERROR]` in the logs:

- **"limited"** - Your proxy announced itself, waited ~30 seconds, but no clients were matched
- **"no match"** - Your proxy announced itself but broker said "no clients available right now"

Both messages indicate your Conduit node is **working correctly** and properly communicating with the Psiphon broker. It just means there aren't clients needing connections at that moment.

The fixed script now displays these as `[INFO]` instead of `[ERROR]` to avoid confusion.

### Connection Statistics

```
Current:
  ● Connecting clients:    31     <- Clients in the process of connecting
  ● Connected clients:     91     <- Clients successfully connected
```

When you see these numbers above 0, your node is actively helping users!

## Troubleshooting

### Script Shows "Container not running"

```bash
# Check if container exists and is running
docker ps -a | grep conduit

# If it's stopped, start it
docker start conduit

# If it doesn't exist, check your Docker setup
```

### Still Getting Errors

If you still see actual error messages (not "limited"/"no match"):

1. Check Docker logs directly:
   ```bash
   docker logs conduit -f
   ```

2. Verify your Docker image is correct:
   ```bash
   docker inspect conduit | grep Image
   ```

3. Check container resources:
   ```bash
   docker stats conduit
   ```

### No Connections Showing Up

This is normal! It can take time for the Psiphon network to:

1. Trust your node (reputation building)
2. Need your capacity
3. Route clients to your node

Keep the node running and be patient. As noted in the official documentation, "limited" and "no match" messages are expected and mean everything is working.

## Additional Notes

### Why Were These Errors Happening?

The errors occurred because:

1. **Log parsing can return empty strings** - When grep or sed don't find matches
2. **Bash arithmetic is strict** - Empty strings in numeric comparisons cause errors
3. **Docker logs can be inconsistent** - Especially during container startup

The fixed script handles all these scenarios gracefully.

### Performance Impact

The fixed script includes additional checks and function calls, but the performance impact is negligible:

- Still updates every 5 seconds (configurable)
- Uses the same Docker API calls
- Minimal CPU overhead from validation functions

### Compatibility

The fixed script works on:

- ✅ Raspberry Pi OS (Raspbian)
- ✅ Ubuntu/Debian
- ✅ Any Linux system with bash 4.0+
- ✅ macOS with bash 4.0+

## Credits

Original concept from bmd007/initial-setup repository.
Fixes applied to handle edge cases and improve error reporting.
