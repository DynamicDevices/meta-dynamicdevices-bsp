#!/bin/bash
# Filesystem Optimizations Script for E-Ink Board
# 
# This script applies runtime filesystem optimizations for power saving and eMMC longevity.
# It complements the WIC-level mount options with additional runtime optimizations.

set -e

LOG_TAG="fs-optimization"

log_info() {
    echo "[$LOG_TAG] $1"
    logger -t "$LOG_TAG" "$1"
}

log_error() {
    echo "[$LOG_TAG] ERROR: $1" >&2
    logger -t "$LOG_TAG" -p user.err "ERROR: $1"
}

# Optimize filesystem scheduler for eMMC
optimize_io_scheduler() {
    log_info "Optimizing I/O scheduler for eMMC storage"
    
    # Find the eMMC device
    local emmc_device
    for device in /sys/block/mmcblk*; do
        if [ -d "$device" ]; then
            local dev_name=$(basename "$device")
            # Set deadline scheduler for better eMMC performance and power efficiency
            if [ -f "$device/queue/scheduler" ]; then
                # Check available schedulers
                local available_schedulers
                available_schedulers=$(cat "$device/queue/scheduler")
                
                # Prefer mq-deadline, then deadline, then noop for eMMC
                if echo "$available_schedulers" | grep -q "mq-deadline"; then
                    echo "mq-deadline" > "$device/queue/scheduler"
                    log_info "Set mq-deadline scheduler for $dev_name"
                elif echo "$available_schedulers" | grep -q "deadline"; then
                    echo "deadline" > "$device/queue/scheduler"
                    log_info "Set deadline scheduler for $dev_name"
                elif echo "$available_schedulers" | grep -q "noop"; then
                    echo "noop" > "$device/queue/scheduler"
                    log_info "Set noop scheduler for $dev_name"
                else
                    log_info "No preferred scheduler available for $dev_name, using default"
                fi
            fi
            
            # Optimize read-ahead for sequential access patterns (E-Ink image updates)
            if [ -f "$device/queue/read_ahead_kb" ]; then
                echo "128" > "$device/queue/read_ahead_kb"
                log_info "Set read-ahead to 128KB for $dev_name"
            fi
            
            # Reduce nr_requests for lower memory usage
            if [ -f "$device/queue/nr_requests" ]; then
                echo "64" > "$device/queue/nr_requests"
                log_info "Set nr_requests to 64 for $dev_name"
            fi
        fi
    done
}

# Optimize virtual memory settings for power efficiency
optimize_vm_settings() {
    log_info "Optimizing virtual memory settings for power efficiency"
    
    # Reduce swappiness to minimize eMMC writes
    if [ -f "/proc/sys/vm/swappiness" ]; then
        echo "10" > "/proc/sys/vm/swappiness"
        log_info "Set swappiness to 10 (prefer RAM over swap)"
    fi
    
    # Increase dirty_expire_centisecs to batch writes (reduce power)
    if [ -f "/proc/sys/vm/dirty_expire_centisecs" ]; then
        echo "6000" > "/proc/sys/vm/dirty_expire_centisecs"  # 60 seconds
        log_info "Set dirty_expire_centisecs to 60 seconds"
    fi
    
    # Increase dirty_writeback_centisecs to reduce write frequency
    if [ -f "/proc/sys/vm/dirty_writeback_centisecs" ]; then
        echo "6000" > "/proc/sys/vm/dirty_writeback_centisecs"  # 60 seconds
        log_info "Set dirty_writeback_centisecs to 60 seconds"
    fi
    
    # Reduce dirty ratio to prevent large write bursts
    if [ -f "/proc/sys/vm/dirty_ratio" ]; then
        echo "5" > "/proc/sys/vm/dirty_ratio"
        log_info "Set dirty_ratio to 5%"
    fi
    
    # Set background dirty ratio
    if [ -f "/proc/sys/vm/dirty_background_ratio" ]; then
        echo "2" > "/proc/sys/vm/dirty_background_ratio"
        log_info "Set dirty_background_ratio to 2%"
    fi
}

# Optimize tmpfs mounts for power efficiency
optimize_tmpfs() {
    log_info "Optimizing tmpfs mounts for reduced memory pressure"
    
    # Check if we can remount /tmp with size limit
    if mountpoint -q /tmp && mount | grep -q "tmpfs.*/tmp"; then
        # /tmp is already tmpfs, check if we can optimize it
        log_info "/tmp is already on tmpfs - good for power efficiency"
    else
        log_info "/tmp is not on tmpfs - consider mounting as tmpfs for better performance"
    fi
    
    # Optimize /run if it's tmpfs
    if mountpoint -q /run && mount | grep -q "tmpfs.*/run"; then
        log_info "/run is on tmpfs - optimal for temporary files"
    fi
}

# Create optimized fstab entries (for reference)
create_fstab_reference() {
    log_info "Creating filesystem optimization reference"
    
    local ref_file="/etc/filesystem-optimizations-reference.txt"
    cat > "$ref_file" << 'EOF'
# Filesystem Optimization Reference for E-Ink Board
# These optimizations are applied at runtime and build-time for maximum battery life

# Recommended fstab entries (for reference):
# /dev/mmcblk0p2 / ext4 defaults,noatime,commit=60,data=writeback 0 1
# tmpfs /tmp tmpfs defaults,noatime,size=100M 0 0
# tmpfs /var/log tmpfs defaults,noatime,size=50M 0 0

# Key optimizations:
# - noatime: Prevents access time updates (reduces writes)
# - commit=60: Batches writes every 60 seconds (power efficient)
# - data=writeback: Faster writes with acceptable risk for E-Ink use case
# - tmpfs for /tmp and /var/log: Reduces eMMC writes for temporary files

# Runtime optimizations applied:
# - I/O scheduler: mq-deadline/deadline for eMMC
# - VM settings: Reduced swappiness, batched dirty writes
# - Read-ahead: Optimized for sequential access patterns
EOF
    
    log_info "Created filesystem optimization reference: $ref_file"
}

# Main optimization function
main() {
    log_info "Starting filesystem optimizations for E-Ink board"
    
    optimize_io_scheduler
    optimize_vm_settings
    optimize_tmpfs
    create_fstab_reference
    
    log_info "Filesystem optimizations completed successfully"
}

# Run optimizations
main

exit 0
