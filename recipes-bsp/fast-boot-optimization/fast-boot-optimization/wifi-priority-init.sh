#!/bin/sh

# WiFi priority initialization for imx93-jaguar-eink workflow
# Ensure WiFi is ready as quickly as possible for image update checks

echo "Initializing WiFi for image update workflow..."

# WiFi modules are built-in, so just ensure interface is up
# Check if WiFi interface exists
WIFI_INTERFACE=""
for iface in /sys/class/net/wlan*; do
    if [ -e "$iface" ]; then
        WIFI_INTERFACE=$(basename "$iface")
        break
    fi
done

if [ -z "$WIFI_INTERFACE" ]; then
    echo "ERROR: No WiFi interface found"
    exit 1
fi

echo "Found WiFi interface: $WIFI_INTERFACE"

# Bring up the WiFi interface
ip link set "$WIFI_INTERFACE" up

# Load firmware if needed (should be automatic with built-in drivers)
echo "WiFi interface $WIFI_INTERFACE is ready for network operations"

# Optional: Pre-configure for known networks (if needed)
# This could be extended to automatically connect to known SSIDs

exit 0
