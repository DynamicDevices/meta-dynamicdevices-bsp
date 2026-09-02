# Display panel reference profiles

This directory records validated display modules independently of the carrier
board that first used them. A screen machine selects a profile with
`DISPLAY_PANEL_PROFILE` and describes its physical mounting with:

- `DISPLAY_PANEL_ROTATION`: panel orientation in counter-clockwise degrees for
  the DTS `rotation` property (`0`, `90`, `180`, or `270`).
- `DISPLAY_FBCON_ROTATE`: Linux framebuffer-console rotation (`0` normal, `1`
  clockwise, `2` upside-down, `3` counter-clockwise).
- `DISPLAY_WESTON_TRANSFORM`: compositor transform applied to the native DRM
  mode (`normal`, `rotate-90`, `rotate-180`, or `rotate-270`). The distro image
  must consume this variable when generating `weston.ini`; applications must
  not compensate for the panel mounting themselves.

Keep these geometries distinct. The ST1010 panel advertises its native DRM
mode as `1200x1920`; when mounted at 90 degrees, Weston exposes a logical
`1920x1200` output to Wayland clients. A native mode in sysfs is therefore not
evidence that the compositor orientation is wrong.

The panel DTS node must use the profile's specific compatible before any
controller-family fallback. Timing, DSI link mode, power/reset behaviour and
initialization data belong to the panel descriptor selected by that compatible;
they must not be copied into a generic board descriptor.

Each profile should record its source evidence, known-good Foundries target,
native geometry, link format, timing, power sequence, touch mapping, mounting
orientation, and remaining limitations.

For display test services, check both runtime and image provenance. Use the
process cgroup or `systemctl status <pid>` to find the owning unit, verify
`is-enabled` as well as `is-active`, inspect boot-target symlinks, and check
package ownership. A manually installed unit with `Restart=always` can respawn
after its process is killed while still being absent from the built image.
