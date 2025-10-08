#!/bin/bash
# EdgeLock Enclave Status Display Script
# Shows comprehensive ELE subsystem status for i.MX93

set -e

ELE_DEVICE="/dev/ele_mu"
ELE_SYSFS="/sys/class/misc/ele_mu"
ELE_FIRMWARE_DIR="/lib/firmware/imx/ele"

echo "🔐 EdgeLock Enclave (ELE) Status Report"
echo "======================================="
echo "Platform: i.MX93 Jaguar E-Ink"
echo "Date: $(date)"
echo ""

# Check ELE Device Node
echo "📋 Device Node Status:"
if [ -e "$ELE_DEVICE" ]; then
    echo "  ✅ ELE device node: $ELE_DEVICE (present)"
    ls -la "$ELE_DEVICE"
else
    echo "  ❌ ELE device node: $ELE_DEVICE (missing)"
fi
echo ""

# Check ELE Sysfs Interface
echo "📁 Sysfs Interface:"
if [ -d "$ELE_SYSFS" ]; then
    echo "  ✅ ELE sysfs: $ELE_SYSFS (present)"
    echo "  📄 Available attributes:"
    ls -la "$ELE_SYSFS/" 2>/dev/null | grep -v "^total" | sed 's/^/    /'
else
    echo "  ❌ ELE sysfs: $ELE_SYSFS (missing)"
fi
echo ""

# Check ELE Firmware
echo "💾 Firmware Status:"
if [ -d "$ELE_FIRMWARE_DIR" ]; then
    echo "  ✅ Firmware directory: $ELE_FIRMWARE_DIR (present)"
    echo "  📦 Available firmware files:"
    ls -la "$ELE_FIRMWARE_DIR/" 2>/dev/null | grep -v "^total" | sed 's/^/    /'
else
    echo "  ❌ Firmware directory: $ELE_FIRMWARE_DIR (missing)"
fi
echo ""

# Check Kernel Modules
echo "🔧 Kernel Module Status:"
echo "  📋 ELE-related modules:"
lsmod | grep -i ele || echo "    ℹ️  No ELE-specific modules found"
echo ""

# Check dmesg for ELE messages
echo "📜 Recent ELE Kernel Messages:"
dmesg | grep -i "ele\|enclave\|seco" | tail -10 | sed 's/^/  /' || echo "  ℹ️  No recent ELE messages found"
echo ""

# Check Security State
echo "🔒 Security Information:"
if [ -r "/proc/device-tree/chosen/bootargs" ]; then
    echo "  📋 Boot arguments:"
    cat /proc/device-tree/chosen/bootargs 2>/dev/null | tr '\0' ' ' | sed 's/^/    /'
else
    echo "  ℹ️  Boot arguments not accessible"
fi
echo ""

# Check ELE Process Status
echo "⚙️  Process Status:"
echo "  📋 ELE-related processes:"
ps aux | grep -i ele | grep -v grep | sed 's/^/    /' || echo "    ℹ️  No ELE-related processes found"
echo ""

# System Information
echo "💻 System Information:"
echo "  📋 Kernel version: $(uname -r)"
echo "  📋 Architecture: $(uname -m)"
echo "  📋 Uptime: $(uptime | cut -d',' -f1 | sed 's/^.*up //')"
echo ""

echo "✅ ELE Status Report Complete"
echo ""
echo "💡 Tips:"
echo "  - Use 'ele-dev-tools debug' for detailed debugging"
echo "  - Use 'ele-dev-tools test' to run functionality tests"
echo "  - Check dmesg for ELE initialization messages after boot"
