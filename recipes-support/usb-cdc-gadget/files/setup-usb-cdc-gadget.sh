#!/bin/sh
# USB CDC (Serial) Gadget Setup Script for imx8mm-jaguar-sentai
# Creates a USB CDC ACM (Abstract Control Model) serial interface
# Based on NXP USB gadget setup patterns from conversav2
#
# Usage: setup-usb-cdc-gadget {setup|stop|status|restart}
# Prerequisites: USB port in device mode, ConfigFS mounted
#
# Author: Alex J Lennon <ajlennon@dynamicdevices.co.uk>

CONFIGFS=/sys/kernel/config/usb_gadget
GADGET_NAME="g_cdc"
GADGET=$CONFIGFS/$GADGET_NAME
CONFIG=$GADGET/configs/c.1
FUNCTIONS=$GADGET/functions

# USB Device Descriptor
VID="0x1d6b"  # Linux Foundation
PID="0x0104"  # Multifunction Composite Gadget
SERIALNUMBER="$(cat /sys/devices/soc0/serial_number 2>/dev/null || cat /etc/machine-id 2>/dev/null || echo 'DD-UNKNOWN')"
MANUFACTURER="Dynamic Devices Ltd"
PRODUCT="Jaguar Sentai USB CDC Serial"

# Function to add CDC ACM function (based on NXP pattern)
add_acm_function() {
    function_name="$1"
    
    mkdir "$FUNCTIONS/acm.$function_name" || echo "  Couldn't create $FUNCTIONS/acm.$function_name"
    ln -s "$FUNCTIONS/acm.$function_name" "$CONFIG" || echo "  Couldn't symlink acm.$function_name"
}

# Function to create gadget configuration (based on NXP pattern)
create_config() {
    config_name="$1"
    
    # Check if ConfigFS is available
    if ! [ -e "$CONFIGFS" ]; then
        echo "  $CONFIGFS does not exist, skipping configfs usb gadget"
        return 1
    fi
    
    # Create USB gadget configuration
    mkdir "$GADGET" || echo "  Couldn't create $GADGET"
    echo $VID > "$GADGET/idVendor"
    echo $PID > "$GADGET/idProduct"
    
    mkdir "$GADGET/strings/0x409" || echo "  Couldn't create $GADGET/strings/0x409"
    echo "$SERIALNUMBER" > "$GADGET/strings/0x409/serialnumber"
    echo "$MANUFACTURER" > "$GADGET/strings/0x409/manufacturer"
    echo "$PRODUCT" > "$GADGET/strings/0x409/product"
    
    # Create configuration instance for the gadget
    mkdir "$CONFIG" || echo "  Couldn't create $CONFIG"
    mkdir "$CONFIG/strings/0x409" || echo "  Couldn't create $CONFIG/strings/0x409"
    echo "$config_name" > "$CONFIG/strings/0x409/configuration" || echo "  Couldn't write configuration name"
}

# Function to setup USB CDC gadget
setup_gadget() {
    echo "Setting up USB CDC Serial Gadget..."
    
    # Create gadget configuration
    create_config "USB CDC Debug"
    
    # Add CDC ACM function for serial communication
    add_acm_function "debug"
    
    echo "USB CDC Serial Gadget configured successfully!"
}

# Function to enable the gadget
enable_gadget() {
    # Check if there's a USB Device Controller
    if [ -z "$(ls /sys/class/udc 2>/dev/null)" ]; then
        echo "  No USB Device Controller available"
        return 1
    fi
    
    # Activate the gadget
    udc_device="$(find /sys/class/udc -maxdepth 1 -type l | head -1 | xargs basename 2>/dev/null)"
    echo "Enabling USB CDC Serial Gadget on $udc_device..."
    echo "$udc_device" > "$GADGET/UDC" || echo "  Couldn't write UDC"
    
    # Configure the serial device for proper operation
    if [ -c /dev/ttyGS0 ]; then
        echo "Configuring /dev/ttyGS0 for serial communication..."
        stty -F /dev/ttyGS0 raw 2>/dev/null || echo "  Warning: Couldn't configure ttyGS0 (may not be ready yet)"
        stty -F /dev/ttyGS0 -echo 2>/dev/null || true
        stty -F /dev/ttyGS0 noflsh 2>/dev/null || true
        echo "USB CDC Serial device available at /dev/ttyGS0"
    else
        echo "Warning: /dev/ttyGS0 not yet available (may appear shortly)"
    fi
    
    echo "USB CDC Serial Gadget enabled!"
    echo "Host computer should detect a new CDC ACM serial device."
}

# Function to disable the gadget (based on NXP cleanup pattern)
disable_gadget() {
    echo "Disabling USB CDC Serial Gadget..."
    
    if [ -d "$GADGET" ]; then
        # Unbind from UDC first
        echo "" > "$GADGET/UDC" 2>/dev/null || true
        
        # Remove function symlinks from configuration
        rm -f "$CONFIG"/acm.* 2>/dev/null || true
        
        # Remove configuration
        rm -rf "$CONFIG/strings/0x409" 2>/dev/null || true
        rm -rf "$CONFIG" 2>/dev/null || true
        
        # Remove functions
        rm -rf "${FUNCTIONS:?}"/* 2>/dev/null || true
        
        # Remove strings and gadget
        rm -rf "$GADGET/strings/0x409" 2>/dev/null || true
        rm -rf "$GADGET" 2>/dev/null || true
        
        echo "USB CDC Serial Gadget disabled!"
    else
        echo "USB CDC Serial Gadget is not configured."
    fi
}

# Function to show status
show_status() {
    echo "USB CDC Serial Gadget Status:"
    echo "============================="
    
    if [ -d "$GADGET" ]; then
        echo "Gadget: CONFIGURED"
        echo "UDC: $(cat "$GADGET/UDC" 2>/dev/null || echo 'Not bound')"
        echo "Vendor ID: 0x$(cat "$GADGET/idVendor" 2>/dev/null || echo 'N/A')"
        echo "Product ID: 0x$(cat "$GADGET/idProduct" 2>/dev/null || echo 'N/A')"
        echo "Manufacturer: $(cat "$GADGET/strings/0x409/manufacturer" 2>/dev/null || echo 'N/A')"
        echo "Product: $(cat "$GADGET/strings/0x409/product" 2>/dev/null || echo 'N/A')"
        
        echo ""
        echo "CDC ACM Functions:"
        for func in "$FUNCTIONS"/acm.*; do
            if [ -d "$func" ]; then
                func_name="$(basename "$func")"
                echo "  $func_name: Available"
            fi
        done
        
        echo ""
        echo "Serial Device:"
        if [ -c /dev/ttyGS0 ]; then
            echo "  /dev/ttyGS0: Available"
            echo "  Device permissions: $(ls -l /dev/ttyGS0 | awk '{print $1 " " $3 " " $4}')"
        else
            echo "  /dev/ttyGS0: Not available"
        fi
    else
        echo "Gadget: NOT CONFIGURED"
    fi
    
    echo ""
    echo "Available UDC devices:"
    ls /sys/class/udc/ 2>/dev/null || echo "  None found"
    
    echo ""
    echo "USB Role Status:"
    for role_path in $(find /sys -name 'role' 2>/dev/null | head -3); do
        current_role=$(cat "$role_path" 2>/dev/null || echo 'unknown')
        echo "  $role_path: $current_role"
    done
}

# Main script logic
case "$1" in
    "setup"|"start")
        disable_gadget  # Clean up any existing configuration
        setup_gadget
        enable_gadget
        ;;
    "stop"|"disable")
        disable_gadget
        ;;
    "status")
        show_status
        ;;
    "restart")
        disable_gadget
        setup_gadget
        enable_gadget
        ;;
    *)
        echo "Usage: $0 {setup|start|stop|disable|status|restart}"
        echo ""
        echo "Commands:"
        echo "  setup/start  - Configure and enable USB CDC serial gadget"
        echo "  stop/disable - Disable and remove USB CDC serial gadget"
        echo "  status       - Show current gadget status"
        echo "  restart      - Disable and re-enable gadget"
        echo ""
        echo "Note: Make sure the USB port is in device/OTG mode before running setup."
        echo "After setup, the device will appear as a CDC ACM serial port on the host."
        echo "Use /dev/ttyGS0 on the target for serial communication."
        exit 1
        ;;
esac
