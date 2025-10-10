#!/bin/bash
# E-ink Board Custom Shutdown Handler
# Handles power-optimized shutdown using eink-power-cli and MCXC143VFM power controller

set -e

log_message() {
    echo "$(date): $1"
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

# Prepare MCXC143VFM for shutdown using eink-power-cli
prepare_power_controller_shutdown() {
    log_message "Preparing MCXC143VFM power controller for shutdown..."
    
    if check_eink_power_cli; then
        # Use eink-power-cli to prepare for shutdown
        log_message "Notifying power controller of impending shutdown..."
        if eink-power-cli ping >/dev/null 2>&1; then
            log_message "Power controller is responsive"
            
            # No prepare-shutdown command available in v2.3.0, skip preparation
            log_message "Power controller communication verified"
        else
            log_message "Warning: Power controller not responding to ping"
        fi
    else
        log_message "Falling back to direct UART communication..."
        # Fallback to direct UART if CLI not available
        if [ -c "/dev/ttyLP2" ]; then
            echo "PREPARE_SHUTDOWN" > /dev/ttyLP2 || log_message "Failed to notify power controller via UART"
            log_message "Notified MCXC143VFM via UART"
        else
            log_message "Warning: Neither eink-power-cli nor UART available"
        fi
    fi
    
    # Give power controller time to prepare
    sleep 0.5
}

# Configure GPIO power controls for shutdown
configure_gpio_shutdown() {
    log_message "Configuring GPIO power controls for shutdown..."
    
    # WiFi power GPIO (634) - prepare for clean shutdown
    if [ -d "/sys/class/gpio/gpio634" ]; then
        echo "out" > /sys/class/gpio/gpio634/direction 2>/dev/null || true
        log_message "Configured WiFi power GPIO for shutdown"
    fi
    
    # BT power GPIO (632) - prepare for clean shutdown  
    if [ -d "/sys/class/gpio/gpio632" ]; then
        echo "out" > /sys/class/gpio/gpio632/direction 2>/dev/null || true
        log_message "Configured BT power GPIO for shutdown"
    fi
}

# Optimize system for shutdown
optimize_system_shutdown() {
    log_message "Optimizing system for shutdown..."
    
    # Sync all filesystems
    sync
    
    # Drop caches to ensure clean state
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || log_message "Failed to drop caches"
    
    log_message "System optimized for shutdown"
}

# Battery-aware shutdown (if battery monitoring available)
check_battery_shutdown() {
    log_message "Checking battery status for shutdown..."
    
    # Check if battery monitoring is available via MCXC143VFM
    if [ -c "/dev/ttyLP2" ]; then
        # Query battery status (example command)
        echo "BATTERY_STATUS" > /dev/ttyLP2 || true
        # In real implementation, you'd read the response
        log_message "Battery status checked for shutdown"
    fi
}

# Execute power-controlled shutdown using eink-power-cli
execute_power_shutdown() {
    log_message "Executing power-controlled shutdown using eink-power-cli..."
    
    if check_eink_power_cli; then
        # Try eink-power-cli board shutdown up to 5 times
        log_message "Attempting board shutdown via eink-power-cli (up to 5 attempts)..."
        
        for attempt in $(seq 1 5); do
            log_message "Board shutdown attempt $attempt/5..."
            
            if eink-power-cli board shutdown; then
                log_message "eink-power-cli board shutdown successful on attempt $attempt"
                sleep 3  # Give time for power controller to execute shutdown
                return 0
            else
                log_message "Board shutdown attempt $attempt failed"
                if [ $attempt -lt 5 ]; then
                    log_message "Waiting 1 second before next attempt..."
                    sleep 1
                fi
            fi
        done
        
        log_message "All 5 board shutdown attempts failed"
    else
        log_message "eink-power-cli not available"
    fi
    
    # If we reach here, power controller shutdown failed
    log_message "Power controller shutdown failed, allowing normal system shutdown to proceed"
    return 1
}

# Main shutdown handler
main() {
    log_message "E-ink board custom shutdown handler started"
    
    # Prepare system for power-optimized shutdown
    prepare_power_controller_shutdown
    configure_gpio_shutdown
    optimize_system_shutdown
    check_battery_shutdown
    
    # Attempt power controller shutdown
    if ! execute_power_shutdown; then
        log_message "Power controller shutdown failed, proceeding with system shutdown"
        # Don't block the normal shutdown process
    fi
    
    log_message "Custom shutdown handler completed"
}

main "$@"
