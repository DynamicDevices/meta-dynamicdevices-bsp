# Extend compatibility to include Dynamic Devices i.MX93 boards
# The base recipe only supports (mx8ulp-nxp-bsp|mx9-nxp-bsp) but our 
# imx93-jaguar-eink machine inherits from mx93 which should be compatible

# Add imx93-jaguar-eink to the compatible machines list
COMPATIBLE_MACHINE:append = "|imx93-jaguar-eink"

# Ensure we have the right platform setting for i.MX93
EXTRA_OEMAKE:imx93-jaguar-eink = "PLAT=ele"
