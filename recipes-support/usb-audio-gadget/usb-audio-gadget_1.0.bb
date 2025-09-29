SUMMARY = "USB Audio Gadget setup utilities for imx8mm-jaguar-sentai"
DESCRIPTION = "Scripts and configuration for setting up USB Audio Class gadget functionality"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://setup-usb-audio-gadget.sh"

S = "${WORKDIR}"

RDEPENDS:${PN} = ""

# Only install on machines with USB audio gadget support
COMPATIBLE_MACHINE = "imx8mm-jaguar-sentai"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/setup-usb-audio-gadget.sh ${D}${bindir}/setup-usb-audio-gadget
    
    install -d ${D}${systemd_system_unitdir}
    
    cat > ${D}${systemd_system_unitdir}/usb-audio-gadget.service << EOF
[Unit]
Description=USB Audio Gadget Setup
After=sys-kernel-config.mount
Requires=sys-kernel-config.mount
ConditionPathExists=/sys/kernel/config

[Service]
Type=oneshot
ExecStart=${bindir}/setup-usb-audio-gadget setup
ExecStop=${bindir}/setup-usb-audio-gadget stop
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

FILES:${PN} = "${bindir}/setup-usb-audio-gadget ${systemd_system_unitdir}/usb-audio-gadget.service"

inherit systemd

SYSTEMD_SERVICE:${PN} = "usb-audio-gadget.service"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

# Package is machine-specific
PACKAGE_ARCH = "${MACHINE_ARCH}"
