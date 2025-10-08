#!/bin/bash
# Deep Sleep Mode (DSM) Control Script for i.MX93 E-Ink Board
# Based on AN13917: Achieves 7.6mW standby power consumption

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_NAME="DSM Control"
LOG_FILE="/var/log/eink-dsm.log"

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> $LOG_FILE
    
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
    esac
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR" "This script must be run as root"
        exit 1
    fi
}

# Function to set RTC wake alarm
set_rtc_wake_alarm() {
    local wake_seconds=$1
    
    if [ -z "$wake_seconds" ]; then
        log_message "ERROR" "Wake time in seconds is required"
        return 1
    fi
    
    log_message "INFO" "Setting RTC wake alarm for $wake_seconds seconds"
    
    # Disable any existing alarm
    echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null || true
    
    # Set new alarm
    local current_time=$(cat /sys/class/rtc/rtc0/since_epoch)
    local wake_time=$((current_time + wake_seconds))
    
    echo $wake_time > /sys/class/rtc/rtc0/wakealarm
    
    # Verify alarm was set
    if [ -f /sys/class/rtc/rtc0/wakealarm ]; then
        local set_alarm=$(cat /sys/class/rtc/rtc0/wakealarm)
        if [ "$set_alarm" = "$wake_time" ]; then
            log_message "INFO" "RTC wake alarm set successfully for $(date -d @$wake_time)"
            return 0
        fi
    fi
    
    log_message "ERROR" "Failed to set RTC wake alarm"
    return 1
}

# Function to prepare system for DSM
prepare_for_dsm() {
    log_message "INFO" "Preparing system for Deep Sleep Mode (DSM)"
    
    # Sync filesystems
    sync
    log_message "DEBUG" "Filesystems synced"
    
    # Stop non-essential services
    local services_to_stop=("weston.service" "bluetooth.service")
    for service in "${services_to_stop[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service"
            log_message "DEBUG" "Stopped service: $service"
        fi
    done
    
    # Set power mode to Low Drive (LD) with lowest speed
    if [ -f /sys/devices/platform/imx93-lpm/mode ]; then
        echo 3 > /sys/devices/platform/imx93-lpm/mode
        log_message "DEBUG" "Set power mode to LD (lowest speed)"
    fi
    
    # Enable auto clock gating
    if [ -f /sys/devices/platform/imx93-lpm/auto_clk_gating ]; then
        echo 256 > /sys/devices/platform/imx93-lpm/auto_clk_gating
        log_message "DEBUG" "Enabled auto clock gating"
    fi
    
    # Ensure RTC wake is enabled
    if [ -f /sys/class/rtc/rtc0/device/power/wakeup ]; then
        echo enabled > /sys/class/rtc/rtc0/device/power/wakeup
        log_message "DEBUG" "RTC wake source enabled"
    fi
    
    log_message "INFO" "System prepared for DSM"
}

# Function to enter Deep Sleep Mode
enter_dsm() {
    local wake_seconds=${1:-300}  # Default 5 minutes
    
    log_message "INFO" "Entering Deep Sleep Mode (DSM) - Target: 7.6mW"
    
    # Set wake alarm if specified
    if [ "$wake_seconds" -gt 0 ]; then
        if ! set_rtc_wake_alarm "$wake_seconds"; then
            log_message "ERROR" "Failed to set wake alarm, aborting DSM entry"
            return 1
        fi
    fi
    
    # Prepare system
    prepare_for_dsm
    
    # Final sync
    sync
    
    # Log DSM entry
    log_message "INFO" "Entering DSM now - wake in $wake_seconds seconds"
    
    # Enter suspend mode (DSM)
    echo mem > /sys/power/state
    
    # This line will execute after wake-up
    log_message "INFO" "Woke up from DSM"
}

# Function to check DSM capability
check_dsm_capability() {
    log_message "INFO" "Checking Deep Sleep Mode capability"
    
    local issues=0
    
    # Check if suspend is supported
    if [ ! -f /sys/power/state ]; then
        log_message "ERROR" "Suspend interface not available"
        issues=$((issues + 1))
    else
        if ! grep -q "mem" /sys/power/state; then
            log_message "ERROR" "Memory suspend (DSM) not supported"
            issues=$((issues + 1))
        fi
    fi
    
    # Check RTC wake capability
    if [ ! -c /dev/rtc0 ]; then
        log_message "ERROR" "RTC device not available"
        issues=$((issues + 1))
    fi
    
    if [ ! -f /sys/class/rtc/rtc0/device/power/wakeup ]; then
        log_message "ERROR" "RTC wake capability not available"
        issues=$((issues + 1))
    fi
    
    # Check power management interface
    if [ ! -f /sys/devices/platform/imx93-lpm/mode ]; then
        log_message "WARN" "i.MX93 LPM interface not available"
    fi
    
    if [ $issues -eq 0 ]; then
        log_message "INFO" "DSM capability check passed"
        return 0
    else
        log_message "ERROR" "DSM capability check failed with $issues issues"
        return 1
    fi
}

# Function to show current power status
show_power_status() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  i.MX93 E-Ink Power Status${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    # Suspend capability
    if [ -f /sys/power/state ]; then
        local suspend_modes=$(cat /sys/power/state)
        echo -e "Suspend modes: ${GREEN}$suspend_modes${NC}"
    fi
    
    # RTC status
    if [ -c /dev/rtc0 ]; then
        local rtc_time=$(hwclock --show 2>/dev/null || echo "Not accessible")
        echo -e "RTC time: ${GREEN}$rtc_time${NC}"
        
        if [ -f /sys/class/rtc/rtc0/device/power/wakeup ]; then
            local wake_status=$(cat /sys/class/rtc/rtc0/device/power/wakeup)
            echo -e "RTC wake: ${GREEN}$wake_status${NC}"
        fi
    fi
    
    # Power mode
    if [ -f /sys/devices/platform/imx93-lpm/mode ]; then
        local mode=$(cat /sys/devices/platform/imx93-lpm/mode)
        case $mode in
            0) mode_name="OD (Overdrive)" ;;
            1) mode_name="ND (Normal Drive)" ;;
            2) mode_name="LD (Low Drive - Half)" ;;
            3) mode_name="LD (Low Drive - Lowest)" ;;
            *) mode_name="Unknown" ;;
        esac
        echo -e "Power mode: ${GREEN}$mode ($mode_name)${NC}"
    fi
    
    echo -e "${BLUE}======================================${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  enter [SECONDS]    Enter DSM for specified seconds (default: 300)"
    echo "  check             Check DSM capability"
    echo "  status            Show current power status"
    echo "  wake SECONDS      Set RTC wake alarm only (no DSM)"
    echo "  help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 enter 600      # Enter DSM for 10 minutes"
    echo "  $0 enter 0        # Enter DSM indefinitely (manual wake)"
    echo "  $0 wake 1800      # Set wake alarm for 30 minutes"
    echo "  $0 check          # Check if DSM is supported"
    echo ""
    echo "Based on AN13917: Achieves 7.6mW in Deep Sleep Mode"
}

# Main function
main() {
    check_root
    
    local command=${1:-help}
    
    case $command in
        "enter")
            local wake_time=${2:-300}
            if ! check_dsm_capability; then
                exit 1
            fi
            enter_dsm "$wake_time"
            ;;
        "check")
            check_dsm_capability
            ;;
        "status")
            show_power_status
            ;;
        "wake")
            local wake_time=${2}
            if [ -z "$wake_time" ]; then
                log_message "ERROR" "Wake time in seconds is required"
                exit 1
            fi
            set_rtc_wake_alarm "$wake_time"
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function
main "$@"
