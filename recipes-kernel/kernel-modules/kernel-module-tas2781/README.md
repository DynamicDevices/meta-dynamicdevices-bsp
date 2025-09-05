# TAS2563/TAS2781 Integrated Smart Amplifier Driver

This recipe provides the Texas Instruments TAS2563/TAS2781 integrated smart amplifier driver for the imx8mm-jaguar-sentai platform.

## Overview

The integrated driver supports both TAS2563 and TAS2781 smart amplifiers with the following features:
- On-chip DSP with Smart Amp speaker protection
- Multi-device support (up to 8 devices)
- I2C and SPI communication interfaces
- Real-time speaker voltage and current monitoring
- Device tree integration

## Source

The driver is sourced from the official Texas Instruments repository:
- Repository: https://git.ti.com/cgit/tas2781-linux-drivers/tas2781-linux-driver/
- Commit: 124282c12d471a53a2302881788c008fc2d3c364

## Integration

This driver replaces the previous TAS2563 driver for the imx8mm-jaguar-sentai machine and includes:

### Device Tree Changes
- Updated `/data_drive/dd/meta-dynamicdevices/meta-dynamicdevices-bsp/recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-sentai.dts`
- Simplified device tree configuration using standard bindings
- Proper GPIO and interrupt configuration

### Machine Configuration
- Updated `imx8mm-jaguar-sentai.conf` to use `tas2781-integrated` machine feature
- Replaced `tas2563` with `tas2781-integrated` in MACHINE_FEATURES

### Image Recipe
- Created `lmp-feature-tas2781-integrated.inc` feature file
- Updated `lmp-factory-image.bb` to use the new feature

## Hardware Configuration

The driver is configured for:
- I2C address: 0x4C
- Reset GPIO: GPIO5_4 (active high)
- Interrupt GPIO: GPIO5_5 (active low, level triggered)
- Audio interface: SAI3 (I2S format)

## Module Loading

The kernel module `snd-soc-integrated-tasdevice` is automatically loaded via the KERNEL_MODULE_AUTOLOAD mechanism.

## Dependencies

Required kernel configuration:
- CONFIG_SND_SOC_INTEGRATED_TASDEVICE=m
- CONFIG_REGMAP=y
- CONFIG_REGMAP_I2C=y
- CONFIG_I2C=y
- CONFIG_SYSFS=y
- CONFIG_CRC8=y
- CONFIG_GPIOLIB=y

## Usage

The driver creates an ALSA sound card named "TAS2563 Integrated Audio" which can be used with standard ALSA tools and applications.

## Compatibility

This driver is specifically configured for the `imx8mm-jaguar-sentai` machine and replaces the previous TAS2563 driver implementation.
