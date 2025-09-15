#!/bin/sh

#
# TAS2563 Audio Initialization Script
# Based on TAS2562 driver (basic functionality)
#
# This script initializes the TAS2563 codec using the TAS2562 driver
# which provides basic amplifier functionality without DSP features.
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

# Function to check TAS2562 driver capabilities
check_driver_capabilities() {
    # TAS2562 driver provides basic controls only
    # Check if basic volume controls are available
    if amixer -c "$AUDIO_CARD" cget name="Amp Gain Volume" >/dev/null 2>&1; then
        return 0  # TAS2562 driver loaded
    else
        return 1  # Driver not ready
    fi
}

# Function to set TAS2562 basic audio mode
set_basic_audio_mode() {
    log_info "Setting TAS2563 to basic audio mode (TAS2562 driver)"
    
    # TAS2562 driver doesn't have profile controls
    # Just ensure the device is ready for audio
    log_info "TAS2562 driver provides basic I2S amplification"
    log_info "No profile configuration needed - driver handles audio automatically"
    return 0
}

# TAS2562 driver doesn't support DSP modes or profiles
# All functions simplified to basic volume control

# Function to display current TAS2562 status
show_status() {
    log_info "Current TAS2563 status (TAS2562 driver):"
    
    echo "Available controls:"
    amixer -c "$AUDIO_CARD" controls | grep -i "volume\|gain" || true
    
    echo ""
    echo "Current settings:"
    amixer -c "$AUDIO_CARD" cget name="Amp Gain Volume" 2>/dev/null || echo "Amp Gain Volume not available"
    amixer -c "$AUDIO_CARD" cget name="Digital Volume Control" 2>/dev/null || echo "Digital Volume Control not available"
    
    echo ""
    echo "Note: TAS2562 driver provides basic functionality only"
    echo "No DSP modes, profiles, or advanced features available"
}

# Function to set optimal volume for TAS2562 driver
set_optimal_volume() {
    log_info "Setting optimal volume levels for TAS2562 driver..."
    
    # Set amp gain volume to a good level (20 out of 28 = ~18dB)
    if amixer -c "$AUDIO_CARD" cset name="Amp Gain Volume" 20 >/dev/null 2>&1; then
        log_info "Set Amp Gain Volume to 20 (~18dB)"
    else
        log_info "Could not set Amp Gain Volume"
    fi
    
    # Set digital volume to 75% (82 out of 110)
    if amixer -c "$AUDIO_CARD" cset name="Digital Volume Control" 82 >/dev/null 2>&1; then
        log_info "Set Digital Volume Control to 82 (75%)"
    else
        log_info "Could not set Digital Volume Control"
    fi
    
    log_info "TAS2562 volume configuration completed"
}

# Main function
main() {
    mode="${1:-default}"
    
    log_info "Initializing TAS2563 with TAS2562 driver (mode: $mode)"
    
    # Check if audio card is available
    if ! check_audio_card; then
        exit 1
    fi
    
    # Wait a moment for the driver to be fully ready
    sleep 1
    
    case "$mode" in
        "default"|"basic"|"audio")
            # Check driver capabilities
            if check_driver_capabilities; then
                log_info "TAS2562 driver detected - using basic audio mode"
                set_basic_audio_mode
                set_optimal_volume
            else
                log_error "TAS2562 driver not ready"
                exit 1
            fi
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 [default|basic|audio|status]"
            echo "  default/basic/audio - Initialize TAS2562 driver with optimal volume (default)"
            echo "  status              - Show current TAS2562 configuration"
            echo ""
            echo "Note: TAS2562 driver provides basic functionality only"
            echo "No DSP modes, profiles, or advanced features available"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
