#!/bin/sh
# USB Audio Gadget Setup Script for imx8mm-jaguar-sentai
# Configures USB Audio Class 2.0 gadget (48kHz, 16-bit, stereo)
# Based on NXP USB gadget setup patterns
#
# Usage: setup-usb-audio-gadget {setup|stop|status|restart}
# Prerequisites: USB port in device mode, ConfigFS mounted
# 
# Author: Alex J Lennon <ajlennon@dynamicdevices.co.uk>

CONFIGFS=/sys/kernel/config/usb_gadget
GADGET_NAME="g_audio"
GADGET=$CONFIGFS/$GADGET_NAME
CONFIG=$GADGET/configs/c.1
FUNCTIONS=$GADGET/functions

# USB Device Descriptor
VID="0x1d6b"  # Linux Foundation
PID="0x0104"  # Multifunction Composite Gadget
SERIALNUMBER="$(cat /sys/devices/soc0/serial_number 2>/dev/null || cat /etc/machine-id 2>/dev/null || echo 'DD-UNKNOWN')"
MANUFACTURER="Dynamic Devices Ltd"
PRODUCT="Jaguar Sentai USB Audio"

# Audio Configuration
SAMPLE_RATE=48000
SAMPLE_SIZE=2  # 16-bit (2 bytes)
CHANNELS=2     # Stereo

# Function to add UAC2 audio function (based on NXP pattern)
add_uac2_function() {
    function_name="$1"
    capture_channels="$2"
    playback_channels="$3"
    
    mkdir "$FUNCTIONS/uac2.$function_name" || echo "  Couldn't create $FUNCTIONS/uac2.$function_name"
    
    echo "$PRODUCT $function_name" > "$FUNCTIONS/uac2.$function_name/function_name"
    echo $SAMPLE_RATE > "$FUNCTIONS/uac2.$function_name/c_srate"
    echo $SAMPLE_RATE > "$FUNCTIONS/uac2.$function_name/p_srate"
    echo $SAMPLE_SIZE > "$FUNCTIONS/uac2.$function_name/c_ssize"
    echo $SAMPLE_SIZE > "$FUNCTIONS/uac2.$function_name/p_ssize"
    echo "adaptive" > "$FUNCTIONS/uac2.$function_name/c_sync"
    echo "$capture_channels" > "$FUNCTIONS/uac2.$function_name/c_chmask"
    echo "$playback_channels" > "$FUNCTIONS/uac2.$function_name/p_chmask"
    
    # Enable volume and mute controls
    echo 0x1 > "$FUNCTIONS/uac2.$function_name/c_mute_present"
    echo 0x1 > "$FUNCTIONS/uac2.$function_name/c_volume_present"
    echo 0x1 > "$FUNCTIONS/uac2.$function_name/p_mute_present"
    echo 0x1 > "$FUNCTIONS/uac2.$function_name/p_volume_present"
    
    ln -s "$FUNCTIONS/uac2.$function_name" "$CONFIG" || echo "  Couldn't symlink uac2.$function_name"
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

# Function to setup USB audio gadget
setup_gadget() {
    echo "Setting up USB Audio Gadget..."
    
    # Create gadget configuration
    create_config "USB Audio Debug"
    
    # Add UAC2 functions for audio I/O
    # Playback: host -> device (TAS2563 codec)
    add_uac2_function "Playback" 0x0 $CHANNELS
    
    # Capture: device -> host (micfil input)  
    add_uac2_function "Capture" $CHANNELS 0x0
    
    echo "USB Audio Gadget configured successfully!"
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
    echo "Enabling USB Audio Gadget on $udc_device..."
    echo "$udc_device" > "$GADGET/UDC" || echo "  Couldn't write UDC"
    
    echo "USB Audio Gadget enabled!"
    echo "The device should now appear as a USB audio device when connected to a host."
}

# Function to disable the gadget (based on NXP cleanup pattern)
disable_gadget() {
    echo "Disabling USB Audio Gadget..."
    
    if [ -d "$GADGET" ]; then
        # Unbind from UDC first
        echo "" > "$GADGET/UDC" 2>/dev/null || true
        
        # Remove function symlinks from configuration
        rm -f "$CONFIG"/uac2.* 2>/dev/null || true
        
        # Remove configuration
        rm -rf "$CONFIG/strings/0x409" 2>/dev/null || true
        rm -rf "$CONFIG" 2>/dev/null || true
        
        # Remove functions
        rm -rf "${FUNCTIONS:?}"/* 2>/dev/null || true
        
        # Remove strings and gadget
        rm -rf "$GADGET/strings/0x409" 2>/dev/null || true
        rm -rf "$GADGET" 2>/dev/null || true
        
        echo "USB Audio Gadget disabled!"
    else
        echo "USB Audio Gadget is not configured."
    fi
}

# Function to show status
show_status() {
    echo "USB Audio Gadget Status:"
    echo "========================"
    
    if [ -d "$GADGET" ]; then
        echo "Gadget: CONFIGURED"
        echo "UDC: $(cat "$GADGET/UDC" 2>/dev/null || echo 'Not bound')"
        echo "Vendor ID: 0x$(cat "$GADGET/idVendor" 2>/dev/null || echo 'N/A')"
        echo "Product ID: 0x$(cat "$GADGET/idProduct" 2>/dev/null || echo 'N/A')"
        echo "Manufacturer: $(cat "$GADGET/strings/0x409/manufacturer" 2>/dev/null || echo 'N/A')"
        echo "Product: $(cat "$GADGET/strings/0x409/product" 2>/dev/null || echo 'N/A')"
        
        echo ""
        echo "Audio Functions:"
        for func in "$FUNCTIONS"/uac2.*; do
            if [ -d "$func" ]; then
                func_name="$(basename "$func")"
                echo "  $func_name:"
                echo "    Sample Rate: $(cat "$func/p_srate" 2>/dev/null || echo 'N/A') Hz"
                echo "    Playback Channels: $(cat "$func/p_chmask" 2>/dev/null || echo 'N/A')"
                echo "    Capture Channels: $(cat "$func/c_chmask" 2>/dev/null || echo 'N/A')"
            fi
        done
    else
        echo "Gadget: NOT CONFIGURED"
    fi
    
    echo ""
    echo "Available UDC devices:"
    ls /sys/class/udc/ 2>/dev/null || echo "  None found"
    
    echo ""
    echo "ALSA devices:"
    aplay -l 2>/dev/null || echo "  No playback devices"
    echo ""
    arecord -l 2>/dev/null || echo "  No capture devices"
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
        echo "  setup/start  - Configure and enable USB audio gadget"
        echo "  stop/disable - Disable and remove USB audio gadget"
        echo "  status       - Show current gadget status"
        echo "  restart      - Disable and re-enable gadget"
        echo ""
        echo "Note: Make sure the USB port is in device/OTG mode before running setup."
        exit 1
        ;;
esac
