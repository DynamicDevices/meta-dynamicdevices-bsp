#!/bin/bash
# WiFi Suspend Preparation Script
# Cleanly shuts down WiFi interface before system suspend to prevent driver state corruption

set -e

log_message() {
    echo "$(date): $1"
}

prepare_wifi_for_suspend() {
    log_message "Preparing WiFi for system suspend..."
    
    # Check if WiFi interface exists and is up
    if ip link show wlan0 >/dev/null 2>&1; then
        WIFI_STATE=$(ip link show wlan0 | grep -o "state [A-Z]*" | cut -d' ' -f2 || echo "UNKNOWN")
        log_message "Current WiFi interface state: $WIFI_STATE"
        
        if [ "$WIFI_STATE" = "UP" ]; then
            log_message "Taking WiFi interface down for clean suspend..."
            ip link set wlan0 down
            log_message "WiFi interface wlan0 set to DOWN"
            
            # Give the interface time to properly shut down
            sleep 2
            
            # Verify it's down
            NEW_STATE=$(ip link show wlan0 | grep -o "state [A-Z]*" | cut -d' ' -f2 || echo "UNKNOWN")
            log_message "WiFi interface state after shutdown: $NEW_STATE"
        else
            log_message "WiFi interface already down (state: $WIFI_STATE)"
        fi
    else
        log_message "WiFi interface wlan0 not found"
    fi
    
    # Stop NetworkManager to prevent it from interfering during suspend
    if systemctl is-active --quiet NetworkManager; then
        log_message "Stopping NetworkManager for clean suspend..."
        systemctl stop NetworkManager
        log_message "NetworkManager stopped"
    else
        log_message "NetworkManager already stopped or not running"
    fi
    
    log_message "WiFi suspend preparation completed"
}

main() {
    log_message "WiFi suspend preparation script started"
    prepare_wifi_for_suspend
    log_message "WiFi suspend preparation script completed successfully"
}

main "$@"
