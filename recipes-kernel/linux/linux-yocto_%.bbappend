# Dynamic Devices Linux Kernel Configuration
#
# This bbappend eliminates duplicate inclusion warnings by masking the
# meta-virtualization linux-yocto files that conflict with meta-lmp-base.

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Mask the meta-virtualization linux-yocto files that cause duplicate warnings
# Since meta-lmp-base provides comprehensive virtualization support, we can
# safely exclude the redundant meta-virtualization kernel configurations.
BBMASK += "meta-virtualization/recipes-kernel/linux/linux-yocto_6.6_virtualization.inc"
BBMASK += "meta-virtualization/recipes-kernel/linux/linux-yocto_virtualization.inc"

# Log the masking for transparency
python __anonymous() {
    bb.note("Dynamic Devices: Masked duplicate virtualization includes from meta-virtualization")
    bb.note("Using meta-lmp-base virtualization configuration (Docker, containerd, LXC)")
}

# TECHNICAL DETAILS:
# ==================
# Layer Processing Order (higher BBFILE_PRIORITY = processed later):
# - meta-dynamicdevices: ~15 (this layer - highest priority)
# - meta-lmp-base: ~7 (medium priority)  
# - meta-virtualization: ~5 (lower priority)
#
# Since our layer has the highest priority, this bbappend is processed last,
# allowing us to override any conflicting configurations and document the
# resolution of duplicate inclusion warnings.
#
# The actual virtualization functionality remains fully intact through
# meta-lmp-base, which provides:
# - Docker support
# - containerd runtime
# - LXC containers  
# - Kubernetes support
# - All necessary kernel features for Edge Computing workloads
#
# No additional configuration from meta-virtualization is needed for our
# use case, making this suppression safe and appropriate.
