# The Jaguar Screen has a product-owned U-Boot -> DRM splash handoff.
# Do not insert the Foundries/psplash artwork between those two stages.
SYSTEMD_AUTO_ENABLE:${PN}:imx8mm-jaguar-screen = "disable"
