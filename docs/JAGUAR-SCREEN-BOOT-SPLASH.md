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
5. Weston takes DRM `card2`, rotates the native portrait scanout into a
   1920x1200 landscape desktop, and keeps the landscape Active Edge artwork
   visible until the Waydroid UI presents its first frame.

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

The Linux panel patch is consolidated around the final bench-proven HX8279
mode and power/init behavior. Superseded continuous-clock, intermediate timing,
vendor-BIOS timing, and boot-parameter experiment patches are not shipped.

The early renderer scans all DRM cards and selects one that has a connected
connector and usable CRTC; it does not assume `card0` is the display when a
separate GPU DRM device is present.

U-Boot now leaves LCDIF running at OS prepare and passes its live framebuffer
to Linux as a reserved `simple-framebuffer`. The early splash deliberately
skips that firmware DRM card and waits for a connected native DRM output.

The earlier Linux workaround that skipped selected runtime-PM calls has been
removed. It read the DSIM version while the domain was inaccessible (reporting
`0x0`) and did not preserve the complete display pipeline.

Target 2872 proved that a U-Boot source change is not deployed by an OSTree
update when its boot-firmware marker is left unchanged: Linux contained the
handoff support, but the running `2026090508` U-Boot supplied no
`simple-framebuffer` node and the panel still went black. The handoff-capable
payload was therefore rolled out as boot firmware `2026090601`. The final
U-Boot OS-prepare shutdown guard advances the next payload to `2026090602`.

Target 2874 one-shot tests established both destructive transitions without a
new Foundries build. The test command loaded the intended signed FIT from ext4
`mmc 2:2`, cleared and saved both boot-command overrides before booting, and
failed closed if that FIT could not be loaded. The U-Boot frame stayed visible
when native LCDIF, SEC DSIM, i.MX DRM and `imx8m-blk-ctrl` initcalls were
blacklisted with unused clock and power-domain cleanup disabled. Omitting only
the block-controller blacklist caused a later blackout after the OSTree root
transition. Masking `screen-splash.service` did not prevent it. This proves the
remaining kernel fault is inherited display power/domain state, not the splash
client or framebuffer contents.

## NXP i.MX8M handoff model proved on target 2874

The framebuffer and the machinery scanning it out are separate resources. On
this board the inherited live chain is:

```text
reserved U-Boot framebuffer
        -> LCDIF @ 32e00000
        -> i.MX8M display block control / parent power domain
        -> SEC DSIM @ 32e10000
        -> ST1010B3CYOL / HX8279-D panel
```

Keeping only the framebuffer reservation and `simple-framebuffer` node did not
keep the image visible. Conversely, the later clean black frame did not mean
the BMP bytes had been overwritten: it was caused by Linux changing power,
reset or clock ownership in the active scanout chain.

Two independent transitions were isolated:

1. NXP's U-Boot `arch/arm/lib/bootm.c` called `video_link_shut_down()` even
   when the normal video-remove policy was disabled. The product fix gates it
   with `CONFIG_VIDEO_REMOVE`, alongside preserving the mxsfb device through
   OS prepare.
2. Linux initially models firmware-active display resources as off. In
   particular, the LCDIF runtime state, SEC DSIM domain access and
   `imx8m-blk-ctrl` generic power-domain setup can reset or gate an inherited
   pipeline before native DRM performs its first atomic commit.

The Linux root clock plan is part of the same contract. The previous default
assigned VIDEO_PLL1 rate of 1.0395 GHz conflicted with the running U-Boot
pipeline. The control DT now assigns VIDEO_PLL1 at 594 MHz and LCDIF pixel at
148.5 MHz, matching the handoff configuration and avoiding an early parent-PLL
retune.

The decisive isolation matrix was:

| One-shot condition | Result |
| --- | --- |
| Preserve U-Boot LCDIF only | Frame later blanked |
| Preserve framebuffer/simplefb and disable unused clock/domain cleanup | Frame later blanked |
| Also blacklist native i.MX DRM, LCDIF and SEC DSIM initcalls | Frame later blanked |
| Also blacklist `imx8m-blk-ctrl` | U-Boot frame remained visible |
| Mask `screen-splash.service` without the complete kernel isolation | Frame still blanked |

This establishes a kernel ownership fault and rules out the splash artwork,
simple framebuffer contents and Linux splash service as the cause of the
delayed blackout.

The production Linux change now adopts the firmware-active display block power
domains, LCDIF, SEC DSIM wrapper/common bridge and Santek panel. On the first
native DRM commit it retains the running LCDIF mode and DSIM PLL, and queues
only Linux's replacement framebuffer address. Normal native-driver ownership
continues after that commit.

Target 2875 proved an additional OTA-specific failure mode. Although the
machine configuration requested `drm_kms_helper.fbdev_emulation=0`, OSTree
preserved the installed deployment's older kernel arguments. The running
kernel therefore reported fbdev emulation enabled, created a zero-filled
native `fb1` at 2.250 seconds and committed it at 2.258 seconds. The panel
appeared to blank around `/init`, before `screen-splash` started at 7.108
seconds. The Screen kernel now compiles `CONFIG_DRM_FBDEV_EMULATION=n`, so a
Foundries OTA cannot reintroduce that intermediate black framebuffer by
retaining stale deployment arguments. Native DRM remains enabled for the
early splash client and product compositor.

`initcall_blacklist=`, `clk_ignore_unused` and `pd_ignore_unused` remain
one-shot diagnostic tools only. Shipping them would prevent the Linux splash
and product UI from obtaining native DRM. Likewise, the relocated-RAM
`video_off` write was useful to prove U-Boot teardown ownership but is not a
source fix.

Those initcall blacklists and ignore arguments are diagnostic only and do not
ship: native DRM is required by the Linux splash and product UI.

The native-driver implementation was compiled as kernel release
`6.6.52-lmp-standard`, packaged in a signed one-shot FIT and bench-tested on
2026-09-06. The U-Boot frame remained visible through kernel display takeover,
with no black handoff interval and no visible LCDIF/DSIM mode-reset flash. The
tested FIT SHA-256 was
`ba4e5e159b2532af6d933b3f8d6a742ed34c0fd12dcaf5850f4b8a739dff865c`;
its kernel `Image` SHA-256 was
`6647e66e4b8e15db58cb88a0d4c6072386fb1cb7b0d3f6fa34170e024b19ac53`.
The compiled U-Boot default remains `bootdelay=0`; a previously saved
environment value is a separate persistent override and must be returned to
zero after lab debugging.

Foundries target 2887 proved the complete display path on the physical board:
the U-Boot frame remained upright through native Linux DRM, Weston used
`card2`, and the full-screen Waydroid UI replaced the splash at 1920x1200.
The final Weston handover uses the landscape source image because the output
transform already accounts for the portrait-mounted panel.

The Screen build retains `CONFIG_CMD_WDT` for lab diagnostics but disables both
`CONFIG_SPL_WATCHDOG` and `CONFIG_WATCHDOG_AUTOSTART`. SPL's legacy i.MX path
otherwise starts WDOG1 with its 60-second default timeout before full U-Boot.
Because the i.MX watchdog enable/configuration bits are write-once, Linux then
cannot perform its normal immediate watchdog restart and only systemd's
`RebootWatchdogSec=60` fallback resets the board. Boot firmware `2026090701`
restores the pre-display-change reboot behaviour without altering the splash or
display handoff.

The v1.0.0 release validation build is Foundries target 2888. It combines boot
firmware `2026090701` with the final Waydroid landscape handover splash. A
release is complete only after that target has been installed and an immediate
reboot into Android has been timed on the physical board.
