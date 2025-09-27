# CRITICAL FIX: Override upstream LMP mfgtool-files recipe
# 
# Problem: Upstream meta-lmp-bsp/recipes-support/mfgtool-files/mfgtool-files_%.bbappend
# copies production imx-boot as mfgtool bootloader for mx93-nxp-bsp machines.
# This breaks mfgtool programming because production bootloader has optimizations
# that prevent proper bootstrap functionality.
#
# Solution: Override the problematic do_deploy:prepend:mx93-nxp-bsp function
# to do nothing for our imx93-jaguar-eink machine, allowing Foundries.io
# to use the default mfgtool bootloader generation.

# Override the upstream function that copies production bootloader as mfgtool
# Use machine-specific override with higher precedence than mx93-nxp-bsp
do_deploy:prepend:imx93-jaguar-eink() {
    # Do nothing - let Foundries.io generate proper mfgtool bootloader
    # This prevents copying production imx-boot as imx-boot-mfgtool
    bbwarn "imx93-jaguar-eink: Overriding mfgtool deploy - using default mfgtool generation instead of production bootloader"
}
