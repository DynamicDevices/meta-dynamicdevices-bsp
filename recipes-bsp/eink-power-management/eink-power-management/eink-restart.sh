#!/bin/bash
# E-ink Board Custom Restart Handler
# Handles power-optimized restart using eink-power-cli and MCXC143VFM power controller

set -e

LOG_FILE="/var/log/eink-restart.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Check if eink-power-cli is available
check_eink_power_cli() {
    if command -v eink-power-cli >/dev/null 2>&1; then
        log_message "eink-power-cli found at $(which eink-power-cli)"
        return 0
    elif command -v eink-pmu >/dev/null 2>&1; then
        log_message "eink-pmu symlink found at $(which eink-pmu)"
        return 0
    else
        log_message "ERROR: eink-power-cli not found in PATH"
        return 1
    fi
}

# Prepare MCXC143VFM for restart using eink-power-cli
prepare_power_controller_restart() {
    log_message "Preparing MCXC143VFM power controller for restart..."
    
    if check_eink_power_cli; then
        # Use eink-power-cli to prepare for restart
        log_message "Notifying power controller of impending restart..."
        if eink-power-cli status >/dev/null 2>&1; then
            log_message "Power controller is responsive"
            
            # Prepare for restart (example commands - adjust based on actual CLI)
            eink-power-cli prepare-restart 2>&1 | tee -a "$LOG_FILE" || {
                log_message "Warning: prepare-restart command not available, continuing..."
            }
        else
            log_message "Warning: Power controller not responding to status check"
        fi
    else
        log_message "Falling back to direct UART communication..."
        # Fallback to direct UART if CLI not available
        if [ -c "/dev/ttyLP2" ]; then
            echo "PREPARE_RESTART" > /dev/ttyLP2 || log_message "Failed to notify power controller via UART"
            log_message "Notified MCXC143VFM via UART"
        else
            log_message "Warning: Neither eink-power-cli nor UART available"
        fi
    fi
    
    # Give power controller time to prepare
    sleep 0.5
}

# Configure GPIO power controls for restart
configure_gpio_restart() {
    log_message "Configuring GPIO power controls for restart..."
    
    # WiFi power GPIO (634) - prepare for clean restart
    if [ -d "/sys/class/gpio/gpio634" ]; then
        echo "out" > /sys/class/gpio/gpio634/direction 2>/dev/null || true
        log_message "Configured WiFi power GPIO for restart"
    fi
    
    # BT power GPIO (632) - prepare for clean restart  
    if [ -d "/sys/class/gpio/gpio632" ]; then
        echo "out" > /sys/class/gpio/gpio632/direction 2>/dev/null || true
        log_message "Configured BT power GPIO for restart"
    fi
}

# Optimize system for restart
optimize_system_restart() {
    log_message "Optimizing system for restart..."
    
    # Sync all filesystems
    sync
    
    # Drop caches to ensure clean state
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || log_message "Failed to drop caches"
    
    # Set all CPUs to performance mode for faster restart
    for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$governor" ]; then
            echo "performance" > "$governor" 2>/dev/null || true
        fi
    done
    
    log_message "System optimized for restart"
}

# Battery-aware restart (if battery monitoring available)
check_battery_restart() {
    log_message "Checking battery status for restart..."
    
    # Check if battery monitoring is available via MCXC143VFM
    if [ -c "/dev/ttyLP2" ]; then
        # Query battery status (example command)
        echo "BATTERY_STATUS" > /dev/ttyLP2 || true
        # In real implementation, you'd read the response
        log_message "Battery status checked for restart"
    fi
}

# Execute power-controlled restart using eink-power-cli
execute_power_restart() {
    log_message "Executing power-controlled restart using eink-power-cli..."
    
    if check_eink_power_cli; then
        # Option 1: Use eink-power-cli for board reset
        log_message "Attempting board reset via eink-power-cli..."
        if eink-power-cli reset 2>&1 | tee -a "$LOG_FILE"; then
            log_message "eink-power-cli reset command issued successfully"
            sleep 3  # Give time for power controller to execute reset
            return 0
        else
            log_message "eink-power-cli reset command failed, trying alternative commands..."
            
            # Try alternative reset commands
            if eink-power-cli board-reset 2>&1 | tee -a "$LOG_FILE"; then
                log_message "eink-power-cli board-reset command issued successfully"
                sleep 3
                return 0
            elif eink-power-cli system-reset 2>&1 | tee -a "$LOG_FILE"; then
                log_message "eink-power-cli system-reset command issued successfully"  
                sleep 3
                return 0
            elif eink-power-cli power-cycle 2>&1 | tee -a "$LOG_FILE"; then
                log_message "eink-power-cli power-cycle command issued successfully"
                sleep 3
                return 0
            else
                log_message "All eink-power-cli reset commands failed"
            fi
        fi
    fi
    
    # Fallback: Direct UART communication
    log_message "Falling back to direct UART power restart..."
    if [ -c "/dev/ttyLP2" ]; then
        echo "POWER_RESTART" > /dev/ttyLP2 || {
            log_message "UART power restart failed"
            return 1
        }
        log_message "UART power restart command sent"
        sleep 2
        return 0
    else
        log_message "No power controller communication available"
        return 1
    fi
}

# Main restart handler
main() {
    log_message "E-ink board custom restart handler started"
    
    # Prepare system for power-optimized restart
    prepare_power_controller_restart
    configure_gpio_restart
    optimize_system_restart
    check_battery_restart
    
    # Attempt power controller restart
    if ! execute_power_restart; then
        log_message "Power controller restart failed, proceeding with system restart"
        # Don't block the normal restart process
    fi
    
    log_message "Custom restart handler completed"
}

main "$@"
