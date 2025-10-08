#!/bin/bash
# EdgeLock Enclave Debug Script
# Advanced debugging tools for ELE subsystem

set -e

ELE_DEVICE="/dev/ele_mu"
ELE_SYSFS="/sys/class/misc/ele_mu"

echo "🔍 EdgeLock Enclave Debug Session"
echo "=================================="
echo ""

# Function to check ELE device accessibility
check_device_access() {
    echo "🔧 Device Access Check:"
    
    if [ ! -e "$ELE_DEVICE" ]; then
        echo "  ❌ ELE device not found: $ELE_DEVICE"
        return 1
    fi
    
    echo "  ✅ Device exists: $ELE_DEVICE"
    
    # Check permissions
    if [ -r "$ELE_DEVICE" ]; then
        echo "  ✅ Device readable"
    else
        echo "  ⚠️  Device not readable (check permissions)"
    fi
    
    if [ -w "$ELE_DEVICE" ]; then
        echo "  ✅ Device writable"
    else
        echo "  ⚠️  Device not writable (check permissions)"
    fi
    
    echo ""
}

# Function to dump ELE registers (if accessible)
dump_ele_registers() {
    echo "📊 ELE Register Information:"
    echo "  ℹ️  Register access requires root privileges"
    
    # This would require specific ELE register addresses
    # Placeholder for actual register dump functionality
    echo "  📋 Register dump functionality - implementation needed"
    echo ""
}

# Function to test ELE communication
test_ele_communication() {
    echo "💬 ELE Communication Test:"
    
    if [ ! -c "$ELE_DEVICE" ]; then
        echo "  ❌ ELE device is not a character device"
        return 1
    fi
    
    # Basic device open test
    if timeout 5 cat "$ELE_DEVICE" >/dev/null 2>&1; then
        echo "  ✅ Device can be opened for reading"
    else
        echo "  ⚠️  Device read test failed or timed out"
    fi
    
    echo ""
}

# Function to check ELE firmware integrity
check_firmware_integrity() {
    echo "🔐 Firmware Integrity Check:"
    
    local firmware_dir="/lib/firmware/imx/ele"
    
    if [ ! -d "$firmware_dir" ]; then
        echo "  ❌ Firmware directory not found: $firmware_dir"
        return 1
    fi
    
    echo "  📁 Firmware directory: $firmware_dir"
    
    for fw_file in "$firmware_dir"/*; do
        if [ -f "$fw_file" ]; then
            local filename=$(basename "$fw_file")
            local size=$(stat -c%s "$fw_file")
            local hash=$(sha256sum "$fw_file" | cut -d' ' -f1)
            
            echo "  📦 $filename:"
            echo "      Size: $size bytes"
            echo "      SHA256: $hash"
        fi
    done
    
    echo ""
}

# Function to monitor ELE activity
monitor_ele_activity() {
    echo "📡 ELE Activity Monitor:"
    echo "  ℹ️  Monitoring kernel messages for ELE activity..."
    echo "  ℹ️  Press Ctrl+C to stop monitoring"
    echo ""
    
    # Monitor dmesg for ELE-related messages
    dmesg -w | grep -i --line-buffered "ele\|enclave\|seco" | while read line; do
        echo "  📜 $(date '+%H:%M:%S'): $line"
    done
}

# Function to run interactive debug session
interactive_debug() {
    echo "🎮 Interactive ELE Debug Session:"
    echo ""
    
    while true; do
        echo "Available debug options:"
        echo "  1. Check device access"
        echo "  2. Test communication"
        echo "  3. Check firmware integrity"
        echo "  4. Monitor activity"
        echo "  5. Dump system info"
        echo "  6. Exit"
        echo ""
        
        read -p "Select option (1-6): " choice
        
        case $choice in
            1)
                check_device_access
                ;;
            2)
                test_ele_communication
                ;;
            3)
                check_firmware_integrity
                ;;
            4)
                monitor_ele_activity
                ;;
            5)
                echo "📋 System Information:"
                uname -a
                cat /proc/version
                echo ""
                ;;
            6)
                echo "👋 Exiting debug session"
                break
                ;;
            *)
                echo "❌ Invalid option. Please select 1-6."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Main execution
case "${1:-interactive}" in
    "access")
        check_device_access
        ;;
    "comm")
        test_ele_communication
        ;;
    "firmware")
        check_firmware_integrity
        ;;
    "monitor")
        monitor_ele_activity
        ;;
    "interactive"|"")
        interactive_debug
        ;;
    *)
        echo "Usage: $0 [access|comm|firmware|monitor|interactive]"
        echo ""
        echo "Options:"
        echo "  access      - Check device access"
        echo "  comm        - Test communication"
        echo "  firmware    - Check firmware integrity"
        echo "  monitor     - Monitor ELE activity"
        echo "  interactive - Interactive debug session (default)"
        exit 1
        ;;
esac
