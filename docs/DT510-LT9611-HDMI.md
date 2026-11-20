# DT510 LT9611 HDMI bring-up

Updated 19 November 2026 at Alex's request. Briar helped draft this.

## Current state

Michael reported the hardware cause on 19 November: the 27 MHz crystal did
not oscillate on three failed boots. After adding a **1 MΩ resistor across the
crystal**, the console appeared during all three subsequent boots. This is
Michael's scoped bench observation relayed by Alex, not an independently
reviewed PCB ECO or field-reliability qualification. Record the resistor in the
next hardware revision; software delays are not a replacement for it.

On Alex's requested reboot of image **698**, Alex confirmed that the normal TV
console worked but the U-Boot splash did not appear. Read-only inspection found
the new `lt9611_dt510` code in both eMMC U-Boot copies. After reboot Linux
reported HDMI connected/enabled. A read-only FAT16 root-directory check found
`active-edge-splash-1280x720.bmp` **absent from the boot partition**. Thus this
attempt did not exercise visible splash output; driver-code presence alone was
insufficient. No second reboot, flash, artwork copy or boot-option change was made.

The cleanup in build 699 removes experiments **0036–0044**, their recipe entries and
controller-only test harnesses, including inactive ring-clock/one-second-delay
patch files. Standard crystal selection and ordinary first-error returns remain.
The I2C controller and regmap sources now match the pinned kernel byte-for-byte.
Remove the experimental `single-master` and GPIO bus-clear DT properties,
restore the pre-startup-experiment 400 kHz setting and enable the KSZ9896 switch.
The 400 kHz setting restores prior source behavior, not fresh electrical
qualification of Fast-mode with every shared-bus client.

Keep patches **0031–0035**: reset polarity, NXP host/connector/IRQ support,
sleep-address preservation, the LCDIF atomic-state crash fix and EDID error/
completion handling. Keep manual overscan/console/video tests and the optional
U-Boot display feature. Private captures and Git history retain the retired
experiments; historical sections below are not the current recipe/configuration.

Build **699 passed** and is running on the board. Its packaging correction
includes the BMP in `lmp-boot-firmware` and loads it from the resolved OSTree
deployment after the common header, with FAT-root fallback. A further watched
reboot completed the boot-firmware update: recorded and payload versions both
`81341805870a3eba1aff03a616b6f3dc`, update flags clear, primary boot selected.
The installed bitmap has the expected size and SHA-256.

Passive serial capture on the next watched reboot showed U-Boot selecting the
1280×720 LCDIF/DSI/LT9611 chain, loading the bitmap and reporting
`AESL U-Boot HDMI splash displayed`. Alex had not seen the splash; this message
only proves the software draw path returned success, not a physical HDMI image.
U-Boot text remains serial-only. Linux subsequently reported HDMI connected
and enabled. The serial port was captured at 115200 baud, with no transmitted
bytes or boot/environment changes.

Build **700 passed**, is installed, and completed its primary boot-firmware
update (recorded and payload version `03efb4dac335d9a23a7c5f28c195b3c7`, update
flags clear). Serial capture recorded the successful drawing command and both
10-second hold markers, but Alex still saw no U-Boot HDMI image. The Linux TV
console worked. The hold therefore did not establish a working U-Boot signal.
U-Boot text remains deliberately serial-only; absence of HDMI text alone is not
an additional fault.

The diagnostic holds the verified, successfully drawn splash
for **10 seconds** before continuing to Linux, with serial start/end markers.
Missing/corrupt artwork and failed display paths do not wait. The pause is a
temporary visibility/TV-lock test, not a crystal-startup workaround or a claim
of working HDMI output. Remove it after establishing the cause and choosing
product splash duration.

**Current repair candidate:** source inspection found two missing checks, not
yet a proven explanation for the absent image. SEC DSIM attach discarded
clock-setup and PHY-preparation errors; it now preserves those errors, cleans
up a failed preparation and reports successful lane/clock/status values on
serial. The LT9611 path previously enabled TX without verifying input. After
LCDIF starts pixels, it now checks the plain-LT9611 Linux driver's video
counters: port-A active bytes must be 3840, active lines 720, total lines 750,
and horizontal total in system-clock units nonzero. Two consecutive valid
samples are required, with at most 20 samples 25 ms apart after the existing
500 ms settling interval. Missing/incorrect input or I2C errors keep TX disabled
and return failure; the splash failure path continues to Linux without the hold.
No undocumented PLL-lock bit, reset retry or oscillator workaround is added.

Actual-source native tests cover counter/I2C faults, late/invalid input, bounded
waits, DSIM error propagation and cleanup, and LCDIF failure teardown. A negative
control reproduces the swallowed error in the pinned original DSIM attach.
The updated source also passes a direct U-Boot cross-build; these are software
checks, not physical HDMI proof. Factory build and a watched serial/TV retest
remain required. Linux, device tree, boot arguments, persistent environment and
update/recovery behavior are unchanged. The separately requested graphical
distro remains pending and is not included in this repair.

### Build 703 failure and i.MX8MM signal-inversion correction

Alex's watched reboot of Linux image **703** still showed no splash. Serial
captured 3840 active bytes, **55 active lines**, 746 total lines and 601
horizontal system-clock units; TX remained disabled and Linux booted normally.
The horizontal timing change did not resolve the failure. Recorded firmware
version was `3afe0ff20b86055065921d6c788d6847`, with upgrade flags clear.

The earlier DE analysis below missed the i.MX8MM's hardware inversion between
LCDIF and DSIM. The pinned kernel's actual NXP LCDIF implementation is
`drivers/gpu/imx/lcdif/lcdif-common.c`, not the generic DRM MXS driver. Its
`imx8mm_pdata` sets `hsync_invert`, `vsync_invert` and `de_invert` to true.
Consequently logical high HS/VS/DE at DSIM requires all three LCDIF polarity
bits to be **clear**. Build 703 U-Boot set all three bits instead.

Upstream Linux also explicitly documents this Mini/Nano glue inversion in
[`samsung-dsim.c`](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/bridge/samsung-dsim.c).
The correction is limited to the optional plain-LT9611 DT510/i.MX8MM MXS path:
keep the bridge's logical positive-sync timing, but translate it to active-low
LCDIF HS/VS/DE before programming LCDIF. Keep legacy feature-off, other-panel
and other-SoC behavior, DSIM packet counts, LT9611 timings and strict input
verification unchanged. No Linux, device-tree, boot-environment or update-policy
changes are involved. Actual-source tests execute both this mapping and LCDIF
register programming; an expected value copied from logical flags is not enough.

The separate upstream U-Boot
[pixel-clock edge fix](https://github.com/u-boot/u-boot/commit/ff1932daab1e6381e0b26d69a0197dfb2cd7168f)
changes NEGEDGE to POSEDGE in the LCDIF condition. Neither flag is selected in
this fixed mode, so that patch alone would not change its clock polarity and
is not bundled into this repair. Physical HDMI remains unproven until a new
firmware image is installed and a watched serial/TV test succeeds.

### Build 702 watched retest and 720p sync-pulse correction

Build **702 passed** and completed the watched primary boot-firmware update to
`90ca9d34cffd637f1dcee244aa88b020`; recorded and payload versions agree, upgrade
flags are clear and primary boot is selected. The new primary U-Boot still read
3840 active bytes, **55 active lines**, 746 total lines and 600 horizontal
system-clock units. It kept TX disabled and skipped the splash. Linux 702 booted
and was reachable over SSH. Thus the DE correction alone did not establish
working U-Boot output; this is not an old-firmware/update failure.

The next source correction follows the pinned Linux driver's explicit
four-lane, sync-pulse **1280×720@60** workaround. Linux
`drivers/gpu/drm/bridge/sec-dsim.c` adds two pixels to horizontal sync start/end
and total for this exact mode because the unadjusted standard timing cannot
display correctly. This adds two pixels only to the horizontal front porch:
112 instead of 110, total 1652 instead of 1650. Pixel clock, active area, sync
widths and all vertical values remain unchanged. Apply the same adjusted
horizontal values to the LT9611 timing registers; do not alter Linux or shared
DSIM behavior. Advertise VIC0 (custom timing) and update the AVI checksum, as
DRM's exact CEA timing match no longer identifies the adjusted total as VIC4.
Linux's four-lane blanking-table values are HFP/HBP/HSA
**78/159/24**; actual U-Boot DSIM register tests show the old front porch yielded
77/159/24 and the correction matches all three Linux values. The initial red
regression and an explicit old-timing negative control preserve that distinction.

Actual LCDIF, DSIM and LT9611 timing tests now agree on the adjusted mode. The
input gate still requires two valid 1280×720/750-line samples before TX enable;
it is not relaxed to accept the failing measurement. This is a documented
source-parity correction, not proof of the remaining physical root cause.
Updated cross-build, independent review, factory image and watched TV/serial
test are required before declaring U-Boot output fixed.

### Build 701 watched retest and DE correction

Build **701 passed** and completed its primary firmware update to
`a9f929508c9995771498bc6114e4d3b4`. The fresh serial capture shows successful
four-lane DSIM preparation at 74.25 MHz pixel/445.5 MHz bit clocks, but the
LT9611 input check read 3840 active bytes, **55 active lines**, 745 total lines
and 600 horizontal system-clock units. TX stayed disabled and the splash was
skipped. Linux booted successfully but Alex saw no picture. Its connector
reported connected/enabled; that status did not prove a physical image.

Alex requested a live test without a full build. With no graphical client,
detaching the `imx-drm` display master, then the LT9611 bridge, and rebinding
bridge first/master second completed successfully without changing the boot ID.
The packaged native 1080p edge pattern was displayed and **Alex confirmed it
was visible**. This proves live Linux recovery on that boot, not reliable
startup or a working U-Boot splash. The running edge image is intentionally
left displayed while source work continues.

**Historical interpretation, superseded by the inversion analysis above.**
Source comparison found an apparent polarity mismatch: pinned Linux
`drivers/gpu/drm/bridge/sec-dsim.c` explicitly requires active-high DE, whereas
U-Boot `drivers/video/mxsfb.c` forcibly clears `DISPLAY_FLAGS_DE_HIGH` for SEC
DSIM. The next candidate preserves high DE only for the optional DT510/plain
LT9611 path and declares the flag in its fixed timing. Other panels and
feature-off behavior remain unchanged. An actual-source regression fails with
the old polarity override and passes with the correction; the real LCDIF
initialization and register definitions are also tested. This explains a real
source discrepancy, but whether it corrects the measured line counts and TV
output still requires the next watched hardware test. The existing input gate
and nonfatal Linux continuation remain; no speculative PLL bits are added.

The image candidate also packages **manual-only** `dt510-hdmi-recover` in the
existing DT510 test package. It follows the successful detach/rebind order,
checks driver/chip/board identity, refuses saved display tests and active or
unverifiable DRM clients, and attempts restoration after partial failures or
handled interruption. It never writes raw I2C, reloads a shared adapter, reboots,
changes boot settings or runs at startup. Explicit recovery can fail; inspect
the result and stop rather than retrying blindly.

```sh
sudo dt510-hdmi-test restore  # only if a saved image/console test is active
sudo dt510-hdmi-recover
sudo dt510-hdmi-test show
```

Helper tests cover ordering, wrong board/chip/binding, saved tests, active or
missing DRM-client information, partial detach and failed restoration. No
automatic rebind service is installed. Factory packaging and physical U-Boot
acceptance remain pending for this candidate.

### Historical build 697 — before the hardware repair

Build **697 passed but did not fix natural startup**. The last observed image
is `5.0.9-697-96`, OSTree
`64ef9e12b3e5500113c82034261b5472c1cc621d0fff806964495139b406106d`,
boot `ffaef5e6-8537-4505-98e8-c41893ecd2f3`.
Target: <https://app.foundries.io/factories/vixdt/targets/697/>.
After a controlled warm reboot from working HDMI, both clock-select attempts
again had three ACKs and three IRQs. A measured 51.338 ms pre-STOP delay did
not prevent the roughly 513 ms STOP timeout, recovery `-16`, and later address
NACK. The LT9611 remained unbound and no HDMI connector appeared. The board
was left running without manual recovery. This is not only a cold-power symptom.

Earlier on 697, late normal reprobes succeeded with both 50 ms and zero added
pre-STOP delay (STOP 26.125 and 13.125 microseconds respectively). These do not
prove a startup fix or distinguish elapsed time from bridge/bus state. The
upstream i.MX single-master STOP fix is already present. Recovery evidence
indicates SDA read low during recovery, not which device held it or a measured
crystal fault. Do not keep increasing blind delays.

### Optional U-Boot AESL HDMI splash — implementation, not hardware proof

Alex requested testing initialization before Linux, reusing the Jaguar Screen
splash approach. This is a hardware-specific **MACHINE_FEATURES** switch,
`hdmi-boot-splash`, enabled by default on DT510, not a DISTRO_FEATURES switch.
Disable it in subscriber configuration with:

```bitbake
MACHINE_FEATURES:remove:imx8mm-jaguar-dt510 = " hdmi-boot-splash"
```

The feature is removed for `lmp-mfgtool`; manufacturing/recovery U-Boot stays
on its original path. Other boards are unchanged. U-Boot proper (not SPL)
uses a separate control DT, plain LT9611 on I2C3 address 0x39, active-low
GPIO2_IO11 reset, four DSI lanes on port A, fixed CEA-4 1280x720p60 RGB888.
EDID negotiation, HDMI audio and Linux takeover are not implemented here.

NXP SEC DSIM requires a panel-class endpoint even though the device is an I2C
bridge. Its panel-enable callback attaches DSI and configures the bridge with
HDMI TX disabled. SEC DSIM's host-enable function is a no-op in this pin:
LCDIF starts the pixel stream later. An LT9611-only LCDIF completion hook then
calls the DSIM bridge again (100 rather than the initial 80); only this final
call waits 500 ms and enables TX. Other panels do not get the extra call.
Output-enable failure removes the bridge and stops LCDIF, preserving the first
error. Every I2C write/read and reset operation propagates its
first error. Crystal selection still uses the standard `0x8101=0x18`; it could
fail in U-Boot too. Success messages are not proof of a visible picture.

The signed boot script loads at most 2,764,854 bytes to the EVK's existing
0x50000000 splash scratch address. It checks exact size and SHA-256 before
`bmp display`. Missing/corrupt artwork or display failure is non-fatal. The
renderer also fails the build if its output does not match that digest, so
Pillow/rendering drift cannot silently ship an unusable splash. The
original boot/update body is unchanged apart from this optional fragment;
no root arguments, BLS, persistent environment or partition layout is changed.
The WIC boot partition receives the BMP. It is also included in the ordinary
`lmp-boot-firmware` payload so OTA can deliver it with the current deployment.
The optional fragment runs after the unchanged common header resolves
`ostree_bootpart` and `image_dir_path`; it first uses bounded `ext4load` from
that deployment, then falls back to the FAT root. No new environment-save,
root-argument rewrite or copy service is introduced. An OS version alone does
not prove bootloader/artwork installation or a visible splash.

Inputs: meta-lmp `4dffdff79b4df49c683c9a7faea406595cb7e9ca` selects U-Boot
`imx-2024.04`, source `adbe53791d8f3cc2d7ecf2a3f308494d561def9e`.
The existing screen artwork comes from BSP
`bcc4b64876191901c1cd4a897e30c2d9511becc6`; its PNG SHA-256 is
`70469b3d038df99f829b0ed0fc3f09b8a16ed05a85f6d03ad2a382418a5bd67e`.
It is fitted without stretching into a landscape 1280x720 24-bit BMP, SHA-256
`64b2f36f6305a8012d9dbab4ec2a266aba9f023bb4f4294eb30754dd37573da3`.
Earlier screen work supplies packaging/artwork, not proof of a hardware-tested
U-Boot splash on either board.

Validation: native actual-source driver tests with ASan/UBSan, per-operation
I2C/GPIO/attach faults, actual LCDIF plus NXP callback ordering/cleanup (including
the no-op host-enable behavior) and feature-off behavior,
actual recipe unpack-hook tests, non-fatal script paths and bitmap checks.
Direct U-Boot cross-compilation passes with pinned Foundries common/EVK and
current DT510 fragments. This is not a complete BitBake image/signing build.
Run `scripts/dt510-uboot-splash-test.py --uboot-source /path/to/patched/u-boot`
to include the actual NXP callback regression. Independent review, factory
build and physical splash/cold/warm startup tests are still required. Linux
currently resets/reinitializes the bridge: a U-Boot picture would not establish
seamless handover or resolve the Linux startup problem by itself.

## Historical investigation — retired experiments, not product settings

### Previous 696 evidence

The earlier image
is `5.0.9-696-96`, OSTree
`cac16a3446c559f925cfe92ef6224d54a65fc529536b705e01864449c84811c1`,
boot `de154364-f7dd-4fb7-a1e2-62b3e7dcf602`.
Target: <https://app.foundries.io/factories/vixdt/targets/696/>.
Patch **0043** establishes that all three clock-selection bytes were ACKed and
all three IRQs arrived. Initial START, runtime resume and bus-idle checks
succeeded. STOP then waited about 504 ms for IBB to clear and returned `-110`;
bus recovery returned `-16`. Post-disable status `0x81` is not a final-byte NACK.
The LT9611 probe aborted before IRQ/DRM bridge publication. No matched kernel
oops was found. This localizes the failure but does not identify its electrical
cause or prove oscillator startup time.

### Controlled live isolation on 696

At 11.26 seconds, the LT9611 was unbound and the display master remained bound.
Holding controller runtime PM on did not resolve the address NACK. An LT-only
GPIO reset **plus** the standard `0x80ee=0x01` I2C initialization restored
revision `0xe1` and ring-clock selection `0x08`, with controller PM held on and
master still bound. This is not reset-pin-only evidence.

After restoring PM auto, detaching the master and rebinding normally, the first
clock-select `0x18` still failed (raw 522.705 ms, STOP 515.142 ms). The driver's
reset retry succeeded: raw 27.306 ms, of which STOP was 26.811 ms, with all bytes
ACKed and IRQs delivered. A previous healthy STOP took only 11.625 microseconds.
The outer ftrace timings include about 60 ms of post-transfer diagnostic printing
and must not be called oscillator/STOP duration. Master detach alone was not
sufficient; delayed recovery is also confounded by LT state changes.

HDMI was restored to connected/enabled with a 256-byte EDID and valid checksums;
physical picture was not checked in this pass. Temporary test services were
removed, PM auto and tracing restored, updater left running. No boot options
were changed. Private captures are retained in the existing diagnostic work record.

### Failed experiment: post-final-ACK/pre-STOP settling (0044 / 697)

Patch **0044** retains0042/0043 and adds a sleepable **50 ms** delay after the
successful final ACK of page `0x81`, register `0x01`, value `0x18`, before the
controller issues STOP. This is an experiment, not a vendor timing requirement
or a proven fix. The earlier failed one-second delay was **before** the write,
not at this boundary. Timeouts, error propagation, retries and boot options
remain unchanged. The longer transaction can delay other clients on this bus.

Qualification requires the DT510 machine, adapter2, enabled plain-LT9611 DT
child at0x39 and an immediately preceding successful standalone page81 selection.
Other LT accesses, failures and atomic accesses invalidate the conservative
page hint; out-of-band resets cannot be inferred from I2C traffic. There is no
delay for atomic transfers, failed bytes, unrelated devices or other banks.
Three byte-wait and four IRQ samples stay bounded; printing remains after the
transfer. `start_initial` describes initial START only, not repeated START.
`DT510-SETTLE` reports eligibility, requested microseconds and measured
nanoseconds separately from STOP duration. Zero phase fields can mean a phase
was never reached; they do not by themselves establish success.

Root can select only **0 or 50000 microseconds** for subsequent transfers:

```sh
echo 0 | sudo tee /sys/module/i2c_imx/parameters/dt510_lt9611_stop_delay_us
echo 50000 | sudo tee /sys/module/i2c_imx/parameters/dt510_lt9611_stop_delay_us
```

Other values are rejected without changing the setting. The compiled default
is50000 on every boot; this live control does **not** provide reboot A/B testing
at0. Do not edit boot arguments to obtain that comparison. Native actual-source
tests cover0/50000, qualification, page invalidation, errors, atomic paths,
measurement and post-ACK placement; they are not kernel or cold-boot proof.
Independent review, CI, the new Foundries build and startup acceptance remain
outstanding at preparation time. Successful builds do not establish deployment.

### Earlier build 692 evidence

Build **692** passed and automatically booted as `5.0.9-692-96`, OSTree
`4329d616c377837ba7e6589f9934b6eab2cba97d82bbd253a7699b633098a7b8`,
boot ID `d46286f2-97ac-4fb7-b8c6-b5b18a01ec58`. HDMI remains disconnected,
disabled, with zero EDID bytes and inactive scanout. This observation made no
manual reboot, detect, driver reload or boot-option change.
Target: <https://app.foundries.io/factories/vixdt/targets/692/>; manifest
`9ed64a3ba39433f1db1c532c5d76929d7fa93661`, BSP
`202fc0deb70b6bcdbf7d4ec42b8fe36ae733b607`.

At 3.241915 s, STOP waits 504 ms and fails `-110`; standard bus recovery
returns `-16` (`-EBUSY`) at 3.254505 s. Crucially, the driver now reports the
failed write as **logical `0x8101`, value `0x18`, return `-110`**. Initialization
retries, but the page-selector address-ACK check fails `-6`, with I2SR `0x91`
and I2CR `0xd8`. Power-on fails at 3.300738 s before reading TV EDID. There
were no matched kernel warning/oops/panic headers in this read. Error propagation
works, but attempted bus recovery does not establish a startup fix. `-EBUSY`
does not by itself identify the electrical fault or the device holding a line.

### Next candidate: clock initialization before publication, one reset recovery

Build **694 passed but did not fix startup**. It booted as `5.0.9-694-96`,
OSTree `a70508b65f7713a6396e73c99c34aaf8a79b290c77464c32444f92f247ed3990`,
boot ID `8bfe1377-b5f3-442e-9081-bade2ecc900a`. The first clock selection
still returned `-110` after a 504 ms STOP wait, bus recovery returned `-16`,
then address/page operations returned `-6` and EDID power-on failed. Initial
HDMI was disconnected/disabled with no EDID or active scanout. The extra second
is not a demonstrated correction and is removed from the active recipe.

Alex requested a better fix and then explicitly requested integration, review
and a build of the reset/reinitialization candidate. Active patch **0042** now
replaces 0041, applied directly after 0039; 0040/0041 remain historical files.
It initializes clock/power during probe, before HPD IRQ registration and DRM
bridge publication. On eligible clock transport errors (`-EAGAIN`,
`-ETIMEDOUT`, `-ENXIO`), it makes at most one further attempt starting from a
complete hardware reset and revision/I2C initialization. Revision failures and
other errors are returned immediately; a final failure follows the existing
probe cleanup rather than publishing a broken bridge. The existing power-on
transport retries remain bounded: at most six setup calls across two hardware
initializations. There is no infinite deferred-probe loop, new delay, reset from
an active DRM callback, rail/DT change, or boot-option edit. Subsequent EDID
calls retain the successfully initialized power-on state.

This follows observed recovery, not a proven root cause. In bounded live tests
on 694, DRM master was detached before the LT9611 driver and raw I2C was used
only while the bridge was unbound, with no forced busy-address override.
Verified target/boot, live reset phandle/line/polarity, GPIO controller and
always-on rail guards preceded writes. Both ring-setup-then-crystal and a
crystal-first control read back `0x18` and revision `0xe1` after hardware reset.
Both tests explicitly wrote/read the ring value first and used userspace I2C
subprocesses, unlike the exact early kernel path. The ~7.4/7.5 ms command times
include process overhead, not measured wire timing. The control also passed,
so reordering is NOT a demonstrated fix and these tests do not distinguish
elapsed time, reset or transaction spacing. The initial GPIO harness attempt
aborted before raw I2C because a completed toggle exits normally; hold handling
was corrected before the successful tests. Both driver bindings were restored
after each attempt.

After final restoration, the same 694 boot had connected/enabled HDMI, 256 EDID
bytes and active scanout (fb37). This is late recovery, not startup acceptance.
The camera was busy in another application and was not interrupted or visually
checked. No reboot, system startup service or boot-option change was made.

The new combined actual-C tests cover reset/revision/setup order, cache state,
one reset replay, exhausted transfer attempts, permanent errors and revision
errors on either attempt. Source checks place initialization before HPD polarity,
IRQ registration and bridge publication, and retain cleanup on failure. These
are native mock/source checks, not a full kernel build or hardware boot proof.
An immediate early reset may still fail even though late reset worked. Require
exact new image/boot identity, initialization/recovery logs, EDID/scanout and
visible output without manual intervention, then repeated cold/warm starts.
693 remains the successful ring-clock startup comparison; restore unrelated
development comparisons and qualify modes/hotplug/network before production.

### Previous comparison: delayed crystal selection, build 694 (18 November)

Alex requested a build of the crystal-settling experiment. Active patch **0041**
replaces **0040** in the DT510 recipe (0040 remains a historical file). Applied
directly after 0039, it adds `msleep(1000)` after the already-powered guard and
before the existing first write `0x8101=0x18`. The full wait is once per power-on
sequence, not per retry; existing retry bounds and STOP/error propagation remain.
All other register values, reset, rails, controller, Ethernet comparison and boot
options remain unchanged. This is a diagnostic interval, not a vendor-specified
startup time or production fix. Reset release already waits 100 ms.

Build 693 booted as `5.0.9-693-96`, OSTree
`3dfe6a51790bad9c4d3a7bb6fc9e12a11461c2a376a75df2ee6de1d38849ad2d`,
boot ID `6ba6aaee-df19-41e7-b426-6497c6c78e58`. Read-only inspection after the
requested warm reboot found connected/enabled HDMI and active scanout, with no
matched STOP/EDID-power-on failures or fault headers. A DPX USB-camera capture
independently showed the console. Alex subsequently relayed Michael's successful
cold-power-cycle display observation; that cold boot was not independently
inspected. These are startup observations, not timing or lifetime qualification.

Michael suggests oscillator startup time. Upstream and public vendor-derived
plain-LT9611 code select the crystal without an explicit settling interval;
searches found no verified fix for this exact failure. UXC/UXD reports are not
plain-LT9611 evidence. Vendor-derived Chip_ID code selects the crystal before
System_Init, so a claim that analog-power-first is the vendor fix is unsupported.
Hardware guide revision 0.4 section 1.5 specifies a 27 MHz reference under 50 ppm
for system clock and HDMI pixel-clock recovery. The externally supplied register
list is titled LT1702 despite its filename; do not derive new oscillator-control
bits from it without LT9611 confirmation.

The newly supplied `202600r1.pdf` is drawing 202600 rev1, HDMI sheet18 of25,
but the file contains only that single sheet. Static extraction and a private
byte-for-byte archive are complete under the workspace's local hardware-reference
directory; MemPalace indexing remains pending its unavailable service. It shows
U44 plain LT9611, passive 27 MHz X5 (12 pF annotation), two 18 pF loading
capacitors, and a 2 kOhm 1% REXT resistor. No independent clock-enable signal is
shown. Capacitor values alone do not demonstrate incorrect loading; no physical
startup/clock measurement has been made. The proprietary drawing is not published.

Acceptance for the next comparison: identify the new target and boot, observe
the first clock write and subsequent I2C/STOP errors, EDID, scanout and camera
without reload/forced detection. Repeat cold/warm starts only as requested.
A pass supports timing sensitivity, not a defective crystal or minimum safe
delay. A failure shows this elapsed-time delay was inadequate; do not blindly
increase delays or suppress errors. Retain 693 as the identified working
comparison; qualify modes/video and restore development-only comparisons before
production acceptance. No manual deployment/reboot is part of this build request.

Reference code checked:

- <https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/bridge/lontium-lt9611.c>
- <https://github.com/sipeed/MaixCDK/blob/main/components/3rd_party/sophgo-middleware/sophgo-middleware/v2/sample/mipi_tx/lt9611/lt9611.c>

### Temporary internal-clock comparison: build 693 (18 November)

Alex requested the build after the clock-source investigation. Patch **0040**
changes only the first system-clock write from `0x8101=0x18` to `0x08`:
bit 4 stays on the internal ring oscillator and bias bits remain `0x8`.
All prior patches, diagnostics, recovery, 100 kHz/single-master settings and
KSZ-disabled configuration remain unchanged. No new sleeps, retry counts,
boot options, reset, supply or manual board operations are included.

This is **not a production fix**. The frequency-meter constants and display/DDC
timings are not qualified against the ring oscillator. The vendor reference
drivers select the crystal with `0x18`, without a documented settling delay.
The hardware guide requires a 27 MHz reference at pin 18. At preparation time,
no HDMI schematic was available; the subsequently supplied sheet is described
above. There is still no physical clock measurement.

Compare first startup against 692: identify the exact image/boot, inspect the
first `0x8101` transfer and STOP/recovery errors, then report EDID and scanout
separately. I2C surviving on the ring clock would isolate dependence on the
clock-source transition; it would not prove a bad/missing crystal. Failure on
both selections would weaken that hypothesis and retain controller/shared-bus
causes. Do not accept video timing or a late manual recovery as startup proof.
Remove 0040 and its preflight expectation after the comparison, retain all
independently justified fixes, and complete Ethernet-enabled product tests.

### Previous diagnostic baseline: build 691

Build **691** passed and automatically booted on the board as version
`5.0.9-691-96`, OSTree
`b14052eb2e1b4797a2d2879a1c3c84175dc60c8d0200cfa88e524dc25b930bee`,
boot ID `2c3bdd33-7498-40f8-b270-6bdf53fa2afb`. Read-only inspection found
disconnected/disabled HDMI and zero EDID bytes. No manual recovery was performed.
Target: <https://app.foundries.io/factories/vixdt/targets/691/>; manifest
`5f7591da9c2b04dfb5333e276a7eb27222701da9`, BSP
`87b3b5eb1d2b612815937610c8c6e7ff4c81bde7`.

The diagnostic image identifies this order on its first startup:

| Boot time | Observation |
| --- | --- |
| 2.619234 s | LT9611 revision `0xe1` reads successfully. |
| 3.238612 s | STOP/idle wait times out after 504 ms; I2SR `0xa0` has IBB set. |
| 3.246039 s | Controller confirms STOP timeout `-110`, still ignored by 691. |
| 3.254110 s | Next address-ACK check fails `-6`; I2SR `0x91`, I2CR `0xd8`. |
| 3.263536–3.277938 s | Selector read `0xff` fails while selecting page `0x82` for write `0x821b=0x69`. |
| 3.285010 s | Power-on fails before the TV's EDID is read. |

`0x91` includes both RXAK and arbitration-loss IAL; I2CR has lost MSTA.
This is not proof of a clean target-address NACK. The first STOP stall follows
the crystal-clock-selection write, consistent with the earlier boot trace.
Electrical cause and crystal readiness remain unproved without a waveform.

### STOP recovery correction candidate (not deployed)

Patch **0039** retains STOP errors from write, PIO-read and DMA-read completion,
disables the controller, and attempts standard GPIO bus recovery once when
configured and non-atomic. It returns the original transfer error (or STOP
error when bytes otherwise succeeded); it never reports recovery as transfer
success or replays arbitrary client messages. Read STOP results are saved to
avoid another 500 ms wait. DT510 supplies the I2C3-only GPIO recovery state on
SCL GPIO5_IO18 and SDA GPIO5_IO19, preserving the default pad settings.
The existing Linux recovery path restores the I2C pinmux before returning.

LT9611 power-on may retry `-ETIMEDOUT` as well as `-EAGAIN` within its existing
three-attempt budget, replaying only its idempotent initialization sequence.
Permanent errors still return immediately. No boot-option, reset, regulator,
clock-selection value, delay or Ethernet-isolation change is made.
This corrects the confirmed hidden STOP failure and supplies a bounded bus-clear
path, but hardware must show whether it restores startup. It does not establish
why the clock transition stalls, nor justify hiding persistent electrical faults.

Native tests compile the actual STOP and transfer wrapper through 64 fault
combinations, including original-error precedence, failed recovery, no replay,
and atomic exclusion. Actual read STOP placement is source-checked rather than
whole-path compiled. DT compilation checks the GPIO phandles, lines, mux/pad
cells and restoration state. All nine patches and existing checks pass, with
two pre-existing unrelated DTC warnings. No local kernel/Yocto build was run.
Independent review, publication, Foundries compilation and hardware tests remain
required before acceptance. Keep 0038 diagnostics for this comparison.

Acceptance must distinguish a clean first startup from a recovered one: retain
any STOP/recovery log, validate EDID checksums, scanout and visible output, then
test cleaned-up cold/warm starts and Ethernet/charger/network/update behaviour.
Reassess 0039 and its GPIO configuration against those results; do not remove
a demonstrated necessary correction just because it began as a test candidate.

### Previous controlled baseline: build 690

Build **690** was booted on the board with OSTree
`8d914c045f907c952b80591dedb709e4f76f4f6782b7fef7dc451dbc7050fc2a`
and boot ID `73b7ae02-5d78-479c-afb8-9a6ac2546aca`. It was already running
when Briar began the approved deployment/test, so no duplicate installation or
extra reboot was performed. The live KSZ node is `disabled`, no switch driver
is bound, and this boot has no KSZ probe event. Nevertheless LT9611 revision
`0xe1` at 2.602908 s is followed by `EDID power-on failed: -6` at 3.227082 s.
Read-only inspection found disconnected/disabled HDMI, zero EDID bytes and an
inactive CRTC with no framebuffer. No driver reload/rebind or boot-option edit
was performed. This reproduces the failure without KSZ driver probe/reset
activity; it does not electrically isolate the switch or identify the first
failing I2C phase. The diagnostic image is **not** a startup fix.

### Startup investigation test plan (17 November)

Alex requested a testing plan and execution. Diagnose the first bridge-control
failure separately from stale connector state and pixel-output recovery. Do not
add another speculative build, boot arguments, arbitrary startup sleeps or an
automatic rebind service. Each live capture is finite and scoped; stop on its
result, retain reduced evidence, and remove only tracing created by this test.
Keep the TV input, cable and picture settings unchanged during comparisons;
record any external intervention rather than treating it as spontaneous recovery.

| Test | Action and controlled input | Decision / observable evidence | Status |
| --- | --- | --- | --- |
| T0: baseline | Reuse identified 690 boot, live disabled KSZ, initial failure and source review. Read current state only as prerequisite to the next action. | Identify build/boot and whether HDMI is still failed; never call a later recovery a startup pass. | Initial 690 failure captured above; KSZ probe/reset not required to reproduce it. |
| T1: capture readiness | Read available I2C tracepoints, filters and optional controller debug facilities. No register scan/read, boot edit or tracing reconfiguration yet. | Determine the smallest supported live capture and preserve existing tracing settings. | Complete: adapter-filtered private tracepoints available; global tracer `nop`, tracing on; left unchanged. Controller debug available but not enabled. |
| T2: late detection only | With a private adapter-2 trace, perform exactly one connector `detect`, without reset, rebind or player. Bound capture/action duration and check overruns. | Identify logical-register/page-selector transfers, first failed message/errno and timing, or establish that this late sequence succeeds. Record EDID/checksums, connector and scanout separately. A late pass is not boot acceptance. | Complete: late detection succeeds without reset; valid EDID, enabled connector and active scanout. Detailed evidence below. |
| T3: recovery comparison | If T2 is insufficient, use the same capture around one previously established ordered display-master/LT9611 rebind; do not add other variables. | Compare equivalent clock-switch and page-selection transfers with T2 and retained boot evidence. Rebind success alone does not identify the underlying cause. | Not repeated: T2 already recovers without reset, and earlier successful rebind evidence remains valid. Revisit only for a named unresolved recovery question. |
| T3b: controller-specific rebind | Alex explicitly requested an I2C driver reload. As `CONFIG_I2C_IMX=y`, detach the idle display master, unbind/rebind only controller `30a40000.i2c`, then reattach the display, with a private adapter-2 trace. | Reinitialise I2C3 and its bridge/charger clients without reboot or touching the PMIC buses; distinguish a late successful reinitialisation from cold-start acceptance. | Complete: bindings restored, valid EDID, connected/enabled HDMI and active scanout, no captured transfer errors or new kernel faults. Details below. |
| T4: first-startup capture | Electrical capture would distinguish address/data NACK and STOP waveforms, but Alex confirms there is no logic analyser. Alex approved preparing and triggering a diagnostic-only build: error-only register/page, PIO phase and STOP/status instrumentation. | Locate the first failure at startup, not only its late successful counterpart. Software cannot establish the electrical waveform. | Complete on 691: STOP timeout, followed by address-ACK failure with IAL set during page selection; details above. |
| T5: demonstrated-cause correction | Choose the smallest correction supported by T2–T4, test the complete affected transfer/state path and independently review. Treat HPD/sleep/wake error handling as separate findings unless evidence links them to the initiating failure. | Real hardware shows the relevant fault removed, not merely a successful mocked helper or hidden retry. | Alex said to carry on after 691 evidence. Candidate 0039 addresses hidden STOP errors and missing bus recovery; native checks pass, review/build/hardware pending. |
| T6: cleaned-up acceptance | Restore diagnostic settings as below, then test like-for-like warm and cold starts, TV present at boot, later hotplug, native console edges, supported modes and existing-mode video. Record each attempt and visual confirmation. | First-start valid EDID/checksums and visible output without manual recovery; no I2C faults, kernel oops or Ethernet/charger/WiFi/update regression. Do not claim reliability from one pass. | After a demonstrated correction and cleanup. |

Cleanup is part of acceptance, not an optional follow-up: restore KSZ status and
its temporary preflight expectation; reassess the experimental 100 kHz bus,
single-master patch/property and EAGAIN-only retry independently against the final
cause; remove diagnostic patch 0038, its recipe/test integration, temporary
capture instances/debug settings and transient players.
Retain fixes with independent correctness evidence (reset polarity, address
preservation and DRM state/lifecycle fixes) unless review establishes otherwise.
Do not blanket-revert all patches, copy live boot options or remove product
diagnostic test images. Keep development-image results distinct from the final
Ethernet-enabled product configuration. No deployment/build is authorised merely
by a pending plan row; apply Alex's actual current instruction and live coverage.

#### T2 execution evidence

Baseline: same build-690 boot ID `73b7ae02-5d78-479c-afb8-9a6ac2546aca`,
disconnected/disabled connector and zero EDID bytes. Exactly one write of
`detect` to the connector status was traced, with an 8-second action timeout,
private 512 KiB-per-CPU trace buffers, adapter-2 filtering and a 30-second
overall remote command bound. It exited successfully. No reset, driver rebind,
reboot, player, dynamic-debug change or boot-option edit was used.

The capture contains 3,094 I2C events and 959 completed transfers, none reporting
an error; per-CPU overrun/commit-overrun/drop counters sum to zero. Two message
events at the capture tail lack their completion record and are excluded from
error/timing claims. The successful crystal-select write `0x8101 = 0x18` starts
at monotonic 648.818750 s and completes in **0.496 ms**; the longest completed
transfer is 0.687 ms. This is late access, not proof about the initiating boot
failure or its precise STOP/ACK phase. Compare with the retained earlier
502.614 ms failing-boot clock-switch evidence without equating different builds.

The saved 256-byte EDID has the expected header, extension count and zero modulo
256 checksum for both 128-byte blocks. During immediate post-action sampling,
the connector's enabled flag was still disabled while the CRTC had become
active; a subsequent completion check on the same boot found connected/enabled
HDMI and 256 EDID bytes. Active 1080p scanout was observed during T2. This is not
camera-confirmed picture acceptance. The test trace instance was removed;
global `nop`/tracing-on settings remain unchanged, and no player was started.

Raw private evidence is retained on the board at
`/var/lib/dt510-hdmi-debug/t2-690-detect.YQZOuZ/` (trace, per-CPU stats, EDID and
metadata), with local copy `/tmp/dt510-690-t2.kLs6MT/`. Trace SHA-256:
`8f484f2273e21b92c8d3409f0197594a41f0f42b2689cc1c298e18489b1e48f4`.
The local reducer `/tmp/dt510-i2c-summary.py` uses parsed adapter/transfer fields
and fixed success/failure/interleaved/no-match fixtures; it reports incomplete
tails rather than treating them as successful transfers.

#### T3b: I2C3 controller rebind requested by Alex

`CONFIG_I2C_IMX=y`: a module unload is not possible. One controller-specific
unbind/rebind was performed instead on the same 690 boot. The display master
was detached first, controller `30a40000.i2c` was detached/recreated, and the
display master was reattached. This also removes/reprobes LT9611 and BQ25792;
it is not an isolated reset of the controller hardware with unchanged clients.
There were no userspace DRM clients, and SSH used `wlan0`. The PMIC controller
`30a20000.i2c` and other controller `30a30000.i2c` remained bound. No module
unload, reboot, boot edit, raw register write or player was used.

All three I2C3/bridge/charger bindings were restored. HDMI was connected/enabled,
scanout active with framebuffer 37, and the saved 256-byte EDID had the correct
header, extension count and both block checksums zero modulo 256. The same
scoped reducer found 1,482 completed transfers with no errors, no trace drops,
a maximum completed-transfer duration of 0.985 ms and a crystal-select write
of 0.502 ms in the display-attach phase. Two trailing message events had no
completion and are excluded. No new kernel warning/oops/panic/trace headers
were found in the action's kernel-log window. The private trace instance was
removed and global tracing settings were unchanged.

This proves a late full I2C3 reinitialisation can work; it does not prove which
first-startup condition differs or that reloading is an acceptable product fix.
Trace phases use the trace `mono` clock; do not assume exact raw timestamp
equivalence with kernel printk timestamps. Raw evidence:
`/var/lib/dt510-hdmi-debug/t3-690-i2c3-rebind.3EM8CX/`, local copy
`/tmp/dt510-690-t3.dMsmDm/`; trace SHA-256
`95575719fe8848c30f44da631101bbe85e6d7d5139c3ba0c586b05df55b16282`.

#### Diagnostic-only startup image: patch 0038

Alex approved one diagnostic build after confirming no logic analyser is
available. Keep the KSZ-disabled tree, all other pins and patches unchanged.
Temporary `0038-dt510-lt9611-startup-diagnostics.patch` adds error-only kernel
messages prefixed `DT510-DIAG`:

- Regmap errors on device `2-0039` include the full logical read/write register
  and, for failed writes, its intended value. Page-selection errors include
  the logical register, selector and requested page. Existing regmap locking
  and register sequences are unchanged; errors may produce nested context.
- Adapter-2/`0x39` short PIO transfers identify address completion versus ACK,
  data completion versus ACK, and the zero-based data-byte position (address
  phase uses `-1`). Read-address failures are covered too. Error-time I2SR/I2CR
  MMIO snapshots are printed. DMA data phases are not instrumented; the initial
  bridge register accesses are short PIO transfers.
- Adapter-2 bus-wait timeouts include idle/busy direction, stopped state, the
  existing status sample and elapsed milliseconds. STOP failures are logged
  explicitly, but their result remains ignored as in the legacy driver.

No new I2C transactions, successful-transfer logging, retries, delays, timeouts,
error-return changes, recovery service or boot-option edits are added. The
diagnostics are selected only by the DT510 recipe. Logging and two error-time
controller MMIO reads may alter timing **after** the first observed failure;
status samples are not proof of electrical waveforms. A later successful boot
with instrumentation is therefore not automatically a demonstrated fix.

Native preflight applies all eight patches to the pinned kernel without
offsets/fuzz. It compiles the actual error helper, PIO writer, STOP function and
regmap read/write functions against fault-injection mocks: success stays quiet,
returns and bus-operation counts are unchanged, address/data phases and bytes
are correct, unrelated devices are quiet and failed-read output remains intact.
Read-address and page-selection diagnostic placement are source-checked, not a
complete compiled kernel-path test. Existing polling, EDID, lifecycle, reset,
address, LCDIF and compiled-DT checks pass. No local Yocto/kernel build is run.

On the first authorised deployment, collect the boot ID, artifact identity and
the first chronological `DT510-DIAG` records with their surrounding LT9611
revision/power-on messages **before** detect/rebind or TV/cable intervention.
Record zero/absent messages as insufficient evidence, not a startup pass.
Do not fix the ignored STOP error, add retries or restore Ethernet in this
same diagnostic candidate. Remove 0038 and its integration after diagnosis;
restore the final intended Ethernet/controller settings before acceptance.

### Build 689 baseline

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

Diagnostic build 690 disables **only** `ksz9896_sw` on I2C3. It is a temporary
isolation test requested by Alex, not a production Ethernet change or a
demonstrated HDMI fix. See its failed result above and the experiment below.

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
- Experimental patches `0036` through `0044` are retired from the cleanup
  candidate, not additional required board support. Their old descriptions and
  test results above are historical evidence only.

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
