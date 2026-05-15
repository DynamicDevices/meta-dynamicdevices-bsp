#!/usr/bin/env python3
"""
Transmit fixed bytes on a serial TTY (e.g. CP2108 /dev/ttyUSB*) for RS‑485 lab bring-up.

DT510 CP2108 (U13): bridge UART **[2]**/**[3]** are RS‑485 (**DE** from CP2108 **GPIO.10**/**GPIO.14** when NVM programmed); **[0]**/**[1]** are RS‑232 —
do not assume **`ttyUSB2`**=`UART2`; use **`udev` by-path/by-id`** to map minors.

  - Sets 8n1 raw port via stty(1) for baud (works with many non-standard integer rates).
  - Kernel optional: **`--rs485`** uses **TIOCSRS485** (**`serial_rs485`**) — **only if the
    USB‑serial driver implements it**. That is **software** in Linux (RTS timing / ioctl path),
    not the same thing as enabling **Silabs CP2108 hardware RS‑485** in NVM (GPIO asserts DE
    along with TX). Use **`--rs485`** here to **test** whether **`cp210x`** (and friends) exposes
    the ioctl; failures are normal on drivers with no **`rs485`** support.
  - **Production intent:** run **hardware RS‑485** on CP2108 (NVM / Enhanced Feature config via
    Silabs CP210x programming tools) so the bridge drives **DE/RE** reliably without depending on
    the kernel RTS hook.

Examples (on target, after package board-scripts installs /usr/sbin/rs485_tx_bytes):

  rs485_tx_bytes --tty /dev/ttyUSB0 --baud 115200
  rs485_tx_bytes --tty /dev/ttyUSB1 --baud 9600 --hex "DE AD BE EF"
  rs485_tx_bytes --tty /dev/ttyUSB0 --baud 115200 --rs485
  rs485_tx_bytes --tty /dev/ttyUSB0 --baud 115200 --rs485 --rs485-apply-timing late
  rs485_tx_bytes --tty /dev/ttyUSB2 --baud 115200 --rs485-dump
  rs485_tx_bytes --tty /dev/ttyUSB2 --baud 115200 --loop --interval 0.5

Loop mode: repeats until you press a key (interactive TTY) or Ctrl+C. Without a TTY on
stdin, only Ctrl+C stops the loop.

RS485 ioctl: **`--rs485`** sends **TIOCSRS485** (**`--rs485-apply-timing`** **`early`** = after
**`open`** (default), **`late`** = after **`termios`**). **`--rs485-dump`** uses **TIOCGRS485**,
prints flags/delays, exits (**no transmit**).

If **TIOCSRS485** fails (**EINVAL** / **EOPNOTSUPP**), the driver has no **RS485** ioctl path;
for lab you can use an auto‑direction transceiver or bit‑bang **DE**; for product, prefer
**CP2108 hardware RS‑485** in NVM above.
"""

from __future__ import annotations

import argparse
import fcntl
import os
import select
import struct
import subprocess
import sys
import termios
import time
import tty as tty_module

# Kernel serial_rs485 ioctls (only if usb-serial driver implements them — not CP2108 NVM RS485).
TIOCGRS485 = 0x542E
TIOCSRS485 = 0x542F

_RS485_BUF_LEN = 32  # 8 x __u32 struct serial_rs485 (common Linux uapi layout)

# linux/uapi/linux/serial.h (subset)
SER_RS485_ENABLED = 1 << 0
SER_RS485_RTS_ON_SEND = 1 << 1
SER_RS485_RTS_AFTER_SEND = 1 << 2
SER_RS485_RX_DURING_TX = 1 << 4
SER_RS485_TERMINATE_BUS = 1 << 5
SER_RS485_ADDRB = 1 << 6
SER_RS485_ADDR_RECV = 1 << 7
SER_RS485_ADDR_DEST = 1 << 8
SER_RS485_MODE_RS422 = 1 << 9

_RS485_KNOWN_MASK = (
    SER_RS485_ENABLED
    | SER_RS485_RTS_ON_SEND
    | SER_RS485_RTS_AFTER_SEND
    | SER_RS485_RX_DURING_TX
    | SER_RS485_TERMINATE_BUS
    | SER_RS485_ADDRB
    | SER_RS485_ADDR_RECV
    | SER_RS485_ADDR_DEST
    | SER_RS485_MODE_RS422
)

# tcgetattr()/tcsetattr() attr list indices (POSIX — always 0..6 on Unix Python).
# Some embedded images ship a minimal `termios` without IFLAG/CC name aliases.
_TERMIOS_IFLAG = 0
_TERMIOS_OFLAG = 1
_TERMIOS_CFLAG = 2
_TERMIOS_LFLAG = 3
_TERMIOS_CC_IDX = 6
# Linux tty/cc.h VMIN/VTIME (Python usually exposes them; fall back if absent)
_TERMIOS_VMIN = getattr(termios, "VMIN", 6)
_TERMIOS_VTIME = getattr(termios, "VTIME", 5)
_CS8 = getattr(termios, "CS8", 0o0000060)
_CREAD = getattr(termios, "CREAD", 0o0000200)
_CLOCAL = getattr(termios, "CLOCAL", 0o0004000)
_PARENB = getattr(termios, "PARENB", 0o0000400)
_CSTOPB = getattr(termios, "CSTOPB", 0o0000100)


def parse_hex(s: str) -> bytes:
    parts = s.replace(",", " ").split()
    out = bytearray()
    for p in parts:
        p = p.strip()
        if not p:
            continue
        out.append(int(p, 16))
    return bytes(out)


def rs485_ioctl_buf(flags: int, delay_before: int = 0, delay_after: int = 0) -> bytes:
    """Pack struct serial_rs485 (8 x __u32) for common Linux layouts."""
    return struct.pack(
        "@IIIIIIII",
        flags,
        delay_before,
        delay_after,
        0,
        0,
        0,
        0,
        0,
    )


def unpack_rs485(buf: bytes | bytearray) -> tuple[int, int, int, tuple[int, ...]]:
    vals = struct.unpack("@IIIIIIII", buf)
    flags, delay_b, delay_a = vals[0], vals[1], vals[2]
    padding = vals[3:]
    return flags, delay_b, delay_a, padding


def format_rs485_flags(flags: int) -> str:
    bits: list[tuple[int, str]] = [
        (SER_RS485_ENABLED, "ENABLED"),
        (SER_RS485_RTS_ON_SEND, "RTS_ON_SEND"),
        (SER_RS485_RTS_AFTER_SEND, "RTS_AFTER_SEND"),
        (SER_RS485_RX_DURING_TX, "RX_DURING_TX"),
        (SER_RS485_TERMINATE_BUS, "TERMINATE_BUS"),
        (SER_RS485_ADDRB, "ADDRB"),
        (SER_RS485_ADDR_RECV, "ADDR_RECV"),
        (SER_RS485_ADDR_DEST, "ADDR_DEST"),
        (SER_RS485_MODE_RS422, "MODE_RS422"),
    ]
    known = "|".join(name for mask, name in bits if flags & mask) or "(none)"
    unknown = flags & ~_RS485_KNOWN_MASK
    extra = f" +0x{unknown:x}" if unknown else ""
    return f"{known}{extra}"


def rs485_ioctl_get(fd: int) -> tuple[int, int, int]:
    buf = bytearray(_RS485_BUF_LEN)
    fcntl.ioctl(fd, TIOCGRS485, buf)
    flags, delay_b, delay_a, _ = unpack_rs485(buf)
    return flags, delay_b, delay_a


def rs485_ioctl_set(fd: int, flags: int, delay_before_us: int, delay_after_us: int) -> None:
    buf = rs485_ioctl_buf(flags, delay_before_us, delay_after_us)
    fcntl.ioctl(fd, TIOCSRS485, buf)


def configure_termios_raw_8n1(fd: int) -> None:
    attr = termios.tcgetattr(fd)
    attr[_TERMIOS_IFLAG] = 0
    attr[_TERMIOS_OFLAG] = 0
    attr[_TERMIOS_LFLAG] = 0
    attr[_TERMIOS_CFLAG] = (_CS8 | _CREAD | _CLOCAL) & ~(_PARENB | _CSTOPB)
    attr[_TERMIOS_CC_IDX][_TERMIOS_VMIN] = 0
    attr[_TERMIOS_CC_IDX][_TERMIOS_VTIME] = 0
    termios.tcsetattr(fd, getattr(termios, "TCSANOW", 0), attr)
    termios.tcflush(fd, termios.TCIOFLUSH)


def rs485_compute_flags(args: argparse.Namespace) -> int:
    flags = SER_RS485_ENABLED | SER_RS485_RTS_ON_SEND
    if args.rs485_idle_rts_high:
        flags |= SER_RS485_RTS_AFTER_SEND
    if args.rs485_rx_during_tx:
        flags |= SER_RS485_RX_DURING_TX
    return flags


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--tty", default="/dev/ttyUSB0", help="Serial device (default /dev/ttyUSB0)")
    ap.add_argument("--baud", type=int, default=115200, help="Line speed (default 115200)")
    ap.add_argument(
        "--hex",
        default="01 02 03 04 05 06 07 08",
        help='Space-separated hex bytes to send (default "01 02 ... 08")',
    )
    ap.add_argument(
        "--rs485",
        action="store_true",
        help=(
            "Linux TIOCSRS485 / serial_rs485 (driver must implement; lab test only). "
            "Product RS485 should use CP2108 hardware/NVM GPIO DE, not this ioctl alone."
        ),
    )
    ap.add_argument(
        "--rs485-delay-after-us",
        type=int,
        default=0,
        metavar="US",
        help="delay_rts_after_send in microseconds (0 default)",
    )
    ap.add_argument(
        "--rs485-idle-rts-high",
        action="store_true",
        help="Also set SER_RS485_RTS_AFTER_SEND (try if DE idle state needs RTS high)",
    )
    ap.add_argument(
        "--rs485-delay-before-us",
        type=int,
        default=0,
        metavar="US",
        help="delay_rts_before_send in microseconds (0 default)",
    )
    ap.add_argument(
        "--rs485-rx-during-tx",
        action="store_true",
        help="Set SER_RS485_RX_DURING_TX if the driver honours it",
    )
    ap.add_argument(
        "--rs485-apply-timing",
        choices=("early", "late"),
        default="early",
        metavar="WHEN",
        help=(
            "When to call TIOCSRS485: "
            "'early'=right after open (default); "
            "'late'=after termios is programmed (try if RTS/DE ignores early ioctl)"
        ),
    )
    ap.add_argument(
        "--rs485-dump",
        action="store_true",
        help="TIOCGRS485 (if driver supports it); not a substitute for CP2108 NVM RS485 config",
    )
    ap.add_argument(
        "--loop",
        action="store_true",
        help="Repeat transmit until a key is pressed (TTY stdin) or Ctrl+C",
    )
    ap.add_argument(
        "--interval",
        type=float,
        default=1.0,
        metavar="SEC",
        help="Seconds between bursts in --loop mode (default 1.0; 0 = back-to-back)",
    )
    args = ap.parse_args()

    if args.loop and args.rs485_dump:
        print("error: --rs485-dump cannot be used with --loop", file=sys.stderr)
        return 1

    tty_dev = args.tty
    if not os.path.exists(tty_dev):
        print(f"error: {tty_dev} does not exist", file=sys.stderr)
        return 1

    payload = parse_hex(args.hex)
    if not args.rs485_dump and not payload:
        print("error: no bytes after --hex", file=sys.stderr)
        return 1

    saved_stdin_term = None

    def stdin_cbreak_enter() -> None:
        nonlocal saved_stdin_term
        if not args.loop or not sys.stdin.isatty():
            return
        fd = sys.stdin.fileno()
        saved_stdin_term = termios.tcgetattr(fd)
        tty_module.setcbreak(fd)

    def stdin_cbreak_exit() -> None:
        if saved_stdin_term is None:
            return
        fd = sys.stdin.fileno()
        termios.tcsetattr(
            fd,
            getattr(termios, "TCSAFLUSH", getattr(termios, "TCSANOW", 0)),
            saved_stdin_term,
        )

    def stdin_quit_try() -> bool:
        """If a key is already waiting, consume it and return True."""
        if saved_stdin_term is None:
            return False
        stdin_fd = sys.stdin.fileno()
        r, _, _ = select.select([sys.stdin], [], [], 0)
        if not r:
            return False
        try:
            os.read(stdin_fd, 64)
        except OSError:
            pass
        return True

    def interruptible_sleep(seconds: float) -> bool:
        """Return True if user pressed a key (consume and stop)."""
        if seconds <= 0:
            return False
        if saved_stdin_term is None:
            time.sleep(seconds)
            return False
        deadline = time.monotonic() + seconds
        stdin_fd = sys.stdin.fileno()
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            r, _, _ = select.select([sys.stdin], [], [], min(0.2, remaining))
            if r:
                try:
                    os.read(stdin_fd, 64)
                except OSError:
                    pass
                return True

    stdin_cbreak_enter()
    if args.loop and saved_stdin_term is None:
        print(
            "note: stdin is not a TTY; loop runs until Ctrl+C (no single-key exit)",
            file=sys.stderr,
        )

    try:
        subprocess.check_call(
            [
                "stty",
                "-F",
                tty_dev,
                str(args.baud),
                "cs8",
                "-parenb",
                "-cstopb",
                "raw",
                "-echo",
            ],
            shell=False,
        )

        fd = os.open(tty_dev, os.O_RDWR | os.O_NOCTTY)
        try:
            delay_b = max(0, args.rs485_delay_before_us)
            delay_a = max(0, args.rs485_delay_after_us)

            if args.rs485_dump:
                configure_termios_raw_8n1(fd)
                try:
                    rf, rd_b, rd_a = rs485_ioctl_get(fd)
                except OSError as e:
                    print(f"error: TIOCGRS485 failed ({e})", file=sys.stderr)
                    return 1
                print(
                    f"TIOCGRS485 {tty_dev}: raw_flags=0x{rf:x} ({format_rs485_flags(rf)}) "
                    f"delay_rts_before_send_us={rd_b} delay_rts_after_send_us={rd_a}"
                )
                return 0

            if args.rs485 and args.rs485_apply_timing == "early":
                try:
                    rs485_ioctl_set(fd, rs485_compute_flags(args), delay_b, delay_a)
                except OSError as e:
                    print(
                        f"error: TIOCSRS485 failed ({e}); try late timing (--rs485-apply-timing late) "
                        f"or without --rs485",
                        file=sys.stderr,
                    )
                    return 1

            configure_termios_raw_8n1(fd)

            if args.rs485 and args.rs485_apply_timing == "late":
                try:
                    rs485_ioctl_set(fd, rs485_compute_flags(args), delay_b, delay_a)
                except OSError as e:
                    print(
                        f"error: TIOCSRS485 failed ({e}); try early (--rs485-apply-timing early) "
                        f"or without --rs485",
                        file=sys.stderr,
                    )
                    return 1

            burst = 0
            stop_reason = ""

            try:
                while True:
                    burst += 1
                    n = os.write(fd, payload)
                    if n != len(payload):
                        print(f"error: short write {n}/{len(payload)}", file=sys.stderr)
                        return 1
                    termios.tcdrain(fd)
                    tag = f" [{burst}]" if args.loop else ""
                    print(
                        f"OK{tag}: wrote {n} bytes to {tty_dev} @ {args.baud} baud: {payload.hex(' ')}"
                    )
                    if not args.loop:
                        break
                    gap = max(0.0, args.interval)
                    if gap > 0:
                        if interruptible_sleep(gap):
                            stop_reason = "key pressed"
                            break
                    elif stdin_quit_try():
                        stop_reason = "key pressed"
                        break
            except KeyboardInterrupt:
                stop_reason = "Ctrl+C"

            if args.loop and stop_reason:
                print(f"stopped: {stop_reason}", file=sys.stderr)
            return 0
        finally:
            os.close(fd)
    finally:
        stdin_cbreak_exit()


if __name__ == "__main__":
    sys.exit(main())
