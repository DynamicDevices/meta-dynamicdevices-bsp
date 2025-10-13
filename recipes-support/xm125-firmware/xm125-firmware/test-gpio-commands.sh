#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Test script to verify GPIO commands work correctly for XM125
# This script tests the GPIO commands without actually running the full firmware flash
#

set -e

# Configuration (same as main script)
XM125_GPIO_CHIP="gpiochip4"
XM125_RESET_LINE="28"      # GPIO4_IO28 (SAI3_RXFS - active-low reset)
XM125_BOOT_LINE="13"       # GPIO5_IO13 (ECSPI2_SS0 - BOOT0 pin)
XM125_WAKE_LINE="11"       # GPIO5_IO11 (ECSPI2_MOSI - wake up control)
XM125_IRQ_LINE="29"        # GPIO4_IO29 (SAI3_RXC - MCU interrupt)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for GPIO access"
        exit 1
    fi
}

# Test GPIO availability
test_gpio_availability() {
    log_info "Testing GPIO availability..."
    
    # Check if GPIO chip exists
    if [ ! -e "/dev/${XM125_GPIO_CHIP}" ]; then
        log_error "GPIO chip ${XM125_GPIO_CHIP} not found!"
        log_error "Available chips: $(ls /dev/gpiochip* 2>/dev/null | tr '\n' ' ')"
        return 1
    fi
    
    log_success "GPIO chip ${XM125_GPIO_CHIP} found"
    return 0
}

# Test individual GPIO commands
test_gpio_commands() {
    log_info "Testing GPIO set commands..."
    
    # Test reset GPIO
    log_info "Testing reset GPIO (${XM125_RESET_LINE})..."
    if gpioset "${XM125_GPIO_CHIP}" "${XM125_RESET_LINE}=0"; then
        log_success "Reset assert (low) - OK"
    else
        log_error "Reset assert (low) - FAILED"
        return 1
    fi
    
    sleep 0.1
    
    if gpioset "${XM125_GPIO_CHIP}" "${XM125_RESET_LINE}=1"; then
        log_success "Reset deassert (high) - OK"
    else
        log_error "Reset deassert (high) - FAILED"
        return 1
    fi
    
    # Test boot GPIO
    log_info "Testing boot GPIO (${XM125_BOOT_LINE})..."
    if gpioset "${XM125_GPIO_CHIP}" "${XM125_BOOT_LINE}=1"; then
        log_success "Boot mode set (high) - OK"
    else
        log_error "Boot mode set (high) - FAILED"
        return 1
    fi
    
    sleep 0.1
    
    if gpioset "${XM125_GPIO_CHIP}" "${XM125_BOOT_LINE}=0"; then
        log_success "Run mode set (low) - OK"
    else
        log_error "Run mode set (low) - FAILED"
        return 1
    fi
    
    # Test wake GPIO
    log_info "Testing wake GPIO (${XM125_WAKE_LINE})..."
    if gpioset "${XM125_GPIO_CHIP}" "${XM125_WAKE_LINE}=1"; then
        log_success "Wake assert (high) - OK"
    else
        log_error "Wake assert (high) - FAILED"
        return 1
    fi
    
    sleep 0.1
    
    if gpioset "${XM125_GPIO_CHIP}" "${XM125_WAKE_LINE}=0"; then
        log_success "Wake deassert (low) - OK"
    else
        log_error "Wake deassert (low) - FAILED"
        return 1
    fi
    
    return 0
}

# Test GPIO read commands
test_gpio_read() {
    log_info "Testing GPIO read commands..."
    
    # Test reading IRQ line
    log_info "Testing IRQ GPIO read (${XM125_IRQ_LINE})..."
    local irq_status
    if irq_status=$(gpioget "${XM125_GPIO_CHIP}" "${XM125_IRQ_LINE}"); then
        log_success "IRQ read - OK (value: $irq_status)"
    else
        log_error "IRQ read - FAILED"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    log_info "XM125 GPIO Command Test"
    log_info "======================="
    
    check_root
    
    if ! test_gpio_availability; then
        exit 1
    fi
    
    if ! test_gpio_commands; then
        log_error "GPIO command tests failed"
        exit 1
    fi
    
    if ! test_gpio_read; then
        log_error "GPIO read tests failed"
        exit 1
    fi
    
    log_success "All GPIO tests passed!"
    log_info "The XM125 firmware flash script should now work correctly"
}

# Run main function
main "$@"
