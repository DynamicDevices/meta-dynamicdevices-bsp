FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

inherit lmp-signing-override

# Disable SE050 for mfgtools builds to prevent initialization errors during programming
# SE050 is only needed for production runtime, not for UUU programming operations
SRC_URI:append = " file://disable-se050.cfg"
