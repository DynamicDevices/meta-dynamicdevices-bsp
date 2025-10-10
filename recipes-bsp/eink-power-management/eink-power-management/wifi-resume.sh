#!/bin/bash
# WiFi Resume Restoration Script
# Cleanly restores WiFi interface after system resume to ensure proper connectivity

set -e

log_message() {
    echo "$(date): $1"
}

restore_wifi_after_resume() {
    log_message "Restoring WiFi after system resume..."
    
    # Start NetworkManager first
    if ! systemctl is-active --quiet NetworkManager; then
        log_message "Starting NetworkManager..."
        systemctl start NetworkManager
        log_message "NetworkManager started"
        
        # Give NetworkManager time to initialize
        sleep 3
    else
        log_message "NetworkManager already running"
    fi
    
    # Check if WiFi interface exists
    if ip link show wlan0 >/dev/null 2>&1; then
        WIFI_STATE=$(ip link show wlan0 | grep -o "state [A-Z]*" | cut -d' ' -f2 || echo "UNKNOWN")
        log_message "Current WiFi interface state: $WIFI_STATE"
        
        if [ "$WIFI_STATE" = "DOWN" ]; then
            log_message "Bringing WiFi interface up after resume..."
            ip link set wlan0 up
            log_message "WiFi interface wlan0 set to UP"
            
            # Give the interface time to come up
            sleep 3
            
            # Verify it's up
            NEW_STATE=$(ip link show wlan0 | grep -o "state [A-Z]*" | cut -d' ' -f2 || echo "UNKNOWN")
            log_message "WiFi interface state after restore: $NEW_STATE"
        else
            log_message "WiFi interface already up (state: $WIFI_STATE)"
        fi
        
        # Restart NetworkManager to ensure clean network stack
        log_message "Restarting NetworkManager for clean network state..."
        systemctl restart NetworkManager
        log_message "NetworkManager restarted"
        
        # Wait for network to stabilize
        sleep 5
        
        # Test connectivity
        log_message "Testing network connectivity..."
        if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            log_message "Network connectivity restored successfully"
        else
            log_message "Warning: Network connectivity test failed, but interface is up"
        fi
        
    else
        log_message "Error: WiFi interface wlan0 not found"
        return 1
    fi
    
    log_message "WiFi resume restoration completed"
}

main() {
    log_message "WiFi resume restoration script started"
    restore_wifi_after_resume
    log_message "WiFi resume restoration script completed successfully"
}

main "$@"
