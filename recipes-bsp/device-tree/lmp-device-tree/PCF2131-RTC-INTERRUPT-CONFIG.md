# PCF2131 RTC Interrupt Configuration Guide

## Overview

The PCF2131 RTC on the i.MX93 Jaguar E-Ink board supports dual interrupt outputs that can be configured for different power management scenarios.

## Hardware Configuration

### Interrupt Pins
- **INTA#** → GPIO4_IO22 (MX93_PAD_ENET2_RX_CTL) → i.MX93 wake interrupt
- **INTB#** → RTC_INTB → MCXC143VFM PMU PTC5/LLWU_P9 → PMU wake capability

### I2C Connection
- **Bus**: LPI2C3
- **Address**: 0x53
- **SDA**: GPIO_IO28 (Pin J21)
- **SCL**: GPIO_IO29 (Pin J20)

## Configuration Options

### 1. INTA# Only (Default)
**File**: `imx93-jaguar-eink.dts` (default configuration)
**Overlay**: `imx93-jaguar-eink-rtc-inta-only.dtso`

```dts
nxp,interrupt-mode = "inta-only";
```

**Use Case**: Standard i.MX93 system wake from Deep Sleep Mode
**Benefits**: 
- Simple configuration
- Direct i.MX93 wake capability
- Lower power consumption

### 2. INTB# Only
**Overlay**: `imx93-jaguar-eink-rtc-intb-only.dtso`

```dts
nxp,interrupt-mode = "intb-only";
```

**Use Case**: PMU-managed wake scenarios
**Benefits**:
- PMU microcontroller handles wake logic
- Advanced battery management
- Custom power sequencing

### 3. Dual Interrupt Mode
**Overlay**: `imx93-jaguar-eink-rtc-dual.dtso`

```dts
nxp,interrupt-mode = "dual";
nxp,dual-interrupt-mode;
```

**Use Case**: Maximum redundancy and flexibility
**Benefits**:
- Both i.MX93 and PMU wake capability
- Interrupt redundancy
- Advanced power management scenarios

### 4. Interrupts Disabled
**Overlay**: `imx93-jaguar-eink-rtc-disabled.dtso`

```dts
nxp,interrupt-mode = "disabled";
```

**Use Case**: RTC timekeeping only, no wake functionality
**Benefits**:
- Lowest power consumption
- No interrupt conflicts
- Simple polling-based operation

## Usage Instructions

### Method 1: Edit Device Tree Source
1. Edit `imx93-jaguar-eink.dts`
2. Change the `nxp,interrupt-mode` property:
   ```dts
   nxp,interrupt-mode = "inta-only";  // or "intb-only", "dual", "disabled"
   ```
3. Rebuild and deploy

### Method 2: Apply Device Tree Overlay (Runtime)
1. Copy desired overlay to target device
2. Apply overlay:
   ```bash
   # For INTB# only
   dtoverlay imx93-jaguar-eink-rtc-intb-only
   
   # For dual interrupt mode
   dtoverlay imx93-jaguar-eink-rtc-dual
   
   # For disabled interrupts
   dtoverlay imx93-jaguar-eink-rtc-disabled
   ```

### Method 3: Kernel Module Parameter (Future Enhancement)
```bash
# Load driver with specific interrupt mode
modprobe rtc-pcf2127 interrupt_mode=inta-only
```

## Testing Interrupt Configuration

### Verify Current Configuration
```bash
# Check RTC device
cat /sys/class/rtc/rtc0/name

# Check interrupt configuration
cat /proc/interrupts | grep rtc

# Test alarm functionality
echo +10 > /sys/class/rtc/rtc0/wakealarm
```

### Debug Interrupt Issues
```bash
# Check GPIO configuration
cat /sys/kernel/debug/gpio

# Monitor interrupt activity
cat /proc/interrupts

# Check device tree configuration
cat /proc/device-tree/soc@0/bus@42000000/i2c@42530000/rtc@53/nxp,interrupt-mode
```

## Power Management Integration

### Deep Sleep Mode Wake
- **INTA# mode**: Direct i.MX93 wake
- **INTB# mode**: PMU-mediated wake
- **Dual mode**: Both wake paths available

### Battery Optimization
- **INTA# only**: Minimal power, direct wake
- **INTB# only**: PMU-managed power optimization
- **Dual mode**: Maximum flexibility, higher power
- **Disabled**: Lowest power, no wake capability

## Troubleshooting

### Common Issues
1. **"failed to configure interrupt pins"**: Check GPIO pin conflicts
2. **No wake from alarm**: Verify interrupt mode matches hardware setup
3. **High power consumption**: Consider disabling unused interrupt outputs

### Diagnostic Commands
```bash
# Check RTC status
hwclock --show
timedatectl status

# Verify interrupt configuration
dmesg | grep pcf2131
lsmod | grep rtc
```

## Hardware Validation

The interrupt pin assignments have been validated against:
- Schematic document: 202500r1.pdf
- Hardware testing on target device
- i.MX93 Reference Manual pin definitions

**Confirmed Connections**:
- ✅ INTA# → GPIO4_IO22 → i.MX93 wake
- ✅ INTB# → RTC_INTB → PMU PTC5/LLWU_P9 → PMU wake
- ✅ I2C3 bus → LPI2C3 → GPIO_IO28/29
