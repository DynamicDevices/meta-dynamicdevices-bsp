# XM125 Radar Monitor

Production CLI tool for Acconeer XM125 radar modules with automatic firmware management, multi-mode detection (distance, presence, breathing), and GPIO control.

## Features

- Multi-mode radar detection (distance, presence, breathing)
- Automatic firmware management
- GPIO control integration
- Configuration file support
- Backward compatibility with shell scripts

## Usage

```bash
# Basic usage
xm125-radar-monitor

# Set mode
xm125-radar-monitor --mode presence

# Use custom config
xm125-radar-monitor --config /etc/xm125/custom.toml

# Verbose output
xm125-radar-monitor --verbose
```

## Compatibility

This tool provides backward compatibility through symlinks:
- `xm125-control` → `xm125-radar-monitor`
- `xm125-firmware-flash` → `xm125-radar-monitor`

## Configuration

Configuration files can be placed in `/etc/xm125/` directory.

## License

GPL-3.0-or-later
