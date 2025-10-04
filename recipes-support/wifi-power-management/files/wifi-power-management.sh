#!/bin/bash
# WiFi Power Management Script for E-Ink Board
# 
# This script manages WiFi power saving modes for optimal battery life.
# It enables aggressive power saving when idle and disables it during active transfers.

set -e

WLAN_INTERFACE="wlan0"
LOG_TAG="wifi-power-mgmt"

log_info() {
    echo "[$LOG_TAG] $1"
    logger -t "$LOG_TAG" "$1"
}

log_error() {
    echo "[$LOG_TAG] ERROR: $1" >&2
    logger -t "$LOG_TAG" -p user.err "ERROR: $1"
}

check_interface() {
    if [ ! -d "/sys/class/net/$WLAN_INTERFACE" ]; then
        log_error "WiFi interface $WLAN_INTERFACE not found"
        return 1
    fi
    
    # Check if interface is up
    if ! ip link show "$WLAN_INTERFACE" | grep -q "state UP"; then
        log_info "WiFi interface $WLAN_INTERFACE is down, skipping power management"
        return 1
    fi
    
    return 0
}

enable_power_saving() {
    log_info "Enabling WiFi power saving for battery optimization"
    
    # Enable power saving mode
    if command -v iw >/dev/null 2>&1; then
        if iw dev "$WLAN_INTERFACE" set power_save on 2>/dev/null; then
            log_info "WiFi power saving enabled via iw"
        else
            log_error "Failed to enable power saving via iw"
        fi
    fi
    
    # Set aggressive power management via iwconfig (fallback)
    if command -v iwconfig >/dev/null 2>&1; then
        if iwconfig "$WLAN_INTERFACE" power on 2>/dev/null; then
            log_info "WiFi power management enabled via iwconfig"
        else
            log_info "iwconfig power management not available (normal for some drivers)"
        fi
    fi
    
    # Reduce beacon interval monitoring (less frequent wake-ups)
    if [ -f "/sys/class/net/$WLAN_INTERFACE/device/power_save" ]; then
        echo 1 > "/sys/class/net/$WLAN_INTERFACE/device/power_save" 2>/dev/null || true
        log_info "Device-level power saving enabled"
    fi
    
    log_info "WiFi power saving configuration completed"
}

disable_power_saving() {
    log_info "Disabling WiFi power saving for active transfers"
    
    # Disable power saving for better performance during transfers
    if command -v iw >/dev/null 2>&1; then
        if iw dev "$WLAN_INTERFACE" set power_save off 2>/dev/null; then
            log_info "WiFi power saving disabled via iw"
        else
            log_error "Failed to disable power saving via iw"
        fi
    fi
    
    # Disable power management via iwconfig (fallback)
    if command -v iwconfig >/dev/null 2>&1; then
        if iwconfig "$WLAN_INTERFACE" power off 2>/dev/null; then
            log_info "WiFi power management disabled via iwconfig"
        else
            log_info "iwconfig power management not available (normal for some drivers)"
        fi
    fi
    
    # Disable device-level power saving
    if [ -f "/sys/class/net/$WLAN_INTERFACE/device/power_save" ]; then
        echo 0 > "/sys/class/net/$WLAN_INTERFACE/device/power_save" 2>/dev/null || true
        log_info "Device-level power saving disabled"
    fi
    
    log_info "WiFi power saving disabled for optimal performance"
}

show_status() {
    log_info "WiFi Power Management Status:"
    
    if command -v iw >/dev/null 2>&1; then
        local power_save_status
        power_save_status=$(iw dev "$WLAN_INTERFACE" get power_save 2>/dev/null || echo "unknown")
        log_info "iw power save: $power_save_status"
    fi
    
    if [ -f "/sys/class/net/$WLAN_INTERFACE/device/power_save" ]; then
        local device_power_save
        device_power_save=$(cat "/sys/class/net/$WLAN_INTERFACE/device/power_save" 2>/dev/null || echo "unknown")
        log_info "Device power save: $device_power_save"
    fi
    
    # Show current power consumption info if available
    if [ -f "/sys/class/net/$WLAN_INTERFACE/statistics/rx_bytes" ]; then
        local rx_bytes tx_bytes
        rx_bytes=$(cat "/sys/class/net/$WLAN_INTERFACE/statistics/rx_bytes")
        tx_bytes=$(cat "/sys/class/net/$WLAN_INTERFACE/statistics/tx_bytes")
        log_info "Network activity - RX: $rx_bytes bytes, TX: $tx_bytes bytes"
    fi
}

case "$1" in
    enable)
        if check_interface; then
            enable_power_saving
        fi
        ;;
    disable)
        if check_interface; then
            disable_power_saving
        fi
        ;;
    status)
        if check_interface; then
            show_status
        fi
        ;;
    *)
        echo "Usage: $0 {enable|disable|status}"
        echo "  enable  - Enable WiFi power saving for battery optimization"
        echo "  disable - Disable WiFi power saving for active transfers"
        echo "  status  - Show current WiFi power management status"
        exit 1
        ;;
esac

exit 0
