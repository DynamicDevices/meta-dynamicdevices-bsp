# Jaguar Screen boot splash

## Intended sequence

1. U-Boot keeps its text console on `ttymxc1`.
2. U-Boot initializes the ST1010B3CYOL / HX8279-D panel at its native
   1200x1920 scanout and displays a pre-rotated derivative of the canonical
   1920x1200 landscape Active-Edge artwork from the boot filesystem.
3. Linux boots quietly with `fbcon` mapped away from `fb0`, preserving the
   splash until DRM takes over.
4. `screen-splash` redraws the same canonical artwork once Linux DRM is ready,
   releases DRM master immediately for the product UI, and runs a clear
   2.4-second edge-glint loop until the UI replaces its framebuffer.

The Linux renderer rotates the landscape source clockwise into native panel
scanout, matching the current physical hwlab mounting proven after the image
rebuild. The U-Boot BMP and portrait desktop derivative use that same rotation,
so no stage can independently invert the brand artwork. Its first 300 ms and
the 800 ms rest at the end of every loop are
pixel-identical to the U-Boot BMP. The animation changes only saturated pixels
inside the edge mark: opposing glints run along the outer arcs while the inner
mark, lockup, background and typography remain static. Glints are limited to
high-intensity interior colour
pixels and use squared easing before the endpoints, preserving the mark's
silhouette and removing the apparent widen/snap at the loop boundary.
There is no video decoder or compositor dependency during boot. The process
writes its already-scanned-out dumb buffer after dropping DRM master, polls for
the UI's replacement framebuffer, and exits as soon as that handoff occurs.

Review media generated from the same animation routine:

- [`active-edge-boot-animation-preview.mp4`](media/active-edge-boot-animation-preview.mp4)
  — canonical 1920x1200 landscape, H.264, 20 fps, 2.4 seconds.
- [`active-edge-boot-animation-preview.gif`](media/active-edge-boot-animation-preview.gif)
  — 960x600 looping review copy.

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
