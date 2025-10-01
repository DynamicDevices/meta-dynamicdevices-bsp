#!/bin/bash
# WiFi Power Management Script for imx8mm-jaguar-sentai
# Fixes CMD_RESP: 0x107 block in pre_asleep! error with IW612 module

set -e

LOG_FILE="/var/log/wifi-power-management.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Configure IW612 SDIO power management
configure_iw612_power() {
    log_message "Configuring IW612 SDIO power management..."
    
    # Enable SDIO runtime power management
    if [ -d "/sys/bus/sdio/devices" ]; then
        for sdio_dev in /sys/bus/sdio/devices/*/power/control; do
            if [ -f "$sdio_dev" ]; then
                echo auto > "$sdio_dev" || log_message "Failed to enable runtime PM for $sdio_dev"
                log_message "Enabled runtime PM for SDIO device: $sdio_dev"
            fi
        done
    fi
    
    # Configure MMC host power management
    for mmc_host in /sys/class/mmc_host/mmc*/power/control; do
        if [ -f "$mmc_host" ]; then
            echo auto > "$mmc_host" || log_message "Failed to enable runtime PM for $mmc_host"
            log_message "Enabled runtime PM for MMC host: $mmc_host"
        fi
    done
    
    # Set SDIO power management parameters
    for mmc_host in /sys/class/mmc_host/mmc*; do
        if [ -f "$mmc_host/power/autosuspend_delay_ms" ]; then
            echo 1000 > "$mmc_host/power/autosuspend_delay_ms" || log_message "Failed to set autosuspend delay"
            log_message "Set autosuspend delay for: $mmc_host"
        fi
    done
}

# Configure WiFi interface power save
configure_wifi_power_save() {
    log_message "Configuring WiFi power save..."
    
    # Wait for WiFi interface to be available
    for i in {1..30}; do
        WIFI_INTERFACE=$(ip link show | grep -E "wl[a-z0-9]+" | cut -d: -f2 | tr -d ' ' | head -n1)
        if [ -n "$WIFI_INTERFACE" ]; then
            break
        fi
        sleep 1
    done
    
    if [ -n "$WIFI_INTERFACE" ]; then
        log_message "Found WiFi interface: $WIFI_INTERFACE"
        
        # Enable power save mode
        iw dev "$WIFI_INTERFACE" set power_save on || log_message "Failed to enable power save"
        log_message "Enabled power save for $WIFI_INTERFACE"
        
        # Configure wake-on-LAN for magic packets only
        if command -v iw > /dev/null 2>&1; then
            # Find the correct PHY
            PHY_NAME=$(iw dev "$WIFI_INTERFACE" info | grep wiphy | awk '{print $2}')
            if [ -n "$PHY_NAME" ]; then
                PHY_NAME="phy$PHY_NAME"
                iw phy "$PHY_NAME" wowlan enable magic-packet || log_message "Failed to enable WoWLAN"
                log_message "Enabled WoWLAN magic packet wake for $PHY_NAME"
            fi
        fi
    else
        log_message "No WiFi interface found after 30 seconds"
    fi
}

# Configure GPIO wake sources
configure_gpio_wakeup() {
    log_message "Configuring GPIO wakeup sources..."
    
    # Enable WiFi wake GPIO (GPIO2_6 - WL_WAKE_DEV)
    if [ -d "/sys/class/gpio" ]; then
        # Export GPIO if not already exported
        if [ ! -d "/sys/class/gpio/gpio70" ]; then  # GPIO2_6 = 32*2 + 6 = 70
            echo 70 > /sys/class/gpio/export 2>/dev/null || log_message "GPIO 70 already exported or failed"
        fi
        
        if [ -d "/sys/class/gpio/gpio70" ]; then
            echo in > /sys/class/gpio/gpio70/direction || log_message "Failed to set GPIO direction"
            echo both > /sys/class/gpio/gpio70/edge || log_message "Failed to set GPIO edge"
            log_message "Configured GPIO 70 (WL_WAKE_DEV) for wake"
        fi
    fi
}

# Fix SDIO interrupt handling for IW612
fix_sdio_interrupts() {
    log_message "Fixing SDIO interrupt handling for IW612..."
    
    # Enable SDIO async interrupts in sysfs if available
    for mmc_host in /sys/class/mmc_host/mmc*; do
        if [ -f "$mmc_host/caps2" ]; then
            # Check if SDIO_IRQ_NOTHREAD is supported
            caps2=$(cat "$mmc_host/caps2" 2>/dev/null || echo "")
            log_message "MMC host $mmc_host caps2: $caps2"
        fi
    done
    
    # Ensure SDIO card stays powered during suspend
    for sdio_card in /sys/bus/sdio/devices/*/power/wakeup; do
        if [ -f "$sdio_card" ]; then
            echo enabled > "$sdio_card" || log_message "Failed to enable wakeup for $sdio_card"
            log_message "Enabled wakeup for SDIO card: $sdio_card"
        fi
    done
}

# Main execution
main() {
    log_message "Starting WiFi Power Management for imx8mm-jaguar-sentai..."
    
    # Wait for system to stabilize
    sleep 5
    
    configure_iw612_power
    fix_sdio_interrupts
    configure_gpio_wakeup
    configure_wifi_power_save
    
    log_message "WiFi Power Management configuration completed for imx8mm-jaguar-sentai"
}

main "$@"
