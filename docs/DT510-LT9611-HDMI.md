# DT510 LT9611 HDMI bring-up

Updated 16 November 2026 at Alex's request. Briar helped draft this.

## Current state

Foundries development build **682** passed and reached Michael's DT510.
HDMI console video has been observed on the TV, but boot/reboot reliability is
not established: a later boot produced a black display, recovered by ordered
display-controller and LT9611 driver rebind without rebooting the board.
The part is the plain **LT9611**, not LT9611UXC or LT9611UXD. Michael Hull
confirmed four DSI data lanes wired to **MIPI port A** and correct board power
sequencing; Alex relayed that **RSTn is active-low**. The hardware Google Doc
was updated with those confirmations.

The DT enables LCDIF, MIPI DSI and the LT9611 at I2C3 address `0x39` (Linux
adapter numbering is normally `i2c-2`). It replaces the EVK graph with one
reciprocal LCDIF -> DSI -> LT9611 -> HDMI connector path. Both known EVK
ADV7535 node names are removed to avoid retaining its GPIO claims.
The DSI output endpoint includes `attach-bridge`, required by the pinned NXP
SEC DSIM driver. The kernel fragment builds the full display path in, including
`CONFIG_DRM_LONTIUM_LT9611=y` and `CONFIG_DRM_DISPLAY_CONNECTOR=y`; no bridge
module installation/autoload step is needed.

The 1.8 V supply remains a fixed, always-on model without an invented parent or
enable GPIO; 3.3 V uses the existing fixed `reg_vddext_3v3`. Michael's sequencing
confirmation does not document the actual upstream rail topology. This remains
a documentation/bench check, not a reason to invent a PMIC connection.
No HDMI audio DAI routing has been added. Michael confirmed on 16 November 2026
that the audio interface is not connected, so TV audio cannot be enabled through
software alone on this wiring.

## Hardware recovery evidence — 16 November 2026

Alex explicitly designated Michael's DT510 as development hardware and requested
live diagnostics and driver-reload experiments. Device identity:
`imx8mm-jaguar-dt510-1b1b6209dabc234a`, reported LAN address `192.168.2.205`.
Build 682 uses BSP `b3e99127bc1384ee66cab74519587f919bde3bde`, manifest
`78692c1010d20e3a8f7e1a7161e5b999f4547eae`.

Observed failure and recovery, not yet an established root cause:

1. The board remained reachable over SSH. LT9611 revision `0xe1` was read and
   DRM initialized, followed by `read edid failed: access not done` and
   `edid read failed`. Later logs included HDMI connect/disconnect transitions.
2. In the failed state, connector status was disconnected, EDID length zero,
   and the CRTC inactive. The DPX Cheese camera view showed a black TV on HDMI3.
3. A software re-detect did not recover it. Forcing connector status on alone
   did not start scanout. A temporary explicit 720p60 DRM colour-bar test was
   accepted by KMS but produced no visible picture; the driver logged
   `power on failed`. During cleanup it logged `video on failed`, which is the
   driver's misleading label for a failed HDMI-disable register write.
   Automatic detection and the original inactive scanout were restored.
4. With no userspace DRM clients, one ordered rebind succeeded: unbind
   `display-subsystem` from `imx-drm`; unbind I2C device `2-0039` from `lt9611`;
   bind `2-0039` to `lt9611`; bind `display-subsystem` to `imx-drm`.
   These are built-in drivers, so this is not a module unload/reload.
5. The new probe read revision `0xe1`; no EDID failure appeared in the immediate
   recovery log window. The camera showed the console again. Validation found
   connected/enabled HDMI, an active **1920x1080 at 60 Hz** CRTC (148.5 MHz pixel
   clock), and **256 EDID bytes with both 128-byte block checksums equal to zero**.

No board reboot, firmware update, new build, persistent EDID override or boot
workaround was used for recovery. The working display was left running.
One successful recovery is not a fix or proof of repeated-boot reliability.

### Timing/state investigation still open

An I2C/bridge/TV-readiness race is plausible, but the initial successful chip
revision read argues against the simple claim that the I2C controller had not
started. Rebind changes several variables together: time since power-up, bridge
reset/reinitialization, driver software state, DSI attachment and DRM modesetting.
It does not isolate which one repairs the failure.

Next experiments should separate display-master-only rebind from bridge reset,
capture the first failing register operation and errno, and compare cold boot,
warm reboot and TV-ready timing. The sleep/wake and EDID/HPD paths also warrant
inspection: several register operations currently ignore errors. Do not add an
arbitrary startup delay or automatic rebind service and call the cause solved.
Further disruptive tests should preserve this working baseline and be agreed
before resetting the board or changing firmware.

**Controlled reproduction (same build and boot, 16 November):** restarting only
the `imx-drm` display master, leaving the LT9611 I2C driver bound and not resetting
the chip, changed a connected/enabled, valid-256-byte-EDID baseline to
disconnected/disabled with zero EDID bytes. An isolated trace instance, filtered
to I2C adapter 2, captured 19 transfer results, including seven `ret=-6`
(`-ENXIO`) failures, with zero trace overruns. This establishes I2C transfer
failure during the display-only disable/rebind cycle, not merely a missing
mode. One ordered full display/LT9611 rebind then restored connected/enabled
video and the same valid 256-byte EDID. The private trace instance was removed.
An address/payload-aware repeat at kernel monotonic time approximately 4471.79 s
captured writes at `0x39`: page `0x80`, `[24-76]`, then `[23-01]`.
Subsequent page-register reads failed with `-ENXIO`; again there were 19
transactions, seven failures and no overruns. Ordered full rebind restored
connected/enabled video and 256-byte EDID with both checksums zero. No broad I2C
scan or raw register manipulation was used; the private tracer was removed.

The vendor register manual identifies `0x8024` as the software I2C address and
`0x8023[0]` as its enable. The hardware guide maps 8-bit `0x76` to 7-bit `0x3b`,
whereas this board is strapped to 7-bit `0x39` (8-bit `0x72`). The driver therefore
selects a different control address during sleep. The trace places the loss of
communication immediately after that override is enabled. Response at `0x3b`
was not separately probed.

Candidate patch 0033 derives the software address from `client->addr << 1`,
preserving the configured address while retaining the rest of the sleep sequence.
It is local only: not deployed to build 682, and not yet hardware-validated.
The preflight regression compiles the actual patched sleep function against a
register-address model, checks repeated sequences at both strap addresses and
requires the old hardcoded sequence to reproduce loss of `0x39` after two writes.
This model does not prove physical sleep/wake or reboot reliability.

The driver's `atomic_post_disable` calls `lt9611_sleep_setup`; waking in
`atomic_pre_enable` writes a different sequence and clears its software sleep
flag without checking the write result. EDID probing instead calls
`lt9611_power_on`, which can return early from its cached software power flag.
These paths are now concrete suspects. The controlled reproduction makes a
simple "I2C controller not started yet" explanation less likely, but does not
prove that the original boot-time EDID error and the sleep/rebind failure have
the same cause.

### HDMI audio remains unconfigured

After video recovery, `aplay -l` and `/proc/asound/cards` exposed Loopback,
TAS6424, TAS2563, TAA5412 and TAC5301 cards, but no HDMI playback device; no HDMI
PCM name or ELD entry was found. No music was played through unrelated outputs.
Michael subsequently confirmed: "The audio interface isn't connected up."
This is a physical wiring limitation, not merely a missing ALSA machine/DAI
route. No TV-audio playback or software-only audio fix is claimed.

## Board-only kernel patches

The manifest's meta-lmp pin `4dffdff79b4df49c683c9a7faea406595cb7e9ca` selects
Linux 6.6.52 at `e0f9e2afd4cff3f02d71891244b4aa5899dfc786`.

- `0031-drm-bridge-lt9611-fix-dt510-active-low-reset.patch`: retain
  `GPIO_ACTIVE_LOW`; use logical `0/1/0`, yielding physical high/low/high with
  20/20/100 ms delays. Acquisition at `GPIOD_OUT_HIGH` initially asserts reset
  during power enable.
- `0032-drm-bridge-lt9611-dt510-host-and-irq.patch`: support the NXP host's
  legacy connector ownership by attaching the terminal bridge with
  `DRM_BRIDGE_ATTACH_NO_CONNECTOR` and creating a DRM bridge connector when
  the parent expects one. Modern NO_CONNECTOR hosts retain their own ownership.
  Also set register `0x8210` bit 0 before requesting the level-high IRQ so the
  chip's polarity matches `HDMI_INT` in the board specification. I2C failure
  takes the existing regulator cleanup path.
- `0033-drm-bridge-lt9611-preserve-i2c-address-in-sleep.patch`: use the configured
  client address instead of moving the bridge from `0x39` to `0x3b` during sleep.
  Local candidate only; hardware sleep/wake, warm reboot and cold boot remain
  acceptance checks. No arbitrary timing delay or rebind service is added.

Independent review also found a circular probe dependency: the NXP host is
registered only during component bind, while LT9611 previously needed that host
before its bridge could remain available. Patch 0032 now publishes the bridge
after probe setup without requiring a DSI host, and registers/attaches the DSI
devices during bridge attach instead. Explicit detach/unregister cleanup covers
attach errors, deferred retries, bridge detach and removal. Connector ownership
is retained by the DRM core, with a separate reference held until bridge detach.
A follow-up review found direct connector destruction bypassed reference counting
and could reach the HPD mutex after bridge removal. The patch now disconnects
bridge callbacks and stops HPD before bridge removal, drops only its own reference
on successful detach, and leaves final destruction to DRM. A board-selected helper
addition in `drm_bridge_connector.c` clears the bridge-chain pointers so outstanding
connector references can be released after the bridge is removed.

All three patches are selected only by `SRC_URI:append:imx8mm-jaguar-dt510`.
No other machine's driver build is changed.

## Michael's vendor archive

Inspected `/home/ajlennon/Downloads/LT9611 6911.zip` as data only. No supplied
code or binaries were executed, and vendor files are not copied into this repo.
Archive SHA-256:
`ab81bb834688c862edf1adc35560369c2613ddd50bfcb298ae843e64eb9ce944`.

- `LT9611_HW_System_Design_Guide_Release_V0_4.pdf`: reset input, open-drain IRQ,
  address straps (`0x39` with ADDR low), 27 MHz reference and power guidance.
- `LT9611_SW_System_Design_Guide_Release_V1_0.pdf`: reset low then high before
  reading chip identity; useful operational guidance, not a modern DRM driver.
- `lt9611 drm.c`: uses raw GPIO high/low/high, confirming why simply copying
  those values into an active-low descriptor API inverts the reset waveform.
  It uses falling-edge IRQs; that does not match DT510's stated polarity until
  the chip is explicitly configured for active-high interrupts.
- `LT1702_Register_List_Preliminary-cover LT9611.pdf`, register `0x8210`,
  `RGD_INT_POL_SEL` bit 0: `0` = output low active (reset default), `1` = output
  high active. This provides the setting used by patch 0032.

The nested RAR bundles and other vendor C variants have not been exhaustively
reviewed. They are reference material, not instructions or build inputs.

## Preflight and remaining acceptance

Run from the BSP repository:

```sh
python3 scripts/dt510-hdmi-preflight.py \
  --kernel-git /path/to/existing/linux-fslc.git
```

This uses only the pinned local source, a temporary tree, the existing EVKB
PMIC-name patch and host tools. It checks strict patch application, compiles
the actual reset/DSI/bridge attach/detach functions with mocked kernel APIs,
tests host-unavailable retries, primary/secondary DSI cleanup, connector
success/error paths, retained references and delayed destruction after HPD teardown,
and IRQ setup ordering, compiles the DTB, and checks the
resulting graph, enabled nodes, GPIO polarity, supplies, lane count and EVK
removal. It does not run BitBake or compile the complete kernel driver.
The host-order cases are native API simulations, not actual kernel boots.

Before claiming working HDMI:

1. Build 682 completed the reviewed build/pin workflow. Preflight alone still
   does not authorize another build, push or deployment.
2. Check final kernel config and build output; verify the LT9611 revision
   probe, no deferred display probes and a usable DRM HDMI connector.
3. Check the physical reset waveform and active-high IRQ behaviour, then EDID,
   720p video, 1080p60 video, hot-plug and cold/warm boot.
4. Verify the actual supply topology on the schematic/board. Do not claim
   HDMI audio or 4K from this single-DSI-port integration.
