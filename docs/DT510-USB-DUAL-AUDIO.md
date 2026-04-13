# DT510: USB dual audio (gadget) vs on-board codecs

## Roles

| Path | Use |
|------|-----|
| **USB dual UAC2 gadget** | **Simulated / lab** — host sees two audio interfaces (driver + passengers) over USB; pairs with AVM/container tests and laptop bridge scripts. |
| **On-board codecs** (TAS2563, future TAC5301 / TAA5412 / TAS6424 per SSOT) | **Product audio** — I2S/SAI to physical transducers; this is the long-term implementation. |

Both can coexist in software builds; **boot policy** controls whether the gadget starts automatically.

## Machine feature: `dt510-usb-dual-audio-autostart`

Defined in **`conf/machine/imx8mm-jaguar-dt510.conf`**. When **present**, **`usb-dual-audio-gadget-dt510.service`** is **enabled** at boot (`usb-gadget-scripts` recipe).

- **Default in BSP:** feature is **on** — same behaviour as before this toggle (gadget comes up automatically for lab/CI).
- **Codec-first / production-style images:** remove the feature so the gadget **does not** start at boot:

```bitbake
MACHINE_FEATURES:remove:imx8mm-jaguar-dt510 = "dt510-usb-dual-audio-autostart"
```

Add that line in **factory `local.conf` / `site.conf`**, **meta-subscriber-overrides** machine fragment, or another high-priority config layer — wherever you centralise machine overrides for that image.

## Manual simulated testing (autostart off)

Packages and scripts remain installed:

```bash
sudo systemctl start usb-dual-audio-gadget-dt510
# optional persistence for that image:
sudo systemctl enable usb-dual-audio-gadget-dt510
```

Stop:

```bash
sudo systemctl stop usb-dual-audio-gadget-dt510
```

## Device tree / kernel

Gadget mode requires **`&usbotg1`** **peripheral** mode (already set in `imx8mm-jaguar-dt510.dts`). Disabling the systemd unit does not change DT; it only skips creating the configfs gadget at boot.

## See also

- [`DT510-BSP-PROJECT-PLAN.md`](DT510-BSP-PROJECT-PLAN.md) — phased hardware bring-up.
- [`DT510-HARDWARE-AUDIT-CHECKLIST.md`](DT510-HARDWARE-AUDIT-CHECKLIST.md) — codec SSOT vs BSP.

---

*Last updated: 2026-04-13*
