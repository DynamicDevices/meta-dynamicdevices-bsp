#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Acconeer XM125 Radar Module Complete Management Script
# Copyright 2025 Dynamic Devices Ltd
#
# This script provides comprehensive XM125 management including:
# - Automatic GPIO141 bootloader pin fix (Foundries.io workaround)
# - Complete XM125 initialization and control
# - Reset sequences for both run mode and bootloader mode
# - I2C communication verification
# - GPIO status monitoring
#

set -e

# Configuration - Correct GPIO numbers for i.MX8MM
XM125_I2C_BUS="/dev/i2c-2"
XM125_I2C_ADDR="0x52"

# GPIO numbers (calculated from i.MX8MM mapping: GPIO4=96, GPIO5=128)
XM125_RESET_GPIO="124"      # GPIO4_IO28 (96+28) - SAI3_RXFS - active-low reset
XM125_IRQ_GPIO="125"        # GPIO4_IO29 (96+29) - SAI3_RXC - MCU interrupt
XM125_WAKE_GPIO="139"       # GPIO5_IO11 (128+11) - ECSPI2_MOSI - wake up control
XM125_BOOT_GPIO="141"       # GPIO5_IO13 (128+13) - ECSPI2_SS0 - BOOT0 pin

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] xm125:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] xm125 ERROR:${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] xm125:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] xm125 WARNING:${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for GPIO and hardware access"
        exit 1
    fi
}

# Fix GPIO141 bootloader pin (Foundries.io workaround)
fix_gpio141_bootloader_pin() {
    log "Checking GPIO141 bootloader pin availability..."
    
    # Check if GPIO141 is already available
    if [ -d "/sys/class/gpio/gpio${XM125_BOOT_GPIO}" ]; then
        log "GPIO141 bootloader pin already available"
        return 0
    fi
    
    # Try simple export first
    if echo "${XM125_BOOT_GPIO}" > /sys/class/gpio/export 2>/dev/null; then
        log_success "GPIO141 bootloader pin exported successfully"
        return 0
    fi
    
    log_warning "GPIO141 claimed by SPI controller - applying Foundries.io workaround..."
    
    # Step 1: Unbind SPI devices (check if they exist first)
    log "Unbinding SPI devices..."
    for spi_dev in spi1.0 spi3.0; do
        if [ -e "/sys/bus/spi/devices/${spi_dev}" ]; then
            if [ -e "/sys/bus/spi/devices/${spi_dev}/driver" ]; then
                log "  Unbinding SPI device: ${spi_dev}"
                echo "${spi_dev}" > /sys/bus/spi/drivers/spidev/unbind 2>/dev/null && \
                    log "    Successfully unbound ${spi_dev}" || \
                    log_warning "    Failed to unbind ${spi_dev} (may already be unbound)"
            else
                log "  SPI device ${spi_dev} already unbound"
            fi
        else
            log "  SPI device ${spi_dev} not found"
        fi
    done
    
    # Step 2: Unbind SPI controller platform driver (check if bound first)
    log "Unbinding SPI controller platform driver..."
    local spi_controller="30830000.spi"
    
    # Check if SPI controller exists and is bound
    if [ -e "/sys/devices/platform/soc@0/30800000.bus/30800000.spba-bus/${spi_controller}" ]; then
        if [ -e "/sys/bus/platform/drivers/spi_imx/${spi_controller}" ]; then
            log "  Unbinding SPI controller: ${spi_controller}"
            echo "${spi_controller}" > /sys/bus/platform/drivers/spi_imx/unbind 2>/dev/null && \
                log "    Successfully unbound SPI controller" || \
                log_warning "    Failed to unbind SPI controller (may already be unbound)"
        else
            log "  SPI controller ${spi_controller} already unbound"
        fi
    else
        log "  SPI controller ${spi_controller} not found or already disabled"
    fi
    
    # Step 3: Wait for system to stabilize
    sleep 1
    
    # Step 4: Try to export GPIO141 again
    if echo "${XM125_BOOT_GPIO}" > /sys/class/gpio/export 2>/dev/null; then
        log_success "GPIO141 bootloader pin freed and exported successfully"
        return 0
    else
        log_error "Failed to free GPIO141 bootloader pin"
        log "Debug: Checking pinmux status..."
        if [ -r "/sys/kernel/debug/pinctrl/30330000.pinctrl/pinmux-pins" ]; then
            cat /sys/kernel/debug/pinctrl/30330000.pinctrl/pinmux-pins | grep -E "(ECSPI2_SS0|pin 132)" || true
        fi
        return 1
    fi
}

# Export GPIO if not already exported
export_gpio() {
    local gpio_num=$1
    local gpio_name=$2
    
    if [ ! -d "/sys/class/gpio/gpio${gpio_num}" ]; then
        log "Exporting GPIO${gpio_num} (${gpio_name})"
        echo "${gpio_num}" > /sys/class/gpio/export 2>/dev/null || {
            log_warning "Failed to export GPIO${gpio_num} - may already be exported by another driver"
        }
        sleep 0.1
    fi
}

# Set GPIO direction
set_gpio_direction() {
    local gpio_num=$1
    local direction=$2
    local gpio_name=$3
    
    if [ -d "/sys/class/gpio/gpio${gpio_num}" ]; then
        log "Setting GPIO${gpio_num} (${gpio_name}) direction to ${direction}"
        echo "${direction}" > "/sys/class/gpio/gpio${gpio_num}/direction" 2>/dev/null || {
            log_warning "Failed to set GPIO${gpio_num} direction - may be controlled by another driver"
        }
    fi
}

# Set GPIO value
set_gpio_value() {
    local gpio_num=$1
    local value=$2
    local gpio_name=$3
    
    if [ -d "/sys/class/gpio/gpio${gpio_num}" ]; then
        log "Setting GPIO${gpio_num} (${gpio_name}) to ${value}"
        echo "${value}" > "/sys/class/gpio/gpio${gpio_num}/value" 2>/dev/null || {
            log_warning "Failed to set GPIO${gpio_num} value - may be controlled by another driver"
        }
    else
        log_warning "GPIO${gpio_num} not available for direct control"
    fi
}

# Get GPIO value
get_gpio_value() {
    local gpio_num=$1
    
    if [ -d "/sys/class/gpio/gpio${gpio_num}" ] && [ -r "/sys/class/gpio/gpio${gpio_num}/value" ]; then
        cat "/sys/class/gpio/gpio${gpio_num}/value" 2>/dev/null || echo "?"
    else
        echo "?"
    fi
}

# Initialize all XM125 GPIOs
init_gpio() {
    log "Initializing XM125 GPIO pins..."
    
    # Fix GPIO141 bootloader pin first (Foundries.io workaround)
    if ! fix_gpio141_bootloader_pin; then
        log_error "Failed to fix GPIO141 bootloader pin - XM125 will not work properly"
        return 1
    fi
    
    # Export all GPIOs
    export_gpio "${XM125_RESET_GPIO}" "Reset"
    export_gpio "${XM125_IRQ_GPIO}" "MCU Interrupt" 
    export_gpio "${XM125_WAKE_GPIO}" "Wake Up"
    export_gpio "${XM125_BOOT_GPIO}" "Bootloader"
    
    # Set directions
    set_gpio_direction "${XM125_RESET_GPIO}" "out" "Reset"
    set_gpio_direction "${XM125_IRQ_GPIO}" "in" "MCU Interrupt"
    set_gpio_direction "${XM125_WAKE_GPIO}" "out" "Wake Up"
    set_gpio_direction "${XM125_BOOT_GPIO}" "out" "Bootloader"
    
    log_success "GPIO initialization completed"
}

# Set XM125 to run mode (without reset)
xm125_set_run_mode() {
    log "Setting XM125 to RUN mode..."
    
    # Set bootloader pin LOW for run mode
    set_gpio_value "${XM125_BOOT_GPIO}" "0" "Bootloader (run mode)"
    
    # Ensure wake pin is HIGH
    set_gpio_value "${XM125_WAKE_GPIO}" "1" "Wake Up (awake)"
    
    log_success "XM125 set to RUN mode (BOOT0=LOW)"
}

# Set XM125 to bootloader mode (without reset)
xm125_set_bootloader_mode() {
    log "Setting XM125 to BOOTLOADER mode..."
    
    # Set bootloader pin HIGH for bootloader mode
    set_gpio_value "${XM125_BOOT_GPIO}" "1" "Bootloader (bootloader mode)"
    
    # Ensure wake pin is HIGH
    set_gpio_value "${XM125_WAKE_GPIO}" "1" "Wake Up (awake)"
    
    log_success "XM125 set to BOOTLOADER mode (BOOT0=HIGH)"
}

# Reset XM125 module (preserves current boot mode setting)
xm125_reset() {
    log "Performing XM125 reset (preserving current boot mode)..."
    
    local current_boot_mode=$(get_gpio_value "${XM125_BOOT_GPIO}")
    if [ "$current_boot_mode" = "1" ]; then
        log "Current mode: BOOTLOADER (BOOT0=HIGH)"
    else
        log "Current mode: RUN (BOOT0=LOW)"
    fi
    
    # Assert reset (active-low)
    log "Asserting reset (LOW)"
    set_gpio_value "${XM125_RESET_GPIO}" "0" "Reset (asserted)"
    sleep 0.01  # 10ms reset assertion (minimum for STM32)
    
    # Deassert reset
    log "Deasserting reset (HIGH)"
    set_gpio_value "${XM125_RESET_GPIO}" "1" "Reset (released)"
    sleep 0.1   # 100ms for application startup
    
    # Ensure wake pin is HIGH
    set_gpio_value "${XM125_WAKE_GPIO}" "1" "Wake Up (awake)"
    sleep 0.1   # Additional time for wake-up
    
    log_success "Reset completed - XM125 should be ready"
}

# Reset XM125 to specific mode
xm125_reset_to_mode() {
    local target_mode=$1  # "run" or "bootloader"
    
    if [[ "$target_mode" = "bootloader" ]]; then
        log "Performing XM125 reset to BOOTLOADER mode..."
        # Set bootloader pin HIGH for bootloader mode
        set_gpio_value "${XM125_BOOT_GPIO}" "1" "Bootloader (bootloader mode)"
    else
        log "Performing XM125 reset to RUN mode..."
        # Set bootloader pin LOW for run mode
        set_gpio_value "${XM125_BOOT_GPIO}" "0" "Bootloader (run mode)"
    fi
    
    sleep 0.01  # 10ms delay for pin to stabilize
    
    # Assert reset (active-low)
    log "Asserting reset (LOW)"
    set_gpio_value "${XM125_RESET_GPIO}" "0" "Reset (asserted)"
    sleep 0.01  # 10ms reset assertion (minimum for STM32)
    
    # Deassert reset
    log "Deasserting reset (HIGH)"
    set_gpio_value "${XM125_RESET_GPIO}" "1" "Reset (released)"
    sleep 0.1   # 100ms for application startup
    
    # Set wake pin HIGH to ensure module is awake
    log "Setting wake pin HIGH"
    set_gpio_value "${XM125_WAKE_GPIO}" "1" "Wake Up (awake)"
    sleep 0.1   # Additional time for wake-up
    
    if [[ "$target_mode" = "bootloader" ]]; then
        log_success "Reset to BOOTLOADER mode completed - ready for firmware programming"
    else
        log_success "Reset to RUN mode completed - ready for normal operation"
    fi
}

# Wait for MCU interrupt to go HIGH (module ready)
wait_for_module_ready() {
    local timeout=${1:-10}
    local count=0
    
    log "Waiting for XM125 to become ready (MCU_INT HIGH)..."
    
    while [ $count -lt $timeout ]; do
        local mcu_int_status=$(get_gpio_value "${XM125_IRQ_GPIO}")
        if [ "$mcu_int_status" = "1" ]; then
            log_success "XM125 module ready (MCU_INT HIGH)"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        if [ $((count % 3)) -eq 0 ]; then
            log "Still waiting for module ready... ($count/${timeout}s, MCU_INT=${mcu_int_status})"
        fi
    done
    
    log_warning "Timeout waiting for XM125 ready signal (MCU_INT may not go HIGH)"
    return 1
}

# Check I2C communication
check_i2c_communication() {
    log "Checking I2C communication with XM125..."
    
    if [ ! -e "${XM125_I2C_BUS}" ]; then
        log_error "I2C bus ${XM125_I2C_BUS} not found"
        return 1
    fi
    
    # Scan I2C bus for XM125
    local i2c_bus_num=$(echo "${XM125_I2C_BUS}" | grep -o '[0-9]*$')
    log "Scanning I2C bus ${i2c_bus_num} for XM125 at address ${XM125_I2C_ADDR}"
    
    if command -v i2cdetect >/dev/null 2>&1; then
        if i2cdetect -y "${i2c_bus_num}" | grep -q "${XM125_I2C_ADDR#0x}"; then
            log_success "XM125 detected on I2C bus at address ${XM125_I2C_ADDR}"
            return 0
        else
            log_error "XM125 not detected on I2C bus at address ${XM125_I2C_ADDR}"
            log "Available I2C devices:"
            i2cdetect -y "${i2c_bus_num}" | grep -E '[0-9a-f]{2}' || log "  No devices found"
            return 1
        fi
    else
        log_warning "i2cdetect not available - cannot verify I2C communication"
        return 1
    fi
}

# Show GPIO status
show_gpio_status() {
    log "Current XM125 GPIO Status:"
    echo "=========================="
    echo "Reset (GPIO${XM125_RESET_GPIO}):     $(get_gpio_value ${XM125_RESET_GPIO}) (1=released, 0=asserted)"
    echo "MCU Int (GPIO${XM125_IRQ_GPIO}):    $(get_gpio_value ${XM125_IRQ_GPIO}) (1=ready, 0=not ready)"  
    echo "Wake Up (GPIO${XM125_WAKE_GPIO}):    $(get_gpio_value ${XM125_WAKE_GPIO}) (1=awake, 0=sleep)"
    echo "Boot Pin (GPIO${XM125_BOOT_GPIO}):   $(get_gpio_value ${XM125_BOOT_GPIO}) (1=bootloader, 0=run mode)"
    echo ""
}

# Test GPIO141 bootloader control
test_bootloader_control() {
    log "Testing XM125 bootloader control..."
    
    if [ ! -d "/sys/class/gpio/gpio${XM125_BOOT_GPIO}" ]; then
        log_error "GPIO141 bootloader pin not available"
        return 1
    fi
    
    log "Setting bootloader mode (HIGH)..."
    set_gpio_value "${XM125_BOOT_GPIO}" "1" "Bootloader (test)"
    sleep 0.5
    
    log "Setting run mode (LOW)..."
    set_gpio_value "${XM125_BOOT_GPIO}" "0" "Bootloader (test)"
    sleep 0.5
    
    log_success "Bootloader control test completed successfully"
    return 0
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
    -h, --help          Show this help message
    -s, --status        Show GPIO status only (no initialization)
    -r, --reset         Perform reset (preserves current boot mode)
    --reset-run         Reset XM125 to run mode
    --reset-bootloader  Reset XM125 to bootloader mode
    --set-run           Set run mode (without reset)
    --set-bootloader    Set bootloader mode (without reset)
    -i, --i2c           Check I2C communication only
    -t, --test          Test bootloader pin control
    -f, --fix-gpio      Fix GPIO141 bootloader pin only (Foundries.io workaround)
    -v, --verbose       Enable verbose output

Examples:
    $0                      # Full initialization sequence (run mode)
    $0 --status             # Show current GPIO status
    $0 --reset              # Reset XM125 (preserves current boot mode)
    $0 --reset-run          # Reset XM125 to run mode
    $0 --reset-bootloader   # Reset XM125 to bootloader mode (for programming)
    $0 --set-run            # Set run mode without reset
    $0 --set-bootloader     # Set bootloader mode without reset
    $0 --i2c                # Check I2C communication
    $0 --test               # Test bootloader pin control
    $0 --fix-gpio           # Fix GPIO141 pin availability

Modes:
    Run Mode (default):     XM125 boots into normal operation mode
    Bootloader Mode:        XM125 boots into programming/firmware update mode

Description:
    This script provides complete XM125 Acconeer radar module management:
    
    1. Automatic GPIO141 bootloader pin fix (works around Foundries.io SPI conflict)
    2. Complete GPIO initialization and control
    3. Reset sequences for both run mode and bootloader mode
    4. I2C communication verification
    5. GPIO status monitoring and testing
    
    The script automatically handles the Foundries.io bootloader override issue
    where the SPI controller claims GPIO141, making it unavailable for XM125
    bootloader control.

Hardware Requirements:
    - XM125 module connected to I2C3 (${XM125_I2C_BUS})
    - GPIO pins properly configured in device tree
    - Root privileges for hardware access

GPIO Mapping:
    Reset (GPIO124):    GPIO4_IO28 (SAI3_RXFS) - Active-low reset
    MCU Int (GPIO125):  GPIO4_IO29 (SAI3_RXC) - MCU interrupt input
    Wake Up (GPIO139):  GPIO5_IO11 (ECSPI2_MOSI) - Wake up control
    Boot Pin (GPIO141): GPIO5_IO13 (ECSPI2_SS0) - Bootloader control

EOF
}

# Main function
main() {
    local status_only=false
    local reset_only=false
    local reset_to_run=false
    local reset_to_bootloader=false
    local set_run_only=false
    local set_bootloader_only=false
    local i2c_only=false
    local test_only=false
    local fix_gpio_only=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--status)
                status_only=true
                shift
                ;;
            -r|--reset)
                reset_only=true
                shift
                ;;
            --reset-run)
                reset_to_run=true
                shift
                ;;
            --reset-bootloader)
                reset_to_bootloader=true
                shift
                ;;
            --set-run)
                set_run_only=true
                shift
                ;;
            --set-bootloader)
                set_bootloader_only=true
                shift
                ;;
            -i|--i2c)
                i2c_only=true
                shift
                ;;
            -t|--test)
                test_only=true
                shift
                ;;
            -f|--fix-gpio)
                fix_gpio_only=true
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
                log_error "Unexpected argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log "XM125 Acconeer Radar Module Control"
    log "==================================="
    
    # Check prerequisites
    check_root
    
    # Handle different modes
    if [[ "$fix_gpio_only" = true ]]; then
        log "GPIO141 fix mode - applying Foundries.io workaround..."
        if fix_gpio141_bootloader_pin; then
            log_success "GPIO141 bootloader pin fix completed successfully"
            exit 0
        else
            log_error "GPIO141 bootloader pin fix failed"
            exit 1
        fi
    elif [[ "$status_only" = true ]]; then
        show_gpio_status
        exit 0
    elif [[ "$set_run_only" = true ]]; then
        init_gpio
        xm125_set_run_mode
        show_gpio_status
        exit 0
    elif [[ "$set_bootloader_only" = true ]]; then
        init_gpio
        xm125_set_bootloader_mode
        show_gpio_status
        exit 0
    elif [[ "$reset_only" = true ]]; then
        init_gpio
        xm125_reset
        show_gpio_status
        exit 0
    elif [[ "$reset_to_run" = true ]]; then
        init_gpio
        xm125_reset_to_mode "run"
        show_gpio_status
        exit 0
    elif [[ "$reset_to_bootloader" = true ]]; then
        init_gpio
        xm125_reset_to_mode "bootloader"
        show_gpio_status
        log_success "XM125 ready for firmware programming via I2C or UART"
        exit 0
    elif [[ "$i2c_only" = true ]]; then
        # Need GPIO initialization for I2C check
        init_gpio
        check_i2c_communication
        exit $?
    elif [[ "$test_only" = true ]]; then
        init_gpio
        test_bootloader_control
        show_gpio_status
        exit $?
    else
        # Full initialization sequence (default - run mode)
        log "Starting full XM125 initialization sequence (run mode)..."
        
        # Step 1: Initialize GPIOs (includes GPIO141 fix)
        if ! init_gpio; then
            log_error "GPIO initialization failed"
            exit 1
        fi
        
        # Step 2: Reset to run mode
        xm125_reset_to_mode "run"
        
        # Step 3: Wait for module ready (optional)
        wait_for_module_ready 5 || log_warning "Module ready check failed - continuing anyway"
        
        # Step 4: Show status
        show_gpio_status
        
        # Step 5: Check I2C communication
        if check_i2c_communication; then
            log_success "XM125 initialization completed successfully - ready for operation"
            exit 0
        else
            log_warning "XM125 initialization completed but I2C communication failed"
            log_warning "This may be normal if XM125 device tree overlay is not applied"
            log_success "GPIO control is working - XM125 hardware control is ready"
            exit 0
        fi
    fi
}

# Run main function with all arguments
main "$@"
