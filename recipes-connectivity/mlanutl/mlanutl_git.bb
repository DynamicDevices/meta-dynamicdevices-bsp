SUMMARY = "MLAN utility tool for NXP WiFi drivers"
DESCRIPTION = "Command-line utility (mlanutl) for configuring NXP MLAN/moal WiFi drivers including pscfg for power save and DTIM configuration"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

# Override package name to be 'mlanutl' instead of 'mlanutl-git'
PN = "mlanutl"

# Use the same repository as the WiFi driver
# Note: mlanutl is a userspace utility and works with any kernel version
# Using lf-5.15.71_2.2.0 branch (latest available)
SRC_URI = "git://github.com/nxp-imx/mwifiex-iw612.git;protocol=https;branch=lf-5.15.71_2.2.0"
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git/mapp/mlanutl"

# Build dependencies - use recipe names
DEPENDS = "libnl"

# Runtime dependencies - use actual package names
RDEPENDS:${PN} = "libnl-3-200 libnl-genl-3-200"

# Cross-compilation setup
EXTRA_OEMAKE = " \
    CC='${CC}' \
    CFLAGS='${CFLAGS} -I${STAGING_INCDIR}/libnl3' \
    LDFLAGS='${LDFLAGS} -L${STAGING_LIBDIR}' \
    LIBS='-lnl-3 -lnl-genl-3' \
"

do_compile() {
    cd ${S}
    oe_runmake clean
    oe_runmake
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/mlanutl ${D}${bindir}/
}

# Verify binary was created
do_install:append() {
    if [ ! -f ${D}${bindir}/mlanutl ]; then
        bbfatal "mlanutl binary not found after build"
    fi
}

FILES:${PN} = "${bindir}/mlanutl"
