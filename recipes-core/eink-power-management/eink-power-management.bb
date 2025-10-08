SUMMARY = "E-Ink Power Management Scripts for i.MX93 Jaguar E-Ink Board"
DESCRIPTION = "Power management utilities for ultra-low power E-Ink applications \
based on AN13917 power consumption measurements. Provides Deep Sleep Mode (DSM) \
support achieving 7.6mW standby power consumption."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://eink-power-setup.sh \
    file://eink-dsm-control.sh \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "bash util-linux-hwclock"

do_install() {
    # Install power management scripts
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/eink-power-setup.sh ${D}${bindir}/eink-power-setup
    install -m 0755 ${WORKDIR}/eink-dsm-control.sh ${D}${bindir}/eink-dsm-control
    
    # Create systemd service for power optimization on boot
    install -d ${D}${systemd_unitdir}/system
    
    # Create power setup service
    cat > ${D}${systemd_unitdir}/system/eink-power-setup.service << EOF
[Unit]
Description=E-Ink Power Management Setup
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=${bindir}/eink-power-setup
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create log directory
    install -d ${D}${localstatedir}/log
}

SYSTEMD_SERVICE:${PN} = "eink-power-setup.service"
SYSTEMD_AUTO_ENABLE = "enable"

inherit systemd

FILES:${PN} += " \
    ${bindir}/eink-power-setup \
    ${bindir}/eink-dsm-control \
    ${systemd_unitdir}/system/eink-power-setup.service \
"

# Package is machine-specific due to i.MX93 hardware dependencies
PACKAGE_ARCH = "${MACHINE_ARCH}"
