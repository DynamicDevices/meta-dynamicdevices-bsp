# MCUmgr - Command line tool for MCU management
#
# MCUmgr is a management library for 32-bit MCUs that provides
# a command-line interface for managing Zephyr RTOS devices

SUMMARY = "MCUmgr command-line tool for MCU management"
DESCRIPTION = "MCUmgr command-line tool for managing Zephyr RTOS devices with MCUboot bootloader. \
Supports firmware updates, device management, and debugging over multiple transports \
including UART, Bluetooth LE, and UDP. Uses the stable mynewt-mcumgr-cli client."
HOMEPAGE = "https://github.com/apache/mynewt-mcumgr-cli"
SECTION = "devel"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

# Use latest commit from mynewt-mcumgr-cli (stable client, works with current Zephyr servers)
SRCREV = "5c56bd24066c780aad5836429bfa2ecc4f9a944c"
PV = "0.0.0-dev+git${SRCPV}"

SRC_URI = "git://github.com/apache/mynewt-mcumgr-cli.git;protocol=https;branch=master"

S = "${WORKDIR}/git"

# Build dependencies - Go is required to build mcumgr
DEPENDS = "go-native"

# Runtime dependencies
RDEPENDS:${PN} = "bash"

# Don't inherit go class - we'll handle the build manually to avoid conflicts

# Override the default go build process
do_compile() {
    cd ${S}
    
    # Set up Go environment
    export GO111MODULE=on
    export CGO_ENABLED=0
    export GOOS=linux
    export GOARCH=arm64
    
    echo "Building mcumgr from source directory: ${S}"
    echo "Contents of source directory:"
    ls -la
    
    # Check if we have the expected Go module structure
    if [ -f go.mod ]; then
        echo "Found go.mod at root level"
        echo "go.mod content:"
        cat go.mod
        
        echo "Building mcumgr binary..."
        echo "Go version: $(go version)"
        
        # Build directly from the mcumgr subdirectory and place binary at root
        if go build -v -o "$(pwd)/mcumgr" ./mcumgr; then
            echo "mcumgr built successfully"
            ls -la mcumgr*
        else
            echo "Go build failed, trying without verbose output..."
            if go build -o "$(pwd)/mcumgr" ./mcumgr; then
                echo "mcumgr built successfully (second attempt)"
                ls -la mcumgr*
            else
                bbfatal "Go build failed completely"
            fi
        fi
        
        # Verify binary was created - the Go build is working, binary may be in subdirectory
        if [ -f mcumgr ]; then
            echo "mcumgr binary verified at root: $(ls -la mcumgr)"
        elif [ -f mcumgr/mcumgr ]; then
            echo "mcumgr binary found in subdirectory: $(ls -la mcumgr/mcumgr)"
            echo "This is expected - Go build creates binary in package subdirectory"
        else
            echo "mcumgr binary not found, searching..."
            find . -name "mcumgr" -type f -exec ls -la {} \;
            bbfatal "mcumgr binary was not created"
        fi
        
    else
        bbfatal "No go.mod found in source directory - invalid Go module"
    fi
}

do_install() {
    install -d ${D}${bindir}
    
    # Install main mcumgr binary - check both possible locations
    if [ -f "${S}/mcumgr" ]; then
        echo "Installing mcumgr binary from ${S}/mcumgr"
        install -m 0755 "${S}/mcumgr" ${D}${bindir}/mcumgr
    elif [ -f "${S}/mcumgr/mcumgr" ]; then
        echo "Installing mcumgr binary from ${S}/mcumgr/mcumgr"
        install -m 0755 "${S}/mcumgr/mcumgr" ${D}${bindir}/mcumgr
    else
        bbfatal "mcumgr binary not found at ${S}/mcumgr or ${S}/mcumgr/mcumgr"
    fi
    
    # Create configuration helper script
    cat > ${D}${bindir}/mcumgr-setup << 'EOF'
#!/bin/bash
# MCUmgr connection setup helper for Zephyr devices

DEVICE="${1:-/dev/ttyUSB0}"
BAUD="${2:-115200}"
CONN="${3:-serial1}"

echo "Setting up mcumgr connection..."
echo "Device: $DEVICE"
echo "Baud rate: $BAUD"
echo "Connection name: $CONN"

mcumgr conn add "$CONN" type="serial" connstring="dev=$DEVICE,baud=$BAUD"

if [ $? -eq 0 ]; then
    echo "Connection '$CONN' configured successfully!"
    echo ""
    echo "Usage examples:"
    echo "  mcumgr -c $CONN image list"
    echo "  mcumgr -c $CONN image upload firmware.bin"
    echo "  mcumgr -c $CONN reset"
else
    echo "Failed to configure connection"
    exit 1
fi
EOF
    chmod +x ${D}${bindir}/mcumgr-setup
}

# Package files
FILES:${PN} = "${bindir}/mcumgr \
               ${bindir}/mcumgr-setup"

# Compatible machines
COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai|imx8mm-jaguar-dt510|imx93-jaguar-eink)"

# Recommended packages for serial communication
RRECOMMENDS:${PN} = "screen minicom"
