SUMMARY = "Spectra 6 E-Ink Display Userspace Library and Test Tools"
DESCRIPTION = "Userspace library and test applications for the Spectra 6 EL133UF1 E-Ink display. \
Provides SPI communication interface, display control functions, and test utilities for \
13.3-inch E-Ink displays with 6-color Spectra technology."
HOMEPAGE = "https://github.com/DynamicDevices/eink-spectra6"
SECTION = "libs"
AUTHOR = "Dynamic Devices Ltd"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=cb0cf33e845d3825f950a15416b1b7d6"

SRCBRANCH = "main"
SRC_URI = "git://git@github.com/DynamicDevices/eink-spectra6.git;protocol=ssh;branch=${SRCBRANCH}"

# Private repository - requires SSH key access
# Ensure SSH agent forwarding or SSH keys are available in build environment
BB_GENERATE_MIRROR_TARBALLS = "0"

# Private repository access handled via kas-container --ssh-agent --ssh-dir options

# Modify these as desired
PV = "1.0+git${SRCPV}"
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git"

# Dependencies for E-Ink display functionality
# libgpiod re-enabled with upstream compatibility layer for v1.x/v2.x APIs
DEPENDS = "virtual/libc libgpiod pkgconfig-native cmake-native"
RDEPENDS:${PN} = "bash libgpiod"

# Use CMake build system
inherit cmake

# For SPI device access permissions
inherit systemd

# Machine feature-based configuration - only build for machines with EL133UF1 display
COMPATIBLE_MACHINE = "${@bb.utils.contains('MACHINE_FEATURES', 'el133uf1', '${MACHINE}', 'null', d)}"

# Compiler flags for embedded systems
TARGET_CFLAGS += "-O2 -g"
TARGET_CXXFLAGS += "-O2 -g"

# Installation paths and configuration
EXTRA_OECMAKE = " \
    -DCMAKE_INSTALL_PREFIX=${prefix} \
    -DCMAKE_INSTALL_BINDIR=${bindir} \
    -DCMAKE_INSTALL_LIBDIR=${libdir} \
    -DCMAKE_INSTALL_INCLUDEDIR=${includedir} \
"

# CMake configuration is handled automatically by the cmake class

do_install:append() {
    # Install any additional files like examples, configs, or systemd services
    if [ -d "${S}/examples" ]; then
        install -d ${D}${datadir}/${PN}/examples
        cp -r ${S}/examples/* ${D}${datadir}/${PN}/examples/
    fi
    
    if [ -d "${S}/config" ]; then
        install -d ${D}${sysconfdir}/${PN}
        install -m 0644 ${S}/config/* ${D}${sysconfdir}/${PN}/
    fi
    
    # Install systemd service if present
    if [ -f "${S}/systemd/${PN}.service" ]; then
        install -d ${D}${systemd_system_unitdir}
        install -m 0644 ${S}/systemd/${PN}.service ${D}${systemd_system_unitdir}/
    fi
}

# Package configuration
PACKAGES = "${PN} ${PN}-dev ${PN}-staticdev ${PN}-dbg ${PN}-examples ${PN}-doc"

FILES:${PN} = " \
    ${bindir}/* \
    ${libdir}/lib*.so.* \
    ${libdir}/lib*.so \
    ${sysconfdir}/${PN}/* \
    ${systemd_system_unitdir}/${PN}.service \
"

FILES:${PN}-dev = " \
    ${includedir}/* \
    ${libdir}/pkgconfig/* \
"

FILES:${PN}-staticdev = " \
    ${libdir}/lib*.a \
"

FILES:${PN}-examples = " \
    ${datadir}/${PN}/examples/* \
"

FILES:${PN}-doc = " \
    ${datadir}/doc/* \
"

# Systemd service configuration
SYSTEMD_SERVICE:${PN} = "${@bb.utils.contains('SRC_URI', '.service', '${PN}.service', '', d)}"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

# Runtime dependencies for E-Ink display functionality
# Note: spidev is built into kernel, spidev-test provides userspace testing tools
RDEPENDS:${PN} += "${@bb.utils.contains('MACHINE_FEATURES', 'el133uf1', 'spidev-test', '', d)}"

# QA Skip explanations:
# - dev-so: Development libraries are intentionally included for testing
# - build-deps: libgpiod is runtime-only dependency, not needed at build time
INSANE_SKIP:${PN} = "dev-so build-deps"
