# MCUmgr Machine Feature

## Overview

The `mcumgr` machine feature enables support for **MCUmgr command-line tool** for managing Zephyr RTOS devices with MCUboot bootloader support.

## Hardware Context

This feature is specifically designed for boards that include:
- **Dedicated microcontrollers** for power management (e.g., MCXC143VFM)
- **Zephyr RTOS** running on the microcontroller
- **MCUboot bootloader** with serial recovery support
- **UART/Serial communication** between the main processor and microcontroller

## Enabled Components

When the `mcumgr` machine feature is present, the following components are automatically included:

### Core MCUmgr Tools
- **mcumgr-simple**: Command-line tool for device management
- **mcumgr-setup**: Helper script for connection configuration

### Serial Communication
- **screen**: Terminal emulator for serial debugging
- **minicom**: Alternative serial communication tool

### Development Tools (Debug Builds Only)
- **python3-serial**: Python serial communication library
- **python3-pyserial**: Additional Python serial support
- **strace**: System call tracing for debugging

## Usage

### Machine Configuration

Add the feature to your machine configuration:

```bitbake
MACHINE_FEATURES:append:your-machine = " mcumgr"
```

### Automatic Integration

The feature automatically:
- Includes the mcumgr command-line tool
- Configures serial device permissions
- Adds development tools for debug builds
- Sets up user groups for serial access

## Current Machines

The following machines currently use this feature:

- `imx93-jaguar-eink`: i.MX93-based E-Ink platform with MCXC143VFM power controller

## MCUmgr Operations

### Connection Setup
```bash
# Setup serial connection to Zephyr device
mcumgr-setup /dev/ttyUSB0 115200 serial1
```

### Firmware Management
```bash
# List current firmware images
mcumgr -c serial1 image list

# Upload new firmware
mcumgr -c serial1 image upload firmware.signed.bin

# Reset device to apply update
mcumgr -c serial1 reset

# Test and confirm new firmware
mcumgr -c serial1 image test <hash>
mcumgr -c serial1 image confirm <hash>
```

### Device Management
```bash
# Echo test (connectivity check)
mcumgr -c serial1 echo "Hello Zephyr"

# Get device information
mcumgr -c serial1 taskstat
mcumgr -c serial1 mpstat
```

## Hardware Requirements

### Serial Interface
- UART connection between main processor and microcontroller
- Typical configuration: 115200 baud, 8N1
- Device typically appears as `/dev/ttyUSB0` or `/dev/ttyACM0`

### Microcontroller Requirements
- **Zephyr RTOS** with MCUmgr server enabled
- **MCUboot bootloader** with serial recovery support
- **Flash partitioning** for bootloader and application slots
- **Signed firmware images** for secure updates

## Integration Example

For the imx93-jaguar-eink board with MCXC143VFM microcontroller:

```bitbake
# In imx93-jaguar-eink.conf
MACHINE_FEATURES:append:imx93-jaguar-eink = " mcumgr"
```

This enables:
- MCUmgr tool for managing the MCXC143VFM power controller
- Serial communication tools for debugging
- Development utilities for firmware development
- Proper permissions for accessing `/dev/ttyUSB0`

## Security Considerations

### Firmware Signing
- Always use signed firmware images in production
- MCUboot verifies signatures before installing updates
- Keys should be managed securely and rotated regularly

### Access Control
- Serial device access requires appropriate user permissions
- Consider using dedicated service accounts for automated updates
- Implement proper authentication for remote access

## Development Workflow

### Typical Update Process
1. **Build firmware** with Zephyr build system
2. **Sign firmware** with MCUboot signing key
3. **Copy to Linux system** running MCUmgr
4. **Upload via MCUmgr** over serial connection
5. **Test and confirm** new firmware

### Debugging
```bash
# Monitor serial output
screen /dev/ttyUSB0 115200

# Test MCUmgr connectivity
mcumgr -c serial1 echo test

# Check MCUmgr connection status
mcumgr conn show
```

## Related Features

This feature works well with:
- **mcuboot**: For MCUboot bootloader support
- **debug-tweaks**: Enables additional development tools
- **wifi**: For remote firmware deployment scenarios

## Repository References

- **MCUmgr CLI**: https://github.com/apache/mynewt-mcumgr-cli
- **Zephyr MCUmgr**: https://docs.zephyrproject.org/latest/services/device_mgmt/mcumgr.html
- **MCUboot**: https://docs.mcuboot.com/

## Future Extensions

This machine feature can be extended to support:
- **Bluetooth LE transport** for wireless firmware updates
- **UDP transport** for network-based updates
- **Batch update scripts** for multiple device management
- **Integration with OTA systems** like Foundries.io or RDFM
