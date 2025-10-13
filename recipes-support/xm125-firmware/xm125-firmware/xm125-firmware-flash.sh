#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Acconeer XM125 Radar Module Firmware Flashing Script
# Copyright 2025 Dynamic Devices Ltd
#
# This script handles firmware flashing for the Acconeer XM125 radar module
# using I2C communication and GPIO control.
#
# Hardware Configuration:
# - I2C3 (/dev/i2c-2) for communication
# - GPIO4_IO28 (gpiochip4 line 28) for reset control (active-low)
# - GPIO5_IO13 (gpiochip4 line 13) for bootloader control (BOOT0)
# - GPIO5_IO11 (gpiochip4 line 11) for wake up control (assert high to wake up)
# - GPIO4_IO29 (gpiochip4 line 29) for MCU interrupt input
#
# Usage:
#   xm125-firmware-flash.sh [firmware_file] [options]
#

set -e

# Configuration
XM125_I2C_BUS="/dev/i2c-2"
XM125_I2C_ADDR="0x52"
XM125_GPIO_CHIP="gpiochip4"
XM125_RESET_LINE="28"      # GPIO4_IO28 (SAI3_RXFS - active-low reset)
XM125_BOOT_LINE="13"       # GPIO5_IO13 (ECSPI2_SS0 - BOOT0 pin)
XM125_WAKE_LINE="11"       # GPIO5_IO11 (ECSPI2_MOSI - wake up control)
XM125_IRQ_LINE="29"        # GPIO4_IO29 (SAI3_RXC - MCU interrupt)
FIRMWARE_DIR="/lib/firmware/acconeer"
LOG_TAG="xm125-flash"

# Default firmware file
DEFAULT_FIRMWARE="i2c_presence_detector.bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ${LOG_TAG}:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ${LOG_TAG} ERROR:${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ${LOG_TAG} SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ${LOG_TAG} WARNING:${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for GPIO and I2C access"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v gpioset >/dev/null 2>&1 || missing_deps+=("libgpiod-tools")
    command -v gpioget >/dev/null 2>&1 || missing_deps+=("libgpiod-tools")
    command -v i2cdetect >/dev/null 2>&1 || missing_deps+=("i2c-tools")
    command -v stm32flash >/dev/null 2>&1 || missing_deps+=("stm32flash")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install the required packages"
        exit 1
    fi
}

# Check GPIO availability
check_gpio_availability() {
    log "Checking GPIO availability..."
    
    # List available GPIO chips
    log "Available GPIO chips:"
    if command -v gpiodetect >/dev/null 2>&1; then
        gpiodetect 2>&1 | while read line; do
            log "  $line"
        done
    else
        log "  gpiodetect not available"
        ls /dev/gpiochip* 2>/dev/null | while read chip; do
            log "  $chip"
        done
    fi
    
    # Check if our target GPIO chip exists
    if [ ! -e "/dev/${XM125_GPIO_CHIP}" ]; then
        log_error "GPIO chip ${XM125_GPIO_CHIP} not found!"
        log_error "Available chips: $(ls /dev/gpiochip* 2>/dev/null | tr '\n' ' ')"
        return 1
    fi
    
    log "GPIO chip ${XM125_GPIO_CHIP} found"
    return 0
}

# GPIO control functions
xm125_reset_assert() {
    log "Asserting XM125 reset (active low)"
    log "DEBUG: gpioset ${XM125_GPIO_CHIP} ${XM125_RESET_LINE}=0"
    gpioset "${XM125_GPIO_CHIP}" "${XM125_RESET_LINE}=0"
}

xm125_reset_deassert() {
    log "Deasserting XM125 reset"
    log "DEBUG: gpioset ${XM125_GPIO_CHIP} ${XM125_RESET_LINE}=1"
    gpioset "${XM125_GPIO_CHIP}" "${XM125_RESET_LINE}=1"
}

xm125_bootloader_mode() {
    log "Setting XM125 to bootloader mode (BOOT0 high)"
    log "DEBUG: gpioset ${XM125_GPIO_CHIP} ${XM125_BOOT_LINE}=1"
    gpioset "${XM125_GPIO_CHIP}" "${XM125_BOOT_LINE}=1"
}

xm125_run_mode() {
    log "Setting XM125 to run mode (BOOT0 low)"
    log "DEBUG: gpioset ${XM125_GPIO_CHIP} ${XM125_BOOT_LINE}=0"
    gpioset "${XM125_GPIO_CHIP}" "${XM125_BOOT_LINE}=0"
}

# Wake up control functions
xm125_wake_assert() {
    log "Asserting XM125 wake up (high)"
    log "DEBUG: gpioset ${XM125_GPIO_CHIP} ${XM125_WAKE_LINE}=1"
    gpioset "${XM125_GPIO_CHIP}" "${XM125_WAKE_LINE}=1"
}

xm125_wake_deassert() {
    log "Deasserting XM125 wake up (low)"
    log "DEBUG: gpioset ${XM125_GPIO_CHIP} ${XM125_WAKE_LINE}=0"
    gpioset "${XM125_GPIO_CHIP}" "${XM125_WAKE_LINE}=0"
}

# MCU interrupt status functions
xm125_wait_for_ready() {
    local timeout=${1:-30}  # Default 30 second timeout
    local count=0
    
    log "Waiting for XM125 MCU_INT to go HIGH (module ready)..."
    
    while [ $count -lt $timeout ]; do
        log "DEBUG: gpioget ${XM125_GPIO_CHIP} ${XM125_IRQ_LINE}"
        local mcu_int_status=$(gpioget "${XM125_GPIO_CHIP}" "${XM125_IRQ_LINE}")
        if [ "$mcu_int_status" = "1" ]; then
            log_success "XM125 module ready (MCU_INT HIGH)"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        if [ $((count % 5)) -eq 0 ]; then
            log "Still waiting for MCU_INT... ($count/${timeout}s)"
        fi
    done
    
    log_error "Timeout waiting for XM125 module ready signal"
    return 1
}

xm125_wait_for_low_power() {
    local timeout=${1:-10}  # Default 10 second timeout
    local count=0
    
    log "Waiting for XM125 MCU_INT to go LOW (low power ready)..."
    
    while [ $count -lt $timeout ]; do
        local mcu_int_status=$(gpioget "${XM125_GPIO_CHIP}" "${XM125_IRQ_LINE}")
        if [ "$mcu_int_status" = "0" ]; then
            log_success "XM125 entered low power mode (MCU_INT LOW)"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    log_error "Timeout waiting for XM125 low power signal"
    return 1
}

# XM125 initialization sequence for I2C communication
xm125_init_i2c_communication() {
    log "Starting XM125 I2C communication initialization sequence"
    
    # Step 1: Set WAKE_UP pin HIGH
    xm125_wake_assert
    
    # Step 2: Wait for MCU_INT to be HIGH (module ready)
    if ! xm125_wait_for_ready 30; then
        log_error "Failed to initialize XM125 for I2C communication"
        return 1
    fi
    
    # Step 3: I2C communication can now start
    log_success "XM125 ready for I2C communication"
    return 0
}

# XM125 low power mode sequence
xm125_enter_low_power() {
    log "Entering XM125 low power mode"
    
    # Step 1: Ensure module is ready (MCU_INT HIGH)
    if ! xm125_wait_for_ready 10; then
        log_warning "Module not ready, proceeding anyway"
    fi
    
    # Step 2: Set WAKE_UP pin LOW
    xm125_wake_deassert
    
    # Step 3: Wait for MCU_INT to become LOW
    if xm125_wait_for_low_power 10; then
        log_success "XM125 entered low power mode"
        return 0
    else
        log_warning "XM125 may not have entered low power mode properly"
        return 1
    fi
}

# I2C communication functions
xm125_i2c_detect() {
    log "Initializing XM125 for I2C communication..."
    
    # Follow proper initialization sequence
    if ! xm125_init_i2c_communication; then
        return 1
    fi
    
    log "Scanning I2C bus for XM125 module..."
    if i2cdetect -y 2 | grep -q "${XM125_I2C_ADDR#0x}"; then
        log_success "XM125 detected on I2C bus at address ${XM125_I2C_ADDR}"
        return 0
    else
        log_error "XM125 not detected on I2C bus at address ${XM125_I2C_ADDR}"
        return 1
    fi
}

# Firmware flashing function
flash_firmware() {
    local firmware_file="$1"
    
    if [[ ! -f "$firmware_file" ]]; then
        log_error "Firmware file not found: $firmware_file"
        return 1
    fi
    
    log "Starting firmware flash process..."
    log "Firmware file: $firmware_file"
    log "Size: $(stat -c%s "$firmware_file") bytes"
    
    # Step 1: Reset sequence for bootloader entry
    log "Step 1: Performing bootloader entry sequence"
    
    # Sequence for entering STM32 bootloader:
    # 1. Set BOOT0 high (bootloader mode)
    # 2. Assert reset (hold low)
    # 3. Wait minimum 10ms
    # 4. Deassert reset while BOOT0 is high
    # 5. Wait for bootloader to start (minimum 100ms)
    
    xm125_bootloader_mode
    sleep 0.01  # 10ms delay
    
    xm125_reset_assert
    sleep 0.01  # 10ms reset assertion
    
    xm125_reset_deassert
    sleep 0.1   # 100ms for bootloader startup
    
    log "Bootloader entry sequence completed"
    
    # Step 2: Check if module is in bootloader mode
    log "Step 2: Checking bootloader mode"
    if ! xm125_i2c_detect; then
        log_error "Failed to detect XM125 in bootloader mode"
        return 1
    fi
    
    # Step 3: Flash firmware using stm32flash
    log "Step 3: Flashing firmware using stm32flash..."
    
    # XM125 likely uses UART for bootloader communication
    # Find the appropriate UART device (this may need adjustment based on your setup)
    UART_DEVICE="/dev/ttyUSB0"  # Adjust this based on your UART connection
    
    if [[ ! -e "$UART_DEVICE" ]]; then
        log_warning "UART device $UART_DEVICE not found"
        log_warning "You may need to adjust UART_DEVICE in the script"
        log_warning "Common devices: /dev/ttyUSB0, /dev/ttyACM0, /dev/ttyS0"
        return 1
    fi
    
    # Use stm32flash to program the firmware
    # Note: XM125 parameters may need adjustment based on actual hardware
    log "Using stm32flash to program firmware via $UART_DEVICE"
    
    if stm32flash -w "$firmware_file" -v -g 0x0 "$UART_DEVICE"; then
        log_success "Firmware flashing completed successfully"
    else
        log_error "Firmware flashing failed"
        return 1
    fi
    
    # Step 4: Reset to run mode
    log "Step 4: Resetting to run mode"
    
    # Sequence for exiting bootloader to run mode:
    # 1. Set BOOT0 low (run mode)
    # 2. Assert reset 
    # 3. Wait minimum 10ms
    # 4. Deassert reset
    # 5. Wait for application startup (minimum 100ms)
    
    xm125_run_mode
    sleep 0.01  # 10ms delay
    
    xm125_reset_assert
    sleep 0.01  # 10ms reset assertion
    
    xm125_reset_deassert
    sleep 0.1   # 100ms for application startup
    
    log "Reset to run mode completed"
    
    # Step 5: Verify firmware
    log "Step 5: Verifying firmware"
    if xm125_i2c_detect; then
        log_success "Firmware flash completed successfully"
        return 0
    else
        log_error "Firmware verification failed"
        return 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [firmware_file] [options]

Arguments:
    firmware_file    Path to firmware binary file (optional)
                    Default: ${FIRMWARE_DIR}/${DEFAULT_FIRMWARE}

Options:
    -h, --help      Show this help message
    -l, --list      List available firmware files
    -d, --detect    Only detect XM125 module (no flashing)
    -r, --reset     Reset XM125 module only
    -v, --verbose   Enable verbose output

Examples:
    $0                                    # Flash default firmware
    $0 /path/to/custom_firmware.bin      # Flash custom firmware
    $0 --detect                          # Check if XM125 is present
    $0 --reset                           # Reset XM125 module

Hardware Requirements:
    - XM125 module connected to I2C3 (${XM125_I2C_BUS})
    - GPIO control lines properly configured
    - Root privileges for hardware access

EOF
}

# List available firmware files
list_firmware() {
    log "Available firmware files in ${FIRMWARE_DIR}:"
    if [[ -d "$FIRMWARE_DIR" ]]; then
        find "$FIRMWARE_DIR" -name "*.bin" -type f | while read -r file; do
            echo "  - $(basename "$file") ($(stat -c%s "$file") bytes)"
        done
    else
        log_warning "Firmware directory not found: $FIRMWARE_DIR"
    fi
}

# Main function
main() {
    local firmware_file=""
    local detect_only=false
    local reset_only=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                list_firmware
                exit 0
                ;;
            -d|--detect)
                detect_only=true
                shift
                ;;
            -r|--reset)
                reset_only=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                set -x
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                firmware_file="$1"
                shift
                ;;
        esac
    done
    
    # Set default firmware file if not specified
    if [[ -z "$firmware_file" && "$detect_only" = false && "$reset_only" = false ]]; then
        firmware_file="${FIRMWARE_DIR}/${DEFAULT_FIRMWARE}"
    fi
    
    log "XM125 Firmware Management Tool"
    log "==============================="
    
    # Check prerequisites
    check_root
    check_dependencies
    check_gpio_availability
    
    # Handle different modes
    if [[ "$detect_only" = true ]]; then
        log "Detection mode - checking for XM125 module"
        xm125_i2c_detect
        exit $?
    elif [[ "$reset_only" = true ]]; then
        log "Reset mode - resetting XM125 module"
        xm125_run_mode
        xm125_reset_assert
        sleep 0.1
        xm125_reset_deassert
        log_success "XM125 reset completed"
        exit 0
    else
        # Flash firmware
        if flash_firmware "$firmware_file"; then
            log_success "XM125 firmware management completed successfully"
            exit 0
        else
            log_error "XM125 firmware management failed"
            exit 1
        fi
    fi
}

# Run main function with all arguments
main "$@"
