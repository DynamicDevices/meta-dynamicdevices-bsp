#!/bin/sh

# Aggressive delayed wireless module loading for imx93-jaguar-eink (Option 2)
# Prioritized loading with background processing for maximum boot speed

echo "Starting aggressive wireless module loading..."

# Load essential WiFi modules first (highest priority, foreground)
modprobe mlan 2>/dev/null || echo "mlan module already loaded or not available"
modprobe moal 2>/dev/null || echo "moal module already loaded or not available"

# Load lower priority modules in background to not block boot
(
    # Bluetooth modules (medium priority, background)
    sleep 2
    modprobe bluetooth 2>/dev/null || echo "bluetooth module already loaded or not available"
    
    # Additional modules can be loaded here if needed
    sleep 5
    echo "Additional module loading complete"
    
    # Start services after modules are loaded
    sleep 2
    systemctl start bluetooth.service 2>/dev/null || echo "bluetooth.service already running or not available"
    
    echo "Background wireless module loading completed"
) &

echo "Essential wireless modules loaded, background loading started"
