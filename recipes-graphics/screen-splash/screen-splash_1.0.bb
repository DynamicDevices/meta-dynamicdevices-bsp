SUMMARY = "Active-Edge early DRM splash screen"
DESCRIPTION = "Displays the Active-Edge lockup as soon as the product DRM connector is ready"
LICENSE = "CLOSED"

DEPENDS = "libdrm libpng"

SRC_URI = " \
    file://screen-splash.c \
    file://screen-splash.service \
    file://active-edge-splash-1920x1200.png \
    file://active-edge-splash-1920x1080.png \
    file://active-edge-splash-1200x1920.png \
    file://active-edge-splash-1280x720.png \
"

S = "${WORKDIR}"

inherit pkgconfig systemd

SCREEN_SPLASH_IMAGE ?= "active-edge-splash-1920x1200.png"
SCREEN_SPLASH_IMAGE:imx95-frdm-evk = "active-edge-splash-1920x1080.png"

# The Type=simple service can wait for a late DRM connector without delaying
# the rest of userspace. This also covers the FRDM IT6263 probe interval.
SCREEN_SPLASH_WAIT_MS ?= "15000"

SYSTEMD_SERVICE:${PN} = "screen-splash.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_compile() {
    ${CC} ${CFLAGS} ${CPPFLAGS} `pkg-config --cflags libdrm libpng` \
        ${S}/screen-splash.c -o screen-splash \
        `pkg-config --libs libdrm libpng` -lm ${LDFLAGS}
}

do_install() {
    install -d ${D}${bindir} ${D}${datadir}/screen-splash \
        ${D}${systemd_system_unitdir}
    install -m 0755 ${B}/screen-splash ${D}${bindir}/screen-splash
    install -m 0644 ${WORKDIR}/active-edge-splash-1920x1200.png \
        ${D}${datadir}/screen-splash/active-edge-splash-1920x1200.png
    install -m 0644 ${WORKDIR}/active-edge-splash-1920x1080.png \
        ${D}${datadir}/screen-splash/active-edge-splash-1920x1080.png
    install -m 0644 ${WORKDIR}/active-edge-splash-1200x1920.png \
        ${D}${datadir}/screen-splash/active-edge-splash-1200x1920.png
    install -m 0644 ${WORKDIR}/active-edge-splash-1280x720.png \
        ${D}${datadir}/screen-splash/active-edge-splash-1280x720.png
    ln -s ${SCREEN_SPLASH_IMAGE} \
        ${D}${datadir}/screen-splash/active-edge-splash.png
    sed -e 's|@SCREEN_SPLASH_WAIT_MS@|${SCREEN_SPLASH_WAIT_MS}|g' \
        ${WORKDIR}/screen-splash.service \
        > ${D}${systemd_system_unitdir}/screen-splash.service
}

FILES:${PN} += "${datadir}/screen-splash"
