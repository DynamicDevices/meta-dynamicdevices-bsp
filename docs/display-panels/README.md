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
