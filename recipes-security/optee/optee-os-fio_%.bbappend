# Disable SE050 debug output for production builds
# This prevents verbose SE050 information from being displayed during boot

# Disable SE050 display info for imx8mm-jaguar-sentai (production builds)
EXTRA_OEMAKE:append:imx8mm-jaguar-sentai = " CFG_CORE_SE05X_DISPLAY_INFO=0"

# Disable SE050 display info for imx8mm-jaguar-inst (production builds)  
EXTRA_OEMAKE:append:imx8mm-jaguar-inst = " CFG_CORE_SE05X_DISPLAY_INFO=0"

# Reduce OP-TEE core log level for production builds (keep functionality, reduce verbosity)
EXTRA_OEMAKE:append:imx8mm-jaguar-sentai = " CFG_TEE_CORE_LOG_LEVEL=1"
EXTRA_OEMAKE:append:imx8mm-jaguar-inst = " CFG_TEE_CORE_LOG_LEVEL=1"
