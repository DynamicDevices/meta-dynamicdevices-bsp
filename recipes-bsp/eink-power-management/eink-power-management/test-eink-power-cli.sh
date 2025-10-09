#!/bin/bash
# E-ink Power CLI Test Script
# Tests available eink-power-cli commands to understand the interface

LOG_FILE="/var/log/eink-power-cli-test.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

test_eink_power_cli() {
    log_message "Testing eink-power-cli availability and commands..."
    
    # Check if command exists
    if ! command -v eink-power-cli >/dev/null 2>&1; then
        if command -v eink-pmu >/dev/null 2>&1; then
            log_message "Using eink-pmu symlink"
            POWER_CLI="eink-pmu"
        else
            log_message "ERROR: eink-power-cli not found"
            return 1
        fi
    else
        POWER_CLI="eink-power-cli"
    fi
    
    log_message "Found power CLI: $POWER_CLI"
    
    # Test help/usage
    log_message "=== Testing help command ==="
    $POWER_CLI --help 2>&1 | tee -a "$LOG_FILE" || {
        log_message "Help command failed, trying -h"
        $POWER_CLI -h 2>&1 | tee -a "$LOG_FILE" || {
            log_message "No help available"
        }
    }
    
    # Test version
    log_message "=== Testing version command ==="
    $POWER_CLI --version 2>&1 | tee -a "$LOG_FILE" || {
        log_message "Version command failed, trying -V"
        $POWER_CLI -V 2>&1 | tee -a "$LOG_FILE" || {
            log_message "No version available"
        }
    }
    
    # Test status command
    log_message "=== Testing status command ==="
    $POWER_CLI status 2>&1 | tee -a "$LOG_FILE" || {
        log_message "Status command failed"
    }
    
    # Test info command
    log_message "=== Testing info command ==="
    $POWER_CLI info 2>&1 | tee -a "$LOG_FILE" || {
        log_message "Info command failed"
    }
    
    # Test battery command
    log_message "=== Testing battery command ==="
    $POWER_CLI battery 2>&1 | tee -a "$LOG_FILE" || {
        log_message "Battery command failed"
    }
    
    # List all available commands (if supported)
    log_message "=== Testing list/commands ==="
    $POWER_CLI list 2>&1 | tee -a "$LOG_FILE" || {
        $POWER_CLI commands 2>&1 | tee -a "$LOG_FILE" || {
            log_message "No command listing available"
        }
    }
    
    log_message "eink-power-cli test completed"
}

# Main execution
main() {
    log_message "Starting eink-power-cli test..."
    test_eink_power_cli
    log_message "Test completed. Check $LOG_FILE for details."
}

main "$@"
