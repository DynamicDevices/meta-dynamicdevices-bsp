# XM125 Radar Module Firmware Management

This package provides firmware management tools for the Acconeer XM125 radar module on the Dynamic Devices i.MX8MM Jaguar Sentai board.

## Hardware Configuration

- **I2C Interface**: I2C3 (`/dev/i2c-2`) at address `0x52` (default, configurable via I2C_ADDR pin)
- **Reset Control**: GPIO4_IO28 (gpiochip4 line 28) - Active Low (shared with BGT radar)
- **Bootloader Control**: GPIO5_IO13 (gpiochip4 line 13) - Active High (BOOT0 pin)
- **Wake Up Control**: GPIO5_IO11 (gpiochip4 line 11) - Assert High to wake up
- **MCU Interrupt**: GPIO4_IO29 (gpiochip4 line 29) - MCU interrupt input

### I2C Address Configuration
The XM125 I2C address is configurable based on the I2C_ADDR pin:
- **GND**: 0x51
- **Not Connected**: 0x52 (default)
- **VIN**: 0x53

### Reset and Bootloader Timing
- **Reset assertion**: Minimum 10ms
- **Bootloader startup**: Minimum 100ms after reset deassertion
- **BOOT0 control**: Must be set before reset for mode selection

### I2C Communication Initialization Sequence
The XM125 requires a specific sequence to initialize I2C communication:

1. **Set WAKE_UP pin HIGH**: Assert GPIO5_IO11 to wake the module
2. **Wait for MCU_INT to be HIGH**: Monitor GPIO4_IO29 until it goes HIGH (indicates module ready)
3. **Start I2C communication**: Module is now ready for I2C transactions

### Low Power Mode Sequence
To enter low power mode:

1. **Wait for MCU_INT HIGH**: Ensure module is ready
2. **Set WAKE_UP pin LOW**: Deassert GPIO5_IO11
3. **Wait for MCU_INT LOW**: Module confirms low power state

## Files Included

### Scripts
- `/usr/bin/xm125-firmware-flash.sh` - Main firmware flashing tool
- `/usr/bin/xm125-firmware-reset.sh` - Simple reset utility

### Systemd Service
- `xm125-firmware-manager.service` - Systemd service for module management

### Firmware Directory
- `/lib/firmware/acconeer/` - Acconeer XM125 firmware files

### Available Firmware Files
- `i2c_presence_detector.bin` - Presence detection application (97KB)
- `i2c_distance_detector.bin` - Distance measurement application (109KB) 
- `i2c_ref_app_breathing.bin` - Breathing detection reference app (106KB)

## Usage

### Basic Commands

```bash
# Reset the XM125 module
sudo xm125-firmware-reset.sh

# Detect if XM125 is present
sudo xm125-firmware-flash.sh --detect

# List available firmware files
sudo xm125-firmware-flash.sh --list

# Flash default firmware
sudo xm125-firmware-flash.sh

# Flash custom firmware
sudo xm125-firmware-flash.sh /lib/firmware/acconeer/i2c_distance_detector.bin
```

### Manual I2C Communication Setup

If you need to manually set up I2C communication with the XM125:

```bash
# Step 1: Wake up the module
gpioset gpiochip4 11=1

# Step 2: Wait for module ready signal
while [ "$(gpioget gpiochip4 29)" != "1" ]; do
    echo "Waiting for XM125 ready..."
    sleep 1
done
echo "XM125 ready for I2C communication"

# Step 3: Now you can use I2C tools
i2cdetect -y 2
i2cget -y 2 0x52 0x00  # Example I2C read

# Step 4: Enter low power mode when done
gpioset gpiochip4 11=0  # Set WAKE_UP low
while [ "$(gpioget gpiochip4 29)" != "0" ]; do
    echo "Waiting for low power mode..."
    sleep 1
done
echo "XM125 in low power mode"
```

### Systemd Service

```bash
# Enable automatic reset on boot
sudo systemctl enable xm125-firmware-manager.service

# Start the service
sudo systemctl start xm125-firmware-manager.service

# Check service status
sudo systemctl status xm125-firmware-manager.service

# Manually trigger reset via service
sudo systemctl reload xm125-firmware-manager.service
```

## Adding Firmware Files

To add actual firmware files to the recipe:

1. **Copy firmware files** to the recipe directory:
   ```
   meta-dynamicdevices-bsp/recipes-support/xm125-firmware/xm125-firmware/
   ```

2. **Update the recipe** (`xm125-firmware_1.0.0.bb`):
   ```bitbake
   # Uncomment and modify these lines:
   SRC_URI += " \
       file://xm125_firmware_v1.0.0.bin \
       file://xm125_bootloader_v1.0.0.bin \
   "
   
   # In do_install(), uncomment:
   install -m 0644 ${WORKDIR}/xm125_firmware_v1.0.0.bin ${D}${datadir}/xm125-firmware/
   install -m 0644 ${WORKDIR}/xm125_bootloader_v1.0.0.bin ${D}${datadir}/xm125-firmware/
   ```

3. **Update checksums** if needed for proprietary firmware files.

## Development Notes

### Firmware Flashing Protocol

The current flashing script is a **template**. You need to implement the actual XM125 bootloader protocol in the `flash_firmware()` function. This typically involves:

1. **Bootloader Commands**: Send specific I2C commands to enter flash mode
2. **Data Transfer**: Send firmware data in chunks via I2C
3. **Verification**: Verify checksums and successful programming
4. **Reset**: Exit bootloader and start new firmware

### I2C Communication

Use standard Linux I2C tools for development:

```bash
# Scan for devices
i2cdetect -y 2

# Read from device
i2cget -y 2 0x52 0x00

# Write to device  
i2cset -y 2 0x52 0x00 0xFF
```

### GPIO Control

Direct GPIO control examples:

```bash
# Reset control (active low)
gpioset gpiochip4 28=0  # Assert reset
gpioset gpiochip4 28=1  # Deassert reset

# Bootloader control (BOOT0)
gpioset gpiochip4 13=1  # Bootloader mode
gpioset gpiochip4 13=0  # Run mode

# Wake up control
gpioset gpiochip4 11=1  # Assert wake up
gpioset gpiochip4 11=0  # Deassert wake up

# MCU interrupt (input only - read status)
gpioget gpiochip4 29    # Read interrupt status
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure to run scripts as root
2. **GPIO Not Found**: Verify XM125 overlay is applied (`xm125-radar` feature enabled)
3. **I2C Device Not Found**: Check hardware connections and I2C bus
4. **Module Not Responding**: Try manual reset sequence

### Debug Commands

```bash
# Check if overlay is applied
ls /sys/class/gpio/gpiochip*

# Check I2C bus
i2cdetect -l
i2cdetect -y 2

# Check systemd service logs
journalctl -u xm125-firmware-manager.service
```

## Hardware Requirements

- XM125 radar module properly connected to I2C3
- GPIO control lines wired correctly
- `xm125-radar` machine feature enabled
- Device tree overlay applied

## Dependencies

- `libgpiod-tools` - GPIO control utilities
- `i2c-tools` - I2C communication utilities
- `bash` - Shell scripting support

---

**Note**: This is a template implementation. Actual firmware flashing requires implementing the XM125-specific bootloader protocol according to Acconeer's documentation.
