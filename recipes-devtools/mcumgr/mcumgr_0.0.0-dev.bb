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
# Override license file location due to Go workspace structure
LIC_FILES_CHKSUM = "file://src/github.com/apache/mynewt-mcumgr-cli/LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

# Use latest commit from mynewt-mcumgr-cli (stable client, works with current Zephyr servers)
SRCREV = "5c56bd24066c780aad5836429bfa2ecc4f9a944c"
PV = "0.0.0-dev+git${SRCPV}"

SRC_URI = "git://github.com/apache/mynewt-mcumgr-cli.git;protocol=https;branch=master"

S = "${WORKDIR}/git"

# Build dependencies - Go is required to build mcumgr
DEPENDS = "go-native"

# Runtime dependencies
RDEPENDS:${PN} = "bash"

# Inherit go class for proper Go build support
inherit go

# Go module configuration
GO_IMPORT = "github.com/apache/mynewt-mcumgr-cli"
GO_INSTALL = "${GO_IMPORT}/mcumgr"

# Override the default go build process
do_compile() {
    cd ${S}
    
    # Set up Go environment
    export GOPATH="${WORKDIR}/go"
    export GO111MODULE=on
    export CGO_ENABLED=0
    
    # The source is in src/github.com/apache/mynewt-mcumgr-cli/ due to Go workspace setup
    echo "Building mcumgr from source directory: ${S}"
    echo "Contents of source directory:"
    ls -la
    
    # Navigate to the actual source location
    ACTUAL_SRC="${S}/src/github.com/apache/mynewt-mcumgr-cli"
    if [ -d "$ACTUAL_SRC" ]; then
        echo "Found actual source at: $ACTUAL_SRC"
        cd "$ACTUAL_SRC"
        echo "Contents of actual source directory:"
        ls -la
        echo "Contents of mcumgr directory:"
        ls -la mcumgr/
        echo "go.mod content:"
        cat go.mod
        
        # Build mcumgr binary from the mcumgr subdirectory
        echo "Attempting to build mcumgr..."
        echo "Current directory: $(pwd)"
        echo "Go version: $(go version)"
        echo "Go environment:"
        go env
        
        # Try to build with verbose output and error capture
        if ! go build -v -ldflags "-s -w -extldflags '-static'" -o mcumgr ./mcumgr; then
            echo "Go build failed! Checking for detailed error..."
            echo "Trying build without static linking..."
            if ! go build -v -o mcumgr ./mcumgr; then
                echo "Go build failed even without static linking!"
                echo "Checking Go module status..."
                go mod tidy || echo "go mod tidy failed"
                go mod download || echo "go mod download failed"
                bbfatal "Go build failed completely"
            fi
        fi
        
        # Check if binary was created in mcumgr subdirectory (which is the normal Go behavior)
        if [ -f mcumgr/mcumgr ]; then
            echo "Found mcumgr binary in mcumgr/ subdirectory (normal Go build behavior)"
            echo "Current directory: $(pwd)"
            echo "Directory contents:"
            ls -la
            echo "mcumgr subdirectory contents:"
            ls -la mcumgr/
            # The binary is already in the correct location for our install function
            echo "Binary is ready for installation from mcumgr/mcumgr"
        elif [ -f mcumgr ]; then
            echo "Found mcumgr binary in current directory"
        else
            echo "Binary not found in expected locations. Searching..."
            find . -name "mcumgr" -type f -exec ls -la {} \;
            bbfatal "mcumgr binary was not created in any expected location"
        fi
        
        # Final verification that we have a binary ready for installation
        if [ -f mcumgr/mcumgr ]; then
            echo "mcumgr binary ready for installation at mcumgr/mcumgr"
        elif [ -f mcumgr ]; then
            echo "mcumgr binary ready for installation at mcumgr"
        else
            bbfatal "mcumgr binary was not created in any accessible location"
        fi
        
        echo "mcumgr built successfully"
        ls -la mcumgr
    else
        bbfatal "Could not find source at $ACTUAL_SRC"
    fi
}

do_install() {
    install -d ${D}${bindir}
    
    # Install main mcumgr binary (built in actual source directory)
    ACTUAL_SRC="${S}/src/github.com/apache/mynewt-mcumgr-cli"
    if [ -f "$ACTUAL_SRC/mcumgr/mcumgr" ]; then
        echo "Installing mcumgr binary from $ACTUAL_SRC/mcumgr/mcumgr"
        install -m 0755 "$ACTUAL_SRC/mcumgr/mcumgr" ${D}${bindir}/mcumgr
    elif [ -f "$ACTUAL_SRC/mcumgr" ]; then
        echo "Installing mcumgr binary from $ACTUAL_SRC/mcumgr"
        install -m 0755 "$ACTUAL_SRC/mcumgr" ${D}${bindir}/mcumgr
    else
        bbfatal "mcumgr binary not found at expected locations in $ACTUAL_SRC"
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
COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai|imx93-jaguar-eink)"

# Recommended packages for serial communication
RRECOMMENDS:${PN} = "screen minicom"
