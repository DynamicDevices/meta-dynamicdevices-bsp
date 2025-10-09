#!/bin/bash
# Custom reboot wrapper for E-ink board
# This script intercepts reboot commands and adds power management

# Path to original reboot command
ORIGINAL_REBOOT="/sbin/reboot.orig"

# Check if we have the original reboot command
if [ ! -f "$ORIGINAL_REBOOT" ]; then
    ORIGINAL_REBOOT="/usr/sbin/reboot"
fi

log_message() {
    echo "$(date): $1" | tee -a /var/log/eink-reboot.log
}

# Execute custom restart handler
execute_custom_restart() {
    log_message "Custom reboot wrapper called with args: $*"
    
    # Run the custom restart preparation
    if [ -x "/usr/bin/eink-restart.sh" ]; then
        log_message "Running custom restart handler..."
        /usr/bin/eink-restart.sh
    fi
    
    # Execute the original reboot command
    log_message "Executing system reboot..."
    exec "$ORIGINAL_REBOOT" "$@"
}

# Main execution
execute_custom_restart "$@"
