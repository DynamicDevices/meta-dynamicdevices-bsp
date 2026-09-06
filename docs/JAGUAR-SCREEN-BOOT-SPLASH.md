# Jaguar Screen boot splash

## Intended sequence

1. U-Boot keeps its text console on `ttymxc1`.
2. U-Boot initializes the ST1010B3CYOL / HX8279-D panel at its native
   1200x1920 scanout and displays a pre-rotated derivative of the canonical
   1920x1200 landscape Active-Edge artwork from the boot filesystem.
3. Linux boots without `tty1` or framebuffer-console support, so kernel and
   getty text can never bind to the product display.
4. `screen-splash` redraws the same canonical artwork once Linux DRM is ready,
   releases DRM master immediately for the product UI, and runs a clear
   2.4-second edge-glint loop until the UI replaces its framebuffer.

The Linux renderer rotates the landscape source counter-clockwise into native
panel scanout, matching the U-Boot BMP and portrait desktop derivative. This
direction is proved by pixel comparison against the deployed U-Boot frame,
so no stage can independently invert the brand artwork. Its first
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

## U-Boot evidence (target 2868, 2026-09-05)

- Boot firmware `2026090508` displays the 1200x1920 24-bpp derivative from
  FAT `mmc 2:1` in both the manual and automatic boot-script paths.
- The installed BMP is 6,912,054 bytes with CRC32 `5f68ed83` and SHA-256
  `d7f04f12b61990c0edf45efbdc5392808925b3c01264349642545dd5eef380d0`.
- Bench recording proves the artwork is upright and stable in U-Boot.
- The same recording also proves the remaining handoff fault: U-Boot removes
  and resets LCDIF at OS prepare, Linux creates a new DRM framebuffer, and the
  deployed kernel attaches fbcon before a late userspace unbind can run.

## Product boot delay and debug hotpatch

The compiled Screen default is `bootdelay=0`. A lab session can temporarily
restore an interruptible countdown from Linux after first recording the current
environment:

```sh
sudo fw_printenv bootdelay
sudo fw_setenv bootdelay 3
```

Return the board to product behaviour after debugging:

```sh
sudo fw_setenv bootdelay 0
```

This changes only the persistent `bootdelay` variable; it does not replace
`bootcmd`, erase the environment, or touch boot firmware.

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

The early renderer scans all DRM cards and selects one that has a connected
connector and usable CRTC; it does not assume `card0` is the display when a
separate GPU DRM device is present.

U-Boot now leaves LCDIF running at OS prepare and passes its live framebuffer
to Linux as a reserved `simple-framebuffer`. Linux `simpledrm` holds that exact
frame while the native LCDIF/DSI driver probes. When that firmware framebuffer
is present, the native drivers do not cycle their runtime power domains merely
to install IRQ handling or read the DSIM version. The early splash deliberately
skips the firmware DRM card and commits its first frame on native DRM.

Target 2872 proved that a U-Boot source change is not deployed by an OSTree
update when its boot-firmware marker is left unchanged: Linux contained the
handoff support, but the running `2026090508` U-Boot supplied no
`simple-framebuffer` node and the panel still went black. The handoff-capable
payload is therefore rolled out as boot firmware `2026090601`.

The next gate is the factory Yocto build followed by a recorded cold boot. The
acceptance test is no countdown, no black handoff frame, no framebuffer-console
output, and an upright Linux splash that remains until the product UI replaces
its framebuffer.
