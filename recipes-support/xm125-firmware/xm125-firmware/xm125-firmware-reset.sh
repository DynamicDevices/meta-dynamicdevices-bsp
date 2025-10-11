#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Acconeer XM125 Radar Module Reset Script
# Copyright 2025 Dynamic Devices Ltd
#
# Simple script to reset the XM125 radar module
#

set -e

# Configuration
XM125_GPIO_CHIP="gpiochip4"
XM125_RESET_LINE="28"      # GPIO4_IO28 (SAI3_RXFS - active-low reset)
XM125_BOOT_LINE="13"       # GPIO5_IO13 (ECSPI2_SS0 - BOOT0 pin)
XM125_WAKE_LINE="11"       # GPIO5_IO11 (ECSPI2_MOSI - wake up control)
XM125_IRQ_LINE="29"        # GPIO4_IO29 (SAI3_RXC - MCU interrupt)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] xm125-reset:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] xm125-reset:${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root for GPIO access"
    exit 1
fi

# Check if gpioset is available
if ! command -v gpioset >/dev/null 2>&1; then
    echo "gpioset not found. Please install libgpiod-tools"
    exit 1
fi

log "Resetting XM125 radar module..."

# Set to run mode (not bootloader)
log "Setting run mode (BOOT0 low)"
gpioset ${XM125_GPIO_CHIP} ${XM125_BOOT_LINE}=0
sleep 0.01  # 10ms delay

# Perform reset sequence with proper timing
log "Asserting reset"
gpioset ${XM125_GPIO_CHIP} ${XM125_RESET_LINE}=0
sleep 0.01  # 10ms reset assertion (minimum for STM32)

log "Deasserting reset"
gpioset ${XM125_GPIO_CHIP} ${XM125_RESET_LINE}=1
sleep 0.1   # 100ms for application startup

log_success "XM125 reset completed"
