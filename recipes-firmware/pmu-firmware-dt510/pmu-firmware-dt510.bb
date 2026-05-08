# Ship a placeholder DT510 companion PMU Zephyr application image until the real signed
# artifact is built in CI. Install path is stable for scripts and docs.
SUMMARY = "DT510 PMU Zephyr application firmware (placeholder binary)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://dt510-pmu-application.placeholder.bin"

S = "${WORKDIR}"

COMPATIBLE_MACHINE = "imx8mm-jaguar-dt510"
PACKAGE_ARCH = "${MACHINE_ARCH}"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${datadir}/pmu-dt510
    install -m 0644 ${WORKDIR}/dt510-pmu-application.placeholder.bin \
        ${D}${datadir}/pmu-dt510/zephyr-application.signed.placeholder.bin
}

FILES:${PN} = "${datadir}/pmu-dt510/zephyr-application.signed.placeholder.bin"
