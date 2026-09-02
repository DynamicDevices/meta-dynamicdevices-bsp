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

## Adding a screen

1. Add one profile include under `conf/machine/include/display-panels/` with
   native geometry, pixel clock, DSI format/lanes, Linux compatible and U-Boot
   driver/config symbols.
2. Select that include and profile from the machine configuration. Keep only
   carrier GPIOs, regulators, buses and physical mounting rotation in the
   machine DTS.
3. Add the Linux descriptor/init sequence and the U-Boot panel driver for the
   same specific compatible. Do not inherit an EVK display route: explicitly
   disable every unused bridge/panel in both control device trees.
4. Inherit `display-panel-profile` in both recipes. Its pre-configure gate
   rejects incomplete profiles and invalid rotation values.
5. Build the exact device-tree and U-Boot recipes before an image build. Inspect
   the compiled U-Boot DTB to prove that the intended panel is enabled and all
   inherited display bridges are disabled.
6. Advance `LMP_BOOT_FIRMWARE_VERSION` when U-Boot changes, then verify the
   packaged version, secondary boot, confirmation to primary, and a cold boot.
