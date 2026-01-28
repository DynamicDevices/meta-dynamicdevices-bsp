#!/bin/sh
# XM125 Radar Service Startup Script
# This script handles firmware programming and GPIO initialization before starting the radar service
# Copyright 2025 Dynamic Devices Ltd

# Don't use set -e - we want to continue even if some commands fail
# Individual commands use || true or explicit error handling
set +e

SCRIPT_NAME=$(basename "$0")
LOG_TAG="xm125-startup"
EXPECTED_APP_ID=0x02  # Presence Detector Application ID
MAX_VERIFY_ATTEMPTS=3  # Maximum attempts to verify application ID after programming

log() {
    echo "[$LOG_TAG] $1" >&2
}

log_error() {
    echo "[$LOG_TAG] ERROR: $1" >&2
}

# Function to read application ID from device
read_application_id() {
    if INFO_OUTPUT=$(/usr/bin/xm125-radar-monitor --quiet info 2>&1); then
        # Parse application ID from output
        # Format: "Application ID: 0x00000002" (appears in the device information section)
        # The output may include log messages, but we grep for the Application ID line
        # Extract the hex value (e.g., 0x00000002 or 0x02)
        echo "$INFO_OUTPUT" | grep -i "Application ID" | sed -n 's/.*Application ID: *\(0x[0-9a-fA-F]\+\).*/\1/p' | head -1 | sed 's/[[:space:]]*$//'
    else
        echo ""
    fi
}

# Function to check if application ID matches expected value
check_app_id() {
    CURRENT_APP_ID="$1"
    if [ -z "$CURRENT_APP_ID" ]; then
        return 1
    fi

    # Convert both to decimal for reliable comparison (handles 0x02 vs 0x00000002)
    CURRENT_APP_ID_DEC=$(printf "%d" "$CURRENT_APP_ID" 2>/dev/null || echo "0")
    EXPECTED_APP_ID_DEC=$(printf "%d" "$EXPECTED_APP_ID" 2>/dev/null || echo "0")

    if [ "$CURRENT_APP_ID_DEC" = "$EXPECTED_APP_ID_DEC" ] && [ "$CURRENT_APP_ID_DEC" != "0" ]; then
        return 0  # Match
    else
        return 1  # No match
    fi
}

# Function to reset device to run mode with retries
# Retries up to 3 times to handle cases where the device needs multiple reset attempts
reset_to_run_mode_with_retries() {
    local MAX_RESET_ATTEMPTS=3
    local RESET_DELAY=3
    local attempt=1
    local success=0

    log "Attempting to reset device to run mode (up to $MAX_RESET_ATTEMPTS attempts)..."

    while [ $attempt -le $MAX_RESET_ATTEMPTS ]; do
        log "Reset attempt $attempt of $MAX_RESET_ATTEMPTS..."

        # Try to reset to run mode
        if /usr/bin/xm125-radar-monitor gpio reset-run; then
            log "Reset command completed, waiting $RESET_DELAY seconds for device to enter run mode..."
            sleep $RESET_DELAY

            # Check if device successfully entered run mode (I2C address 0x52)
            if i2cdetect -y 2 2>&1 | grep -q " 52 "; then
                log "✓ Device successfully entered run mode (I2C address 0x52) on attempt $attempt"
                success=1
                break
            else
                log "Device still not in run mode after attempt $attempt (checking I2C address)..."
                # Check if it's still in bootloader mode
                if i2cdetect -y 2 2>&1 | grep -q " 48 "; then
                    log "Device is still in bootloader mode (0x48)"
                else
                    log "Device not detected on I2C bus"
                fi
            fi
        else
            log "Reset command failed on attempt $attempt"
        fi

        # If not the last attempt, wait before retrying
        if [ $attempt -lt $MAX_RESET_ATTEMPTS ]; then
            log "Waiting before next reset attempt..."
            sleep 2
        fi

        attempt=$((attempt + 1))
    done

    if [ $success -eq 0 ]; then
        log_error "Failed to reset device to run mode after $MAX_RESET_ATTEMPTS attempts"
        log_error "Device may require manual power cycle to enter run mode after first-time firmware programming"
        return 1
    fi

    return 0
}

# Initialize XM125 GPIO and ensure device is in run mode first
# This is required before we can read the application ID
log "Initializing XM125 GPIO and resetting to run mode..."
if /usr/bin/xm125-radar-monitor gpio reset-run; then
    log "XM125 GPIO initialized and device reset to run mode"
else
    log_error "XM125 GPIO initialization failed (continuing anyway)"
    # Don't exit - allow service to start even if GPIO init fails
    # This handles transient hardware issues
fi

# Check if device is in bootloader mode (0x48) or run mode (0x52) before attempting to read app ID
log "Checking XM125 I2C address to determine device mode..."
if i2cdetect -y 2 2>&1 | grep -q " 48 "; then
    log "Device is in bootloader mode (I2C address 0x48) - attempting to reset to run mode..."
    # Try to reset to run mode
    if /usr/bin/xm125-radar-monitor gpio reset-run; then
        log "Reset command completed, waiting for device to enter run mode..."
        sleep 3  # Allow device time to boot into run mode

        # Check if device successfully entered run mode
        if i2cdetect -y 2 2>&1 | grep -q " 52 "; then
            log "Device successfully entered run mode (I2C address 0x52) - checking application ID..."
            CURRENT_APP_ID=$(read_application_id)
        else
            log "Device still in bootloader mode (0x48) after reset - firmware programming required"
            CURRENT_APP_ID=""
        fi
    else
        log "Failed to reset device to run mode - firmware programming may be required"
        CURRENT_APP_ID=""
    fi
elif i2cdetect -y 2 2>&1 | grep -q " 52 "; then
    log "Device is in run mode (I2C address 0x52) - checking application ID..."
    CURRENT_APP_ID=$(read_application_id)
else
    log "Device not detected on I2C bus - may need firmware programming"
    CURRENT_APP_ID=""
fi

if [ -n "$CURRENT_APP_ID" ]; then
    log "Current application ID: $CURRENT_APP_ID (expected: $EXPECTED_APP_ID)"

    if check_app_id "$CURRENT_APP_ID"; then
        log "Application ID matches expected value (0x02) - presence application is already programmed"
    else
        log "Application ID mismatch - presence application (0x02) is not programmed"
        log "Programming XM125 radar firmware (presence detection)..."

        # Program the firmware and capture output to check for warnings
        # Use debug logging to see stm32flash output
        FIRMWARE_OUTPUT=$(RUST_LOG=debug /usr/bin/xm125-radar-monitor firmware update presence --verify 2>&1)
        FIRMWARE_EXIT=$?

        # Log the firmware output (filter out excessive noise but keep important messages)
        # Also log key status messages even if they don't match the pattern
        # Include DEBUG level to see stm32flash output
        if [ -n "$FIRMWARE_OUTPUT" ]; then
            # First, log any DEBUG messages (which contain stm32flash output)
            echo "$FIRMWARE_OUTPUT" | grep -E "\[.*DEBUG.*stm32flash" | while read line; do
                log "$line"
            done || true
            # Then log other important messages
            echo "$FIRMWARE_OUTPUT" | grep -E "(INFO|WARN|ERROR|Updating|Flashing|completed|Successfully|failed|Failed|Starting execution|Memory programmed)" | while read line; do
                log "$line"
            done || true
        else
            log "WARNING: Firmware update command produced no output"
        fi

        # Log a summary of the firmware update attempt
        log "Firmware update command completed with exit code: $FIRMWARE_EXIT"

        if [ $FIRMWARE_EXIT -eq 0 ]; then
            log "Firmware programming command completed"

            # Always reset to run mode after firmware programming with retries
            if reset_to_run_mode_with_retries; then
                log "Device reset sequence completed"
            else
                log_error "Device reset sequence failed (continuing anyway)"
                log_error "Note: First-time firmware programming may require manual power cycle"
            fi

            # Also handle the warning if it appeared
            if echo "$FIRMWARE_OUTPUT" | grep -q "Device may not be in run mode after reset"; then
                log "Warning detected: Device may not be in run mode after firmware update (already handled above)"
            fi

            log "Verifying application ID..."

            # Loop to verify the application ID is now 0x02
            VERIFIED=0
            ATTEMPT=1
            while [ $ATTEMPT -le $MAX_VERIFY_ATTEMPTS ]; do
                log "Verification attempt $ATTEMPT of $MAX_VERIFY_ATTEMPTS..."
                sleep 1  # Brief delay to allow device to stabilize

                VERIFY_APP_ID=$(read_application_id)
                if [ -n "$VERIFY_APP_ID" ]; then
                    log "Verification read application ID: $VERIFY_APP_ID"
                    if check_app_id "$VERIFY_APP_ID"; then
                        log "✓ Application ID verified as 0x02 - presence application is now programmed"
                        VERIFIED=1
                        break
                    else
                        log "Application ID is still not 0x02 (got: $VERIFY_APP_ID)"
                        # If we can't read the correct app ID, try resetting to run mode again
                        if [ $ATTEMPT -lt $MAX_VERIFY_ATTEMPTS ]; then
                            log "Attempting to reset device to run mode before next verification attempt..."
                            /usr/bin/xm125-radar-monitor gpio reset-run || true
                            sleep 2
                        fi
                    fi
                else
                    log_error "Could not read application ID during verification attempt $ATTEMPT"
                    # If we can't read app ID, device may not be in run mode - try resetting
                    if [ $ATTEMPT -lt $MAX_VERIFY_ATTEMPTS ]; then
                        log "Device may not be in run mode, attempting reset..."
                        /usr/bin/xm125-radar-monitor gpio reset-run || true
                        sleep 2
                    fi
                fi

                ATTEMPT=$((ATTEMPT + 1))
            done

            if [ $VERIFIED -eq 0 ]; then
                log_error "Failed to verify application ID after $MAX_VERIFY_ATTEMPTS attempts (continuing anyway)"
            fi
        else
            log_error "XM125 firmware programming failed (continuing anyway)"
            # Don't exit - allow service to start even if firmware update fails
            # This handles transient issues
        fi
    fi
else
    log_error "Could not read application ID from device (continuing anyway)"
    # If we can't read the app ID, try to program anyway as a safety measure
    log "Attempting firmware update as fallback..."
    # Use debug logging to see stm32flash output
    FIRMWARE_OUTPUT=$(RUST_LOG=debug /usr/bin/xm125-radar-monitor firmware update presence --verify 2>&1)
    FIRMWARE_EXIT=$?

    # Log the firmware output (filter out excessive noise but keep important messages)
    # Also log key status messages even if they don't match the pattern
    # Include DEBUG level to see stm32flash output
    if [ -n "$FIRMWARE_OUTPUT" ]; then
        # First, log any DEBUG messages (which contain stm32flash output)
        echo "$FIRMWARE_OUTPUT" | grep -E "\[.*DEBUG.*stm32flash" | while read line; do
            log "$line"
        done || true
        # Then log other important messages
        echo "$FIRMWARE_OUTPUT" | grep -E "(INFO|WARN|ERROR|Updating|Flashing|completed|Successfully|failed|Failed|Starting execution|Memory programmed)" | while read line; do
            log "$line"
        done || true
    else
        log "WARNING: Firmware update command produced no output"
    fi

    # Log a summary of the firmware update attempt
    log "Firmware update command completed with exit code: $FIRMWARE_EXIT"

    if [ $FIRMWARE_EXIT -eq 0 ]; then
        log "Firmware programming command completed"

        # Always reset to run mode after firmware programming with retries
        if reset_to_run_mode_with_retries; then
            log "Device reset sequence completed"
        else
            log_error "Device reset sequence failed (continuing anyway)"
            log_error "Note: First-time firmware programming may require manual power cycle"
        fi

        # Also handle the warning if it appeared
        if echo "$FIRMWARE_OUTPUT" | grep -q "Device may not be in run mode after reset"; then
            log "Warning detected: Device may not be in run mode after firmware update (already handled above)"
        fi

        # Try to verify after programming
        sleep 1
        VERIFY_APP_ID=$(read_application_id)
        if [ -n "$VERIFY_APP_ID" ] && check_app_id "$VERIFY_APP_ID"; then
            log "✓ Application ID verified as 0x02 after programming"
        else
            log_error "Could not verify application ID after programming"
            # Try one more reset and verification
            log "Attempting reset to run mode and re-verification..."
            /usr/bin/xm125-radar-monitor gpio reset-run || true
            sleep 2
            VERIFY_APP_ID=$(read_application_id)
            if [ -n "$VERIFY_APP_ID" ] && check_app_id "$VERIFY_APP_ID"; then
                log "✓ Application ID verified as 0x02 after reset"
            fi
        fi
    else
        log_error "XM125 firmware programming failed (continuing anyway)"
    fi
fi

log "Startup sequence completed"
exit 0
