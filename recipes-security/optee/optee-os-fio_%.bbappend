# Reduce OP-TEE log level for production builds
# This reduces boot log verbosity while maintaining functionality

# Reduce OP-TEE core log level for production builds
EXTRA_OEMAKE:append:imx8mm-jaguar-sentai = " CFG_TEE_CORE_LOG_LEVEL=1"
EXTRA_OEMAKE:append:imx8mm-jaguar-inst = " CFG_TEE_CORE_LOG_LEVEL=1"
