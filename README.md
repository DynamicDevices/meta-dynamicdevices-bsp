# meta-dynamicdevices-bsp

**Professional Yocto BSP Layer for Dynamic Devices Edge Computing Platforms**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![License: Commercial](https://img.shields.io/badge/License-Commercial-green.svg)](mailto:licensing@dynamicdevices.co.uk)
[![Yocto Compatible](https://img.shields.io/badge/Yocto-scarthgap%20|%20kirkstone-orange.svg)](https://www.yoctoproject.org/)
[![YP Compliance Ready](https://img.shields.io/badge/YP%20Compliance-BSP%20Ready-blue)](https://docs.yoctoproject.org/test-manual/yocto-project-compatible.html)
[![BSP Layer Validation](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/actions/workflows/bsp-layer-validation.yml/badge.svg)](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/actions/workflows/bsp-layer-validation.yml)

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

## Documentation & Support

📚 **Comprehensive Documentation**: For detailed documentation, tutorials, and technical guides, visit the [meta-dynamicdevices Wiki](https://github.com/DynamicDevices/meta-dynamicdevices/wiki).

The wiki includes:
- Getting started guides
- Hardware setup instructions  
- Build configuration examples
- Troubleshooting guides
- Development best practices

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

This BSP layer is available under **dual licensing**:

### 🆓 **Open Source License (GPL v3)**
- Free to use for open source projects
- Must comply with GPL v3 copyleft requirements
- Source code modifications must be shared

### 💼 **Commercial License**
- Available for proprietary/commercial use
- No copyleft restrictions
- Custom support and maintenance available
- Contact: licensing@dynamicdevices.co.uk

See the [LICENSE](./LICENSE) file for complete terms and conditions.

## Related Projects

- **[meta-dynamicdevices](https://github.com/DynamicDevices/meta-dynamicdevices)** - Main application layer
- **[Wiki](https://github.com/DynamicDevices/meta-dynamicdevices/wiki)** - Comprehensive documentation

