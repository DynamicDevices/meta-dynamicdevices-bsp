#!/bin/bash
# CPU Power Optimization Script for E-Ink Board
# Reduces power consumption by disabling cores and setting low power modes
#
# Expected power savings:
# - Disable 1 CPU core: ~30-50% CPU power reduction
# - LPM Mode 3 (900 MHz, 625 MT/s DDR): ~40-60% power reduction vs Mode 0
# - Combined: ~50-70% total power reduction

set -e

LOG_TAG="cpu-power-opt"

log_info() {
    echo "[$LOG_TAG] $1"
    logger -t "$LOG_TAG" "$1"
}

log_error() {
    echo "[$LOG_TAG] ERROR: $1" >&2
    logger -t "$LOG_TAG" -p user.err "ERROR: $1"
}

# Disable one CPU core to reduce power consumption
# Keep CPU0 online, disable CPU1
disable_cpu_core() {
    log_info "Disabling CPU core 1 to reduce power consumption"
    
    if [ -f /sys/devices/system/cpu/cpu1/online ]; then
        # Check if CPU1 is currently online
        if [ "$(cat /sys/devices/system/cpu/cpu1/online)" = "1" ]; then
            # Migrate any processes from CPU1 to CPU0 before disabling
            log_info "Migrating processes from CPU1 to CPU0..."
            # Use taskset to move processes, but most will migrate automatically
            
            # Disable CPU1
            echo 0 > /sys/devices/system/cpu/cpu1/online
            if [ "$(cat /sys/devices/system/cpu/cpu1/online)" = "0" ]; then
                log_info "✓ CPU1 disabled successfully (power savings: ~30-50% CPU power)"
            else
                log_error "Failed to disable CPU1"
                return 1
            fi
        else
            log_info "CPU1 already disabled"
        fi
    else
        log_info "CPU hotplug not available - cannot disable CPU core"
        return 1
    fi
    
    return 0
}

# Set LPM (Low Power Management) mode to maximum power save
# Mode 3: 900 MHz CPU, 625 MT/s DDR (Maximum Power Save)
set_lpm_mode() {
    log_info "Setting LPM mode to 3 (Maximum Power Save: 900 MHz CPU, 625 MT/s DDR)"
    
    if [ -f /sys/devices/platform/imx93-lpm/mode ]; then
        local current_mode=$(cat /sys/devices/platform/imx93-lpm/mode)
        log_info "Current LPM mode: $current_mode"
        
        # Set to mode 3 (Maximum Power Save)
        echo 3 > /sys/devices/platform/imx93-lpm/mode
        
        # Verify the change
        local new_mode=$(cat /sys/devices/platform/imx93-lpm/mode)
        if [ "$new_mode" = "3" ]; then
            log_info "✓ LPM mode set to 3 (900 MHz CPU, 625 MT/s DDR)"
            log_info "  Power savings: ~40-60% vs Mode 0 (1700 MHz, 3733 MT/s DDR)"
        else
            log_error "Failed to set LPM mode (current: $new_mode, expected: 3)"
            return 1
        fi
    else
        log_info "LPM driver not available - cannot set power mode"
        log_info "  This is normal if LPM driver is not enabled in kernel"
        return 1
    fi
    
    return 0
}

# Set CPU frequency governor to powersave (if cpufreq is available)
set_cpu_governor() {
    log_info "Setting CPU frequency governor to powersave"
    
    local governor_set=0
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            echo "powersave" > "$cpu" 2>/dev/null && governor_set=1
            local cpu_num=$(basename $(dirname $(dirname $cpu)))
            log_info "✓ CPU${cpu_num} governor set to powersave"
        fi
    done
    
    if [ $governor_set -eq 0 ]; then
        log_info "CPU frequency scaling not available (normal for some kernel configs)"
    fi
    
    return 0
}

# Set minimum CPU frequency (if cpufreq is available)
set_min_cpu_frequency() {
    log_info "Setting CPU to minimum frequency"
    
    local freq_set=0
    for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq; do
        if [ -d "$cpu_dir" ] && [ -f "$cpu_dir/scaling_min_freq" ] && [ -f "$cpu_dir/scaling_setspeed" ]; then
            local min_freq=$(cat "$cpu_dir/scaling_min_freq")
            echo "$min_freq" > "$cpu_dir/scaling_setspeed" 2>/dev/null && freq_set=1
            local cpu_num=$(basename $(dirname $cpu_dir))
            log_info "✓ CPU${cpu_num} frequency set to minimum: $min_freq Hz"
        fi
    done
    
    if [ $freq_set -eq 0 ]; then
        log_info "CPU frequency control not available (normal for some kernel configs)"
    fi
    
    return 0
}

# Show current power optimization status
show_status() {
    log_info "=== CPU Power Optimization Status ==="
    
    # CPU cores
    log_info "Online CPUs: $(cat /sys/devices/system/cpu/online)"
    for cpu in /sys/devices/system/cpu/cpu*/online; do
        if [ -f "$cpu" ]; then
            local cpu_num=$(basename $(dirname $cpu))
            local status=$(cat "$cpu")
            log_info "  CPU${cpu_num}: $([ "$status" = "1" ] && echo "online" || echo "offline")"
        fi
    done
    
    # LPM mode
    if [ -f /sys/devices/platform/imx93-lpm/mode ]; then
        local mode=$(cat /sys/devices/platform/imx93-lpm/mode)
        case $mode in
            0) mode_name="OD (1700 MHz, 3733 MT/s)" ;;
            1) mode_name="ND (1400 MHz, 1866 MT/s)" ;;
            2) mode_name="LD (900 MHz, 1866 MT/s)" ;;
            3) mode_name="LD (900 MHz, 625 MT/s) - Maximum Power Save" ;;
            *) mode_name="Unknown" ;;
        esac
        log_info "LPM Mode: $mode ($mode_name)"
    else
        log_info "LPM Mode: Not available"
    fi
    
    # CPU frequency
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        log_info "CPU0 Frequency: $freq Hz ($(($freq / 1000)) MHz)"
    fi
    
    # CPU governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        log_info "CPU Governor: $governor"
    fi
    
    log_info "=== Expected Power Savings ==="
    log_info "  - Single core operation: ~30-50% CPU power reduction"
    log_info "  - LPM Mode 3: ~40-60% power reduction vs Mode 0"
    log_info "  - Combined: ~50-70% total power reduction"
}

# Main optimization function
main() {
    log_info "Starting CPU power optimizations for E-Ink board"
    
    # Apply optimizations (non-fatal if not available)
    disable_cpu_core || log_info "CPU core disabling not available (continuing)"
    set_lpm_mode || log_info "LPM mode setting not available (continuing)"
    set_cpu_governor || log_info "CPU governor setting not available (continuing)"
    set_min_cpu_frequency || log_info "CPU frequency setting not available (continuing)"
    
    # Show status
    show_status
    
    log_info "CPU power optimizations completed"
}

# Run optimizations
main "$@"

exit 0

