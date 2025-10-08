#!/bin/bash
# EdgeLock Enclave Firmware Information Script
# Displays detailed information about ELE firmware

set -e

ELE_FIRMWARE_DIR="/lib/firmware/imx/ele"

echo "💾 EdgeLock Enclave Firmware Information"
echo "========================================"
echo "Platform: i.MX93 Jaguar E-Ink"
echo ""

# Check firmware directory
if [ ! -d "$ELE_FIRMWARE_DIR" ]; then
    echo "❌ ELE firmware directory not found: $ELE_FIRMWARE_DIR"
    echo ""
    echo "💡 Troubleshooting:"
    echo "  - Ensure 'firmware-ele-imx' package is installed"
    echo "  - Check if ELE support is enabled in kernel"
    echo "  - Verify machine configuration includes ELE firmware"
    exit 1
fi

echo "📁 Firmware Directory: $ELE_FIRMWARE_DIR"
echo ""

# List all firmware files with detailed information
echo "📦 Available Firmware Files:"
echo ""

firmware_found=0

for fw_file in "$ELE_FIRMWARE_DIR"/*; do
    if [ -f "$fw_file" ]; then
        firmware_found=1
        filename=$(basename "$fw_file")
        size=$(stat -c%s "$fw_file")
        size_kb=$((size / 1024))
        modified=$(stat -c%y "$fw_file" | cut -d'.' -f1)
        permissions=$(stat -c%A "$fw_file")
        hash=$(sha256sum "$fw_file" | cut -d' ' -f1)
        
        echo "  📄 $filename"
        echo "      Size: $size bytes (${size_kb} KB)"
        echo "      Modified: $modified"
        echo "      Permissions: $permissions"
        echo "      SHA256: $hash"
        
        # Try to identify firmware type
        case "$filename" in
            *mx93a1*)
                echo "      Type: i.MX93 A1 revision firmware"
                ;;
            *mx93a0*)
                echo "      Type: i.MX93 A0 revision firmware"
                ;;
            *ahab*)
                echo "      Type: Advanced High Assurance Boot (AHAB) container"
                ;;
            *)
                echo "      Type: Unknown ELE firmware"
                ;;
        esac
        
        echo ""
    fi
done

if [ $firmware_found -eq 0 ]; then
    echo "  ⚠️  No firmware files found in $ELE_FIRMWARE_DIR"
    echo ""
fi

# Check firmware loading status
echo "🔄 Firmware Loading Status:"
echo ""

# Check dmesg for firmware loading messages
firmware_messages=$(dmesg | grep -i "firmware.*ele\|ele.*firmware" | tail -5)
if [ -n "$firmware_messages" ]; then
    echo "  📜 Recent firmware loading messages:"
    echo "$firmware_messages" | sed 's/^/    /'
else
    echo "  ℹ️  No recent firmware loading messages found"
fi
echo ""

# Check if ELE is operational
echo "⚙️  ELE Operational Status:"
echo ""

if [ -e "/dev/ele_mu" ]; then
    echo "  ✅ ELE device node present: /dev/ele_mu"
else
    echo "  ❌ ELE device node missing: /dev/ele_mu"
fi

if [ -d "/sys/class/misc/ele_mu" ]; then
    echo "  ✅ ELE sysfs interface present"
else
    echo "  ❌ ELE sysfs interface missing"
fi

# Check for ELE-related kernel modules
echo ""
echo "🔧 Kernel Module Status:"
echo ""

ele_modules=$(lsmod | grep -i ele || true)
if [ -n "$ele_modules" ]; then
    echo "  📋 ELE-related modules:"
    echo "$ele_modules" | sed 's/^/    /'
else
    echo "  ℹ️  No ELE-specific kernel modules found"
fi

echo ""

# Security and boot information
echo "🔒 Security Information:"
echo ""

# Check secure boot status (if available)
if [ -r "/proc/device-tree/chosen/bootargs" ]; then
    bootargs=$(cat /proc/device-tree/chosen/bootargs 2>/dev/null | tr '\0' ' ')
    if echo "$bootargs" | grep -q "secure"; then
        echo "  🔐 Secure boot parameters detected in bootargs"
    else
        echo "  ℹ️  No explicit secure boot parameters in bootargs"
    fi
else
    echo "  ℹ️  Boot arguments not accessible"
fi

# Check for AHAB/ELE initialization messages
ahab_messages=$(dmesg | grep -i "ahab\|secure.*boot" | tail -3)
if [ -n "$ahab_messages" ]; then
    echo "  📜 AHAB/Secure boot messages:"
    echo "$ahab_messages" | sed 's/^/    /'
fi

echo ""

# Recommendations
echo "💡 Recommendations:"
echo ""
echo "  - Use 'ele-dev-tools test' to verify ELE functionality"
echo "  - Check 'dmesg | grep -i ele' for detailed boot messages"
echo "  - Ensure proper ELE configuration in device tree"
echo "  - Verify secure boot chain integrity"

if [ $firmware_found -eq 0 ]; then
    echo ""
    echo "⚠️  Action Required:"
    echo "  - Install firmware-ele-imx package"
    echo "  - Rebuild image with ELE support enabled"
    echo "  - Check machine configuration for ELE firmware inclusion"
fi
