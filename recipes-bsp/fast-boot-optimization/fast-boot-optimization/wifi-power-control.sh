#!/bin/sh

# WiFi power control for imx93-jaguar-eink 5-year battery life optimization
# Application-controlled WiFi power management for maximum power savings

WIFI_INTERFACE="wlan0"
WIFI_DEVICE_PATH="/sys/class/net/$WIFI_INTERFACE/device"

# Function to check if WiFi interface exists
check_wifi_interface() {
    if [ ! -d "/sys/class/net/$WIFI_INTERFACE" ]; then
        echo "ERROR: WiFi interface $WIFI_INTERFACE not found"
        return 1
    fi
    return 0
}

case "$1" in
    "on")
        echo "Enabling WiFi for image download operations..."
        
        # Check if interface exists
        if ! check_wifi_interface; then
            exit 1
        fi
        
        # Enable runtime power management
        if [ -f "$WIFI_DEVICE_PATH/power/control" ]; then
            echo on > "$WIFI_DEVICE_PATH/power/control"
        fi
        
        # Bring up WiFi interface
        ip link set "$WIFI_INTERFACE" up
        
        # Disable power save mode for maximum performance during downloads
        iw "$WIFI_INTERFACE" set power_save off 2>/dev/null || echo "Power save control not available"
        
        echo "WiFi enabled and ready for network operations"
        ;;
        
    "off")
        echo "Disabling WiFi after download completion for power savings..."
        
        # Check if interface exists
        if ! check_wifi_interface; then
            exit 1
        fi
        
        # Disconnect from network gracefully
        if command -v wpa_cli >/dev/null 2>&1; then
            wpa_cli disconnect 2>/dev/null || echo "wpa_cli disconnect failed or not connected"
        fi
        
        # Bring down WiFi interface
        ip link set "$WIFI_INTERFACE" down
        
        # Enable automatic runtime power management for maximum power savings
        if [ -f "$WIFI_DEVICE_PATH/power/control" ]; then
            echo auto > "$WIFI_DEVICE_PATH/power/control"
        fi
        
        echo "WiFi disabled for maximum power savings"
        ;;
        
    "sleep")
        echo "Putting WiFi in low power mode while maintaining connection..."
        
        # Check if interface exists
        if ! check_wifi_interface; then
            exit 1
        fi
        
        # Enable WiFi power save mode
        iw "$WIFI_INTERFACE" set power_save on 2>/dev/null || echo "Power save mode not available"
        
        # Enable runtime power management
        if [ -f "$WIFI_DEVICE_PATH/power/control" ]; then
            echo auto > "$WIFI_DEVICE_PATH/power/control"
        fi
        
        echo "WiFi in low power mode"
        ;;
        
    "status")
        echo "WiFi Power Status:"
        
        # Check if interface exists
        if ! check_wifi_interface; then
            exit 1
        fi
        
        # Show interface status
        echo "Interface: $(ip link show $WIFI_INTERFACE | head -n1)"
        
        # Show power management status
        if [ -f "$WIFI_DEVICE_PATH/power/control" ]; then
            echo "Runtime PM: $(cat $WIFI_DEVICE_PATH/power/control)"
        fi
        
        # Show power save status
        iw "$WIFI_INTERFACE" get power_save 2>/dev/null || echo "Power save status not available"
        ;;
        
    *)
        echo "Usage: $0 {on|off|sleep|status}"
        echo "  on     - Enable WiFi for network operations (high power)"
        echo "  off    - Disable WiFi completely (maximum power savings)"
        echo "  sleep  - Low power mode while maintaining connection"
        echo "  status - Show current WiFi power status"
        exit 1
        ;;
esac

exit 0
