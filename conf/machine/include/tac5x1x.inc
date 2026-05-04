# Optional: TI TAC5x1x family (e.g. TAC5301-Q1 on DT510 &sai6) via mainline patch series.
#
# Enable on a machine with:
#   MACHINE_FEATURES:append:<machine> = " tac5x1x-audio"
#
# linux-lmp-fslc-imx_%.bbappend then pulls in tac5x1x-lmp/tac5x1x-lmp.cfg and any
# file://.../tac5x1x-lmp/patches/*.patch you add after running:
#   ./scripts/kernel-fetch-tac5x1x-lore-series.sh
# and rebasing onto the NXP 6.6 kernel tree.
#
# Lore / Patchwork tracking:
#   - Thread: linux-sound, subject "[PATCH v1 0/8] ASoC: support TI's TAC5x1x audio codec family"
#   - yhbt mirror: https://yhbt.net/lore/linux-sound/20260312184833.263-1-niranjan.hy@ti.com/
#   - Patchwork (search Message-ID or title): https://patchwork.kernel.org/project/linux-sound/list/
#
# When the series merges upstream, drop local patches and pin a kernel that
# ships CONFIG_MFD_TAC5X1X / CONFIG_PINCTRL_TI_TAC5X1X / CONFIG_SND_SOC_TAC5X1X.
