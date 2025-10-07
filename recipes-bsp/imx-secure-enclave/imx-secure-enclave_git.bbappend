# Extend compatibility to include Dynamic Devices i.MX93 boards
# The base recipe supports (mx8ulp-nxp-bsp|mx9-nxp-bsp) and our 
# imx93-jaguar-eink machine inherits mx93 which gets mx9-nxp-bsp override

# This bbappend extends the base imx-secure-enclave recipe from meta-freescale
# The base recipe already has COMPATIBLE_MACHINE = "(mx8ulp-nxp-bsp|mx9-nxp-bsp)"
# Our imx93-jaguar-eink machine gets mx9-nxp-bsp via MACHINEOVERRIDES_EXTENDER

# Platform is already set to "ele" in base recipe for i.MX93
