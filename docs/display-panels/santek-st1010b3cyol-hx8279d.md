# Santek ST1010B3CYOL / dual Himax HX8279-D

## Identity

- Profile: `santek-st1010b3cyol-hx8279d`
- DTS compatible: `santek,st1010b3cyol`, then `himax,hx8279d`
- Native scan: 1200 x 1920, RGB888, four MIPI DSI lanes
- Controller arrangement: two HX8279-D source drivers in the module
- First validated carrier: `imx8mm-jaguar-screen`
- First readable Foundries target: 2796 (2026-09-01)

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

## Remaining work

- Confirm the final colour test and full-screen graphical scanout.
- Expose the DTS panel orientation through the DRM connector from the panel
  driver, so Wayland compositors can consume it automatically.
- Validate touch-axis swap/inversion against the final compositor transform.
