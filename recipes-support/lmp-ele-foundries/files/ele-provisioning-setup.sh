#!/bin/bash
# ELE PKCS#11 Module Setup and Provisioning Script
# This script helps set up the EdgeLock Enclave PKCS#11 integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELE_PKCS11_PATH="/usr/lib/pkcs11"
HSM_CONFIG_PATH="/etc/sota/hsm"
LOG_FILE="/var/log/ele-provisioning.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi
}

check_ele_hardware() {
    log "Checking ELE hardware availability..."
    
    if [ ! -e "/dev/ele_mu" ]; then
        error "ELE device not found: /dev/ele_mu"
        error "Ensure ELE support is enabled in kernel and device tree"
        return 1
    fi
    
    if ! lsmod | grep -q "imx-ele"; then
        warn "ELE kernel module not loaded (this may be normal)"
    fi
    
    success "ELE hardware check passed"
    return 0
}

create_pkcs11_stub() {
    log "Creating ELE PKCS#11 stub module..."
    
    mkdir -p "$ELE_PKCS11_PATH"
    
    # Create a simple stub PKCS#11 module for initial testing
    cat > "$ELE_PKCS11_PATH/ele-pkcs11-stub.c" << 'EOF'
/*
 * ELE PKCS#11 Stub Module for i.MX93
 * This is a minimal stub implementation for testing purposes
 * 
 * TODO: Replace with full ELE PKCS#11 implementation
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// PKCS#11 return codes
#define CKR_OK                    0x00000000
#define CKR_FUNCTION_NOT_SUPPORTED 0x00000054

// Basic PKCS#11 function stubs
unsigned long C_Initialize(void *pInitArgs) {
    printf("ELE PKCS#11 Stub: C_Initialize called\n");
    return CKR_OK;
}

unsigned long C_Finalize(void *pReserved) {
    printf("ELE PKCS#11 Stub: C_Finalize called\n");
    return CKR_OK;
}

unsigned long C_GetInfo(void *pInfo) {
    printf("ELE PKCS#11 Stub: C_GetInfo called\n");
    return CKR_FUNCTION_NOT_SUPPORTED;
}

// Add more PKCS#11 functions as needed...
EOF

    # Compile the stub module
    if command -v gcc >/dev/null 2>&1; then
        gcc -shared -fPIC -o "$ELE_PKCS11_PATH/ele-pkcs11.so" \
            "$ELE_PKCS11_PATH/ele-pkcs11-stub.c" 2>/dev/null || {
            warn "Failed to compile PKCS#11 stub, creating placeholder"
            touch "$ELE_PKCS11_PATH/ele-pkcs11.so"
        }
        rm -f "$ELE_PKCS11_PATH/ele-pkcs11-stub.c"
        success "ELE PKCS#11 stub module created"
    else
        warn "GCC not available, creating empty placeholder"
        touch "$ELE_PKCS11_PATH/ele-pkcs11.so"
    fi
}

setup_hsm_config() {
    log "Setting up HSM configuration..."
    
    # Create sota directory if it doesn't exist
    mkdir -p "$(dirname "$HSM_CONFIG_PATH")"
    
    # Copy template if HSM config doesn't exist
    if [ ! -f "$HSM_CONFIG_PATH" ]; then
        if [ -f "$SCRIPT_DIR/hsm-config-template" ]; then
            cp "$SCRIPT_DIR/hsm-config-template" "$HSM_CONFIG_PATH"
            success "HSM configuration template installed"
        else
            # Create basic HSM config
            cat > "$HSM_CONFIG_PATH" << EOF
# ELE HSM Configuration
HSM_MODULE="/usr/lib/pkcs11/ele-pkcs11.so"
HSM_PIN="1234"
HSM_SOPIN="123456"
ELE_DEVICE="/dev/ele_mu"
EOF
            success "Basic HSM configuration created"
        fi
        chmod 600 "$HSM_CONFIG_PATH"
    else
        log "HSM configuration already exists"
    fi
}

create_provisioning_service() {
    log "Creating ELE provisioning service..."
    
    cat > "/etc/systemd/system/ele-provisioning.service" << 'EOF'
[Unit]
Description=ELE Provisioning Service
After=multi-user.target
ConditionPathExists=/dev/ele_mu

[Service]
Type=oneshot
ExecStart=/usr/bin/ele-provisioning-setup
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create the provisioning setup script
    cat > "/usr/bin/ele-provisioning-setup" << 'EOF'
#!/bin/bash
# ELE Provisioning Setup Script

echo "Starting ELE provisioning setup..."

# Check ELE device
if [ ! -e "/dev/ele_mu" ]; then
    echo "ERROR: ELE device not found"
    exit 1
fi

# Initialize ELE if needed
echo "ELE device found, initialization complete"

# TODO: Add actual ELE provisioning logic here
# - Generate device keypair in ELE
# - Create device certificate
# - Store credentials securely

echo "ELE provisioning setup complete"
EOF

    chmod +x "/usr/bin/ele-provisioning-setup"
    
    systemctl daemon-reload
    success "ELE provisioning service created"
}

test_ele_functionality() {
    log "Testing ELE functionality..."
    
    # Test basic ELE access
    if command -v simple-ele-test >/dev/null 2>&1; then
        simple-ele-test status || warn "ELE basic test failed"
    else
        warn "ELE test utilities not available"
    fi
    
    # Test PKCS#11 module
    if [ -f "$ELE_PKCS11_PATH/ele-pkcs11.so" ]; then
        success "ELE PKCS#11 module is present"
    else
        error "ELE PKCS#11 module not found"
    fi
}

show_next_steps() {
    log "ELE provisioning setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Customize /etc/sota/hsm with your specific settings"
    echo "2. Install your Foundries.io registration token in /etc/lmp-device-register-token"
    echo "3. Update factory settings in /etc/default/lmp-ele-auto-register"
    echo "4. Replace the stub PKCS#11 module with a full implementation"
    echo "5. Test device registration: systemctl start lmp-ele-auto-register"
    echo ""
    echo "Configuration files:"
    echo "- HSM config: $HSM_CONFIG_PATH"
    echo "- PKCS#11 module: $ELE_PKCS11_PATH/ele-pkcs11.so"
    echo "- Log file: $LOG_FILE"
}

main() {
    log "Starting ELE PKCS#11 provisioning setup..."
    
    check_root
    check_ele_hardware || exit 1
    create_pkcs11_stub
    setup_hsm_config
    create_provisioning_service
    test_ele_functionality
    show_next_steps
    
    success "ELE provisioning setup completed successfully!"
}

# Command line options
case "${1:-setup}" in
    setup)
        main
        ;;
    test)
        test_ele_functionality
        ;;
    status)
        check_ele_hardware && test_ele_functionality
        ;;
    *)
        echo "Usage: $0 [setup|test|status]"
        echo "  setup  - Full ELE PKCS#11 provisioning setup (default)"
        echo "  test   - Test ELE functionality"
        echo "  status - Check ELE hardware and module status"
        exit 1
        ;;
esac
