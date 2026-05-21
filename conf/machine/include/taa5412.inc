# TI TAA5412-Q1 driver mic @ I2C 0x51 (&sai5) — mutually exclusive driver stacks.
#
#   taa5412 (default on imx8mm-jaguar-dt510)
#     In-kernel snd_soc_pcm6240 backport + firmware-taa5412 regbin
#     (linux-lmp-fslc-imx pcm6240-lmp patches + pcm6240-audio-codec.cfg).
#
#   taa5412-tac5x1x-ti (experimental)
#     TI out-of-tree snd-soc-tac5x1x-taa5412 from git.ti.com lpaa-android-drivers/tac5x1x-linux-driver
#     (recipe kernel-module-tac5x1x-ti-taa5412). OF match is ti,taa5412 only — Lore in-kernel
#     snd-soc-tac5x1x @ 0x50 (MACHINE_FEATURES tac5x1x-audio) is unchanged.
#     Kernel pcm6240 backport disabled via taa5412-pcm6240-disable.cfg.
#
# Switch example (meta-subscriber-overrides/conf/layer.conf or factory subscriber):
#   MACHINE_FEATURES:remove:imx8mm-jaguar-dt510 = " taa5412"
#   MACHINE_FEATURES:append:imx8mm-jaguar-dt510 = " taa5412-tac5x1x-ti"
#
# Do NOT combine with tac5x1x-ti-audio (global TI OOT for cabin loop @ 0x50) — use tac5x1x-audio
# (Lore in-kernel) together with taa5412-tac5x1x-ti for the intended DT510 split-stack layout.

TAA5412_USE_PCM6240 = "${@'1' if bb.utils.contains('MACHINE_FEATURES', 'taa5412', True, False, d) and not bb.utils.contains('MACHINE_FEATURES', 'taa5412-tac5x1x-ti', True, False, d) else '0'}"
TAA5412_USE_TAC5X1X_TI = "${@'1' if bb.utils.contains('MACHINE_FEATURES', 'taa5412-tac5x1x-ti', True, False, d) and not bb.utils.contains('MACHINE_FEATURES', 'taa5412', True, False, d) else '0'}"

MACHINE_EXTRA_RDEPENDS:append = " \
    ${@'firmware-taa5412' if d.getVar('TAA5412_USE_PCM6240') == '1' else ''} \
    ${@'kernel-module-tac5x1x-ti-taa5412' if d.getVar('TAA5412_USE_TAC5X1X_TI') == '1' else ''} \
"

KERNEL_MODULE_AUTOLOAD:append = " \
    ${@' snd-soc-tac5x1x-taa5412' if d.getVar('TAA5412_USE_TAC5X1X_TI') == '1' else ''} \
"

python taa5412_mutual_exclusive () {
    mf = (d.getVar('MACHINE_FEATURES') or '').split()
    if 'taa5412' in mf and 'taa5412-tac5x1x-ti' in mf:
        bb.fatal('MACHINE_FEATURES: use taa5412 (pcm6240 in-kernel) OR taa5412-tac5x1x-ti (TI OOT @ 0x51), not both')
}
