#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Script to configure RDC for UART4 access from A53 core
# This can be used as a fallback if device tree RDC configuration doesn't work

RDC_BASE=0x303d0000
UART4_PDAP_OFFSET=0x44

# Check if we're running on i.MX8MM
if [ ! -f /sys/firmware/devicetree/base/compatible ]; then
    echo "Cannot determine SoC compatibility"
    exit 1
fi

if ! grep -q "fsl,imx8mm" /sys/firmware/devicetree/base/compatible; then
    echo "This script is only for i.MX8MM"
    exit 1
fi

# Check if RDC is accessible
if [ ! -d /sys/kernel/debug ]; then
    echo "debugfs not mounted, mounting..."
    mount -t debugfs none /sys/kernel/debug
fi

# Function to configure UART4 for A53 domain access
configure_uart4_rdc() {
    echo "Configuring RDC for UART4 access from A53 core..."
    
    # UART4 PDAP configuration:
    # Bit 0-1: Domain 0 (A53) read/write access (0x3)
    # This assigns UART4 to A53 domain with full access
    
    # Use devmem to write RDC configuration if available
    if command -v devmem >/dev/null 2>&1; then
        # Configure UART4 PDAP for domain 0 access
        devmem $((RDC_BASE + UART4_PDAP_OFFSET)) 32 0x3
        echo "RDC configured: UART4 assigned to A53 domain"
        return 0
    else
        echo "devmem not available, cannot configure RDC"
        return 1
    fi
}

# Function to enable UART4 after RDC configuration
enable_uart4() {
    echo "Enabling UART4..."
    
    # Check if UART4 device exists in sysfs
    UART4_PATH="/sys/bus/platform/devices/30a70000.serial"
    
    if [ -d "$UART4_PATH" ]; then
        echo "UART4 device already exists"
    else
        # Try to trigger device probe
        echo "30a70000.serial" > /sys/bus/platform/drivers/imx-uart/bind 2>/dev/null || true
    fi
    
    # Verify UART4 is accessible
    if [ -c /dev/ttymxc3 ]; then
        echo "UART4 (/dev/ttymxc3) is now available"
        return 0
    else
        echo "UART4 still not accessible"
        return 1
    fi
}

# Main execution
echo "Starting RDC configuration for UART4..."

if configure_uart4_rdc; then
    sleep 1  # Give RDC time to apply changes
    if enable_uart4; then
        echo "UART4 successfully enabled"
        exit 0
    else
        echo "Failed to enable UART4"
        exit 1
    fi
else
    echo "Failed to configure RDC"
    exit 1
fi
