SUMMARY = "MCUboot bootloader for MCXC444 microcontroller on imx93-jaguar-eink"
DESCRIPTION = "MCUboot is a secure bootloader for 32-bit MCUs. This recipe builds \
MCUboot specifically for the NXP MCXC444 microcontroller used on the \
imx93-jaguar-eink board for power management and system control."
HOMEPAGE = "https://mcuboot.com/"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

# MCUboot source repository
SRCREV = "v2.1.0"
SRC_URI = "git://github.com/mcu-tools/mcuboot.git;protocol=https;branch=main"

S = "${WORKDIR}/git"

# Dependencies for building MCUboot
DEPENDS = "python3-native python3-cryptography-native python3-click-native python3-cbor2-native python3-intelhex-native"

# Only build for machines that have the MCXC444 microcontroller
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

# MCUboot configuration for MCXC444
MCUBOOT_CONFIG_DIR = "${S}/boot/zephyr/boards"
MCUBOOT_BOARD = "mcxc444"

# Build configuration
EXTRA_OEMAKE = " \
    BOARD=${MCUBOOT_BOARD} \
    CONF_FILE=${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf \
"

inherit python3native

do_configure() {
    # Create MCUboot configuration for MCXC444
    cat > ${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf << EOF
# MCUboot configuration for NXP MCXC444 microcontroller
# Used on imx93-jaguar-eink board for power management

# Board configuration
CONFIG_BOARD_MCXC444=y

# MCUboot specific settings
CONFIG_MCUBOOT=y
CONFIG_BOOT_SIGNATURE_TYPE_RSA=y
CONFIG_BOOT_SIGNATURE_KEY_FILE="root-rsa-2048.pem"

# Flash configuration for MCXC444
CONFIG_FLASH=y
CONFIG_FLASH_PAGE_LAYOUT=y
CONFIG_FLASH_MAP=y

# Bootloader configuration
CONFIG_BOOT_MAX_IMG_SECTORS=128
CONFIG_BOOT_BOOTSTRAP=y

# Security features
CONFIG_BOOT_VALIDATE_SLOT0=y
CONFIG_BOOT_UPGRADE_ONLY=y

# Power management optimizations
CONFIG_PM=y
CONFIG_PM_DEVICE=y

# Serial/UART for debugging (optional)
CONFIG_SERIAL=y
CONFIG_UART_CONSOLE=y

# Size optimizations for small flash
CONFIG_SIZE_OPTIMIZATIONS=y
CONFIG_COMPILER_OPT_SIZE=y
EOF

    # Create board definition if it doesn't exist
    mkdir -p ${MCUBOOT_CONFIG_DIR}
    if [ ! -f ${MCUBOOT_CONFIG_DIR}/${MCUBOOT_BOARD}.conf ]; then
        cp ${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf ${MCUBOOT_CONFIG_DIR}/
    fi
}

do_compile() {
    cd ${S}/boot/zephyr
    
    # Build MCUboot for MCXC444
    python3 ${S}/scripts/build.py \
        --board ${MCUBOOT_BOARD} \
        --config ${WORKDIR}/mcuboot-${MCUBOOT_BOARD}.conf \
        --build-dir ${B}
}

do_install() {
    install -d ${D}${bindir}
    install -d ${D}${datadir}/mcuboot
    install -d ${D}${datadir}/mcuboot/keys
    
    # Install MCUboot binary
    if [ -f ${B}/zephyr/zephyr.bin ]; then
        install -m 0644 ${B}/zephyr/zephyr.bin ${D}${datadir}/mcuboot/mcuboot-${MCUBOOT_BOARD}.bin
    fi
    
    # Install MCUboot ELF for debugging
    if [ -f ${B}/zephyr/zephyr.elf ]; then
        install -m 0644 ${B}/zephyr/zephyr.elf ${D}${datadir}/mcuboot/mcuboot-${MCUBOOT_BOARD}.elf
    fi
    
    # Install MCUboot tools
    install -m 0755 ${S}/scripts/imgtool.py ${D}${bindir}/mcuboot-imgtool
    
    # Install signing keys (development keys - replace with production keys)
    if [ -f ${S}/root-rsa-2048.pem ]; then
        install -m 0600 ${S}/root-rsa-2048.pem ${D}${datadir}/mcuboot/keys/
    fi
    
    # Create wrapper script for easy MCUboot operations
    cat > ${D}${bindir}/mcuboot-mcxc444 << 'EOF'
#!/bin/bash
# MCUboot wrapper script for MCXC444 microcontroller
# Usage: mcuboot-mcxc444 <command> [options]

MCUBOOT_DIR="/usr/share/mcuboot"
MCUBOOT_BIN="$MCUBOOT_DIR/mcuboot-mcxc444.bin"
IMGTOOL="/usr/bin/mcuboot-imgtool"

case "$1" in
    "sign")
        echo "Signing Zephyr application for MCXC444..."
        $IMGTOOL sign --key $MCUBOOT_DIR/keys/root-rsa-2048.pem \
                     --header-size 0x200 \
                     --align 4 \
                     --version 1.0.0 \
                     --slot-size 0x20000 \
                     "$2" "$3"
        ;;
    "flash")
        echo "Flashing MCUboot to MCXC444..."
        echo "Use your preferred programming tool to flash: $MCUBOOT_BIN"
        ;;
    "info")
        echo "MCUboot for MCXC444 microcontroller"
        echo "Bootloader: $MCUBOOT_BIN"
        echo "Tools: $IMGTOOL"
        ;;
    *)
        echo "Usage: mcuboot-mcxc444 {sign|flash|info}"
        echo "  sign <input.bin> <output.bin> - Sign Zephyr application"
        echo "  flash                         - Flash MCUboot bootloader"
        echo "  info                          - Show MCUboot information"
        ;;
esac
EOF
    chmod +x ${D}${bindir}/mcuboot-mcxc444
}

FILES:${PN} = " \
    ${bindir}/mcuboot-imgtool \
    ${bindir}/mcuboot-mcxc444 \
    ${datadir}/mcuboot/mcuboot-${MCUBOOT_BOARD}.bin \
    ${datadir}/mcuboot/mcuboot-${MCUBOOT_BOARD}.elf \
    ${datadir}/mcuboot/keys/root-rsa-2048.pem \
"

FILES:${PN}-dev = "${datadir}/mcuboot/*.elf"

RDEPENDS:${PN} = "python3-core python3-cryptography python3-click python3-cbor2 python3-intelhex"

# Package information
PACKAGE_ARCH = "${MACHINE_ARCH}"
