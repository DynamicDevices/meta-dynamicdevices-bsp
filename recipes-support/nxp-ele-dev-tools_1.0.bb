SUMMARY = "EdgeLock Enclave Development Tools for i.MX93"
DESCRIPTION = "Collection of development and debugging tools for EdgeLock Enclave on i.MX93 platforms"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=8636bd68fc00cc6a3809b7b58b45f982"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI = "file://ele-debug.sh \
           file://ele-status.sh \
           file://ele-firmware-info.sh \
           file://LICENSE"

DEPENDS = "openssl"
RDEPENDS:${PN} = "bash openssl-bin devmem2 i2c-tools"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/ele-debug.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/ele-status.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/ele-firmware-info.sh ${D}${bindir}/
    
    # Create main ELE development tool launcher
    cat > ${D}${bindir}/ele-dev-tools << 'EOF'
#!/bin/bash
# EdgeLock Enclave Development Tools Launcher

echo "🔐 EdgeLock Enclave Development Tools for i.MX93"
echo "================================================"
echo ""
echo "Available tools:"
echo "  1. ele-status         - Show ELE subsystem status"
echo "  2. ele-debug          - Debug ELE communication"
echo "  3. ele-firmware-info  - Display firmware information"
echo "  4. enhanced-ele-test  - Run comprehensive test suite"
echo ""

case "$1" in
    "status")
        ele-status.sh
        ;;
    "debug")
        ele-debug.sh "$@"
        ;;
    "firmware")
        ele-firmware-info.sh
        ;;
    "test")
        shift
        enhanced-ele-test "$@"
        ;;
    *)
        echo "Usage: $0 {status|debug|firmware|test} [options]"
        echo ""
        echo "Examples:"
        echo "  $0 status              - Show ELE status"
        echo "  $0 debug               - Start debug session"
        echo "  $0 firmware            - Show firmware info"
        echo "  $0 test all            - Run all tests"
        echo "  $0 test device_presence - Run specific test"
        exit 1
        ;;
esac
EOF
    chmod +x ${D}${bindir}/ele-dev-tools
}

FILES:${PN} = "${bindir}/ele-debug.sh ${bindir}/ele-status.sh ${bindir}/ele-firmware-info.sh ${bindir}/ele-dev-tools"

# Only install on i.MX93 platforms with ELE support
COMPATIBLE_MACHINE = "(mx9-generic-bsp)"
