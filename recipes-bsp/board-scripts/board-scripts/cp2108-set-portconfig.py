#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""CP2108: attempt to PATCH + WRITE quad NVM config blob (EnhancedFxn_IFC RS-485).

READ path matches linux cp210x.c + cp2108-get-portconfig.py (Vendor IN, bRequest 0xff,
wValue GET 0x370c).

WRITE path is NOT published in upstream Linux. This script probes a small ordered set of
DEVICE/INTERFACE Vendor OUT setups (wValue trials) documented in-code. If programming fails,
use Silicon Labs CP210xManufacturing.dll / official tools after USB-tracing which transfer
actually sticks.

EnhancedFxn_IFC bits (AN978): 0x04 RS-485 alternate (DE timed with UART TX);
0x08 RS-485_LOGIC (invert DE polarity vs default active-high-idle).

DT510 (U13) — program GPIO alternate + DE invert for both RS-485 UARTs
-----------------------------------------------------------------------
**Production:** run this OTP/NVM program **once per board** during manufacturing (before
RS-485 test). Not on every SoC flash. **Lab 2026-05-16:** UART IFC2/3 RS-485 + DE polarity
validated after --rs485-de-invert (readback 0x0c; scope DE high on TX). See checklist § CP2108.

Run as root on the target (PyUSB detaches cp210x on interface 0; ttyUSB* drop briefly).

1) Snapshot current NVM (backup):

     sudo cp2108-get-portconfig > /tmp/cp2108-nvm-before.txt

2) Program RS-485 alternate on bridge IFC2 & IFC3 (GPIO.10 / GPIO.14) with DT DE polarity
   (DE high during TX, low when idle — requires 0x08 invert on this board):

     sudo cp2108-set-portconfig --rs485-de-invert --dry-run
     sudo cp2108-set-portconfig --rs485-de-invert -y --bus-reset

   Default --rs485-ifc is 2 and 3; only IFC0/IFC1 stay plain (RS-232 nets).

3) Verify (expect EnhancedFxn_IFC2/3 = 0x0c):

     sudo cp2108-get-portconfig --quiet-text | grep -E '^--- IFC|raw='

4) Scope: RS485_TX1 + RS485_DE1 while:

     sudo rs485_tx_bytes --tty /dev/ttyUSB2 --baud 115200 --loop --interval 0.05

   Map tty with: ls -l /dev/serial/by-path/*1.3:1.2*  (IFC2) and *1.3:1.3* (IFC3).

To revert DE invert only (back to 0x04 on IFC2/3): --clear-rs485-de-invert -y --bus-reset

  ** Mis-programming NVM can brick VID/PID or pin mux — READ + backup first. **
"""

from __future__ import annotations

import argparse
import sys
import time


# --- Mirrors cp210x.c + linux uapi/usb/ch9.h ---------------------------------
REQTYPE_VENDOR_DEV_IN = 0xC0      # DIR_IN | TYPE_VENDOR | RECIP_DEVICE
REQTYPE_VENDOR_DEV_OUT = 0x40     # DIR_OUT | TYPE_VENDOR | RECIP_DEVICE
REQTYPE_VENDOR_IFACE_OUT = 0x41  # DIR_OUT | TYPE_VENDOR | RECIP_INTERFACE
BREQUEST_VENDOR = 0xFF

WV_GET_QUAD_PORTCFG = 0x370C
# Common guess: contiguous opcode after GET; fallbacks bracket GPIO latch style (0x37xx).
WV_SET_TRIALS = (
    (REQTYPE_VENDOR_DEV_OUT, WV_GET_QUAD_PORTCFG + 1),           # 0x370d, device recipient
    (REQTYPE_VENDOR_IFACE_OUT, WV_GET_QUAD_PORTCFG + 1),
    (REQTYPE_VENDOR_DEV_OUT, WV_GET_QUAD_PORTCFG),
    (REQTYPE_VENDOR_IFACE_OUT, WV_GET_QUAD_PORTCFG),
)

EXPECTED_LEN = 0x49

EF_IFC_GPIO_RS485 = 0x04
EF_IFC_GPIO_RS485_LOGIC = 0x08

DT510_EPILOG = """
DT510 quick setup (IFC2/3 RS-485 + DE invert for GPIO.10 / GPIO.14):
  sudo cp2108-get-portconfig > /tmp/cp2108-nvm-before.txt
  sudo cp2108-set-portconfig --rs485-de-invert --dry-run
  sudo cp2108-set-portconfig --rs485-de-invert -y --bus-reset
  sudo cp2108-get-portconfig --quiet-text | grep -E '^--- IFC|raw='
"""


def _quad_control_in(dev, iface: int, w_length: int) -> bytes:
    ret = dev.ctrl_transfer(
        REQTYPE_VENDOR_DEV_IN,
        BREQUEST_VENDOR,
        WV_GET_QUAD_PORTCFG,
        iface,
        w_length,
        timeout=8000,
    )
    return bytes(ret)


def quad_read_pyusb(dev, iface: int) -> bytes:
    raw = _quad_control_in(dev, iface, EXPECTED_LEN)
    if len(raw) != EXPECTED_LEN:
        raise RuntimeError(f"quad read wrong length {len(raw)} expected {EXPECTED_LEN}")
    return raw


def quad_write_try_pyusb(dev, iface: int, bmREQ: int, w_value: int, blob: bytes) -> None:
    dev.ctrl_transfer(
        bmREQ,
        BREQUEST_VENDOR,
        w_value,
        iface,
        blob,
        timeout=12000,
    )


def enhancedfxn_unpack(blob: bytes) -> tuple[int, int, int, int]:
    if len(blob) != EXPECTED_LEN:
        raise ValueError(f"blob len {len(blob)}")
    base = 30 + 30 + 4
    return blob[base], blob[base + 1], blob[base + 2], blob[base + 3]


def _enhancedfxn_base() -> int:
    return 30 + 30 + 4


def _norm_rs485_mask(mask: int) -> int:
    mask &= 0xFF
    if mask & EF_IFC_GPIO_RS485_LOGIC:
        mask |= EF_IFC_GPIO_RS485
    return mask


def patch_enhanced_fxn(
    blob: bytes,
    or_masks: dict[int, int],
    clear_masks: dict[int, int] | None = None,
) -> bytes:
    """Patch EnhancedFxn_IFC0..3 bytes (clear bits first, then OR)."""
    b = bytearray(blob)
    base = _enhancedfxn_base()
    for ifc_idx in sorted(set(or_masks) | set(clear_masks or {})):
        if not 0 <= ifc_idx <= 3:
            raise ValueError(f"invalid ifc idx {ifc_idx}")
        off = base + ifc_idx
        if clear_masks and ifc_idx in clear_masks:
            b[off] &= (~clear_masks[ifc_idx]) & 0xFF
        if ifc_idx in or_masks:
            b[off] = (b[off] | _norm_rs485_mask(or_masks[ifc_idx])) & 0xFF
    return bytes(b)


def build_enhanced_fxn_masks(args: argparse.Namespace) -> tuple[dict[int, int], dict[int, int]]:
    """Return (or_masks, clear_masks) from CLI flags."""
    rs485_ifcs = list(args.rs485_ifc)
    or_masks: dict[int, int] = {}
    clear_masks: dict[int, int] = {}

    for ifc in rs485_ifcs:
        or_masks.setdefault(ifc, 0)
        or_masks[ifc] |= EF_IFC_GPIO_RS485

    invert_ifcs = set(args.rs485_de_invert_ifc)
    if args.rs485_de_invert:
        invert_ifcs.update(rs485_ifcs)

    for ifc in invert_ifcs:
        or_masks.setdefault(ifc, 0)
        or_masks[ifc] |= EF_IFC_GPIO_RS485 | EF_IFC_GPIO_RS485_LOGIC

    # Legacy name (same as --rs485-de-invert-ifc)
    for ifc in args.logical_invert_ifc:
        or_masks.setdefault(ifc, 0)
        or_masks[ifc] |= EF_IFC_GPIO_RS485 | EF_IFC_GPIO_RS485_LOGIC

    clear_ifcs = set(args.clear_rs485_de_invert_ifc)
    if args.clear_rs485_de_invert:
        clear_ifcs.update(rs485_ifcs)

    for ifc in clear_ifcs:
        clear_masks.setdefault(ifc, 0)
        clear_masks[ifc] |= EF_IFC_GPIO_RS485_LOGIC

    return or_masks, clear_masks


def claim_usb(dev, iface: int):
    """Detach cp210x on chosen interface and claim."""
    import usb.core
    import usb.util

    if iface > 127 or iface < 0:
        raise ValueError("--interface")
    detached = False
    try:
        if dev.is_kernel_driver_active(iface):
            dev.detach_kernel_driver(iface)
            detached = True
    except (usb.core.USBError, NotImplementedError) as exc:
        print(f"warning: detach interface {iface}: {exc}", file=sys.stderr)

    try:
        dev.set_configuration()
    except usb.core.USBError:
        pass
    usb.util.claim_interface(dev, iface)
    return detached


def release_usb(dev, iface: int, detached: bool) -> None:
    import usb.util

    try:
        usb.util.release_interface(dev, iface)
    except Exception:
        pass
    if detached:
        try:
            dev.attach_kernel_driver(iface)
        except Exception:
            pass


def resolve_dev(busadr: str | None, vid: int, pid: int):
    import usb.core

    if busadr:
        bus_s, slash, adr_s = busadr.partition("/")
        if slash != "/" or not bus_s.isdigit() or not adr_s.isdigit():
            sys.stderr.write("use --bus-device BBB/DDD\n")
            raise SystemExit(2)
        bus_i, adr_i = int(bus_s), int(adr_s)
        for d in usb.core.find(find_all=True):
            if d.bus == bus_i and d.address == adr_i:
                return d
        sys.stderr.write("device not found for bus/addr\n")
        raise SystemExit(2)
    d = usb.core.find(idVendor=vid, idProduct=pid)
    if not d:
        sys.stderr.write(f"no_usb {vid:04x}:{pid:04x}\n")
        raise SystemExit(2)
    return d


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n\n")[0],
        epilog=DT510_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--vid", type=lambda x: int(x, 0), default=0x10C4)
    ap.add_argument("--pid", type=lambda x: int(x, 0), default=0xEA71)
    ap.add_argument("--bus-device", dest="busadr", metavar="BBB/DDD")
    ap.add_argument("-i", "--interface", dest="iface", type=int, default=0)
    ap.add_argument(
        "--rs485-ifc",
        metavar="IFC",
        type=int,
        action="append",
        default=None,
        help=(
            "Interface index (0..3): OR EF_IFC_GPIO_RS485 (0x04) into EnhancedFxn_IFC#. "
            "(Repeatable; default IFC2 & IFC3 if omitted.)"
        ),
    )
    ap.add_argument(
        "--rs485-de-invert",
        action="store_true",
        help=(
            "Set EF_IFC_GPIO_RS485_LOGIC (0x08) on each --rs485-ifc (default IFC2 & IFC3). "
            "With 0x04, EnhancedFxn becomes 0x0c: DE high during TX (DT510 transceiver)."
        ),
    )
    ap.add_argument(
        "--rs485-de-invert-ifc",
        metavar="IFC",
        type=int,
        action="append",
        default=[],
        help="OR 0x08 (and 0x04) on this IFC only; repeatable.",
    )
    ap.add_argument(
        "--clear-rs485-de-invert",
        action="store_true",
        help="Clear 0x08 on each --rs485-ifc (leave 0x04 RS-485 alternate if already set).",
    )
    ap.add_argument(
        "--clear-rs485-de-invert-ifc",
        metavar="IFC",
        type=int,
        action="append",
        default=[],
        help="Clear 0x08 on this IFC only; repeatable.",
    )
    ap.add_argument(
        "--logical-invert-ifc",
        metavar="IFC",
        type=int,
        action="append",
        default=[],
        help=argparse.SUPPRESS,
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Read + show patched HEX only (no WRITE / reset).",
    )
    ap.add_argument(
        "-y",
        action="store_true",
        dest="assume_yes",
        help="Do not prompt before writing NVM.",
    )
    ap.add_argument(
        "--no-verify",
        action="store_true",
        help="Skip GET-after write compare.",
    )
    ap.add_argument(
        "--bus-reset",
        action="store_true",
        help="USB-reset hub port after WRITE (drops ttyUSB nodes briefly; omit if unstable).",
    )
    ap.add_argument(
        "--trial",
        nargs=2,
        metavar=("BMREQ_HEX", "WVALUE_HEX"),
        help="Exact single WRITE trial (skip default probes), e.g. --trial 0x40 0x370d",
    )
    args = ap.parse_args()

    if args.rs485_ifc is None:
        args.rs485_ifc = [2, 3]

    or_masks, clear_masks = build_enhanced_fxn_masks(args)
    if not or_masks and not clear_masks:
        sys.stderr.write(
            "ERR: no patch requested (default only enables RS-485 0x04 on IFC2/3; "
            "add --rs485-de-invert or --clear-rs485-de-invert to change DE polarity)\n"
        )
        return 2

    try:
        import usb.core  # pylint: disable=unused-import  # noqa: F401
    except ImportError:
        sys.stderr.write("needs python3-pyusb\n")
        return 1

    dev = resolve_dev(args.busadr, args.vid, args.pid)

    claimed_main = False
    detached_main = False
    try:
        detached_main = claim_usb(dev, args.iface)
        claimed_main = True

        old = quad_read_pyusb(dev, args.iface)
        before = enhancedfxn_unpack(old)
        new = patch_enhanced_fxn(old, or_masks, clear_masks or None)
        after = enhancedfxn_unpack(new)

        print(f"EnhancedFxn_IFC[0..3] before {' '.join(hex(b) for b in before)}")
        print(f"EnhancedFxn_IFC[0..3] after  {' '.join(hex(b) for b in after)}")
        if or_masks:
            print(
                "patch OR: "
                + " ".join(f"IFC{i}=0x{m:02x}" for i, m in sorted(or_masks.items()))
            )
        if clear_masks:
            print(
                "patch CLEAR: "
                + " ".join(f"IFC{i}=0x{c:02x}" for i, c in sorted(clear_masks.items()))
            )
        print(f"PAYLOAD_HEX_PATCH {new.hex()}")

        if new == old:
            print("no patch needed (already set)")
            return 0

        if args.dry_run:
            print("dry-run: not writing NVM")
            return 0

        if not args.assume_yes:
            ans = input("Write CP2108 quad NVM NOW? [y/N] ").strip().lower()
            if ans not in {"y", "yes"}:
                print("abort")
                return 3

        trials: list[tuple[int, int, str]]
        if args.trial:
            bm = int(args.trial[0], 0)
            wv = int(args.trial[1], 0)
            trials = [(bm, wv, "explicit")]
        else:
            trials = [(bm, wv, "auto") for bm, wv in WV_SET_TRIALS]

        written = False
        last_err: BaseException | None = None
        for bm_req, wval, tag in trials:
            try:
                sys.stderr.write(
                    f"trial[{tag}] OUT bmReq=0x{bm_req:02x} wValue=0x{wval:04x} "
                    f"wIndex iface={args.iface}\n"
                )
                quad_write_try_pyusb(dev, args.iface, bm_req, wval, new)
                written = True
                sys.stderr.write(
                    f"trial[{tag}] OK bmReq=0x{bm_req:02x} wValue=0x{wval:04x}\n"
                )
                break
            except Exception as e:
                last_err = e
                sys.stderr.write(f"trial FAILED: {e}\n")

        if not written:
            sys.stderr.write(
                "\n*** All WRITE probes failed ***\n"
                "Programming likely needs Silicon Labs DLL or a traced USB opcode.\n"
                f"(last_error={last_err!r})\n"
            )
            return 5

        release_usb(dev, args.iface, detached_main)
        detached_main = False
        claimed_main = False

        time.sleep(0.25)

        if args.bus_reset:
            sys.stderr.write("USB bus reset...\n")
            try:
                dev.reset()
            except Exception as reset_ex:
                sys.stderr.write(f"usb reset: {reset_ex} (manual replug may still apply)\n")

        dev2 = resolve_dev(args.busadr, args.vid, args.pid)
        try:
            det2 = claim_usb(dev2, args.iface)
            try:
                if not args.no_verify:
                    final = quad_read_pyusb(dev2, args.iface)
                    fv = enhancedfxn_unpack(final)
                    print(
                        "EnhancedFxn_IFC[0..3] readback "
                        f"{' '.join(hex(b) for b in fv)}"
                    )
                    print(f"PAYLOAD_HEX_READBK {final.hex()}")
                    if fv != tuple(after):
                        print(
                            "warning: readback differs from patched intent — "
                            "WRITE may no-op internally or opcode wrong",
                            file=sys.stderr,
                        )
                        return 4
            finally:
                release_usb(dev2, args.iface, det2)
        except Exception as ver_ex:
            sys.stderr.write(f"verify/readback failed ({ver_ex})\n")

        print("VERIFY_OK" if not args.no_verify else "DONE (skip verify)")
        return 0
    finally:
        if claimed_main:
            release_usb(dev, args.iface, detached_main)


if __name__ == "__main__":
    raise SystemExit(main())
