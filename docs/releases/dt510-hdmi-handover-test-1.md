# DT510 HDMI handover — test release 1

22 November 2026. Briar helped draft this.

This prerelease identifies the exact code already built and tested as Foundries
vixdt target 718. It is for the development DT510, not production promotion.

## Reproduce the tested image

| Component | Identity |
| --- | --- |
| BSP release tag | `dt510-hdmi-handover-test-1` |
| Tagged BSP commit | `291b2188e2e096d06283efef0ed4cba98677382d` |
| Foundries target | [vixdt 718](https://app.foundries.io/factories/vixdt/targets/718/) |
| Trigger | `platform-main-imx8mm-jaguar-dt510` |
| Manifest | `f181ced27d53b2d20beb5c159c604c19f0ddcd40` |
| Distro | `1952d7efda4f0abb00c834bd5b4205bbc42d8533` |
| Subscriber | `5c43d6db7b1bb9dc9cb3011c8becce74173296bf` (`dt510-dev-pins`) |
| Containers | `cc3d41cead8f056e74bae9b911661ef369c3fdd1` |
| Installed image | `5.0.9-718-96` |
| Installed OSTree | `6c4d108f7575ddc595c1145647011593082826db80134e938f81d9f5b44caf41` |

The tag points to the tested BSP code, not a later documentation-only commit.
Use the manifest pins above to reproduce the complete image. The GitHub source
archive is not a flashable board image; obtain signed artifacts through the
Foundries target using the existing authorised programming/update workflow.
No new build or automatic deployment is part of this release.

## What works

- Exact LT9611 (not LT9611UXC/UXD), four DSI lanes on MIPI port A; active-low
  reset and the board-specific Linux reset correction.
- U-Boot AESL splash at 1280×720 and retained firmware scanout into Linux.
- Hardware-accelerated G2D Weston, with the same artwork as desktop background
  and no intervening TV console. Serial diagnostics remain available.
- Three complete recorded warm reboots showed no black/white handover interval
  once U-Boot's splash appeared. The normal shutdown/pre-splash blackout is a
  separate phase and is not a claim of retaining the old desktop across reset.

## Why the earlier handover failed

1. Device-core removal powered down the display even when U-Boot's video-driver
   remove callback preserved it. Retention is now per-device after final valid
   handover commit; driver-wide flag changes would also alter default clocks.
2. Linux's upstream CCM default retuned VIDEO_PLL1 from 594 to 1039.5 MHz,
   corrupting the inherited 74.25 MHz pixel and 27 MHz DSI reference clocks.
   Only that validated assigned-rate cell is suppressed for admitted handover;
   failed final admission restores the normal default.
3. Display power domains switched off during deferred probe. Valid pending
   adoption now holds the relevant GPC/blk domains until native takeover, with
   balanced rejection, terminal bind/probe failure and removal cleanup.
4. Native LCDIF, DSIM and LT9611 startup now preserves validated live timings,
   link lock and output rather than resetting a working display.

Native source fixtures (18) and DTB admission tests (4), full patch-apply checks,
direct U-Boot cross-build, exact-candidate review and exact-head GitHub CI
passed for this code; Foundries 718 passed. These software checks are distinct
from the subsequent physical camera/serial acceptance.

## Limits and follow-up

- **Residual handover blackout reported:** Alex subsequently thinks a black
  period still occurs during handover. Earlier sampled checks did not identify
  it; the report remains unresolved and investigation is deferred at his request.
  Do not interpret this test release as fully seamless/production acceptance.
- This prototype required Michael's 1 MΩ resistor across the crystal to start
  the oscillator. Software timing workarounds do not replace that repair.
- Cold power-on, suspend/resume, display disconnect/reconnect/mode changes and
  broader GPIO/USB regression qualification remain open in
  [HDMI issue #6](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/issues/6).
- Physical camera sampling was 5 fps, accepted by Alex for these tests; a faster
  Cap window recording does not remove its roughly 200 ms observation limit.
- The same artwork changes scale at desktop takeover. No pixel-identical
  placement claim is made. TV overscan must be disabled for correct edge tests.
- U-Boot retains its ten-second diagnostic splash hold. HDMI audio is not
  connected; no TV-audio acceptance is claimed.
- Uncommitted codec/audio work is excluded from the release. The headed feature
  path must continue preserving explicit headless and static/e-ink products.

## Reuse on other display-feature boards

The versioned [build-skill snapshot](../skills/source-command-build/SKILL.md)
and its [handover reference](../skills/source-command-build/references/display-splash-handover.md)
capture the intended display-feature defaults, clock/power/ownership invariants
and physical test procedure. They are guidance, not an assertion that another
board has already been enabled or tested. Live installed skill ownership remains
in the project workspace; this snapshot makes that guidance recoverable in Git.

Private camera recordings and full serial logs are not release assets. Their
locations and per-boot evidence remain in the existing private project checkpoint.
