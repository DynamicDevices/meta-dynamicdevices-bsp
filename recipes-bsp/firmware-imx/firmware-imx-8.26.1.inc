# Copyright (C) 2012-2016 Freescale Semiconductor
# Copyright 2017-2024 NXP
# Copyright (C) 2018 O.S. Systems Software LTDA.
SECTION = "base"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://COPYING;md5=bc649096ad3928ec06a8713b8d787eac"

# Note: This .inc file is used from differently named recipes, so the package
# name must be hard-coded, i.e., ${BPN} cannot be used.
SRC_URI = "${FSL_MIRROR}/firmware-imx-${PV}-${IMX_SRCREV_ABBREV}.bin;fsl-eula=true"
IMX_SRCREV_ABBREV = "410be01"
SRC_URI[sha256sum] = "0c2e2136c1efa544409017f14f07a1412cf8c1702075ed0e4060e903b91fe313"

S = "${WORKDIR}/firmware-imx-${PV}-${IMX_SRCREV_ABBREV}"

inherit fsl-eula-unpack

# This LmP branch predates NXP's v63 software licence. Keep the compatibility
# allowance scoped to this firmware release while retaining checksum validation.
FSL_EULA_FILE_MD5SUM_LA_OPT_NXP_SOFTWARE_LICENSE_V63 = "bc649096ad3928ec06a8713b8d787eac"
FSL_EULA_FILE_MD5SUMS += "${FSL_EULA_FILE_MD5SUM_LA_OPT_NXP_SOFTWARE_LICENSE_V63}"
