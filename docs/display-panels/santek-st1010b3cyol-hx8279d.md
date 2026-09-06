# Santek ST1010B3CYOL / dual Himax HX8279-D

## Identity

- Profile: `santek-st1010b3cyol-hx8279d`
- DTS compatible: `santek,st1010b3cyol`, then `himax,hx8279d`
- Native scan: 1200 x 1920, RGB888, four MIPI DSI lanes
- Controller arrangement: two HX8279-D source drivers in the module
- First validated carrier: `imx8mm-jaguar-screen`
- First readable Foundries target: 2796 (2026-09-01)
- First validated U-Boot splash target: 2868, boot firmware `2026090508`
  (2026-09-05)

## Known-good display link

- Pixel clock: 159420 kHz
- Horizontal: active 1200, front porch 80, sync 60, back porch 24
- Vertical: active 1920, front porch 10, sync 14, back porch 4
- DSI mode: video, sync-pulse
- DSI clock: non-continuous
- Commands: low-power mode, generic writes for HX8279 register pages

These values match the upstream Linux Aoly SL101PM1794FOG-V15 HX8279 profile.
The ST1010 retains its own vendor initialization sequence and board power
handling; only the link timing and clock behaviour are shared.

## Active Screen mounting

- Native portrait scan is mounted landscape with the panel right edge at the
  top of the product: DTS `rotation = <90>`.
- Linux text console default: `fbcon=rotate:1` (clockwise).
- Touch logical area: 1920 x 1200. Touch transformation must follow the same
  product orientation in the graphical compositor.

## Power and initialization

- `DSI_EN_2` / GPIO1_IO12 controls the TPS22913B LCD power path; it is not the
  HX8279 reset pin.
- Use the ST1010 vendor HX8279 initialization table already carried by
  `panel-boe-himax8279d` patches.
- Keep panel commands in LPM and send HX8279 register writes as generic DSI
  packets.

## Evidence and alternatives

- Michael's `10.1 FHD BIOS light up panel data` supplied the first nearly
  working 159391 kHz setup (80/1/60 and 35/1/25).
- The upstream HX8279 timing above produced a stable readable console on target
  2796 and is the current reference.
- Boot-time `panel_boe_himax8279d.st1010_*` parameters remain available for
  controlled experiments without creating a kernel patch for every timing.

## U-Boot splash evidence

- Boot filesystem: FAT on `mmc 2:1`.
- Generated derivative: `active-edge-splash-1200x1920.bmp`, 6,912,054 bytes,
  1200 x 1920, 24 bpp, uncompressed.
- SHA-256: `d7f04f12b61990c0edf45efbdc5392808925b3c01264349642545dd5eef380d0`.
- U-Boot CRC32 over `0x697836` bytes: `5f68ed83`.
- Reproducible display sequence:
  `fatload mmc 2:1 0x40400000 active-edge-splash-1200x1920.bmp`,
  `bmp info 0x40400000`, `crc32 0x40400000 0x697836`, then
  `bmp display 0x40400000 0 0`.
- A successful `bmp display` was not sufficient while DSIM video was enabled
  before the panel command sequence and LCDIF scanout. The proven order is
  panel power/command-mode setup, complete DCS initialization, LCDIF start,
  then DSIM standby/video enable.
- Target 2868 proved both the manual sequence and the automatic boot-script
  path on the mounted panel with the correct orientation.
- A signed one-shot Linux FIT tested on 2026-09-06 proved native DRM can adopt
  the firmware-active display domains, LCDIF, SEC DSIM and panel without a
  black interval or visible mode-reset flash. The first native commit retains
  the inherited mode/PLL and queues Linux's replacement framebuffer address.

## Remaining work

- Confirm the final colour test under Linux and the complete kiosk takeover.
- Expose the DTS panel orientation through the DRM connector from the panel
  driver, so Wayland compositors can consume it automatically.
- Validate touch-axis swap/inversion against the final compositor transform.
