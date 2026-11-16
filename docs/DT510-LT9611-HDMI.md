# DT510 LT9611 HDMI bring-up

Updated 16 November 2026 at Alex's request. Briar helped draft this.

## Current state

HDMI is enabled in local BSP sources for the next build, not proven on hardware.
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
No HDMI audio DAI routing has been added: the physical audio input wiring has
not been established by this investigation.

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

Both patches are selected only by `SRC_URI:append:imx8mm-jaguar-dt510`.
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

1. Complete the normal reviewed build/pin workflow; no full build, commit,
   push, CI trigger or deployment is authorised by this preflight alone.
2. Check final kernel config and build output; verify the LT9611 revision
   probe, no deferred display probes and a usable DRM HDMI connector.
3. Check the physical reset waveform and active-high IRQ behaviour, then EDID,
   720p video, 1080p60 video, hot-plug and cold/warm boot.
4. Verify the actual supply topology on the schematic/board. Do not claim
   HDMI audio or 4K from this single-DSI-port integration.
