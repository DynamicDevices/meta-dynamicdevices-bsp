SUMMARY = "MCUboot bootloader (Zephyr) for Jaguar companion PMU/MCU"
DESCRIPTION = "Builds MCUboot for the Zephyr BOARD named in MCUBOOT_BOARD (defaults to MCXC444) and installs the \
bootloader artifact as mcuboot-${MCU_PMU_VARIANT}.bin so imx93 Jaguar E-Ink and imx8mm DT510 images do not confuse PMU binaries."

HOMEPAGE = "https://mcuboot.com/"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

SRCREV = "v2.1.0"
SRC_URI = " \
    git://github.com/mcu-tools/mcuboot.git;protocol=https;branch=main \
    file://imx93-jaguar-eink.mcuboot.kconfig \
    file://imx8mm-jaguar-dt510.mcuboot.kconfig \
"

S = "${WORKDIR}/git"

# MCU_PMU_VARIANT, MCUBOOT_BOARD, MCU_PMU_KCONFIG — defaults in conf/machine/include/mcuboot-pmu-vars.inc
COMPATIBLE_MACHINE = "(imx93-jaguar-eink|imx8mm-jaguar-dt510)"

DEPENDS = " python3-native python3-cryptography-native python3-click-native python3-cbor2-native python3-intelhex-native"

MCUBOOT_CONFIG_DIR = "${S}/boot/zephyr/boards"

EXTRA_OEMAKE = " \
    BOARD=${MCUBOOT_BOARD} \
    CONF_FILE=${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf \
"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit python3native

do_configure() {
    # Copy machine-specific Kconfig fragment (see conf/machine/include/mcuboot-pmu-vars.inc)
    if [ ! -f "${WORKDIR}/${MCU_PMU_KCONFIG}" ]; then
        bbfatal "Missing ${WORKDIR}/${MCU_PMU_KCONFIG} — check mcuboot/files/ and MCU_PMU_KCONFIG / MCU_PMU_VARIANT."
    fi
    cp "${WORKDIR}/${MCU_PMU_KCONFIG}" "${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf"

    mkdir -p ${MCUBOOT_CONFIG_DIR}
    if [ ! -f "${MCUBOOT_CONFIG_DIR}/${MCUBOOT_BOARD}.conf" ]; then
        cp "${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf" "${MCUBOOT_CONFIG_DIR}/"
    fi
}

do_compile() {
    cd "${S}/boot/zephyr"
    python3 "${S}/scripts/build.py" \
        --board ${MCUBOOT_BOARD} \
        --config "${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf" \
        --build-dir "${B}"
}

do_install() {
    install -d ${D}${bindir}
    install -d ${D}${datadir}/mcuboot
    install -d ${D}${datadir}/mcuboot/keys

    V="${MCU_PMU_VARIANT}"
    BN="mcuboot-${V}.bin"
    EN="mcuboot-${V}.elf"
    WB="mcuboot-${V}"

    if [ -f "${B}/zephyr/zephyr.bin" ]; then
        install -m 0644 "${B}/zephyr/zephyr.bin" "${D}${datadir}/mcuboot/${BN}"
    fi
    if [ -f "${B}/zephyr/zephyr.elf" ]; then
        install -m 0644 "${B}/zephyr/zephyr.elf" "${D}${datadir}/mcuboot/${EN}"
    fi

    install -m 0755 "${S}/scripts/imgtool.py" ${D}${bindir}/mcuboot-imgtool

    if [ -f "${S}/root-rsa-2048.pem" ]; then
        install -m 0600 "${S}/root-rsa-2048.pem" ${D}${datadir}/mcuboot/keys/
    fi

    # Helper: sign/flash/info for this product's bootloader filename
    cat > "${D}${bindir}/${WB}" << EOF
#!/bin/sh
# MCUboot helper — product build ${MCU_PMU_VARIANT}, Zephyr BOARD ${MCUBOOT_BOARD}
MCUBOOT_DIR="/usr/share/mcuboot"
MCUBOOT_BIN="\$MCUBOOT_DIR/${BN}"
IMGTOOL="/usr/bin/mcuboot-imgtool"
case "\$1" in
    sign)
        echo "Signing Zephyr image for ${MCU_PMU_VARIANT} (BOARD ${MCUBOOT_BOARD})..."
        \$IMGTOOL sign --key \$MCUBOOT_DIR/keys/root-rsa-2048.pem \\
            --header-size 0x200 --align 4 --version 1.0.0 --slot-size 0x20000 \\
            "\$2" "\$3"
        ;;
    flash)
        echo "Flash this PMU bootloader with your tool: \$MCUBOOT_BIN"
        ;;
    info)
        echo "MCUboot ${MCU_PMU_VARIANT} / BOARD=${MCUBOOT_BOARD} — \$MCUBOOT_BIN"
        ;;
    *)
        echo "Usage: ${WB} {sign|flash|info}"
        ;;
esac
EOF
    chmod 0755 "${D}${bindir}/${WB}"

    # Backward-compatible name on E-Ink line (historical docs / scripts).
    if [ "${MCU_PMU_VARIANT}" = "imx93-jaguar-eink" ]; then
        ln -sf "${WB}" "${D}${bindir}/mcuboot-mcxc444"
    fi
}

FILES:${PN} = " \
    ${bindir}/mcuboot-imgtool \
    ${bindir}/mcuboot-${MCU_PMU_VARIANT} \
    ${datadir}/mcuboot/mcuboot-${MCU_PMU_VARIANT}.bin \
    ${datadir}/mcuboot/mcuboot-${MCU_PMU_VARIANT}.elf \
    ${datadir}/mcuboot/keys/root-rsa-2048.pem \
"

# Legacy helper name on E-Ink (PMU == MCXC444 bring-up scripts)
FILES:${PN}:append:imx93-jaguar-eink = " ${bindir}/mcuboot-mcxc444"

FILES:${PN}-dev = "${datadir}/mcuboot/*.elf"

RDEPENDS:${PN} = "python3-core python3-cryptography python3-click python3-cbor2 python3-intelhex"

PACKAGE_ARCH = "${MACHINE_ARCH}"