# Display panel reference profiles

This directory records validated display modules independently of the carrier
board that first used them. A screen machine selects a profile with
`DISPLAY_PANEL_PROFILE` and describes its physical mounting with:

- `DISPLAY_PANEL_ROTATION`: panel orientation in counter-clockwise degrees for
  the DTS `rotation` property (`0`, `90`, `180`, or `270`).
- `DISPLAY_FBCON_ROTATE`: Linux framebuffer-console rotation (`0` normal, `1`
  clockwise, `2` upside-down, `3` counter-clockwise).

The panel DTS node must use the profile's specific compatible before any
controller-family fallback. Timing, DSI link mode, power/reset behaviour and
initialization data belong to the panel descriptor selected by that compatible;
they must not be copied into a generic board descriptor.

Each profile should record its source evidence, known-good Foundries target,
native geometry, link format, timing, power sequence, touch mapping, mounting
orientation, and remaining limitations.

## Jaguar Screen ST1010B3CYOL / FT5x06 touch acceptance

The 2026-09-24 physical regression exposed a mismatch between display logical
geometry and the touchscreen controller's native coordinate space. The
source-level fix is BSP commit
`36db9b8195d0e5cd098d5f1d73c19718d1a4db41`: retain the controller's native
`600x1024` geometry and apply X inversion. Do not replace those values with the
rotated Weston output size. Michael physically accepted the hotpatched mapping;
Foundries target 2995, manifest
`ce04cfa7e6e9cf382114ee4a667c8962ec41e831`, remains the exact image/OTA gate.

Board-generic input harnesses must discover the deployed event device and
clone both its kernel capabilities and the udev policy consumed by libinput
and Weston, including output association and calibration. Cloning ABS ranges
alone is insufficient and can produce a synthetic mapping that differs from
physical touch. Synthetic uinput proof does not cover the controller, bus,
IRQ, or driver; retain a real corner/centre trace and physical acceptance.
