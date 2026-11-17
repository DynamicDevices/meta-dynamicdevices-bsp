# DT510 LT9611 HDMI bring-up

Updated 17 November 2026 at Alex's request. Briar helped draft this.

## Current state

Build **689** passed, was installed by OTA after re-registration, booted and
finalized. Its first HDMI attempt still failed: revision `0xe1` at 2.722348 s,
then `EDID power-on failed: -6` at 3.359272 s, with disconnected/disabled HDMI
and zero EDID bytes. The single-master candidate did **not** fix startup.
Later on the same boot, HDMI disconnect/connect interrupts at 641.865001 s and
643.152842 s were accompanied by framebuffer-console creation. Without a driver
reload/rebind by Briar, the connector subsequently reported connected/enabled,
256 EDID bytes and active 1920x1080 scanout. This is not repeated-startup or
camera-confirmed visible-output acceptance; the external cause of those HPD
events has not been established.

The next diagnostic image disables **only** `ksz9896_sw` on I2C3. It is a
temporary isolation test requested by Alex, not a production Ethernet change or
a demonstrated HDMI fix. See the experiment and acceptance criteria below.

### Earlier results

Foundries development build **686** passed, booted on Michael's DT510 and
finalized successfully. Its checked power-on path exposed `-EAGAIN` (`-11`)
before EDID, leaving HDMI disconnected with zero EDID bytes. It contains the
LCDIF bridge-state and EDID-handling changes as well as the sleep-address fix.
On 684, ordered display-controller/LT9611 rebind recovered a visible 1080p console and
valid 256-byte EDID. Video playback exposed DRM bridge-state warnings and a
black picture despite GStreamer reporting PLAYING. Video is not an accepted pass.
A single later `detect` reprobe on 685, without reset or rebind, read a valid
256-byte EDID. The adapter-2 trace recorded 6068 events, zero failed transfers
and zero overruns. Detection recovered; scanout was still disabled, so this
alone is not visible-output acceptance. Patch 0036 is deployed in 686, but its
three power-on attempts still fail at boot. More retries are not an established
fix; underlying electrical/arbitration causation is not proven.
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

### Display cropping resolved: TV overscan

Michael reported that the first visible 16-pixel bands in the native 1080p
overscan pattern were orange at left/right and red at top/bottom. This was
consistent with roughly 32–47 source pixels cropped horizontally at each edge
and 16–31 vertically. Michael then confirmed that TV overscan was enabled;
after disabling it, his report was **"It's perfect now"**. The apparent console
offset/clipping was therefore a TV picture-setting issue, not evidence that the
framebuffer needs an offset or underscan workaround. Do not compensate for it
by changing board timing or framebuffer geometry. This does not resolve the
separate sleep/re-enable or boot reliability defect.

### Manual diagnostics included in the next image candidate

The new DT510-only `dt510-hdmi-test` package includes the exact bench-tested
image, `/usr/share/dt510-hdmi-test/overscan-1920x1080.png`, a compressed BGRX copy
and a manual framebuffer utility:

```sh
sudo dt510-hdmi-test info
sudo dt510-hdmi-test show
sudo dt510-hdmi-test restore
sudo dt510-hdmi-test console
sudo dt510-hdmi-test restore
```

The helper requires the existing native 1920×1080 XRGB8888 scanout, refuses
userspace DRM owners, saves the console in a private root-owned `/run` directory
and prevents text overwrites until restoration. It does not change modes, force
HPD, reload a driver or start at boot. Restore before attempting any KMS playback.
Other resolutions/formats are deliberately refused. The installed PNG can also
be used by another viewer. The white outer band must reach all four edges;
each subsequent coloured band is 16 source pixels wide. The companion source
generator and host tests check image/raw agreement, edge colours, payload lengths
and geometry rejection. Assets are generated on the host, not during Yocto or on
the board; Pillow and font files are not runtime dependencies.

The `console` action is a real text-console test, not a rendered screenshot:
it saves `/dev/vcsaN` (character cells, attributes and cursor), fills every row
and column with a known repeating `0–9A–Z` sequence, marks corners `TL/TR/BL/BR`
and labels intermediate row edges `Lnnn/Rnnn`. Direct character-cell writes avoid
bottom-row wrap/scroll. `restore` puts back the original cells and cursor. Restore
an active graphical test before starting it. Verify the first/last characters
and every edge row marker, including the bottom-right corner. Host tests check
exact row/column lengths, corner markers and payload layout; hardware results
must be recorded separately.

The next DT510 image candidate also requests GStreamer KMS output (`kmssink`),
H.264 parsing/FFmpeg decoding, MP4 demux, playback/typefinding, video conversion,
test-pattern generation and direct HTTP media support. These are explicit image
packages, not a browser/YouTube player. No music/video content is bundled or
automatically fetched, and no HDMI audio routing is invented. The existing distro
already accepts the `commercial` license flag used by its FFmpeg/libav recipes;
this change does not broaden that license policy. Software H.264 decoding is a
functional fallback; its usable resolution/frame rate must be measured on target.

Build 688 has the required elements. The following **silent local H.264 MP4**
pipeline was visually confirmed by Alex on 17 November 2026. First establish an
enabled connector with an existing display mode; a connected connector and valid
EDID alone are insufficient. Do not start playback over another DRM owner.

```sh
# First restore the manual framebuffer test if it is active.
sudo dt510-hdmi-test restore
sudo gst-launch-1.0 -e \
  filesrc location=/absolute/path/test.mp4 \
  ! qtdemux ! h264parse ! avdec_h264 max-threads=4 \
  ! queue max-size-buffers=3 ! videoconvert \
  ! video/x-raw,format=BGRx \
  ! kmssink driver-name=imx-drm force-modesetting=false
```

The restore command is needed only if the pattern is active. Audio is deliberately
not linked. No media file is bundled in the image.

**Preserve the existing mode: `force-modesetting=false` is intentional.** On
build 688, `force-modesetting=true` reached GStreamer's `PLAYING` state but left
the CRTC disabled with no framebuffer attached. A simple SMPTE test pattern
also failed through that forced-modesetting path, ruling out H.264 decoding as
the sole cause. An ordered live rebind restored an enabled connector, but forcing
a new mode blanked it again. Stopping that player restored the existing mode;
the pipeline above then produced visible video. DRM reported CRTC 33 active,
plane 31 attached with framebuffer 39, XR24 format and 1920×1080@60 scanout.
This is not proof of native 24 Hz output: the source file is 1080p at 24000/1001
frames/s, displayed in the existing 60 Hz mode. No new kernel fault markers
occurred. The precise forced-modesetting defect remains unresolved.

For an explicitly requested loop, run the same pipeline in a transient systemd
unit with `Restart=on-success`, `RestartSec=1`, `KillSignal=SIGINT` and
`TimeoutStopSec=5`. It restarts after normal EOS, stops on playback errors, and
is not enabled at boot. The live unit on build 688 is `dt510-shake-loop.service`;
stop it with `sudo systemctl stop dt510-shake-loop.service`. Startup was verified
active/running with HDMI enabled; a completed repeat is not yet separately
observed. Do not install an automatic driver-rebind or player startup service as
a substitute for repairing HDMI startup.

KMS mode switching remains a pending acceptance check, not a claimed pass:
on build 682, a native 1280×720@60 test was accepted by KMS but the camera showed
black video. Ordered full rebind restored 1080p and the pattern.
The connector advertised 1080p at 60/50/30/25/24 Hz and 720p at 60/50 Hz; repeat
native 720p and 1080p geometry tests after deploying the sleep-address correction.
No 4K support is claimed.

The batched next-build candidate also pins the published distro product-feature
architecture. DT510 factory configuration must explicitly select `alsa` and
`usb-gadget` in `DD_PRODUCT_FEATURES` to preserve existing codec/gadget support
under its new minimal defaults. Direct KMS diagnostics need no `display`/Weston
bundle. Do not silently drop existing audio while adding video diagnostics.

**Delivery status (17 November 2026):** build 688 is the confirmed active board
image following a successful full UUU flash, OSTree
`46f0503279885af4b569d2366432803df1c6cb68c0743712734970904142f989`,
version `5.0.9-688-96`, manifest
`6ca81f8bcbdfcedc786a89e94b8830de98d6dc5e`, BSP
`50dde762ffa25592c37f65b1c4a3f8b29ab32968`. Build 688 intentionally rebuilds
687's unchanged source pins. Build 683 failed at an optional
Godot append; distro repair in 684 fixed that parse failure. Patches 0034/0035
are deployed since 685; patch 0036 is deployed since 686. The 100 kHz I2C3
candidate shipped in 687/688 but **did not fix startup**. Build 688 boot
`35401d64-d1ef-425b-825c-75c2ad345047` reported `EDID power-on failed: -11` at
3.324152 seconds, with an initially disconnected/disabled connector and no EDID.
One later live `detect` request recovered 256-byte EDID and modes without reset,
rebind or reboot: 3,076 I2C trace records were retained with no overruns and
zero failed transfer results. Actual visible playback subsequently required the
ordered display-master/bridge rebind and existing-mode pipeline described above.
Alex confirmed that picture; reliable cold/warm startup remains unproved.

**Boot safety:** the clean image boots with `root=/dev/mmcblk2p2` and no injected
tracing options. Later live boot-option tracing edits on 687 preceded a boot
failure; their exact parsing failure was not proved. Do not edit BLS entries,
`/boot/loader/uEnv.txt`, bootloader environment or kernel command-line options
for further HDMI diagnosis. Use scoped live tracing only; do not reboot merely
to collect diagnostics. The successful 688 live tests kept the boot ID unchanged.

### Boot-time clock-switch trace and next controlled candidate

Build 686 reproduces `EDID power-on failed: -11` after software reboots as well
as its original boot. On boot `40898ee5-df3d-4fef-ae79-58e9e01c25d9`, kernel
I2C tracepoints captured the first adapter-2 `-EAGAIN` and stopped tracing.
There were 94 adapter-2 write/result records and zero overruns:

| Operation | Kernel time (seconds) | Result |
| --- | --- | --- |
| Select LT9611 page `0x81` | 2.675249–2.677330 | success |
| Write `0x8101 = 0x18` (select crystal clock) | 2.677333–3.179947 | reported success, **502.614 ms** |
| Read page selector (`0xff`) | 3.179951–3.180120 | **`-EAGAIN`** |

The pinned i.MX controller's STOP path waits up to 500 ms for an idle bus but
does not propagate that wait's error. The observed duration is consistent with
that timeout; the trace alone does not prove the controller status bits or an
electrical cause. The first error precedes the DDC/EDID command sequence, so an
EDID completion delay does not repair this failure.

A later ordered display/bridge rebind on the same boot completed the identical
clock-switch write in **0.279 ms**, with zero failed transfers and zero trace
overruns; connector detection and 256-byte EDID recovered. This is recovery,
not a boot or visible-video acceptance pass. Both temporary boot-option changes
were restored, and tracing was disabled. Boot and rebind traces were retained
under `/var/lib/dt510-hdmi-debug/` on the development board. An earlier capture
stopped on the switch's initial `-ENXIO`, so it is not HDMI failure evidence.

The 687/688 controlled candidate restored shared I2C3 to **100 kHz**, instead of
its experimental 400 kHz DT request. The pinned controller already implements
ERR007805's 384 kHz limit, so the old request must not be described as proof
that the wire actually ran at 400 kHz or that this erratum fix was absent.
The LT9611 sequence/retry count, other bus clients and all other pins remain
unchanged. Compiled-DTB preflight checks the new frequency and LT9611 parent.
This tests bus-timing sensitivity; **100 kHz is not yet a demonstrated fix**.
Acceptance requires a boot trace without the long clock-switch transfer or
I2C errors, valid EDID, actual picture, repeated cold/warm boots, and the existing
mode/format/hotplug tests. If it persists, inspect crystal readiness and the
controller's STOP/idle state rather than lengthening EDID polling.

**17 November follow-up:** 687/688 reproduced the startup failure at 100 kHz;
do not describe that candidate as an outstanding untested fix. Michael's register
manual (`LT1702_Register_List_Preliminary-cover LT9611.pdf`, printed page 12,
register `0x8101`) defines bit 4 as ring/crystal system-clock selection; reset
value is `0x08`, and writing `0x18` selects crystal without changing the low
ring-bias bits. The supplied `lt9611_v1.6.c` writes page `0x81`, register `0x01`
value `0x18`, then immediately selects page `0x82`; it specifies no intervening
clock-settle sleep. This confirms the operation being investigated, not a cause
or an endorsement of a different delay.

The next distinguishing evidence is the first failing transaction's controller
STOP/idle/arbitration state and, ideally, SCL/SDA plus crystal readiness at the
bridge. A long STOP wait followed by `-EAGAIN` cannot by itself distinguish an
electrical clock-switch disturbance from controller recovery behaviour. Do not
introduce a longer blind sleep, another unchanged factory retry, or unsafe early
boot tracing options to bridge that evidence gap. An electrical capture needs
Michael's physical probe access; no such capture has been obtained.

Public sources checked during this investigation:

- [Upstream sleep-address proposal](https://lkml.iu.edu/hypermail/linux/kernel/2601.3/03089.html)
  and [independent bench confirmation](https://lkml.rescloud.iu.edu/2601.3/08811.html).
  These concern resume/replug address loss, not proof of this startup cause.
- [i.MX single-master bus-polling change](https://github.com/torvalds/linux/commit/6692694aca86ddf6831e2be86e5089258c2789bf)
  and its [STOP-condition correction](https://github.com/torvalds/linux/commit/768776dd4efc681cdca33a79e29bb508d6de9bc0).
  Neither is imported blindly: single-master topology must be verified, and
  skipping STOP polling would reproduce a known upstream regression.
- [ERR007805 frequency-limit implementation](https://github.com/torvalds/linux/commit/39c025721d706eb4fa8a5a7a376c93a3162b71bc),
  already present in our pinned controller driver.

The pinned controller also returns from its pre-transfer idle-error path
without balancing a successful runtime-PM get. This is a source-level defect
for follow-up, not evidence that it caused the first failed transfer; no broad
controller or power-management change was included in the 100 kHz candidate.

### Single-master I2C3: deployed in 689, startup still fails

Alex confirmed on 17 November 2026 that i.MX is the only master on I2C3;
the LT9611, KSZ9896 and BQ25792 share that bus as targets. The KSZ9896C data
sheet DS00002390C, section 4.9.2, describes its management interface as an I2C
slave. Do not infer this topology for other buses or boards.

Patch `0037-i2c-imx-support-single-master-with-stop-polling.patch` adapts
upstream `6692694aca86ddf6831e2be86e5089258c2789bf` together with correction
`768776dd4efc681cdca33a79e29bb508d6de9bc0` to the pinned NXP driver. Its
intermediate upstream version must not be used: skipping the polling helper
entirely loses STOP generation and leaves the stopped flag stale. This combined
version skips arbitration/start-busy checks only on explicitly single-master
controllers, clears stopped on START, and retains IBB idle/STOP polling.
The pinned NXP transfer-completion function has no separate IAL check, so no
nonexistent upstream transfer-completion hunk is added. Controllers without
`single-master` retain the existing multi-master path. Only DT510 selects this
patch, and only its I2C3 gains the property; its bus speed remains 100 kHz.

Source/native validation passes: all seven HDMI/controller patches apply to
the pinned kernel without offsets/fuzz; the actual patched bus-polling function
passes 22 compiled single/multi-master, START/STOP, stale-IAL, stuck-bus timeout
and atomic/sleep-path cases. The compiled DTB has `single-master` only on I2C3.
These tests verify the polling helper, not physical bus recovery or propagation
of STOP errors through the existing void STOP function. Existing HDMI/EDID,
LCDIF, reset/lifecycle and retry tests also pass. Two pre-existing non-HDMI DT
warnings remain. No local Yocto/kernel build was run.

Build 689 deployed this candidate and still failed on initial power-on, now with
`-ENXIO` (`-6`, an I2C NACK) rather than `-EAGAIN`. The failure is before the
EDID/DDC read. Its exact register and address-versus-data phase are not captured.
The earlier 500 ms STOP wait remains a suspect, not a proved cause on 689.

### Temporary KSZ9896 startup-isolation experiment

On the same 689 boot the KSZ driver failed its chip-ID read at I2C address
`0x5f` with `-ENXIO` at 2.527889 s, before the LT9611 revision read succeeded
at `0x39`. These distinct addresses do not collide. Linux serializes I2C
transfers, so shared-bus use alone does not establish a software race. An
electrical/shared-controller disturbance or switch-reset effect is unproved.

For one diagnostic build, set only `ksz9896_sw` to `status = "disabled"`.
Retain the FEC node and its pinctrl, I2C3 at 100 kHz with `single-master`, the
charger, all HDMI nodes and all seven existing patches. This prevents the KSZ
driver's boot probe and its reset writes; it does not electrically isolate the
switch, guarantee a reset-pin level or rule out passive loading/power effects.
Ethernet DSA ports are unavailable in this image. Restore the switch node and
its diagnostic preflight expectation after the experiment; do not ship this
temporary setting as the product fix.

Acceptance: verify the deployed image identity and live disabled switch node,
absence of the KSZ probe, and the **first** LT9611 power-on/EDID/scanout result
without reload, rebind or cable/TV changes. Compare like-for-like warm starts
with 689; subsequent cold starts remain required before claiming reliability.
A pass implicates the removed probe/reset activity, but does not distinguish
its individual effects or prove that the switch is electrically faulty. A
failure excludes those driver actions as a sufficient explanation for that
attempt, not every possible hardware interaction. Do not add HDMI retries,
delays, driver fixes or boot-option edits to this isolation image.

Source review also found unchecked HPD/sleep/wake I2C errors and discarded
i.MX STOP errors. They remain separate follow-up findings, not changes in this
experiment. The connector uses HPD-only notification, so a failed initial
detection can remain stale until another event. First-failure ACK/STOP capture
is still needed to identify the underlying bus/register failure.

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
It was absent from 682 and is deployed in 684; it did not resolve cold-start EDID.
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
  Deployed in 684; startup remains unresolved. No automatic rebind is installed.
- `0034-drm-imx-lcdif-check-fb-modeset-before-bridges.patch`: decide format/stride
  full-modeset requirements before `drm_atomic_helper_check`, not in its later
  plane-check stage. The late decision omitted connector/bridge atomic states,
  triggering WARN_ON in bridge disable/post-disable/pre-enable/enable on 684.
  Native regression compiles the actual new check and reproduces the old ordering
  failure. It covers unchanged flips, format/stride transitions, multiple planes,
  enable/disable and error propagation; it is not a full kernel or hardware test.
- `0035-drm-bridge-lt9611-poll-edid-and-check-i2c-errors.patch`: retain the vendor
  5–10 ms command-settle time, then poll completion/error at 5 ms intervals with
  a 100 ms polling budget per 32-byte chunk. This budget is a software bound, not
  a vendor-specified maximum or proof of the original failure cause. Check setup,
  request, status, FIFO, release and power-on errors; reject done-with-DDC-error.
  Native tests exercise the actual reader with delayed completion, timeout,
  NACK/arbitration errors, each transfer failing and cleanup error precedence.
  Physical DDC/startup behaviour still requires testing on the new image.
- `0036-drm-bridge-lt9611-retry-power-on-arbitration-loss.patch`: retry only
  `-EAGAIN` in the idempotent power-on register sequence, at most three total
  attempts with 1–2 ms backoff after retryable failures. The pinned i.MX adapter
  leaves `retries` zero-initialized; the core therefore makes just one attempt
  unless another user explicitly changes that setting. Other errors still fail
  immediately; exhausted retries leave `power_on=false`. Recovery is logged.
  The actual compiled function is tested with errors at every sequence position,
  recovery on attempts two/three, exhaustion, cached success, later reprobe and
  permanent errors. This is bounded handling of a proven returned error, not
  proof that three attempts cover every physical startup failure.

On 684, the first warning was at boot monotonic time 1203.27 s in
`drm_atomic_bridge_chain_disable`, from `videotestsrc0:s`; subsequent video
threads triggered the same missing-old-bridge-state assertion. The trace reaches
`drm_atomic_helper_update_plane` / `drm_mode_setplane` through LCDIF commit.
The exact pinned LCDIF plane check sets `mode_changed` on format/stride changes
after the generic modeset check has already collected affected bridge states.
The board remained responsive; these were kernel WARN stack traces, not evidence
of a fatal panic. They are nevertheless a failed display test, not harmless noise.

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
