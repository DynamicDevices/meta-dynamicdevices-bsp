# LMP factory specific customizations (either replace or extend options as defined by meta-lmp)

# kernel modules signing key
MODSIGN_KEY_DIR = "${TOPDIR}/conf/factory-keys"
MODSIGN_PRIVKEY = "${MODSIGN_KEY_DIR}/privkey_modsign.pem"
MODSIGN_X509 = "${MODSIGN_KEY_DIR}/x509_modsign.crt"

# U-Boot signing key
UBOOT_SIGN_KEYDIR = "${TOPDIR}/conf/factory-keys"
UBOOT_SIGN_KEYNAME = "ubootdev"

# OP-TEE TA signing key (factory production). optee-os-fio adds TA_SIGN_KEY to OE make
# when this is non-empty; meta-lmp does not honor OPTEE_TA_SIGN_ENABLE. Unset only for
# LOCAL_DEVELOPMENT_BUILD (KAS/local smoke) so builds without factory-keys/opteedev.key
# succeed. Foundries may set DEV_MODE=1 without LOCAL_DEVELOPMENT_BUILD — keep factory key.
OPTEE_TA_SIGN_KEY = "${@'' if (d.getVar('LOCAL_DEVELOPMENT_BUILD') or '0') == '1' else (d.getVar('TOPDIR') + '/conf/factory-keys/opteedev.key')}"

# SPL / U-Boot proper signing key
UBOOT_SPL_SIGN_KEYDIR = "${TOPDIR}/conf/factory-keys"
UBOOT_SPL_SIGN_KEYNAME = "spldev"

# UEFI keys and certificates
UEFI_SIGN_KEYDIR = "${TOPDIR}/conf/factory-keys/uefi"

# TF-A Trusted Boot
TF_A_SIGN_KEY_PATH = "${TOPDIR}/conf/factory-keys/tf-a/privkey_ec_prime256v1.pem"

# Use custom DTS handling
PREFERRED_PROVIDER_virtual/dtb ?= "lmp-device-tree"

PACKAGECONFIG:append:pn-networkmanager:imx8mm-jaguar-sentai = " modemmanager ppp"
PACKAGECONFIG:append:pn-networkmanager:imx93-jaguar-eink = " modemmanager ppp"

# Support SE050 (disabled for local development builds)
SE05X_OEFID:imx8mm-jaguar-sentai = "0xA1F4"
MACHINE_FEATURES:append:imx8mm-jaguar-sentai = "${@'' if d.getVar('LOCAL_DEVELOPMENT_BUILD') == '1' else ' se05x'}"

SE05X_OEFID:imx8mm-jaguar-inst = "0xA1F4"
MACHINE_FEATURES:append:imx8mm-jaguar-inst = "${@'' if d.getVar('LOCAL_DEVELOPMENT_BUILD') == '1' else ' se05x'}"

# When a new bootloader is used, e.g. moving to a new LMP up-rev here
LMP_BOOT_FIRMWARE_VERSION:imx8mm-jaguar-sentai = "2"
