#!/bin/sh

# Load delayed components for imx93-jaguar-eink workflow
# Load non-essential modules after WiFi and network are operational

echo "Loading delayed components after network initialization..."

# Load Bluetooth modules in background (not needed for image updates)
(
    sleep 10  # Wait for network operations to complete
    echo "Loading Bluetooth modules..."
    modprobe bluetooth 2>/dev/null || echo "bluetooth module already loaded or not available"
    modprobe hci_uart 2>/dev/null || echo "hci_uart module already loaded or not available"
    modprobe btmrvl 2>/dev/null || echo "btmrvl module already loaded or not available"
    modprobe btmrvl_sdio 2>/dev/null || echo "btmrvl_sdio module already loaded or not available"
    
    # Start Bluetooth service if needed
    systemctl start bluetooth.service 2>/dev/null || echo "bluetooth.service already running or not available"
    echo "Bluetooth modules loaded"
) &

# Load additional modules in background (not needed for image updates)
(
    sleep 10  # Wait for essential components first
    echo "Loading additional modules..."
    # Load other non-essential modules here if needed
    echo "Additional modules loaded"
) &

# Load LTE modem modules if needed (backup connectivity)
(
    sleep 20  # Load LTE last as WiFi is primary
    echo "Loading LTE modem modules..."
    modprobe option 2>/dev/null || echo "option module already loaded or not available"
    modprobe cdc_acm 2>/dev/null || echo "cdc_acm module already loaded or not available"
    echo "LTE modem modules loaded"
) &

echo "Delayed component loading initiated in background"
