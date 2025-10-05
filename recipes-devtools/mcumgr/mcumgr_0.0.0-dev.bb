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
    
    # Create proper Go workspace
    mkdir -p ${WORKDIR}/go/src/github.com/apache
    ln -sf ${S} ${WORKDIR}/go/src/github.com/apache/mynewt-mcumgr-cli
    
    # Build mcumgr binary
    cd ${WORKDIR}/go/src/github.com/apache/mynewt-mcumgr-cli
    go build -ldflags "-s -w -extldflags '-static'" -o mcumgr ./mcumgr
    
    if [ ! -f mcumgr ]; then
        bbfatal "mcumgr binary was not created"
    fi
    
    echo "mcumgr built successfully"
    ls -la mcumgr
}

do_install() {
    install -d ${D}${bindir}
    
    # Install main mcumgr binary (built in Go workspace)
    if [ -f ${WORKDIR}/go/src/github.com/apache/mynewt-mcumgr-cli/mcumgr ]; then
        install -m 0755 ${WORKDIR}/go/src/github.com/apache/mynewt-mcumgr-cli/mcumgr ${D}${bindir}/mcumgr
    else
        bbfatal "mcumgr binary not found for installation"
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
