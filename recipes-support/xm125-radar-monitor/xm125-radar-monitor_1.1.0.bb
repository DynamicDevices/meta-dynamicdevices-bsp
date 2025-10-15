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
PV = "1.1.0"
SRCBRANCH = "main"
SRCREV = "${AUTOREV}"

SRC_URI = "git://github.com/DynamicDevices/xm125-radar-monitor.git;protocol=https;branch=${SRCBRANCH}"

S = "${WORKDIR}/git"

# Only build for machines with XM125 radar support
COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai)"

# Check for XM125 radar feature
python () {
    machine_features = d.getVar('MACHINE_FEATURES') or ''
    if 'xm125-radar' not in machine_features:
        raise bb.parse.SkipRecipe("XM125 radar feature not enabled for this machine")
}

# Inherit cargo for Rust builds
inherit cargo

# For now, we'll use network access to download dependencies
# In production, you would generate proper crate:// URLs from Cargo.lock
# using cargo-bitbake tool or similar
do_configure[network] = "1"
do_compile[network] = "1"

# Cross-compilation setup for ARM64
CARGO_BUILD_FLAGS = "--release"

# Set up cross-compilation environment
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${CC}"
export CC_aarch64_unknown_linux_gnu = "${CC}"
export CXX_aarch64_unknown_linux_gnu = "${CXX}"

# Install the application
do_install() {
    # Install the main binary
    install -d ${D}${bindir}
    install -m 0755 ${CARGO_TARGET_SUBDIR}/xm125-radar-monitor ${D}${bindir}/
    
    # Create symlinks for backward compatibility (replacing shell scripts)
    ln -sf xm125-radar-monitor ${D}${bindir}/xm125-control
    ln -sf xm125-radar-monitor ${D}${bindir}/xm125-firmware-flash
    
    # Install configuration directory
    install -d ${D}${sysconfdir}/xm125
    
    # Install documentation
    install -d ${D}${docdir}/${PN}
    install -m 0644 ${S}/README.md ${D}${docdir}/${PN}/
    install -m 0644 ${S}/CHANGELOG.md ${D}${docdir}/${PN}/
    
    # Install example configuration if it exists
    if [ -f ${S}/config/xm125-config.toml ]; then
        install -m 0644 ${S}/config/xm125-config.toml ${D}${sysconfdir}/xm125/
    fi
}

# Package files
FILES:${PN} = " \
    ${bindir}/xm125-radar-monitor \
    ${bindir}/xm125-control \
    ${bindir}/xm125-firmware-flash \
    ${sysconfdir}/xm125/* \
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