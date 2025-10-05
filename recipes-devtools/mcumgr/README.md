# MCUmgr Yocto Integration for Zephyr RTOS Bootloader Updates

This directory contains Yocto recipes for building MCUmgr, a command-line tool for managing Zephyr RTOS devices with MCUboot bootloader support.

## Overview

MCUmgr is the standard tool for updating Zephyr RTOS bootloaders and applications. It supports:

- **Firmware Updates**: Upload new firmware images to devices
- **Multiple Transports**: UART/Serial, Bluetooth LE, UDP over IP
- **MCUboot Integration**: Works seamlessly with MCUboot bootloader
- **Secure Updates**: Supports signed firmware images
- **Device Management**: Image listing, testing, confirmation, and reset

## Files

- `mcumgr_git.bb` - Full-featured recipe with Go toolchain integration
- `mcumgr-simple_git.bb` - Simplified recipe for basic builds
- `mcumgr-support.inc` - Include file to easily add mcumgr to images

## Usage

### Option 1: Add to Existing Image

Add this line to your image recipe (e.g., `lmp-factory-image.bbappend`):

```bitbake
require recipes-devtools/mcumgr/mcumgr-support.inc
```

### Option 2: Add Package Directly

Add to your image recipe or local.conf:

```bitbake
IMAGE_INSTALL += "mcumgr-simple"
```

### Option 3: Build as Standalone Package

```bash
# In your Yocto build environment
bitbake mcumgr-simple
```

## Prerequisites

The recipe requires Go compiler to be available in your build environment. Most modern Yocto distributions include Go support.

If Go is not available, you can:

1. **Add Go to your distro**: Include `go` in your `DISTRO_FEATURES`
2. **Use pre-built binary**: Download mcumgr binary and create a simple install recipe
3. **Cross-compile separately**: Build mcumgr outside Yocto and package the binary

## Testing the Integration

After building your image with mcumgr support:

1. **Boot your Yocto system**
2. **Connect Zephyr device**: Connect your Zephyr device via UART/USB
3. **Setup connection**:
   ```bash
   mcumgr-setup /dev/ttyUSB0 115200 serial1
   ```
4. **Test connection**:
   ```bash
   mcumgr -c serial1 image list
   ```

## Example: Updating Zephyr Bootloader

Based on your existing project at `/data_drive/esl/eink-microcontroller`:

```bash
# On your Yocto Linux system:

# 1. Setup mcumgr connection
mcumgr-setup /dev/ttyUSB0 115200 serial1

# 2. Upload new firmware (signed binary)
mcumgr -c serial1 image upload /path/to/zephyr.signed.bin

# 3. Reset device to apply update
mcumgr -c serial1 reset

# 4. Verify new firmware is running
mcumgr -c serial1 image list
```

## Integration with Your Existing Project

Your project already uses mcumgr successfully in the `target_scripts/firmware_update.py`. This Yocto recipe allows you to:

1. **Include mcumgr in your Linux image**: No need to install separately
2. **Standardize the tool**: Same mcumgr version across all systems
3. **Simplify deployment**: Everything needed is in the image
4. **Enable automation**: Scripts can rely on mcumgr being available

## Compatibility

- **Zephyr RTOS**: All versions with MCUboot support
- **MCUboot**: All versions with serial recovery
- **Transports**: UART/Serial (primary), Bluetooth LE, UDP
- **Architectures**: ARM Cortex-M (your MCXC143VFM), others supported by Zephyr

## Troubleshooting

### Build Issues

```bash
# Check if Go is available
bitbake -e mcumgr-simple | grep "^GO"

# Force rebuild
bitbake -c cleansstate mcumgr-simple
bitbake mcumgr-simple
```

### Runtime Issues

```bash
# Check mcumgr installation
which mcumgr
mcumgr version

# Test serial connection
mcumgr conn show
mcumgr -c serial1 echo hello
```

### Connection Problems

```bash
# Check serial device
ls -la /dev/ttyUSB* /dev/ttyACM*

# Test with screen first
screen /dev/ttyUSB0 115200

# Check mcumgr connection
mcumgr -c serial1 image list
```

## Advanced Configuration

### Custom Transport

```bash
# Bluetooth LE connection
mcumgr conn add ble type="ble" connstring="peer=XX:XX:XX:XX:XX:XX"

# UDP connection  
mcumgr conn add udp type="udp" connstring="host=192.168.1.100,port=1337"
```

### Batch Operations

```bash
# Script for automated updates
#!/bin/bash
FIRMWARE="$1"
mcumgr -c serial1 image upload "$FIRMWARE"
mcumgr -c serial1 image test $(mcumgr -c serial1 image list | grep "pending" | cut -d' ' -f4)
mcumgr -c serial1 reset
sleep 5
mcumgr -c serial1 image confirm
```

## Security Notes

- Always use signed firmware images in production
- Verify image integrity before upload
- Use secure transports (encrypted) when possible
- Implement proper access controls on the Linux system

## References

- [MCUmgr Documentation](https://docs.zephyrproject.org/latest/services/device_mgmt/mcumgr.html)
- [MCUboot Documentation](https://docs.mcuboot.com/)
- [Zephyr RTOS Device Management](https://docs.zephyrproject.org/latest/services/device_mgmt/index.html)
- [Your Project Documentation](../../../eink-microcontroller/README.md)
