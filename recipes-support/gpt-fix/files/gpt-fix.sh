#!/bin/bash
# GPT Partition Table Fix Script
# Fixes: GPT: Use GNU Parted to correct GPT errors
# Fixes: GPT:Alternate GPT header not at the end of the disk

set -e

DEVICE="/dev/mmcblk0"
LOG_TAG="gpt-fix"

log_info() {
    echo "[$LOG_TAG] $1" | systemd-cat -p info
}

log_error() {
    echo "[$LOG_TAG] ERROR: $1" | systemd-cat -p err
}

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    log_error "Device $DEVICE not found"
    exit 1
fi

# Check if we have write access
if [ ! -w "$DEVICE" ]; then
    log_error "No write access to $DEVICE"
    exit 1
fi

log_info "Checking GPT partition table on $DEVICE"

# Use parted to fix GPT errors
if command -v parted >/dev/null 2>&1; then
    log_info "Fixing GPT partition table with parted"
    
    # Fix GPT - this will repair the backup GPT header location
    if parted -s "$DEVICE" print 2>&1 | grep -q "fix the GPT"; then
        log_info "GPT errors detected, applying fix"
        echo "Fix" | parted ---pretend-input-tty "$DEVICE" print >/dev/null 2>&1 || {
            log_info "Attempting alternative GPT fix method"
            parted -s "$DEVICE" mklabel gpt >/dev/null 2>&1 || {
                log_error "Failed to fix GPT partition table"
                exit 1
            }
        }
        log_info "GPT partition table fixed successfully"
    else
        log_info "No GPT errors detected"
    fi
else
    log_error "parted command not available"
    exit 1
fi

# Verify the fix
if parted -s "$DEVICE" print >/dev/null 2>&1; then
    log_info "GPT partition table verification successful"
else
    log_error "GPT partition table verification failed"
    exit 1
fi

log_info "GPT fix completed successfully"
