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

The Linux renderer rotates the landscape source counter-clockwise into native
panel scanout, matching the physical hwlab mounting proven by webcam. Its first
300 ms and the 800 ms rest at the end of every loop are
pixel-identical to the U-Boot BMP. The animation changes only saturated pixels
inside the edge mark: opposing glints run along the outer arcs while the inner
mark, lockup, background and typography remain static. Glints are limited to
high-intensity interior colour
pixels and use squared easing before the endpoints, preserving the mark's
silhouette and removing the apparent widen/snap at the loop boundary.
There is no video decoder or compositor dependency during boot. The process
writes its already-scanned-out dumb buffer after dropping DRM master, polls for
the UI's replacement framebuffer, and exits as soon as that handoff occurs.
Frames use an absolute 30 fps monotonic schedule so rendering time does not
accumulate as cadence drift. The renderer skips the static centre and rest
period, uses a bounded arithmetic glint profile rather than a per-pixel
exponential, and checks UI takeover independently at approximately 100 ms.

Review media generated from the same animation routine:

- [`active-edge-boot-animation-preview.mp4`](media/active-edge-boot-animation-preview.mp4)
  — canonical 1920x1200 landscape, H.264, 30 fps, 2.4 seconds.
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
24-bit native BMP deployment, U-Boot video configuration, non-fatal
`boot.cmd` loading/display path, and a U-Boot panel driver for
`santek,st1010b3cyol`. The driver ports all 293 entries from the proven
HX8279-D vendor register sequence and the live 159420 kHz timing above. It
treats GPIO1_IO12 as a load-switch enable rather than a reset and turns on
GPIO1_IO01 only after DSI initialization.

The driver and patched control DT were compiled and linked successfully
against Foundries/NXP U-Boot 2024.04. The resulting DT selects the Santek
compatible with four DSI lanes, RGB888 scanout, 90-degree mounting metadata,
GPIO1_IO12 panel power, and GPIO1_IO01 backlight.

The next gate is the factory Yocto build. Do not flash its bootloader until the
generated artifacts have passed recipe/config inspection and the i.MX8MM
recovery path is ready.
