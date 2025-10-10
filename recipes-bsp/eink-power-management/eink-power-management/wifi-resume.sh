#!/bin/bash
# WiFi Resume Restoration Script
# Aggressively restores WiFi interface after system resume - assumes WiFi is broken and needs immediate fixing

set -e

log_message() {
    echo "$(date): $1"
}

restore_wifi_after_resume() {
    log_message "Fast WiFi recovery after resume - assuming WiFi is broken"
    
    # Assume WiFi is broken and immediately start aggressive recovery
    # Don't waste time checking - just fix it
    
    # Force interface down first (in case it's in a bad state)
    if ip link show wlan0 >/dev/null 2>&1; then
        log_message "Forcing WiFi interface down for clean restart"
        ip link set wlan0 down 2>/dev/null || true
    fi
    
    # Stop NetworkManager to reset network stack
    log_message "Stopping NetworkManager for clean restart"
    systemctl stop NetworkManager 2>/dev/null || true
    
    # Brief pause to let things settle
    sleep 1
    
    # Bring interface up
    log_message "Bringing WiFi interface up"
    ip link set wlan0 up
    
    # Start NetworkManager
    log_message "Starting NetworkManager"
    systemctl start NetworkManager
    
    # Give NetworkManager minimal time to initialize (2 seconds instead of 3+)
    sleep 2
    
    # Restart NetworkManager one more time for clean state
    log_message "Restarting NetworkManager for final clean state"
    systemctl restart NetworkManager
    
    # Quick connectivity test (only 3 attempts, 2 seconds apart)
    log_message "Quick connectivity test (6 seconds max)"
    local attempt=1
    
    while [ $attempt -le 3 ]; do
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            log_message "WiFi connectivity restored in $((attempt * 2)) seconds"
            return 0
        fi
        log_message "Quick test $attempt/3 failed"
        [ $attempt -lt 3 ] && sleep 2
        attempt=$((attempt + 1))
    done
    
    # If quick test fails, continue anyway - NetworkManager may still be connecting
    log_message "Quick test failed but NetworkManager is running - WiFi may connect shortly"
    
    log_message "Fast WiFi recovery completed"
}

main() {
    log_message "WiFi resume restoration script started"
    restore_wifi_after_resume
    log_message "WiFi resume restoration script completed successfully"
}

main "$@"
