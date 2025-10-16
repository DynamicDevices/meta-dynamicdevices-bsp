SUMMARY = "XM125 Radar Monitor - Production CLI Tool"
DESCRIPTION = "Production-ready CLI tool for Acconeer XM125 radar modules with automatic firmware management, \
multi-mode detection (distance, presence, breathing), and GPIO control. Replaces legacy shell scripts \
with robust Rust implementation."

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
    bash \
"

# Version and source
SRCBRANCH = "main"
# SRCREV = "${AUTOREV}"  # Not needed for local files
PV = "1.4.0+git${SRCPV}"

# Temporary: Use local files until repository is ready
# SRC_URI = "git://github.com/DynamicDevices/xm125-radar-monitor.git;protocol=https;branch=${SRCBRANCH}"
SRC_URI = "file://Cargo.toml \
           file://src/main.rs \
           file://README.md \
           file://LICENSE"

S = "${WORKDIR}"

# Only build for machines with XM125 radar support
COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai)"

# Check for XM125 radar feature
python () {
    machine_features = d.getVar('MACHINE_FEATURES') or ''
    if 'xm125-radar' not in machine_features:
        raise bb.parse.SkipRecipe("XM125 radar feature not enabled for this machine")
}

# Inherit cargo_bin for Rust binary builds
inherit cargo_bin

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
    
    # Create symlinks for backward compatibility (replacing shell scripts)
    ln -sf xm125-radar-monitor ${D}${bindir}/xm125-control
    ln -sf xm125-radar-monitor ${D}${bindir}/xm125-firmware-flash
    
    # Install documentation if it exists
    if [ -f ${S}/README.md ]; then
        install -d ${D}${docdir}/${PN}
        install -m 0644 ${S}/README.md ${D}${docdir}/${PN}/
    fi
    if [ -f ${S}/CHANGELOG.md ]; then
        install -d ${D}${docdir}/${PN}
        install -m 0644 ${S}/CHANGELOG.md ${D}${docdir}/${PN}/
    fi
    
    # Install example configuration if it exists
    if [ -f ${S}/config/xm125-config.toml ]; then
        install -d ${D}${sysconfdir}/xm125
        install -m 0644 ${S}/config/xm125-config.toml ${D}${sysconfdir}/xm125/
    fi
}

# Package files
FILES:${PN} = " \
    ${bindir}/xm125-radar-monitor \
    ${bindir}/xm125-control \
    ${bindir}/xm125-firmware-flash \
    ${docdir}/${PN}/* \
"

# Package architecture
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Provides legacy script names for compatibility
PROVIDES = "xm125-control xm125-firmware-flash"

# Conflicts with old shell script packages if they exist
CONFLICTS = "xm125-shell-scripts"

# Package metadata
AUTHOR = "Alex J Lennon <ajlennon@dynamicdevices.co.uk>"
MAINTAINER = "Dynamic Devices Ltd <info@dynamicdevices.co.uk>"