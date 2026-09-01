# Jaguar Screen boot splash

## Intended sequence

1. U-Boot keeps its text console on `ttymxc1`.
2. U-Boot initializes the ST1010B3CYOL / HX8279-D panel at its native
   1200x1920 scanout and displays the pre-rotated Active-Edge BMP from the boot
   filesystem.
3. Linux boots quietly with `fbcon` mapped away from `fb0`, preserving the
   splash until DRM takes over.
4. `screen-splash` redraws the same canonical artwork once Linux DRM is ready
   and releases DRM master for the product UI.

## Live Linux evidence (target 2796, 2026-09-01)

- Connector: `card0-DSI-1`, connected, mode `1200x1920`.
- Driver: `panel-boe-himax8279d`, compatible `santek,st1010b3cyol`.
- Proven timing reported by the running driver: pixel clock 159420 kHz;
  horizontal front/back/sync 80/60/24; vertical front/back/sync 10/14/4.
- Four-lane RGB888 scanout, panel load-switch sequencing and GPIO backlight
  produce clean colour, grayscale and geometry frames.
- FT5626 binds through `edt_ft5x06` as `/dev/input/event1`.
- The apparent display corruption was `fbcon` drawing repeated kernel
  `martian source` messages over the raw framebuffer. Detaching `fbcon`
  produced a clean stable image.

## Implementation status

This increment supplies the quiet Linux hand-off, mounting orientation,
24-bit native BMP deployment, U-Boot video configuration, and non-fatal
`boot.cmd` loading/display path.

The remaining prerequisite for bench-visible U-Boot output is a U-Boot panel
driver for `santek,st1010b3cyol`. NXP U-Boot 2024.04 already contains the
i.MX8MM LCDIF, Samsung SEC DSIM, video and BMP infrastructure, but its EVK
configuration only includes the Raydium RM67191/RM67199 panel driver. The new
driver must port the proven HX8279-D vendor register sequence and the live
159420 kHz timing above, treat GPIO1_IO12 as a load-switch enable rather than
a reset, and turn on GPIO1_IO01 only after DSI initialization.

Do not flash a bootloader until that driver builds in the factory configuration
and the resulting bootloader is tested first through the i.MX8MM recovery path.
