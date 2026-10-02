# Jaguar screen TAS2555 audio

## Hardware basis

Alex's instructions on 2026-09-30 identify the screen codec as TAS2555,
using Michael's wiring details. The EVK's WM8524 is not fitted.

Michael's hardware confirmation supplied by Alex on 2026-10-02 establishes
the remaining audio bring-up facts:

- the board is revision 1.0;
- the TAS2555 is connected through its ASI1 interface;
- the present bench load is an arbitrary 4 ohm development speaker; and
- no speaker characterization or tuning has been performed.

The speaker is therefore a bring-up load, not a production acoustic-system
definition. Protected production playback still requires characterization,
PurePath Console tuning, integration and calibration for the actual speaker
and enclosure.

| Connection | SoC pad | Package pin |
| --- | --- | --- |
| Audio bit clock | SAI2_TXC | AD22 |
| Audio frame sync | SAI2_TXFS | AD23 |
| Receive data | SAI2_RXD0 | AC24 |
| Transmit data | SAI2_TXD0 | AC22 |
| Master clock | SAI2_MCLK | AD19 |
| AUD_INT, GPIO input with pull-up | SAI5_MCLK | AD15 |
| AUD_RST#, GPIO output, low asserts reset | SAI5_RXFS | AB15 |

The control interface is hardware I2C1. A response at seven-bit address
`0x4c` was verified on the board after releasing AUD_RST#; silicon ID
and speaker-specific DSP configuration have not been verified. Alex's
follow-up initially directed use of the datasheet default/example rather
than waiting for Michael to identify it. The configuration defaults to
`0x4c`, now supported by the live reset-dependent response on this unit;
this is not a universal chip default. Override
`TAS2555_I2C_ADDRESS` if the board's straps select another address.

## Datasheet source

TI document SLASE69B, revision B (February 2019), was downloaded on
2026-09-30 from `https://www.ti.com/lit/ds/symlink/tas2555.pdf`.
The PDF and layout-preserving text extraction are stored under
`docs/datasheets/TAS2555_SLASE69B.{pdf,txt}`.

PDF SHA-256:
`1c4719082d980eda23050aae4cc50fd841ab88b545672bf5800312b6fb31b0a4`.

Requirements derived from the datasheet:

- Section 9.3.1, page 18: seven-bit addresses are 0x4c–0x4f, selected by
  ADR0/ADR1 straps; SPI_SELECT must select I2C.
- Sections 9.3.10.5 and 11: software reset is mandatory after hardware
  reset; allow at least 100 microseconds before further register access.
- Sections 9.4.3.1–2, pages 29–30: ROM modes permit playback without
  downloaded DSP firmware. ROM mode 1 disables speaker protection and
  I/V sensing; ROM mode 2 enables I/V feedback, not speaker protection.
- Section 9.5.2, pages 32–33: follow the documented power/mute sequencing.

ROM playback is a possible bring-up path, not a protected production
speaker configuration. Do not apply sample clock/load settings blindly.

## EVK support removal

The screen machine inherits the EVK machine configuration and includes
`freescale/imx8mm-evkb.dts`. WM8524 is instantiated by the inherited
`imx8mm-evk.dtsi`, not by a dedicated WM8524 machine feature.

Both screen DTS copies remove the inherited `sound-wm8524` card and
`audio-codec` node. The screen-only kernel fragment disables
`CONFIG_SND_SOC_WM8524`. Other machines and the shared EVK sources are
unchanged.

## TAS2555 integration status

The feature name is `tas2555`. The Screen machine includes its runtime
dependency wiring, but does not enable the feature by default while the
usable device configuration remains unconfirmed.

The separately named `tas2555-rom1-dev` modifier is valid only alongside the
base `tas2555` feature and only when `DEV_MODE=1`. The Screen device-tree and
image-construction gates fail if either condition is false. When valid, the
generated device tree adds the
explicit `ti,rom1-dev` property and rootfs construction may omit
`tas2555_uCDSP.bin`; this is an unprotected development exception, not a
relaxation of the normal `tas2555` firmware gate. The driver must explicitly
support that property before the mode can produce playback.

The feature selects the `kernel-module-snd-soc-tas2555` package and kernel
dependencies. Screen's generated header enables the SAI2/I2C1 DTS
integration only when the feature is selected. `TAS2555_I2C_ADDRESS`
defaults to TI's both-straps-low example, `0x4c`, and remains overridable
within the seven-bit range `0x4c`–`0x4f`. AUD_RST# uses GPIO3_IO19 and AUD_INT uses GPIO3_IO25 with
the requested pull-up. The codec link selects the driver's ASI1 DAI, matching
Michael's confirmed board connection. RXD0 is muxed for feedback; the imported
driver does not advertise microphone capture.

The feature also disables inherited SAI5/MICFIL consumers of the reset
and interrupt pads. Both are already disabled in the current Screen DTS;
the feature include makes that ownership explicit if the EVK defaults
change later.

The kiosk distro recipe selects ALSA card `tas2555audio` only when the
feature is enabled, replacing its former WM8524-specific default.

TI's `tas2555sw-android/tas2555-android-driver` repository at commit
`0468cf54e49f57163e17998846b62dc941130929` supplies a `ti,tas2555` driver.
The module recipe applies a component-API/I2C port, synchronous firmware
loading, and managed GPIO/IRQ handling. The Android tuning device is not
built. Calibration file access no longer uses removed address-limit APIs.

Additional patches bound the firmware parser, validate configuration
references, check allocations, release firmware metadata on teardown,
propagate initialization failures, and limit advertised rates to 8–96 kHz.
Runtime firmware reload through `TAS_FWLoad` returns `EOPNOTSUPP` to
prevent freeing metadata used by ALSA callbacks and interrupt work.
Firmware replacement requires device unbind/rebind, not that mixer control.
The no-boost startup selection is also corrected to test the firmware's
`mnBoost` field rather than its unrelated `mnAppMode` field. This fixes both
the ROM1 and ROM2/tuning branches and is required for a deliberate boost-off
configuration.

The driver requests `tas2555_uCDSP.bin`. This is a requirement of that
driver's implementation, not a hardware requirement for all playback:
the datasheet also describes ROM operation. Its example I2C address is
not evidence of the screen board's strapped address. Neither the example
address assumption nor firmware for another amplifier establishes
confirmed screen hardware inputs.

A bounded read-only check of target 2991 on 2026-10-01 found no TAS2555,
uCDSP or PurePath firmware file, package or OSTree-deployment path. The
deployed board therefore does not contain a recoverable vendor tuning asset.

TI's end-system integration guide (SLAA952) describes the required flow as
speaker characterization, PurePath Console 3 tuning, end-system integration
and factory calibration. TI's TAS2555 EVM guide (SLOU408) states that a device
configuration must be created before the device functions. These sources
confirm that an arbitrary firmware blob from another speaker product is not a
valid substitute for the Screen assembly's configuration.

The `tas2555` machine include therefore adds an image-construction gate. When
the feature is enabled, rootfs post-processing requires the non-empty file
`/usr/lib/firmware/tas2555_uCDSP.bin` (the usrmerge location corresponding to
the driver's request). Module, kernel and DT component builds remain available
without the binary, but an image cannot claim TAS2555 support while omitting
the configuration that the driver requires.

Exact-manifest metadata validation on 2026-10-01 proved both sides of this
gate. With the temporary `tas2555` feature override,
`ROOTFS_POSTPROCESS_COMMAND` contained
`jaguar_screen_tas2555_validate_rootfs` and `TAS2555_FIRMWARE_FILE` expanded to
`/usr/lib/firmware/tas2555_uCDSP.bin`. With the saved feature-off Cog tuple, the
hook was absent. Existing products therefore do not inherit the audio-firmware
gate.

The imported driver source contains ROM1 power-up arrays, but they are selected
through program/boost metadata parsed from the device configuration. Sample
rate setup, PLL data and configuration blocks also depend on that parsed
firmware. The existing code is therefore not a complete firmware-free ROM
playback implementation; exposing it would require inventing board-specific
clock, serial-interface and speaker settings outside the supplied flow.

The confirmed ASI1 connection removes the serial-interface ambiguity, but the
arbitrary 4 ohm speaker and absence of tuning do not supply the missing
speaker, PLL or configuration data. A future firmware-free path must therefore
be a separately named DEV-only ROM1 feature. It must be rejected in PROD,
remain explicitly unprotected, start muted, keep boost disabled, use
conservative gain and restrict playback to a reviewed clock/rate tuple derived
from authoritative TAS2555 data. The existing `tas2555` feature retains its
speaker-specific firmware requirement.

The implemented DEV tuple is deliberately narrower than the normal driver:

- ASI1 I2S only, with the PCM word length taken from ALSA hardware parameters;
- 48 kHz only, enforced by an ALSA runtime constraint;
- SAI2 MCLK fixed to 12.288 MHz (`256 * 48 kHz`), allowing the TAS2555 PLL to
  remain powered down as described in SLASE69B section 9.4.3.1;
- ROM1 selected with the datasheet value `B0_P0_R34 = 0x21`;
- boost and I/V sense disabled, with the documented minimum 1.5 A boost limit
  retained defensively in `B0_P0_R43`;
- DAC gain set to the documented minimum 0 dB while retaining the reset-default
  14 ns Class-D edge rate; and
- the amplifier kept muted at probe and powered only through ALSA stream mute
  transitions, using the TI shutdown sequence on stop/remove.

This path deliberately skips firmware, configuration and calibration objects.
It logs an explicit unprotected-mode warning and must not be used as evidence
of production speaker protection.

Configuration acceptance covers feature-gated driver packaging, SAI2/I2C1
device-tree integration with the specified GPIOs, replacement of the
WM8524 ALSA default, and selected Screen kernel/component validation.
Hardware playback is a separate acceptance step and remains unverified.
Device-tree compilation alone is not playback evidence.

## Validation boundary

### Live address detection, 2026-09-30

Foundries discovery and SSH identified
`imx8mm-jaguar-screen-2210a09dab86563` at `192.168.2.46`, target 2991,
tag `r16-jaguar-screen`, kernel `6.6.52-lmp-standard`.
Hardware I2C1 (`30a20000.i2c`) maps to Linux `/dev/i2c-0`.

An address-limited `i2cdetect -y -r 0 0x4c 0x4f` initially received no
responses. GPIO3_IO19 was unclaimed and configured as input; a GPIO read
returned low. With Alex's explicit approval, the diagnostic temporarily
held that line high. The same restricted address check then received a
response at `0x4c`, with no response at `0x4d`–`0x4f`.

The diagnostic terminated its GPIO holder and restored GPIO3_IO19 to
unclaimed input, reading low again. It did not reboot the board, program
the amplifier, play audio, or install an image. This demonstrates an I2C
device responding at the expected codec address when reset is released;
it is not a silicon-ID read, driver-binding proof or playback acceptance.

Alex subsequently accepted this evidence as the basis for the board's
audio support target:

> good - lock this in and take it as evidence this is the device we need to support

The locked support baseline is therefore Jaguar Screen board revision 1.0
with TAS2555 ASI1, using Michael's supplied SAI2 wiring, hardware I2C1 / Linux
bus 0, address `0x4c`, active-low reset on GPIO3_IO19, and interrupt input on
GPIO3_IO25. The current load is an arbitrary untuned 4 ohm development
speaker. Reset must be released before testing address presence. A no-response
result while reset is low must not be treated as evidence that this board has
no codec.

This is Alex's accepted device-selection evidence, not a claim that a
silicon-ID read or audio playback test has taken place.

### Offline configuration and compilation

Direct DTS compilation passes for both Screen source paths with the
feature disabled and with each of the four address alternatives. These
are synthetic configuration tests, not detection of the board address.
The EVK control build retains its WM8524 nodes.

All four stored patches apply to the pinned TI source through normal
BitBake recipe tasks. An isolated build of the selected Screen kernel
recipe and module passed compilation, installation, packaging and package
QA: 1,067 tasks attempted, 1,054 already satisfied, all succeeded.
The selected kernel base is
`90192c5d29cb650fd7f7dd9094af14eefb38837d`; the patched source HEAD is
`19bc8bd74baf1b5e3385962db31a45ad868c14b6`.

The ARM64 module advertises the `ti,tas2555` OF and `i2c:tas2555` aliases
and `6.6.52-lmp-standard` vermagic. Runtime package data provides
`kernel-module-snd-soc-tas2555`, matching the machine dependency. Its
empty module dependency list is consistent with built-in ASoC/I2C/regmap
providers in this kernel. The built Screen DTB contains `tas2555audio`
and amplifier address `0x4c`, with the specified reset and interrupt GPIOs
and no WM8524 nodes. The kernel configuration disables WM8524.

Package QA completed offline in the existing Ubuntu 22.04 Yocto container
(image ID `fb2f613e3f50`) after the Ubuntu 24.04 host pseudo/tar interaction
prevented dependency packaging. The container ran non-root, networkless,
with read-only source mounts and only the isolated build directory
writable. Existing public meta-security debug fixture keys signed the
validation module; no production signing key was used. These artifacts
must not be deployed as production artifacts.

Evidence is retained under `/tmp/jaguar-screen-bitbake.YTtWDd`, including
`module-package-qa-container.log`, package data, the built DTB and module.
This proves the selected Screen kernel recipe and staged BSP/distro
components against cached base layers, not the complete exact factory
manifest, an image build, deployment, driver binding or playback.

Isolated BitBake metadata evaluation passes for Screen's
`lmp-device-tree` and `linux-lmp-fslc-imx` with the feature off and on, and
for the enabled module recipe. Assertions verify the module runtime
dependency, conditional kernel fragment, unconditional Screen WM8524
disable fragment, pinned driver source, and browser ALSA default.
The enabled test uses synthetic address `0x4c`, not a board measurement.
Browser metadata was evaluated directly from its recipe because the local
layer cache lacks its Chromium runtime provider.

This metadata-only environment masks three unrelated dangling bbappends
for Chromium, Node.js and Godot whose matching recipes are absent from
the local layer cache. No repository configuration or shared build was
changed to work around those gaps. This does not prove a complete image
build or validate the selected Screen manifest's full layer combination.

An extracted firmware-parser harness passes ASan/UBSan checks for three
synthetic format variants, every truncated prefix, allocation-failure
injection, and 5,000 mutations per fixture. These checks do not establish
compatibility with an actual speaker firmware image.

### Exact Cog manifest proof, 2026-10-01

The staged BSP was subsequently copied into the complete Jaguar Screen Cog
workspace on `ai-tools` and evaluated with the existing product tuple plus a
temporary BitBake post-read setting that appended `tas2555` to
`MACHINE_FEATURES`. The saved `build-cog` configuration was not changed.

`bitbake kernel-module-tas2555 -c package_qa` attempted 1,005 tasks; 954 were
already satisfied and every task succeeded. This exact-manifest run rebuilt
the Screen kernel and device tree dependencies, applied all four driver
patches, and passed module compile, install, package, packagedata and package
QA. Its retained log is:

`/srv/yocto/jaguar-screen-kiosk/build-cog/cog-evidence/tas2555-exact-manifest-package-qa.log`

The installed module has SHA-256
`aa6c5d15a1af21053a6ee43bab5137118235b55d5e17054880754039b8e02d87`,
`6.6.52-lmp-standard` ARM64 vermagic, the expected OF/I2C aliases, and the
factory's configured kernel-module signing identity. The generated Screen DTB
has SHA-256
`7f4a8ab1b4e43790081a3d3d7539c4ae81963e2dea236b0a71c0a35db60cdf5f`
and contains `ti,tas2555` and `tas2555audio`.

This strengthens the build evidence only. No speaker firmware was added, no
audio-complete image was produced, and the target was not programmed or asked
to play audio by this proof.

### DEV-only ROM1 component proof, 2026-10-02

The exact Cog manifest was evaluated with `DEV_MODE=1` and temporary machine
features `tas2555 tas2555-rom1-dev`. Screen device-tree compilation attempted
871 tasks and all passed. The generated DTB contains both `tas2555audio` and
the explicit `ti,rom1-dev` property. Its SHA-256 is
`8be8858d76e5c93c750c7247541d8e35024f88022bc7650641925f9f6273edb0`.

The same tuple with `DEV_MODE=0` failed closed during kernel/device-tree
configuration with `tas2555-rom1-dev is an unprotected development mode and
requires DEV_MODE=1`. This proves that selecting the modifier cannot silently
enter a production build.

After adding the bounded ROM1 driver path, `bitbake kernel-module-tas2555
-c package_qa` attempted 1,005 tasks. The six-patch stack applied cleanly and
the kernel, device tree, module compile, install, packaging, packagedata and
package QA tasks all passed. The installed ARM64 module has SHA-256
`8c59b07bf33642b804cb39aa1f8c74e27c526384cbe5effbc9f999810b3948af`.
The temporary AppArmor user-namespace relaxation used by the build was restored
to its original value after completion.

This is component evidence, not an image or playback acceptance. Before target
use, build and verify an image carrying the exact DEV tuple, then begin with a
very low-amplitude 48 kHz signal and DPX capture. The board must remain labelled
as running unprotected ROM1 audio throughout that experiment.

Full runtime behavior still requires review and target validation.
No changes have been deployed and no TAS2555 playback has been verified.
Do not deploy this staging implementation as accepted production support.

The address for the tested unit is established as the bring-up value `0x4c`,
and Michael has confirmed the codec-side ASI1 connection. Before enabling the
protected `MACHINE_FEATURES:append = " tas2555"` path, obtain and review the
speaker-specific `tas2555_uCDSP.bin` configuration. The driver currently
requires that firmware; unprotected ROM fallback is not implemented. The
arbitrary untuned 4 ohm development speaker is suitable only for a separately
gated, conservative DEV ROM1 experiment after its register sequence is derived
and reviewed.
