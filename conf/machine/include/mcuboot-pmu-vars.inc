# MCU companion / PMU bootloader (MCUboot-on-Zephyr) — consumed by mcuboot_git.bb + packagegroup-mcuboot.
# Override per-machine in this file only (not in distro).

MCU_PMU_VARIANT ?= "${MACHINE}"
MCUBOOT_BOARD ?= "mcxc444"

# Kconfig basename under recipes-bsp/mcuboot/files/ (see mcuboot_git.bb SRC_URI).
MCU_PMU_KCONFIG ?= "${MCU_PMU_VARIANT}.mcuboot.kconfig"

# Optional Zephyr application package name bundled with FEATURE_mcuboot (empty = omit).
ZEPHYR_PMU_PN:imx93-jaguar-eink ?= "zephyr-mcxc444"
ZEPHYR_PMU_PN:imx8mm-jaguar-dt510 ?= ""
