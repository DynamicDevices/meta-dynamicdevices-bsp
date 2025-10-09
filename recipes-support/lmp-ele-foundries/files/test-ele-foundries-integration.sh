#!/bin/bash
# ELE Foundries.io Integration Test Script
# Comprehensive testing for EdgeLock Enclave integration with Foundries.io

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LOG="/var/log/ele-foundries-test.log"
RESULTS_FILE="/tmp/ele-test-results.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$TEST_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$TEST_LOG"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$TEST_LOG"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$TEST_LOG"
}

test_start() {
    local test_name="$1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log "🧪 Starting test: $test_name"
}

test_pass() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    success "✅ PASS: $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    error "❌ FAIL: $test_name - $reason"
}

# Test 1: ELE Hardware Availability
test_ele_hardware() {
    test_start "ELE Hardware Availability"
    
    local errors=0
    
    # Check ELE device node
    if [ ! -e "/dev/ele_mu" ]; then
        test_fail "ELE Hardware" "ELE device node /dev/ele_mu not found"
        return 1
    fi
    
    # Check ELE sysfs interface
    if [ ! -d "/sys/class/misc/ele_mu" ]; then
        warn "ELE sysfs interface not found (may be normal)"
        errors=$((errors + 1))
    fi
    
    # Check ELE firmware
    if [ ! -d "/lib/firmware/imx/ele" ]; then
        test_fail "ELE Hardware" "ELE firmware directory not found"
        return 1
    fi
    
    # Check device tree
    if ! find /proc/device-tree -name "*s4muap*" -o -name "*ele*" 2>/dev/null | grep -q .; then
        warn "ELE device tree entries not found"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        test_pass "ELE Hardware Availability"
    else
        test_fail "ELE Hardware" "$errors warnings found"
    fi
    
    return $errors
}

# Test 2: ELE Test Suite Functionality
test_ele_functionality() {
    test_start "ELE Functionality"
    
    # Test simple ELE test
    if command -v simple-ele-test >/dev/null 2>&1; then
        if simple-ele-test status >/dev/null 2>&1; then
            success "Simple ELE test passed"
        else
            test_fail "ELE Functionality" "simple-ele-test failed"
            return 1
        fi
    else
        warn "simple-ele-test not available"
    fi
    
    # Test enhanced ELE test
    if command -v enhanced-ele-test >/dev/null 2>&1; then
        if enhanced-ele-test status >/dev/null 2>&1; then
            success "Enhanced ELE test passed"
        else
            warn "enhanced-ele-test failed"
        fi
    else
        warn "enhanced-ele-test not available"
    fi
    
    test_pass "ELE Functionality"
    return 0
}

# Test 3: HSM Configuration
test_hsm_configuration() {
    test_start "HSM Configuration"
    
    local hsm_config="/etc/sota/hsm"
    
    if [ ! -f "$hsm_config" ]; then
        test_fail "HSM Configuration" "HSM config file not found: $hsm_config"
        return 1
    fi
    
    # Check required HSM variables
    local required_vars=("HSM_MODULE" "HSM_PIN" "HSM_SOPIN")
    local missing_vars=""
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$hsm_config"; then
            missing_vars="$missing_vars $var"
        fi
    done
    
    if [ -n "$missing_vars" ]; then
        test_fail "HSM Configuration" "Missing variables:$missing_vars"
        return 1
    fi
    
    # Check HSM module file
    local hsm_module=$(grep "^HSM_MODULE=" "$hsm_config" | cut -d'=' -f2 | tr -d '"')
    if [ ! -f "$hsm_module" ]; then
        test_fail "HSM Configuration" "HSM module not found: $hsm_module"
        return 1
    fi
    
    test_pass "HSM Configuration"
    return 0
}

# Test 4: PKCS#11 Module
test_pkcs11_module() {
    test_start "PKCS#11 Module"
    
    local pkcs11_module="/usr/lib/pkcs11/ele-pkcs11.so"
    
    if [ ! -f "$pkcs11_module" ]; then
        test_fail "PKCS#11 Module" "PKCS#11 module not found: $pkcs11_module"
        return 1
    fi
    
    # Check if module is executable/loadable
    if [ ! -x "$pkcs11_module" ] && [ ! -r "$pkcs11_module" ]; then
        test_fail "PKCS#11 Module" "PKCS#11 module not accessible: $pkcs11_module"
        return 1
    fi
    
    # Basic library check
    if command -v file >/dev/null 2>&1; then
        local file_type=$(file "$pkcs11_module")
        if [[ "$file_type" == *"shared object"* ]] || [[ "$file_type" == *"ELF"* ]]; then
            success "PKCS#11 module appears to be a valid shared library"
        else
            warn "PKCS#11 module may not be a valid shared library"
        fi
    fi
    
    test_pass "PKCS#11 Module"
    return 0
}

# Test 5: Foundries.io Configuration
test_foundries_config() {
    test_start "Foundries.io Configuration"
    
    local config_file="/etc/default/lmp-ele-auto-register"
    
    if [ ! -f "$config_file" ]; then
        test_fail "Foundries.io Configuration" "Config file not found: $config_file"
        return 1
    fi
    
    # Check for required configuration
    local required_configs=("REPOID" "ELE_DEVICE_KEY_ID" "ELE_DEVICE_CERT_ID")
    local missing_configs=""
    
    for config in "${required_configs[@]}"; do
        if ! grep -q "^$config=" "$config_file"; then
            missing_configs="$missing_configs $config"
        fi
    done
    
    if [ -n "$missing_configs" ]; then
        test_fail "Foundries.io Configuration" "Missing configurations:$missing_configs"
        return 1
    fi
    
    # Check if REPOID is customized
    if grep -q 'REPOID="your-factory-name"' "$config_file"; then
        warn "REPOID still set to default value - needs customization"
    fi
    
    test_pass "Foundries.io Configuration"
    return 0
}

# Test 6: Registration Token
test_registration_token() {
    test_start "Registration Token"
    
    local token_file="/etc/lmp-device-register-token"
    
    if [ ! -f "$token_file" ]; then
        test_fail "Registration Token" "Token file not found: $token_file"
        return 1
    fi
    
    # Check if token file is not empty
    if [ ! -s "$token_file" ]; then
        test_fail "Registration Token" "Token file is empty"
        return 1
    fi
    
    # Basic token format check (should be a long string)
    local token=$(head -n1 "$token_file")
    if [ ${#token} -lt 32 ]; then
        test_fail "Registration Token" "Token appears to be too short"
        return 1
    fi
    
    test_pass "Registration Token"
    return 0
}

# Test 7: Services Configuration
test_services() {
    test_start "Services Configuration"
    
    local service="lmp-ele-auto-register.service"
    
    # Check if service file exists
    if ! systemctl list-unit-files | grep -q "$service"; then
        test_fail "Services Configuration" "Service not found: $service"
        return 1
    fi
    
    # Check service status
    local service_status=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
    if [ "$service_status" = "enabled" ]; then
        success "Service is enabled: $service"
    else
        warn "Service is not enabled: $service"
    fi
    
    test_pass "Services Configuration"
    return 0
}

# Test 8: Device Registration Test (dry run)
test_device_registration() {
    test_start "Device Registration (dry run)"
    
    # Check if lmp-device-register command exists
    if ! command -v lmp-device-register >/dev/null 2>&1; then
        test_fail "Device Registration" "lmp-device-register command not found"
        return 1
    fi
    
    # Test help command (should not fail)
    if lmp-device-register --help >/dev/null 2>&1; then
        success "lmp-device-register command is accessible"
    else
        test_fail "Device Registration" "lmp-device-register command failed"
        return 1
    fi
    
    # Check if device is already registered
    if [ -f "/var/sota/sql.db" ]; then
        warn "Device appears to be already registered"
    else
        success "Device is ready for registration"
    fi
    
    test_pass "Device Registration (dry run)"
    return 0
}

# Generate test results in JSON format
generate_results() {
    cat > "$RESULTS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "board": "imx93-jaguar-eink",
  "test_suite": "ELE Foundries.io Integration",
  "summary": {
    "total_tests": $TESTS_TOTAL,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED,
    "success_rate": "$(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
  },
  "system_info": {
    "kernel": "$(uname -r)",
    "arch": "$(uname -m)",
    "os_release": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
  }
}
EOF
}

# Show test summary
show_summary() {
    echo ""
    echo "========================================"
    echo "🔐 ELE Foundries.io Integration Test Summary"
    echo "========================================"
    echo "Board: imx93-jaguar-eink"
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        success "🎉 All tests passed! ELE integration is ready."
        echo ""
        echo "Next steps:"
        echo "1. Customize /etc/sota/hsm with your specific PINs"
        echo "2. Update REPOID in /etc/default/lmp-ele-auto-register"
        echo "3. Install your Foundries.io registration token"
        echo "4. Start the registration service: systemctl start lmp-ele-auto-register"
    else
        error "❌ Some tests failed. Please review the issues above."
        echo ""
        echo "Common fixes:"
        echo "1. Ensure ELE drivers are loaded: modprobe imx-ele"
        echo "2. Check device tree configuration for ELE/S4MUAP"
        echo "3. Verify ELE firmware is installed"
        echo "4. Run: ele-provisioning-setup.sh"
    fi
    
    echo ""
    echo "Log file: $TEST_LOG"
    echo "Results: $RESULTS_FILE"
}

# Main test execution
main() {
    log "🔐 Starting ELE Foundries.io Integration Tests"
    log "Target: imx93-jaguar-eink"
    echo ""
    
    # Initialize log
    echo "ELE Foundries.io Integration Test - $(date)" > "$TEST_LOG"
    
    # Run all tests
    test_ele_hardware || true
    test_ele_functionality || true
    test_hsm_configuration || true
    test_pkcs11_module || true
    test_foundries_config || true
    test_registration_token || true
    test_services || true
    test_device_registration || true
    
    # Generate results and show summary
    generate_results
    show_summary
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Command line options
case "${1:-all}" in
    all)
        main
        ;;
    hardware)
        test_ele_hardware
        ;;
    functionality)
        test_ele_functionality
        ;;
    config)
        test_hsm_configuration
        test_foundries_config
        ;;
    registration)
        test_device_registration
        ;;
    *)
        echo "Usage: $0 [all|hardware|functionality|config|registration]"
        echo "  all           - Run all tests (default)"
        echo "  hardware      - Test ELE hardware availability"
        echo "  functionality - Test ELE functionality"
        echo "  config        - Test configuration files"
        echo "  registration  - Test device registration setup"
        exit 1
        ;;
esac
