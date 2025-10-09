# ELE Foundries.io Integration Setup Guide

This guide explains how to configure EdgeLock Enclave (ELE) integration with Foundries.io for the `imx93-jaguar-eink` board.

## Overview

The `imx93-jaguar-eink` board uses EdgeLock Enclave (ELE) instead of SE05X for hardware security. This provides:

- **Hardware-based key storage** in the i.MX93's built-in security controller
- **PKCS#11 interface** for cryptographic operations
- **Secure device registration** with Foundries.io
- **Integrated OTA updates** using hardware-backed credentials

## Prerequisites

1. **Hardware**: i.MX93 Jaguar E-Ink board with ELE support
2. **Software**: LmP v95.2+ with ELE drivers enabled
3. **Foundries.io Account**: Active factory with device registration enabled
4. **Registration Token**: From your Foundries.io dashboard

## Installation

The ELE integration is automatically included in the `imx93-jaguar-eink` build. The following packages are installed:

- `lmp-ele-foundries` - Main ELE integration package
- `nxp-ele-test-suite` - ELE testing utilities
- `nxp-ele-dev-tools` - ELE development and debugging tools

## Configuration Steps

### 1. Initial Setup (Run on Target Device)

```bash
# Run the provisioning setup script
sudo ele-provisioning-setup.sh

# This will:
# - Check ELE hardware availability
# - Create PKCS#11 module (stub)
# - Set up HSM configuration template
# - Create provisioning service
```

### 2. HSM Configuration

Edit `/etc/sota/hsm` with your specific settings:

```bash
sudo nano /etc/sota/hsm
```

**Required settings:**
```bash
HSM_MODULE="/usr/lib/pkcs11/ele-pkcs11.so"
HSM_PIN="your_secure_pin"
HSM_SOPIN="your_secure_so_pin"
ELE_DEVICE="/dev/ele_mu"
```

**Security Note**: Change the default PINs to secure values for production use.

### 3. Factory Configuration

Edit `/etc/default/lmp-ele-auto-register`:

```bash
sudo nano /etc/default/lmp-ele-auto-register
```

**Required changes:**
```bash
REPOID="your-factory-name"          # Your Foundries.io factory name
DEVICE_GROUP="your-device-group"    # Device group (e.g., "production")
DEVICE_TAG="your-device-tag"        # Device tag (e.g., "eink-v1")
```

### 4. Registration Token

Install your Foundries.io registration token:

```bash
# Get token from Foundries.io dashboard
sudo echo "your_registration_token_here" > /etc/lmp-device-register-token
sudo chmod 600 /etc/lmp-device-register-token
```

### 5. Enable Services

```bash
# Enable the ELE auto-registration service
sudo systemctl enable lmp-ele-auto-register.service

# Start the service (will register device)
sudo systemctl start lmp-ele-auto-register.service
```

## Testing and Validation

### 1. Hardware Test

```bash
# Test ELE hardware functionality
simple-ele-test all
enhanced-ele-test all
```

### 2. Integration Test

```bash
# Run comprehensive integration test
test-ele-foundries-integration.sh

# Check specific components
test-ele-foundries-integration.sh hardware
test-ele-foundries-integration.sh config
```

### 3. Service Status

```bash
# Check service status
sudo systemctl status lmp-ele-auto-register.service

# View service logs
sudo journalctl -u lmp-ele-auto-register.service -f
```

### 4. Device Registration Status

```bash
# Check if device is registered
ls -la /var/sota/sql.db

# View device information
aktualizr-lite status
```

## Troubleshooting

### ELE Hardware Issues

```bash
# Check ELE device
ls -la /dev/ele_mu

# Check ELE drivers
lsmod | grep ele

# Check device tree
find /proc/device-tree -name "*ele*" -o -name "*s4muap*"

# View ELE messages
dmesg | grep -i ele
```

### PKCS#11 Issues

```bash
# Check PKCS#11 module
ls -la /usr/lib/pkcs11/ele-pkcs11.so

# Test module loading
pkcs11-tool --module /usr/lib/pkcs11/ele-pkcs11.so --list-slots
```

### Registration Issues

```bash
# Check token file
cat /etc/lmp-device-register-token

# Manual registration test
lmp-device-register --help

# Check network connectivity
ping app.foundries.io
```

### Debug Tools

```bash
# ELE debug session
ele-debug.sh interactive

# ELE status report
ele-status.sh

# ELE firmware information
ele-firmware-info.sh

# Foundries.io CLI
ele-foundries-cli.py status
```

## Production Deployment

### Security Considerations

1. **Change Default PINs**: Update HSM_PIN and HSM_SOPIN in `/etc/sota/hsm`
2. **Secure Token Storage**: Protect registration token file permissions
3. **Enable Production Mode**: Set `PRODUCTION_MODE="1"` in HSM config
4. **Firmware Verification**: Ensure ELE firmware is authentic

### Factory Integration

1. **Customize Configuration**: Update factory-specific settings
2. **Device Grouping**: Use appropriate device groups and tags
3. **Certificate Management**: Implement proper CA certificate handling
4. **Monitoring**: Set up device health monitoring

## File Locations

| File | Purpose |
|------|---------|
| `/etc/sota/hsm` | HSM configuration |
| `/etc/default/lmp-ele-auto-register` | Factory settings |
| `/etc/lmp-device-register-token` | Registration token |
| `/usr/lib/pkcs11/ele-pkcs11.so` | PKCS#11 module |
| `/var/sota/sql.db` | Registration database |
| `/usr/share/lmp-ele-foundries/hsm-config-template` | Config template |

## Support

For issues with ELE integration:

1. **Run diagnostics**: `test-ele-foundries-integration.sh`
2. **Check logs**: `/var/log/ele-foundries-test.log`
3. **Hardware validation**: `simple-ele-test all`
4. **Contact support**: Include test results and logs

## Advanced Configuration

### Custom PKCS#11 Implementation

The included PKCS#11 module is a basic stub. For production use, implement:

1. **Full PKCS#11 compliance**
2. **ELE API integration**
3. **Key management operations**
4. **Certificate handling**

### Manual Device Registration

```bash
# Manual registration with ELE HSM
lmp-device-register \
  --hsm-module /usr/lib/pkcs11/ele-pkcs11.so \
  --hsm-pin 1234 \
  --hsm-so-pin 123456 \
  -g your-group \
  -T your-token \
  -n $(hostname)
```

This completes the ELE Foundries.io integration setup for the `imx93-jaguar-eink` board.
