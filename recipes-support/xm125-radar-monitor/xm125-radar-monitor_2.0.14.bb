SUMMARY = "XM125 Radar Monitor - Reset Pin Control Fix v2.0.14 (service: tmp.mount + startup script)"
DESCRIPTION = "Production-ready CLI tool for Acconeer XM125 radar modules with automatic hardware initialization, \
multi-mode detection (distance, presence, breathing), GPIO control, and FIFO integration. Features automatic \
XM125 GPIO initialization on I2C failures with improved post-reset timing and retry logic. Includes spi-lib \
compatibility, 7m detection range, modular architecture, and robust error recovery. \
Replaces legacy shell scripts with reliable Rust implementation. Service configured for full 7.0m detection range. \
Fixed reset pin control regression - GPIO initialization now properly sets initial pin values."

HOMEPAGE = "https://github.com/DynamicDevices/xm125-radar-monitor"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1ebbd3e34237af26da5dc08a4e440464"

SECTION = "base"

# Dependencies for build and runtime
DEPENDS = "openssl-native"
RDEPENDS:${PN} = " \
    libgpiod-tools \
    i2c-tools \
    stm32flash \
    xm125-firmware \
"

# Version and source - Updated to v2.0.14 with reset pin control fix
PV = "2.0.14"
SRCBRANCH = "main"
SRCREV = "b73f929ad61e46a8698d1362f811de0411337205"

SRC_URI = "git://github.com/DynamicDevices/xm125-radar-monitor.git;protocol=https;branch=${SRCBRANCH} \
           file://xm125-radar-monitor.service \
           file://xm125-service-startup.sh \
           file://xm125-control.sh \
           file://xm125-presence.conf \
"

S = "${WORKDIR}/git"

# Only build for machines with XM125 radar support
COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai)"

# Check for XM125 radar feature
python () {
    machine_features = d.getVar('MACHINE_FEATURES') or ''
    if 'xm125-radar' not in machine_features:
        raise bb.parse.SkipRecipe("XM125 radar feature not enabled for this machine")
}

# Inherit cargo_bin for Rust binary builds and systemd for service management
inherit cargo_bin systemd

# Systemd service configuration
SYSTEMD_SERVICE:${PN} = "xm125-radar-monitor.service"
# Enable service by default when XM125 radar feature is present
SYSTEMD_AUTO_ENABLE:${PN} = "${@bb.utils.contains('MACHINE_FEATURES', 'xm125-radar', 'enable', 'disable', d)}"

# Enable network for the compile task allowing cargo to download dependencies
do_compile[network] = "1"

# Fix buildpaths QA warnings by ensuring debug prefix mapping is applied to Rust builds
RUSTFLAGS:append = " --remap-path-prefix=${WORKDIR}=/usr/src/debug/${PN}/${PV}"
RUSTFLAGS:append = " --remap-path-prefix=${TMPDIR}=/usr/src/debug/tmpdir"

# Skip QA check for already-stripped - Rust release binaries are pre-stripped
INSANE_SKIP:${PN} += "already-stripped"


# Install the application
do_install() {
    install -d ${D}${bindir}
    
    # cargo_bin class builds to ${B}/${RUST_TARGET}/release/ for release profile
    # where B = ${WORKDIR}/target and RUST_TARGET = aarch64-unknown-linux-gnu
    install -m 755 ${B}/${RUST_TARGET}/release/xm125-radar-monitor ${D}${bindir}/xm125-radar-monitor
    
    # Install startup script (firmware programming and GPIO init before main service)
    install -m 0755 ${WORKDIR}/xm125-service-startup.sh ${D}${bindir}/xm125-service-startup.sh
    
    # Install control script (GPIO/firmware management wrapper)
    install -m 0755 ${WORKDIR}/xm125-control.sh ${D}${bindir}/xm125-control.sh
    
    # Install tmpfiles.d config to create /tmp/presence FIFO at boot (before services)
    install -d ${D}${sysconfdir}/tmpfiles.d
    install -m 0644 ${WORKDIR}/xm125-presence.conf ${D}${sysconfdir}/tmpfiles.d/
    
    # Install systemd service
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/xm125-radar-monitor.service ${D}${systemd_unitdir}/system/xm125-radar-monitor.service
    
    # Install documentation
    install -d ${D}${docdir}/${PN}
    install -m 0644 ${S}/README.md ${D}${docdir}/${PN}/
    install -m 0644 ${S}/CHANGELOG.md ${D}${docdir}/${PN}/
    install -m 0644 ${S}/docs/PROJECT_CONTEXT.md ${D}${docdir}/${PN}/
}

# Package files
FILES:${PN} = " \
    ${bindir}/xm125-radar-monitor \
    ${bindir}/xm125-service-startup.sh \
    ${bindir}/xm125-control.sh \
    ${systemd_unitdir}/system/xm125-radar-monitor.service \
    ${sysconfdir}/tmpfiles.d/xm125-presence.conf \
    ${docdir}/${PN}/* \
"

# Package architecture
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Modern Rust implementation with automatic hardware initialization
PROVIDES = "xm125-radar-monitor"

# Conflicts with old shell script packages if they exist
CONFLICTS = "xm125-shell-scripts"

# Package metadata
AUTHOR = "Alex J Lennon <ajlennon@dynamicdevices.co.uk>"
MAINTAINER = "Dynamic Devices Ltd <info@dynamicdevices.co.uk>"

