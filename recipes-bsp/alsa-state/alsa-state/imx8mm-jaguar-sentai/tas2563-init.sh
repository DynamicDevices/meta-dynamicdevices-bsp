#!/bin/bash

#
# TAS2563 SmartAMP Initialization Script
# Based on TI TAS2781 driver integration guide
#
# This script initializes the TAS2563 codec with appropriate regbin profiles
# for different use cases. It should be called after the audio system is ready.
#

SCRIPT_NAME="tas2563-init"
LOG_TAG="[$SCRIPT_NAME]"
AUDIO_CARD="Audio"

# Function to log messages
log_info() {
    echo "$LOG_TAG INFO: $1"
    logger -t "$SCRIPT_NAME" "INFO: $1"
}

log_error() {
    echo "$LOG_TAG ERROR: $1" >&2
    logger -t "$SCRIPT_NAME" "ERROR: $1"
}

# Function to check if audio card is available
check_audio_card() {
    if ! amixer -c "$AUDIO_CARD" info >/dev/null 2>&1; then
        log_error "Audio card '$AUDIO_CARD' not found"
        return 1
    fi
    return 0
}

# Function to set TAS2563 to echo removal mode (default)
set_echo_removal_mode() {
    log_info "Setting TAS2563 to echo removal mode (Profile 8: PDM recording with echo ref)"
    
    # Enable DSP mode
    if ! amixer -c "$AUDIO_CARD" cset name="Program" 0 >/dev/null 2>&1; then
        log_error "Failed to set Program control"
        return 1
    fi
    
    # Select Profile 8: PDM recording with I2S, 48kHz, 32-bit, echo reference
    if ! amixer -c "$AUDIO_CARD" cset name="TASDEVICE Profile id" 8 >/dev/null 2>&1; then
        log_error "Failed to set Profile id to 8"
        return 1
    fi
    
    # Select default DSP configuration
    if ! amixer -c "$AUDIO_CARD" cset name="Configuration" 0 >/dev/null 2>&1; then
        log_error "Failed to set Configuration"
        return 1
    fi
    
    log_info "TAS2563 configured for echo removal mode (Profile 8) successfully"
    return 0
}

# Function to set TAS2563 to music mode 
set_music_mode() {
    log_info "Setting TAS2563 to music mode (Profile 5: I2S auto-rate)"
    
    # Enable DSP mode
    if ! amixer -c "$AUDIO_CARD" cset name="Program" 0 >/dev/null 2>&1; then
        log_error "Failed to set Program control"
        return 1
    fi
    
    # Select Profile 5: Music I2S auto-rate 16-bit
    if ! amixer -c "$AUDIO_CARD" cset name="TASDEVICE Profile id" 5 >/dev/null 2>&1; then
        log_error "Failed to set Profile id to 5"
        return 1
    fi
    
    # Select default DSP configuration
    if ! amixer -c "$AUDIO_CARD" cset name="Configuration" 0 >/dev/null 2>&1; then
        log_error "Failed to set Configuration"
        return 1
    fi
    
    log_info "TAS2563 configured for music mode (Profile 5) successfully"
    return 0
}

# Function to set TAS2563 to bypass mode
set_bypass_mode() {
    log_info "Setting TAS2563 to bypass mode (DSP disabled)"
    
    # Enable bypass mode
    if ! amixer -c "$AUDIO_CARD" cset name="Program" 1 >/dev/null 2>&1; then
        log_error "Failed to set Program control"
        return 1
    fi
    
    # Select bypass profile (Profile 2)
    if ! amixer -c "$AUDIO_CARD" cset name="TASDEVICE Profile id" 2 >/dev/null 2>&1; then
        log_error "Failed to set Profile id"
        return 1
    fi
    
    log_info "TAS2563 configured for bypass mode successfully"
    return 0
}

# Function to display current TAS2563 status
show_status() {
    log_info "Current TAS2563 status:"
    
    echo "Available controls:"
    amixer -c "$AUDIO_CARD" controls | grep -i "tas\|program\|profile\|configuration" || true
    
    echo ""
    echo "Current settings:"
    amixer -c "$AUDIO_CARD" cget name="Program" 2>/dev/null || echo "Program control not available"
    amixer -c "$AUDIO_CARD" cget name="TASDEVICE Profile id" 2>/dev/null || echo "Profile id control not available"  
    amixer -c "$AUDIO_CARD" cget name="Configuration" 2>/dev/null || echo "Configuration control not available"
}

# Main function
main() {
    local mode="${1:-echo-removal}"
    
    log_info "Initializing TAS2563 SmartAMP (mode: $mode)"
    
    # Check if audio card is available
    if ! check_audio_card; then
        exit 1
    fi
    
    # Wait a moment for the driver to be fully ready
    sleep 1
    
    case "$mode" in
        "echo-removal"|"default")
            set_echo_removal_mode
            ;;
        "music")
            set_music_mode
            ;;
        "bypass")
            set_bypass_mode
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 [echo-removal|music|bypass|status]"
            echo "  echo-removal - Enable DSP mode with echo reference profile (default)"
            echo "  music        - Enable DSP mode with music profile"
            echo "  bypass       - Enable bypass mode for electrical testing"
            echo "  status       - Show current TAS2563 configuration"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
