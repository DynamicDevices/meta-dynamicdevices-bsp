# LmP uses optee-os-fio (virtual/optee-os) but meta-imx packagegroup-fsl-optee-imx
# RDEPENDS on the optee-os package name.
RPROVIDES:${PN} += "optee-os"
