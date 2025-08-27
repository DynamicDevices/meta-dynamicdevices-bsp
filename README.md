# meta-dynamicdevices-bsp

Board Support Package (BSP) layer for Dynamic Devices Edge Computing platforms.

## Overview

This layer provides hardware-specific support for Dynamic Devices edge computing platforms, including:

- **i.MX8MM-based platforms**: Jaguar Sentai, Inst, Handheld, Phasora
- **i.MX93-based platforms**: Jaguar eInk

## Layer Type

This is a **BSP (Board Support Package) layer** that provides:

- Machine configurations (`conf/machine/`)
- Hardware-specific kernel configurations
- Device tree sources and overlays
- Board initialization scripts
- Hardware-specific firmware and drivers

## Supported Machines

| Machine | Description | SoC |
|---------|-------------|-----|
| `imx8mm-jaguar-sentai` | Audio processing platform | i.MX8MM |
| `imx8mm-jaguar-inst` | Industrial IoT platform | i.MX8MM |
| `imx8mm-jaguar-handheld` | Handheld device platform | i.MX8MM |
| `imx8mm-jaguar-phasora` | Multi-sensor platform | i.MX8MM |
| `imx93-jaguar-eink` | E-ink display platform | i.MX93 |

## Usage

To use this BSP layer, add it to your `bblayers.conf`:

```
BBLAYERS += "/path/to/meta-dynamicdevices-bsp"
```

Then select the appropriate machine:

```
MACHINE = "imx8mm-jaguar-sentai"
```

## Dependencies

- `meta-lmp-base` - Linux microPlatform base layer
- `meta-freescale` - NXP/Freescale BSP layer
- `openembedded-core` - Core OpenEmbedded layer

## Yocto Project Compatibility

This layer is designed to be **Yocto Project Compatible** and follows BSP layer best practices:

- Contains only hardware-specific configurations and recipes
- Does not modify builds unless a supported MACHINE is selected
- Passes `yocto-check-layer` validation as a BSP layer

## Maintainer

**Dynamic Devices Ltd**  
Email: info@dynamicdevices.co.uk  
Website: https://dynamicdevices.co.uk

## License

See individual recipe files for license information.
