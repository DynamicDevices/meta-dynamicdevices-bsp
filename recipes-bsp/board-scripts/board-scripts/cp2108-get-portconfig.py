#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""CP2108: GET QUAD_PORT_CONFIG (SiLabs wValue 0x370c, 73 B) matching linux cp210x.c.

DT510 (U13 CP2108) — read back GPIO alternate / RS-485 DE settings
-------------------------------------------------------------------
Hardware (bridge UART index, not always ttyUSBn order — use udev by-path):

  IFC0 / IFC1  RS-232  (no RS-485 DE on this SKU)
  IFC2         RS-485  GPIO.10 -> RS485_DE1   /dev/etm (udev) or ttyUSB2  (USB 1-1.3:1.2)
  IFC3         RS-485  GPIO.14 -> RS485_DE2   typical /dev/ttyUSB3  (USB 1-1.3:1.3)

Correct NVM for DT510 transceiver (DE high during TX, low when idle) — lab-validated 2026-05-16:

  EnhancedFxn_IFC2 = 0x0c  (0x04 RS-485 alternate + 0x08 logic invert)
  EnhancedFxn_IFC3 = 0x0c
  EnhancedFxn_IFC0 = EnhancedFxn_IFC1 = 0x00

Check after programming (root; detaches cp210x briefly if using set-portconfig):

  sudo cp2108-get-portconfig --quiet-text | grep -E '^--- IFC|raw='

Expect IFC2/IFC3 raw=0x0c (GPIO_RS485_DRIVE + RS485_LOGIC_POLARITY in the decode tables).
IFC0/IFC1 should stay raw=0x00. Optional machine-readable dump: --json.

Wrong polarity on scope (DE high idle, low during TX) means IFC2/3 still 0x04 — use
cp2108-set-portconfig --rs485-de-invert (see that script's DT510 note).

Lab TX test after NVM is correct: rs485_tx_bytes --tty /dev/ttyUSB2 (or by-path :1.2-port0).
"""

from __future__ import annotations  # noqa: E402

import argparse
import json
import sys
from dataclasses import dataclass
from struct import unpack_from

REQTYPE_VENDOR_DEV_IN = 0xC0
BREQUEST_VENDOR = 0xFF
WV_GET_QUAD_PORTCFG = 0x370C
EXPECTED_LEN = 0x49

EF_TXLED = 0x01
EF_RXLED = 0x02
EF_RS485 = 0x04
EF_RS485_LOGIC = 0x08
EF_CLOCK = 0x10
EF_DYNAMIC_SUSPEND = 0x40

EF_DEVICE_WEAKPULLUP_RST = 0x10
EF_DEVICE_WEAKPULLUP_SUSP = 0x20
EF_DEVICE_DYNAMIC_SUSPEND = 0x40


@dataclass(frozen=True)
class _EfIfcBitSpec:
    mask: int
    name: str
    summary: str
    kernel_altfunc: bool
    gpio_off: int | None
    """gpio_off 0..3 for global GPIO ifc*4+off; None if not a kernel alt line."""


_BIT_SPECS_ORDERED: tuple[_EfIfcBitSpec, ...] = (
    _EfIfcBitSpec(0x01, "EF_IFC_GPIO_TXLED", "TX activity LED alternate", True, 0),
    _EfIfcBitSpec(0x02, "EF_IFC_GPIO_RXLED", "RX activity LED alternate", True, 1),
    _EfIfcBitSpec(0x04, "EF_IFC_GPIO_RS485", "RS-485 / DE timed with UART TX", True, 2),
    _EfIfcBitSpec(
        0x08,
        "EF_IFC_GPIO_RS485_LOGIC",
        "RS-485 polarity vs TX (only meaningful with EF_IFC_GPIO_RS485)",
        False,
        2,
    ),
    _EfIfcBitSpec(0x10, "EF_IFC_GPIO_CLOCK", "Clock-out alternate", True, 3),
    _EfIfcBitSpec(0x20, "UNKNOWN_BIT5", "Not in DLL excerpt; expect 0", False, None),
    _EfIfcBitSpec(
        0x40,
        "EF_IFC_DYNAMIC_SUSPEND",
        "Dynamic suspend (policy; not gpio_altfunc in linux cp210x.c)",
        False,
        None,
    ),
    _EfIfcBitSpec(0x80, "RESERVED_MSB", "Expect 0", False, None),
)


def _bit_lsb_index(mask: int) -> int:
    p = 0
    while p < 32 and (mask >> p) & 1 == 0:
        p += 1
    return p if p < 32 else -1


def _decode_ef_iface_short(b: int) -> list[str]:
    o: list[str] = []
    if b == 0:
        return o
    if b & EF_TXLED:
        o.append("GPIO_TX_LED")
    if b & EF_RXLED:
        o.append("GPIO_RX_LED")
    if b & EF_RS485:
        o.append("GPIO_RS485_DRIVE")
    if b & EF_RS485_LOGIC:
        o.append("RS485_LOGIC_POLARITY")
    if b & EF_CLOCK:
        o.append("GPIO_CLOCK_OUT")
    if b & EF_DYNAMIC_SUSPEND:
        o.append("DYNAMIC_SUSPEND_IFC")
    if b & 0x20:
        o.append("UNKNOWN_BIT_0x20")
    return o


def decode_enhanced_fxn_ifc_byte(ifc: int, byte_v: int) -> dict[str, object]:
    warns: list[str] = []
    bit_rows: list[dict[str, object]] = []

    for spec in _BIT_SPECS_ORDERED:
        on = bool(byte_v & spec.mask)
        gname = ""
        if spec.gpio_off is not None:
            gname = f"GPIO{ifc * 4 + spec.gpio_off}"
        kern = ""
        if on and spec.kernel_altfunc and spec.gpio_off is not None:
            kern = (
                "cp210x: pin not exported as user sysfs GPIO (gpio_altfunc excludes it)"
            )
        if on and spec.name == "EF_IFC_GPIO_RS485_LOGIC":
            if byte_v & EF_RS485:
                kern = "Same physical line as RS485 (polarity qualifier)"
            else:
                kern = "No RS485 alternate — polarity bit orphaned"

        bit_rows.append(
            {
                "bit_lsb0": _bit_lsb_index(spec.mask),
                "mask_hex": f"0x{spec.mask:02x}",
                "set": on,
                "name": spec.name,
                "description": spec.summary,
                "related_global_gpio": gname,
                "linux_note_when_set": kern,
            }
        )

    if (byte_v & EF_RS485_LOGIC) and not (byte_v & EF_RS485):
        warns.append(
            "EF_IFC_GPIO_RS485_LOGIC set without EF_IFC_GPIO_RS485 (no pairing)."
        )

    kern_alts: list[dict[str, object]] = []
    if byte_v & EF_TXLED:
        kern_alts.append({"global_gpio_index": ifc * 4, "role": "TXLED"})
    if byte_v & EF_RXLED:
        kern_alts.append({"global_gpio_index": ifc * 4 + 1, "role": "RXLED"})
    if byte_v & EF_RS485:
        rd: dict[str, object] = {
            "global_gpio_index": ifc * 4 + 2,
            "role": "RS485_DRIVE",
            "logic_polarity_bit": bool(byte_v & EF_RS485_LOGIC),
        }
        kern_alts.append(rd)
    if byte_v & EF_CLOCK:
        kern_alts.append({"global_gpio_index": ifc * 4 + 3, "role": "CLOCK_OUT"})

    kw = warns.copy()
    if byte_v == 0:
        kw.append("No enhanced IFC bits programmed.")

    return {
        "usb_uart_interface_ifc": ifc,
        "raw_hex": f"0x{byte_v:02x}",
        "binary_msb_first": f"{byte_v:08b}",
        "global_gpio_quartet": list(range(ifc * 4, ifc * 4 + 4)),
        "bit_table": bit_rows,
        "linux_gpio_alternates_active": kern_alts,
        "short_decode": _decode_ef_iface_short(byte_v),
        "warnings": kw,
    }


def _format_enhanced_tables(efx: tuple[int, ...]) -> str:
    lines: list[str] = []
    lines.append("=== EnhancedFxn_IFC0..3 (per-byte full decode) ===")
    lines.append(
        "GPIO indices are global 0..15. Linux cp210x marks alternates in gpio_altfunc."
    )
    lines.append("")
    for ifc, bv in enumerate(efx):
        d = decode_enhanced_fxn_ifc_byte(ifc, bv)
        lines.append(
            f"--- IFC{ifc}  raw={d['raw_hex']}  msb..lsb={d['binary_msb_first']}  "
            f"quartet={d['global_gpio_quartet']} ---"
        )
        if d["linux_gpio_alternates_active"]:
            lines.append("    kernel alternates now active:")
            for item in d["linux_gpio_alternates_active"]:
                lines.append(f"      {item}")
        else:
            lines.append("    kernel alternates: (none)")
        lines.append("    bit  mask  on?  name")
        for br in d["bit_table"]:
            on = "yes" if br["set"] else " no"
            lines.append(
                f"      {br['bit_lsb0']}  {br['mask_hex']}  {on:>3}  {br['name']}"
            )
            if br["set"] and str(br.get("related_global_gpio", "")):
                lines.append(
                    f"            pin {br['related_global_gpio']}: {br['description']}"
                )
                if str(br.get("linux_note_when_set", "")):
                    lines.append(f"            ({br['linux_note_when_set']})")
        for w in d["warnings"]:
            lines.append(f"    * {w}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _decode_ef_device(b: int) -> list[str]:
    o: list[str] = []
    if b & EF_DEVICE_WEAKPULLUP_RST:
        o.append("WEAKPULLUP_RESET")
    if b & EF_DEVICE_WEAKPULLUP_SUSP:
        o.append("WEAKPULLUP_SUSPEND")
    if b & EF_DEVICE_DYNAMIC_SUSPEND:
        o.append("DYNAMIC_SUSPEND_DEVICE")
    x = b & ~(EF_DEVICE_WEAKPULLUP_RST | EF_DEVICE_WEAKPULLUP_SUSP | EF_DEVICE_DYNAMIC_SUSPEND)
    if x:
        o.append(f"reserved_dev=0x{x:02x}")
    return o


def decode(buf: bytes) -> dict[str, object]:
    if len(buf) != EXPECTED_LEN:
        raise ValueError(f"expected {EXPECTED_LEN} bytes got {len(buf)}")
    pb = tuple(f"pb{i}" for i in range(5))
    o = 0

    def blk(name: str) -> dict[str, dict[str, int]]:
        nonlocal o
        modes = unpack_from("<5H", buf, o)
        o += 10
        low = unpack_from("<5H", buf, o)
        o += 10
        lat = unpack_from("<5H", buf, o)
        o += 10
        return {
            name: {
                "gpio_mode_words_le": {pb[i]: modes[i] for i in range(5)},
                "gpio_low_power_words_le": {pb[i]: low[i] for i in range(5)},
                "gpio_latch_words_le": {pb[i]: lat[i] for i in range(5)},
            }
        }

    out: dict[str, object] = {}
    out.update(blk("reset_state"))
    out.update(blk("suspend_state"))

    ipd = unpack_from("<4B", buf, o)
    o += 4
    efx = unpack_from("<4B", buf, o)
    o += 4
    (efx_dev,) = unpack_from("<B", buf, o)
    o += 1
    extclk = unpack_from("<4B", buf, o)
    o += 4
    assert o == EXPECTED_LEN

    full_iface: list[dict[str, object]] = []
    short_rows = []
    for i in range(4):
        full = decode_enhanced_fxn_ifc_byte(i, efx[i])
        full_iface.append(full)
        short_syms = _decode_ef_iface_short(efx[i])
        short_rows.append(
            {
                "interface": i,
                "gpio_index_block_global": list(range(i * 4, i * 4 + 4)),
                "EnhancedFxn_IFC_hex": f"0x{efx[i]:02x}",
                "EnhancedFxn_IFC_decode": short_syms,
                "EnhancedFxn_IFC_decode_full": full,
            }
        )

    out["inter_port_delay_ifc_cycles"] = list(ipd)
    out["enhancedfxn_ifc_bytes_hex"] = [f"0x{x:02x}" for x in efx]
    out["enhancedfxn_ifc_decode_full_ifc_order"] = full_iface
    out["per_interface_enhanced"] = short_rows
    out["enhancedfxn_device"] = {"raw_hex": f"0x{efx_dev:02x}", "decode": _decode_ef_device(efx_dev)}
    out["extclkfreq_bytes_hex"] = [f"0x{x:02x}" for x in extclk]
    out["_note"] = (
        "gpio_mode/gpio_latch WORDs: CP2108 datasheet table 9.1 & QUAD_PORT_STATE PORT_* masks."
    )
    return out


def get_cfg(cfg: argparse.Namespace, dev) -> tuple[bytes, dict[str, object]]:
    import usb.core  # pylint: disable=import-outside-toplevel
    import usb.util

    if cfg.iface > 127 or cfg.iface < 0:
        sys.stderr.write("invalid --interface\n")
        sys.exit(1)

    detached = False
    try:
        if dev.is_kernel_driver_active(cfg.iface):
            dev.detach_kernel_driver(cfg.iface)
            detached = True
    except (usb.core.USBError, NotImplementedError) as exc:
        sys.stderr.write(f"detach: {exc}\n")

    try:
        dev.set_configuration()
    except usb.core.USBError:
        pass

    usb.util.claim_interface(dev, cfg.iface)
    raw: bytes
    try:
        ret = dev.ctrl_transfer(
            REQTYPE_VENDOR_DEV_IN,
            BREQUEST_VENDOR,
            WV_GET_QUAD_PORTCFG,
            cfg.iface,
            EXPECTED_LEN,
            timeout=8000,
        )
        raw = bytes(ret)
        if len(raw) != EXPECTED_LEN:
            sys.stderr.write(f"wrong length {len(raw)}\n")
            sys.exit(1)
        dec = decode(raw)
        dec["_usb_meta"] = {
            "vendor_id": f"0x{cfg.vid:04x}",
            "product_id": f"0x{cfg.pid:04x}",
            "bmRequestType": hex(REQTYPE_VENDOR_DEV_IN),
            "bRequest": hex(BREQUEST_VENDOR),
            "wValue": hex(WV_GET_QUAD_PORTCFG),
            "wIndex_iface": cfg.iface,
            "payload_len": EXPECTED_LEN,
        }
        return raw, dec
    finally:
        usb.util.release_interface(dev, cfg.iface)
        if detached:
            try:
                dev.attach_kernel_driver(cfg.iface)
            except Exception:
                pass


def resolve_dev(cfg: argparse.Namespace):
    import usb.core

    if cfg.busadr:
        a, slash, b = cfg.busadr.partition("/")
        if slash != "/" or not a.isdigit() or not b.isdigit():
            sys.stderr.write("use --bus-device BBB/DDD\n")
            sys.exit(1)
        bus_i, adr_i = int(a), int(b)
        dev = None
        for d in usb.core.find(find_all=True):
            if d.bus == bus_i and d.address == adr_i:
                dev = d
                break
        if not dev:
            sys.stderr.write("device not found for bus/addr\n")
            sys.exit(1)
        return dev
    d = usb.core.find(idVendor=cfg.vid, idProduct=cfg.pid)
    if not d:
        sys.stderr.write(f"no_usb {cfg.vid:04x}:{cfg.pid:04x}\n")
        sys.exit(1)
    return d


DT510_EPILOG = """
DT510: expect EnhancedFxn_IFC2/IFC3 = 0x0c after set-portconfig --rs485-de-invert.
  sudo cp2108-get-portconfig --quiet-text | grep -E '^--- IFC|raw='
See script header for full port map (IFC2=ttyUSB2/RS485_DE1, IFC3=ttyUSB3/RS485_DE2).
"""


def main() -> int:
    p = argparse.ArgumentParser(
        description="GET+decode CP2108 quad NVM config blob",
        epilog=DT510_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--vid", type=lambda x: int(x, 0), default=0x10C4)
    p.add_argument("--pid", type=lambda x: int(x, 0), default=0xEA71)
    p.add_argument("--bus-device", dest="busadr", metavar="BBB/DDD")
    p.add_argument("-i", "--interface", dest="iface", type=int, default=0)
    p.add_argument("--json", action="store_true", help="JSON only (includes full IFC decode structs)")
    p.add_argument(
        "--quiet-text",
        action="store_true",
        help="omit ASCII EnhancedFxn tables (JSON still contains full decode)",
    )

    cfg = p.parse_args()
    try:
        import usb.core
    except ImportError:
        sys.stderr.write("needs PyUSB (python3-pyusb)\n")
        return 1

    raw_bytes, blob = get_cfg(cfg, resolve_dev(cfg))
    # After reset+suspend quad state (60 B), IPDelay (4), EnhancedFxn_IFC @ +64.
    efx = tuple(unpack_from("<4B", raw_bytes, 64))

    if cfg.json:
        print(json.dumps(blob, indent=2))
        return 0

    sys.stdout.write(f"PAYLOAD_HEX {raw_bytes.hex()}\n")
    if not cfg.quiet_text:
        sys.stdout.write(_format_enhanced_tables(efx))
    sys.stdout.write("\nFULL_JSON:\n")
    sys.stdout.write(json.dumps(blob, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
