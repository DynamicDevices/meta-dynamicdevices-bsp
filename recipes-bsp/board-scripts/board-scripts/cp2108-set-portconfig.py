#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""CP2108: attempt to PATCH + WRITE quad NVM config blob (EnhancedFxn_IFC RS-485).

READ path matches linux cp210x.c + cp2108-get-portconfig.py (Vendor IN, bRequest 0xff,
wValue GET 0x370c).

WRITE path is NOT published in upstream Linux. This script probes a small ordered set of
DEVICE/INTERFACE Vendor OUT setups (wValue trials) documented in-code. If programming fails,
use Silicon Labs CP210xManufacturing.dll / official tools after USB-tracing which transfer
actually sticks.

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


def patch_enhanced_fxn(blob: bytes, ifc_masks: dict[int, int]) -> bytes:
    b = bytearray(blob)
    base = 30 + 30 + 4
    for ifc_idx in sorted(ifc_masks):
        mask = ifc_masks[ifc_idx] & 0xFF
        if not 0 <= ifc_idx <= 3:
            raise ValueError(f"invalid ifc idx {ifc_idx}")
        if mask & EF_IFC_GPIO_RS485_LOGIC:
            mask |= EF_IFC_GPIO_RS485
        off = base + ifc_idx
        b[off] = (b[off] | mask) & 0xFF
    return bytes(b)


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
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
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
        "--logical-invert-ifc",
        metavar="IFC",
        type=int,
        action="append",
        default=[],
        help="Also OR EF_IFC_GPIO_RS485_LOGIC (0x08) after RS485 bits for this IFC.",
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

    masks: dict[int, int] = {}
    for ifc in args.rs485_ifc:
        if ifc not in masks:
            masks[ifc] = 0
        masks[ifc] |= EF_IFC_GPIO_RS485
    for ifc in args.logical_invert_ifc:
        if ifc not in masks:
            masks[ifc] = 0
        masks[ifc] |= EF_IFC_GPIO_RS485 | EF_IFC_GPIO_RS485_LOGIC

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
        new = patch_enhanced_fxn(old, masks)
        after = enhancedfxn_unpack(new)

        print(f"EnhancedFxn_IFC[0..3] before {' '.join(hex(b) for b in before)}")
        print(f"EnhancedFxn_IFC[0..3] after  {' '.join(hex(b) for b in after)}")
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
