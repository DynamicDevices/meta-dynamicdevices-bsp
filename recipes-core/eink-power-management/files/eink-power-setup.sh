#!/bin/bash
# E-Ink Power Management Setup Script
# Based on AN13917: i.MX 93 Power Consumption Measurement
# Optimizes system for ultra-low power E-Ink applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  E-Ink Power Management Setup${NC}"
echo -e "${BLUE}======================================${NC}"

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Function to optimize CPU frequency for power saving
optimize_cpu_frequency() {
    echo -e "${YELLOW}Setting CPU to power-saving mode...${NC}"
    
    # Set CPU governor to powersave for minimum power consumption
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo "powersave" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo "powersave" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
        echo -e "${GREEN}✓ CPU governor set to powersave${NC}"
    else
        echo -e "${YELLOW}⚠ CPU frequency scaling not available${NC}"
    fi
    
    # Set minimum CPU frequency
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed ]; then
        MIN_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)
        echo $MIN_FREQ > /sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed
        echo $MIN_FREQ > /sys/devices/system/cpu/cpu1/cpufreq/scaling_setspeed
        echo -e "${GREEN}✓ CPU frequency set to minimum: ${MIN_FREQ} Hz${NC}"
    fi
}

# Function to disable unnecessary network interfaces
disable_unused_network() {
    echo -e "${YELLOW}Disabling unused network interfaces...${NC}"
    
    # Disable Ethernet interfaces (not needed for E-Ink applications)
    for eth in $(ls /sys/class/net/ | grep eth 2>/dev/null || true); do
        if [ -d "/sys/class/net/$eth" ]; then
            ip link set $eth down 2>/dev/null || true
            echo -e "${GREEN}✓ Disabled ethernet interface: $eth${NC}"
        fi
    done
    
    # Keep WiFi available but put in power save mode if connected
    for wlan in $(ls /sys/class/net/ | grep wlan 2>/dev/null || true); do
        if [ -d "/sys/class/net/$wlan" ]; then
            iw dev $wlan set power_save on 2>/dev/null || true
            echo -e "${GREEN}✓ Enabled power save for WiFi: $wlan${NC}"
        fi
    done
}

# Function to optimize display power management
optimize_display() {
    echo -e "${YELLOW}Optimizing display power management...${NC}"
    
    # Blank framebuffer (E-Ink doesn't need active framebuffer)
    if [ -f /sys/class/graphics/fb0/blank ]; then
        echo 1 > /sys/class/graphics/fb0/blank
        echo -e "${GREEN}✓ Framebuffer blanked${NC}"
    fi
    
    # Stop Weston compositor if running (not needed for E-Ink)
    if systemctl is-active --quiet weston.service; then
        systemctl stop weston.service
        echo -e "${GREEN}✓ Stopped Weston compositor${NC}"
    fi
}

# Function to optimize storage power management
optimize_storage() {
    echo -e "${YELLOW}Optimizing storage power management...${NC}"
    
    # Set read-ahead to 512KB for better power efficiency
    for partition in $(lsblk | awk '$1 !~/-/{print $1}' | grep -E 'blk|sd' 2>/dev/null || true); do
        if [ -f "/sys/block/$partition/queue/read_ahead_kb" ]; then
            echo 512 > /sys/block/$partition/queue/read_ahead_kb
            echo -e "${GREEN}✓ Set read-ahead for $partition to 512KB${NC}"
        fi
    done
    
    # Enable laptop mode for aggressive power saving
    if [ -f /proc/sys/vm/laptop_mode ]; then
        echo 5 > /proc/sys/vm/laptop_mode
        echo -e "${GREEN}✓ Enabled laptop mode for storage power saving${NC}"
    fi
}

# Function to configure RTC wake source
configure_rtc_wake() {
    echo -e "${YELLOW}Configuring PCF2131 RTC wake source...${NC}"
    
    # Ensure RTC device is available
    if [ -c /dev/rtc0 ]; then
        # Enable wake alarm capability
        echo enabled > /sys/class/rtc/rtc0/device/power/wakeup 2>/dev/null || true
        echo -e "${GREEN}✓ PCF2131 RTC wake source enabled${NC}"
        
        # Show current RTC time
        RTC_TIME=$(hwclock --show 2>/dev/null || echo "RTC not accessible")
        echo -e "${BLUE}  Current RTC time: $RTC_TIME${NC}"
    else
        echo -e "${YELLOW}⚠ RTC device not found at /dev/rtc0${NC}"
    fi
}

# Function to enable auto clock gating
enable_auto_clock_gating() {
    echo -e "${YELLOW}Enabling automatic clock gating...${NC}"
    
    # Enable DDRC auto clock gating (256 cycles idle threshold)
    if [ -f /sys/devices/platform/imx93-lpm/auto_clk_gating ]; then
        echo 256 > /sys/devices/platform/imx93-lpm/auto_clk_gating
        echo -e "${GREEN}✓ DDRC auto clock gating enabled (256 cycles)${NC}"
    else
        echo -e "${YELLOW}⚠ LPM auto clock gating not available${NC}"
    fi
}

# Function to show power management status
show_power_status() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Power Management Status${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    # CPU governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "CPU Governor: ${GREEN}$GOVERNOR${NC}"
    fi
    
    # CPU frequency
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        echo -e "CPU Frequency: ${GREEN}$FREQ Hz${NC}"
    fi
    
    # Power mode
    if [ -f /sys/devices/platform/imx93-lpm/mode ]; then
        MODE=$(cat /sys/devices/platform/imx93-lpm/mode)
        case $MODE in
            0) MODE_NAME="OD (Overdrive)" ;;
            1) MODE_NAME="ND (Normal Drive)" ;;
            2) MODE_NAME="LD (Low Drive - Half Speed)" ;;
            3) MODE_NAME="LD (Low Drive - Lowest Speed)" ;;
            *) MODE_NAME="Unknown" ;;
        esac
        echo -e "Power Mode: ${GREEN}$MODE ($MODE_NAME)${NC}"
    fi
    
    # Auto clock gating
    if [ -f /sys/devices/platform/imx93-lpm/auto_clk_gating ]; then
        GATING=$(cat /sys/devices/platform/imx93-lpm/auto_clk_gating)
        echo -e "Auto Clock Gating: ${GREEN}$GATING cycles${NC}"
    fi
    
    echo -e "${BLUE}======================================${NC}"
    echo -e "${GREEN}E-Ink power optimization complete!${NC}"
    echo -e "${BLUE}Ready for Deep Sleep Mode (DSM)${NC}"
    echo -e "${BLUE}Use: echo mem > /sys/power/state${NC}"
    echo -e "${BLUE}======================================${NC}"
}

# Main execution
main() {
    check_root
    optimize_cpu_frequency
    disable_unused_network
    optimize_display
    optimize_storage
    configure_rtc_wake
    enable_auto_clock_gating
    show_power_status
}

# Run main function
main "$@"
