# TI TAC5x1x family (e.g. TAC5301-Q1 cabin loop on DT510 &sai6 @ I2C 0x50).
#
# Two mutually exclusive driver stacks — pick ONE per machine image:
#
#   tac5x1x-audio (default on imx8mm-jaguar-dt510)
#     Lore/linux-sound patch series baked into linux-lmp-fslc-imx (MFD + pinctrl + ASoC).
#     See tac5x1x-lmp/tac5x1x-lmp.cfg and linux-lmp-fslc-imx_%.bbappend.
#
#   tac5x1x-ti-audio (experimental)
#     TI out-of-tree snd-soc-tac5x1x from git.ti.com lpaa-android-drivers/tac5x1x-linux-driver
#     (recipe kernel-module-tac5x1x-ti). In-kernel Lore symbols disabled via tac5x1x-lmp-disable-ikernel.cfg.
#     Switch example:
#       MACHINE_FEATURES:remove:imx8mm-jaguar-dt510 = " tac5x1x-audio"
#       MACHINE_FEATURES:append:imx8mm-jaguar-dt510 = " tac5x1x-ti-audio"
#
# Driver mic TAA5412 @ 0x51 is separate — see conf/machine/include/taa5412.inc:
#   taa5412 (default) → pcm6240 in-kernel; taa5412-tac5x1x-ti → snd-soc-tac5x1x-taa5412 OOT @ 0x51 only.
# Do not enable tac5x1x-ti-audio (global TI OOT for cabin loop) on DT510 — use tac5x1x-audio (Lore) +
# taa5412-tac5x1x-ti for the split-stack layout.
#
# Lore / Patchwork tracking (in-kernel path):
#   - Thread: linux-sound, subject "[PATCH v1 0/8] ASoC: support TI's TAC5x1x audio codec family"
#   - yhbt mirror: https://yhbt.net/lore/linux-sound/20260312184833.263-1-niranjan.hy@ti.com/
#
# When the Lore series merges upstream, drop local patches and pin a kernel that
# ships CONFIG_MFD_TAC5X1X / CONFIG_PINCTRL_TI_TAC5X1X / CONFIG_SND_SOC_TAC5X1X.

# bbappend helpers (linux-lmp-fslc-imx_%.bbappend)
TAC5X1X_USE_LORE_IKERNEL = "${@'1' if bb.utils.contains('MACHINE_FEATURES', 'tac5x1x-audio', True, False, d) and not bb.utils.contains('MACHINE_FEATURES', 'tac5x1x-ti-audio', True, False, d) else '0'}"
TAC5X1X_USE_TI_OOT = "${@'1' if bb.utils.contains('MACHINE_FEATURES', 'tac5x1x-ti-audio', True, False, d) else '0'}"

MACHINE_EXTRA_RDEPENDS:append = " \
    ${@'kernel-module-tac5x1x-ti' if d.getVar('TAC5X1X_USE_TI_OOT') == '1' else ''} \
"

KERNEL_MODULE_AUTOLOAD:append = " \
    ${@' snd-soc-tac5x1x' if d.getVar('TAC5X1X_USE_TI_OOT') == '1' else ''} \
"

python tac5x1x_mutual_exclusive () {
    mf = (d.getVar('MACHINE_FEATURES') or '').split()
    if 'tac5x1x-audio' in mf and 'tac5x1x-ti-audio' in mf:
        bb.fatal('MACHINE_FEATURES: use tac5x1x-audio (Lore in-kernel) OR tac5x1x-ti-audio (TI OOT), not both')
}
