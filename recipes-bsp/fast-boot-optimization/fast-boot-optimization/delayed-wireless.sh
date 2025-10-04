#!/bin/sh

# Delayed wireless module loading for imx93-jaguar-eink (Option 1 optimization)
# Load wireless modules after boot completion for faster initial boot

echo "Loading wireless modules after boot completion..."

# Load essential WiFi modules first (highest priority)
modprobe mlan 2>/dev/null || echo "mlan module already loaded or not available"
modprobe moal 2>/dev/null || echo "moal module already loaded or not available"

# Load Bluetooth modules (medium priority)
modprobe bluetooth 2>/dev/null || echo "bluetooth module already loaded or not available"

# Load WiFi and Bluetooth modules (medium priority - needed for updates)
echo "Loading WiFi and Bluetooth modules..."
modprobe mlan 2>/dev/null || echo "mlan module already loaded or not available"
modprobe moal 2>/dev/null || echo "moal module already loaded or not available"

echo "Wireless modules loading completed"

# Start essential wireless services
systemctl start bluetooth.service 2>/dev/null || echo "bluetooth.service already running or not available"

# Optional: Start additional services (uncomment if needed)
# systemctl start wpa_supplicant.service
