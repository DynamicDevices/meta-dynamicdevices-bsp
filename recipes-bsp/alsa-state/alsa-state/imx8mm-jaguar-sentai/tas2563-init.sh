#!/bin/sh

#
# TAS2563 SmartAMP Initialization Script
# Based on TI TAS2781 driver integration guide
#
# This script initializes the TAS2563 codec with appropriate regbin profiles
# for different use cases. It should be called after the audio system is ready.
#

SCRIPT_NAME="tas2563-init"
LOG_TAG="[$SCRIPT_NAME]"
AUDIO_CARD="tas2563audio"

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

# Function to check if DSP firmware is loaded
check_dsp_firmware() {
    # Check if Program control exists (indicates DSP firmware is loaded)
    if amixer -c "$AUDIO_CARD" cget name="Program" >/dev/null 2>&1; then
        return 0  # DSP firmware available
    else
        return 1  # Regbin-only mode
    fi
}

# Function to set TAS2563 to regbin-only echo removal mode
set_regbin_echo_removal_mode() {
    log_info "Setting TAS2563 to regbin-only echo removal mode (Profile 8: Hardware echo reference)"
    
    # Select Profile 8: PDM recording with I2S, 48kHz, 32-bit, echo reference
    if ! amixer -c "$AUDIO_CARD" cset name="TASDEVICE Profile id" 8 >/dev/null 2>&1; then
        log_error "Failed to set Profile id to 8"
        return 1
    fi
    
    log_info "TAS2563 configured for regbin-only echo removal mode (Profile 8) successfully"
    log_info "Echo reference available in TDM slot 3 for external AEC processing"
    return 0
}

# Function to set TAS2563 to echo removal mode (DSP mode)
set_echo_removal_mode() {
    log_info "Setting TAS2563 to DSP echo removal mode (Profile 8: PDM recording with echo ref)"
    
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
    
    log_info "TAS2563 configured for DSP echo removal mode (Profile 8) successfully"
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
    
    echo ""
    echo "Volume and mute settings:"
    amixer -c "$AUDIO_CARD" cget name="tas2563-amp-gain-volume" 2>/dev/null || echo "Amp gain volume not available"
    amixer -c "$AUDIO_CARD" cget name="tas2563-digital-volume" 2>/dev/null || echo "Digital volume not available"
    amixer -c "$AUDIO_CARD" cget name="tas2563-digital-mute" 2>/dev/null || echo "Digital mute not available"
}

# Function to set optimal volume and unmute
set_optimal_volume() {
    log_info "Setting optimal volume levels and unmuting TAS2563..."
    
    # Set amp gain volume to a good level (20 out of 28 = ~18dB)
    if amixer -c "$AUDIO_CARD" cset name="tas2563-amp-gain-volume" 20 >/dev/null 2>&1; then
        log_info "Set amp gain volume to 20 (18dB)"
    else
        log_info "Could not set amp gain volume"
    fi
    
    # Set digital volume to 75% (49152 out of 65535)
    if amixer -c "$AUDIO_CARD" cset name="tas2563-digital-volume" 49152 >/dev/null 2>&1; then
        log_info "Set digital volume to 49152 (75%)"
    else
        log_info "Could not set digital volume"
    fi
    
    # Unmute the device
    if amixer -c "$AUDIO_CARD" cset name="tas2563-digital-mute" 0 >/dev/null 2>&1; then
        log_info "Unmuted TAS2563 digital output"
    else
        log_info "Could not unmute - using legacy volume method"
        # Fallback: ensure digital volume is not zero
        amixer -c "$AUDIO_CARD" cset name="tas2563-digital-volume" 49152 >/dev/null 2>&1 || true
    fi
}

# Main function
main() {
    mode="${1:-echo-removal}"
    
    log_info "Initializing TAS2563 SmartAMP (mode: $mode)"
    
    # Check if audio card is available
    if ! check_audio_card; then
        exit 1
    fi
    
    # Wait a moment for the driver to be fully ready
    sleep 1
    
    case "$mode" in
        "echo-removal"|"default")
            # Auto-detect DSP firmware availability
            if check_dsp_firmware; then
                log_info "DSP firmware detected - using DSP mode"
                set_echo_removal_mode
            else
                log_info "DSP firmware not available - using regbin-only mode"
                set_regbin_echo_removal_mode
            fi
            set_optimal_volume
            ;;
        "music")
            if check_dsp_firmware; then
                set_music_mode
            else
                log_error "Music mode requires DSP firmware (not available in regbin-only mode)"
                exit 1
            fi
            set_optimal_volume
            ;;
        "bypass")
            if check_dsp_firmware; then
                set_bypass_mode
            else
                log_info "Already in regbin-only mode (equivalent to bypass mode)"
                set_regbin_echo_removal_mode
            fi
            set_optimal_volume
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 [echo-removal|music|bypass|status]"
            echo "  echo-removal - Auto-detect DSP/regbin mode with echo reference profile (default)"
            echo "  music        - Enable DSP mode with music profile (requires DSP firmware)"
            echo "  bypass       - Enable bypass mode or regbin-only mode"
            echo "  status       - Show current TAS2563 configuration"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
