FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Machine-specific device registration scripts
SRC_URI:append:imx8mm-jaguar-sentai = " file://imx8mm-jaguar-sentai/lmp-device-auto-register"
SRC_URI:append:imx8mm-jaguar-handheld = " file://imx8mm-jaguar-handheld/lmp-device-auto-register"
SRC_URI:append:imx8mm-jaguar-dt510 = " file://imx8mm-jaguar-dt510/lmp-device-auto-register"
SRC_URI:append:imx93-jaguar-eink = " file://imx93-jaguar-eink/lmp-device-auto-register"
SRC_URI:append:imx93-jaguar-eink-prod = " file://imx93-jaguar-eink-prod/lmp-device-auto-register"
SRC_URI:append:imx8mm-jaguar-screen = " file://imx8mm-jaguar-screen/lmp-device-auto-register-screen.service.in"

do_compile:prepend:imx8mm-jaguar-screen() {
    # Conditions are evaluated after dependencies are queued. Move the clock
    # wait into ExecStartPre so an already-registered Screen does not delay
    # multi-user.target, while first registration still requires valid time.
    install -m 0644 \
        ${WORKDIR}/imx8mm-jaguar-screen/lmp-device-auto-register-screen.service.in \
        ${WORKDIR}/lmp-device-auto-register.service.in
}

do_install:append() {
    # Install machine-specific device registration script if available
    if [ -f ${WORKDIR}/${MACHINE}/lmp-device-auto-register ]; then
        install -D -m 0755 ${WORKDIR}/${MACHINE}/lmp-device-auto-register ${D}${bindir}/lmp-device-auto-register
    fi
}
