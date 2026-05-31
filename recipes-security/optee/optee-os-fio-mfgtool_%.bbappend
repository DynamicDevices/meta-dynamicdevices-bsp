# packagegroup-fsl-optee-imx RDEPENDS on optee-os by name; mfgtool uses optee-os-fio-mfgtool.
RPROVIDES:${PN} += "optee-os"

# Foundries optee-os-fio-bsp-mfgtool.inc has no mx95 platform yet.
OPTEEMACHINE:mx95-nxp-bsp = "imx-mx95evk"
OPTEEMACHINE:imx95-frdm-evk = "imx-mx95evk"
OPTEEMACHINE:imx95-15x15-lpddr4x-frdm = "imx-mx95evk"

EXTRA_OEMAKE:append:mx95-nxp-bsp = " \
    CFG_DT=y CFG_EXTERNAL_DTB_OVERLAY=y CFG_DT_ADDR=0x83200000 \
"
