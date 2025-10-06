SUMMARY = "E-ink Power Management CLI Tool"
DESCRIPTION = "Rust-based command-line interface for controlling the MCXC143VFM power \
management microcontroller on imx93-jaguar-eink board. Provides battery monitoring, \
power sequencing, and system control capabilities."

HOMEPAGE = "https://github.com/DynamicDevices/eink-power-cli"
SECTION = "console/utils"
AUTHOR = "Alex J Lennon <ajlennon@dynamicdevices.co.uk>"

LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

# Only install on imx93-jaguar-eink machine
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

SRCBRANCH = "main"
SRCREV = "${AUTOREV}"
PV = "0.1.0+git${SRCPV}"

SRC_URI = "git://github.com/DynamicDevices/eink-power-cli.git;protocol=https;branch=${SRCBRANCH}"

S = "${WORKDIR}/git"

# Runtime dependencies for serial communication and Rust runtime
RDEPENDS:${PN} = "libgcc coreutils"

inherit cargo_bin

# Enable network for the compile task allowing cargo to download dependencies
do_compile[network] = "1"

# Fix buildpaths QA warnings by ensuring debug prefix mapping is applied to Rust builds
RUSTFLAGS:append = " --remap-path-prefix=${WORKDIR}=/usr/src/debug/${PN}/${PV}"
RUSTFLAGS:append = " --remap-path-prefix=${TMPDIR}=/usr/src/debug/tmpdir"

# Skip QA check for already-stripped - Rust release binaries are pre-stripped
INSANE_SKIP:${PN} += "already-stripped"

# Installation
do_install() {
    install -d ${D}${bindir}
    
    # cargo_bin class builds to ${B}/${RUST_TARGET}/release/ for release profile
    # where B = ${WORKDIR}/target and RUST_TARGET = aarch64-unknown-linux-gnu
    install -m 755 ${B}/${RUST_TARGET}/release/eink-power-cli ${D}${bindir}/eink-power-cli
    
    # Create symlink for convenience
    ln -sf eink-power-cli ${D}${bindir}/eink-pmu
    
    # Install example configuration if it exists
    if [ -f ${S}/examples/eink-power-cli.toml ]; then
        install -d ${D}${sysconfdir}
        install -m 644 ${S}/examples/eink-power-cli.toml ${D}${sysconfdir}/eink-power-cli.toml
    fi
}

FILES:${PN} = " \
    ${bindir}/eink-power-cli \
    ${bindir}/eink-pmu \
    ${sysconfdir}/eink-power-cli.toml \
"

# Package description
PACKAGE_ARCH = "${MACHINE_ARCH}"
