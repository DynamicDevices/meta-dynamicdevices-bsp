SUMMARY = "Spectra 6 E-Ink Display Userspace Library and Test Tools"
DESCRIPTION = "Userspace library and test applications for the Spectra 6 EL133UF1 E-Ink display. \
Provides SPI communication interface, display control functions, and comprehensive test utilities for \
13.3-inch E-Ink displays with 6-color Spectra technology. Features enhanced controller validation \
with multiple register testing (STATUS, REVISION, VCOM, temperature sensor), resolution verification, \
and detailed debugging capabilities for hardware verification and troubleshooting."
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

# Skip this recipe entirely if the machine doesn't have el133uf1 feature
# This prevents parsing errors when building for machines that don't need E-Ink support
python __anonymous() {
    machine_features = d.getVar('MACHINE_FEATURES') or ''
    if 'el133uf1' not in machine_features:
        raise bb.parse.SkipRecipe("eink-spectra6 recipe skipped - machine does not have el133uf1 feature")
}

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

# Linker flags to help find libgpiod
TARGET_LDFLAGS += "-L${STAGING_LIBDIR} -lgpiod"

# Installation paths and configuration
EXTRA_OECMAKE = " \
    -DCMAKE_INSTALL_PREFIX=${prefix} \
    -DCMAKE_INSTALL_BINDIR=${bindir} \
    -DCMAKE_INSTALL_LIBDIR=${libdir} \
    -DCMAKE_INSTALL_INCLUDEDIR=${includedir} \
    -DCMAKE_PREFIX_PATH=${STAGING_DIR_HOST}${prefix} \
    -DCMAKE_FIND_ROOT_PATH=${STAGING_DIR_HOST} \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=ON \
    -Dlibgpiod_DIR=${STAGING_LIBDIR}/cmake \
    -DGPIOD_LIBRARY=${STAGING_LIBDIR}/libgpiod.so \
    -DGPIOD_INCLUDE_DIR=${STAGING_INCDIR} \
"

# CMake configuration is handled automatically by the cmake class

# Add debugging and library path configuration for libgpiod
do_configure:prepend() {
    # Ensure libgpiod can be found during CMake configuration
    export PKG_CONFIG_PATH="${STAGING_LIBDIR}/pkgconfig:${PKG_CONFIG_PATH}"
    export CMAKE_LIBRARY_PATH="${STAGING_LIBDIR}"
    export CMAKE_INCLUDE_PATH="${STAGING_INCDIR}"
    export LDFLAGS="${LDFLAGS} -L${STAGING_LIBDIR} -lgpiod"
    
    # Debug: List available libraries
    echo "=== DEBUG: Available libgpiod files ==="
    find ${STAGING_DIR_HOST} -name "*gpiod*" -type f 2>/dev/null || true
    echo "=== DEBUG: PKG_CONFIG_PATH ==="
    echo "${PKG_CONFIG_PATH}"
    echo "=== DEBUG: STAGING_LIBDIR ==="
    ls -la ${STAGING_LIBDIR}/*gpiod* 2>/dev/null || echo "No libgpiod files found in STAGING_LIBDIR"
    echo "=== DEBUG: LDFLAGS ==="
    echo "${LDFLAGS}"
    echo "=== DEBUG: CMAKE variables ==="
    echo "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}"
    echo "CMAKE_LIBRARY_PATH: ${CMAKE_LIBRARY_PATH}"
    echo "CMAKE_INCLUDE_PATH: ${CMAKE_INCLUDE_PATH}"
}

# Debug the compile step to see what ninja is actually trying to build
do_compile:prepend() {
    echo "=== DEBUG: Ninja build files ==="
    find ${B} -name "*.ninja" -exec echo "File: {}" \; -exec head -20 {} \; 2>/dev/null || true
    echo "=== DEBUG: CMake cache ==="
    if [ -f "${B}/CMakeCache.txt" ]; then
        grep -i gpiod ${B}/CMakeCache.txt || echo "No gpiod entries in CMakeCache.txt"
    fi
    
    # Try to create a symbolic link to libgpiod.so in the build directory
    # This is a workaround for CMake configurations that expect the library as a build artifact
    if [ -f "${STAGING_LIBDIR}/libgpiod.so" ]; then
        echo "=== DEBUG: Creating libgpiod.so symlink in build directory ==="
        ln -sf "${STAGING_LIBDIR}/libgpiod.so" "${B}/libgpiod.so" || true
        ls -la "${B}/libgpiod.so" || echo "Failed to create symlink"
    else
        echo "=== DEBUG: libgpiod.so not found in ${STAGING_LIBDIR} ==="
        ls -la ${STAGING_LIBDIR}/libgpiod* 2>/dev/null || echo "No libgpiod files found"
    fi
}

do_install:append() {
    # Install documentation files
    install -d ${D}${datadir}/doc/${PN}
    if [ -f "${S}/README.md" ]; then
        install -m 644 ${S}/README.md ${D}${datadir}/doc/${PN}/
    fi
    if [ -f "${S}/VALIDATION_ENHANCEMENTS.md" ]; then
        install -m 644 ${S}/VALIDATION_ENHANCEMENTS.md ${D}${datadir}/doc/${PN}/
    fi
    if [ -f "${S}/BOARD_CONFIGURATION.md" ]; then
        install -m 644 ${S}/BOARD_CONFIGURATION.md ${D}${datadir}/doc/${PN}/
    fi
    if [ -f "${S}/GETTING_STARTED.md" ]; then
        install -m 644 ${S}/GETTING_STARTED.md ${D}${datadir}/doc/${PN}/
    fi
    if [ -f "${S}/PROJECT_CONTEXT.md" ]; then
        install -m 644 ${S}/PROJECT_CONTEXT.md ${D}${datadir}/doc/${PN}/
    fi
    if [ -d "${S}/docs" ]; then
        cp -r ${S}/docs/* ${D}${datadir}/doc/${PN}/
    fi
    
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
