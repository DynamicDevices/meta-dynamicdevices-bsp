# LmP uses optee-os-fio (virtual/optee-os) but meta-imx packagegroup-fsl-optee-imx
# RDEPENDS on the optee-os package name.
RPROVIDES:${PN} += "optee-os"

# Foundries optee-os-fio-bsp.inc maps imx93 EVK only; i.MX95 uses NXP imx-mx95evk platform.
OPTEEMACHINE:mx95-nxp-bsp = "imx-mx95evk"
OPTEEMACHINE:imx95-frdm-evk = "imx-mx95evk"
OPTEEMACHINE:imx95-15x15-lpddr4x-frdm = "imx-mx95evk"
