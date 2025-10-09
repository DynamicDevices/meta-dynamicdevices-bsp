# E-ink Board Custom Restart Handler with eink-power-cli

## Overview

This implementation provides a custom restart handler for the imx93-jaguar-eink board that uses the `eink-power-cli` tool to issue board reset commands through the MCXC143VFM power controller.

## Components

### 1. Main Restart Handler Script
**File**: `eink-restart.sh`
- Uses `eink-power-cli` to communicate with MCXC143VFM power controller
- Attempts multiple reset command variations
- Falls back to direct UART communication if CLI fails
- Provides comprehensive logging

### 2. Systemd Service
**File**: `eink-restart.service`
- Runs during system shutdown/reboot
- Executes the restart handler before system shutdown
- Configured with proper dependencies and timeouts

### 3. Test Script
**File**: `test-eink-power-cli.sh`
- Tests eink-power-cli availability and commands
- Helps identify available CLI commands
- Useful for debugging and setup verification

## Installation

### Build the Recipe
```bash
bitbake eink-power-management
```

### Deploy to Target
The systemd service will be automatically enabled and will run during shutdown.

## Usage

### Automatic Operation
Once installed, the restart handler will automatically run whenever you execute:
```bash
reboot
systemctl reboot
shutdown -r now
```

### Manual Testing
```bash
# Test the restart handler directly
/usr/bin/eink-restart.sh

# Test eink-power-cli availability
/usr/bin/test-eink-power-cli.sh

# Check service status
systemctl status eink-restart.service

# View logs
journalctl -u eink-restart.service
tail -f /var/log/eink-restart.log
```

## eink-power-cli Commands Attempted

The restart handler tries these commands in order:

1. `eink-power-cli reset`
2. `eink-power-cli board-reset`
3. `eink-power-cli system-reset`
4. `eink-power-cli power-cycle`

If all CLI commands fail, it falls back to direct UART communication.

## Customization

### Adding New Commands
To add support for additional eink-power-cli commands, modify the `execute_power_restart()` function in `eink-restart.sh`:

```bash
elif eink-power-cli your-new-command 2>&1 | tee -a "$LOG_FILE"; then
    log_message "your-new-command issued successfully"
    sleep 3
    return 0
```

### Adjusting Timeouts
Modify the sleep values in the script to adjust timing:
- `sleep 0.5` - Time for power controller preparation
- `sleep 3` - Time for reset command execution

### Configuration File
The eink-power-cli may use a configuration file at `/etc/eink-power-cli.toml` for settings.

## Troubleshooting

### Check CLI Availability
```bash
which eink-power-cli
eink-power-cli --help
```

### Verify UART Communication
```bash
ls -la /dev/ttyLP2
# Should show character device
```

### View Detailed Logs
```bash
tail -f /var/log/eink-restart.log
journalctl -u eink-restart.service -f
```

### Test Individual Components
```bash
# Test power controller communication
echo "status" > /dev/ttyLP2

# Test CLI commands
eink-power-cli status
```

## Integration with MCXC143VFM

The restart handler integrates with the MCXC143VFM power controller through:

1. **eink-power-cli** - Primary interface (Rust-based CLI tool)
2. **UART Communication** - Fallback via `/dev/ttyLP2`
3. **GPIO Control** - Direct hardware control if needed

## Power Optimization Features

- Battery status checking before restart
- System optimization for faster restart
- Clean power sequencing through MCXC143VFM
- Graceful fallback mechanisms

## Files Installed

- `/usr/bin/eink-restart.sh` - Main restart handler
- `/usr/bin/test-eink-power-cli.sh` - Test script
- `/etc/systemd/system/eink-restart.service` - Systemd service
- `/var/log/eink-restart.log` - Log file

## Dependencies

- `eink-power-cli` - Power management CLI tool
- `bash` - Shell interpreter
- `systemd` - Service management
- MCXC143VFM power controller firmware
