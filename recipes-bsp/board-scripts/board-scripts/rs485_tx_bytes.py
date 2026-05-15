#!/usr/bin/env python3
"""
Transmit fixed bytes on a serial TTY (e.g. CP2108 /dev/ttyUSB*) for RS-485 lab bring-up.

DT510 CP2108 (U13): bridge UART **[2]**/**[3]** are RS‑485 (**DE** from CP2108 **GPIO.10**/**GPIO.14** when NVM programmed); **[0]**/**[1]** are RS‑232 —
do not assume **`ttyUSB2`**=`UART2`; use **`udev` by-path/by-id`** to map minors.

  - Sets 8n1 raw port via stty(1) for baud (works with many non-standard integer rates).
  - Optional: TIOCSRS485 so the kernel toggles RTS around TX (driver must support it).

Examples (on target, after package board-scripts installs /usr/sbin/rs485_tx_bytes):

  rs485_tx_bytes --tty /dev/ttyUSB0 --baud 115200
  rs485_tx_bytes --tty /dev/ttyUSB1 --baud 9600 --hex "DE AD BE EF"
  rs485_tx_bytes --tty /dev/ttyUSB0 --baud 115200 --rs485

If --rs485 fails with EINVAL/EOPNOTSUPP, the USB-serial driver likely has no RS485
hook; use a transceiver with auto direction or drive DE/RE from GPIO / userspace RTS.
"""

from __future__ import annotations

import argparse
import fcntl
import os
import struct
import subprocess
import sys
import termios

# linux/uapi/asm-generic/ioctls.h
TIOCSRS485 = 0x542F

# linux/uapi/linux/serial.h
SER_RS485_ENABLED = 1 << 0
SER_RS485_RTS_ON_SEND = 1 << 1
SER_RS485_RTS_AFTER_SEND = 1 << 2


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
        help="Enable kernel RS485 mode (RTS timing); requires driver TIOCSRS485 support",
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
    args = ap.parse_args()

    tty = args.tty
    if not os.path.exists(tty):
        print(f"error: {tty} does not exist", file=sys.stderr)
        return 1

    payload = parse_hex(args.hex)
    if not payload:
        print("error: no bytes after --hex", file=sys.stderr)
        return 1

    subprocess.check_call(
        [
            "stty",
            "-F",
            tty,
            str(args.baud),
            "cs8",
            "-parenb",
            "-cstopb",
            "raw",
            "-echo",
        ],
        shell=False,
    )

    fd = os.open(tty, os.O_RDWR | os.O_NOCTTY)
    try:
        if args.rs485:
            flags = SER_RS485_ENABLED | SER_RS485_RTS_ON_SEND
            if args.rs485_idle_rts_high:
                flags |= SER_RS485_RTS_AFTER_SEND
            buf = rs485_ioctl_buf(flags, 0, max(0, args.rs485_delay_after_us))
            try:
                fcntl.ioctl(fd, TIOCSRS485, buf)
            except OSError as e:
                print(f"error: TIOCSRS485 failed ({e}); try without --rs485", file=sys.stderr)
                return 1

        attr = termios.tcgetattr(fd)
        attr[termios.IFLAG] = 0
        attr[termios.OFLAG] = 0
        attr[termios.LFLAG] = 0
        attr[termios.CFLAG] = (termios.CS8 | termios.CREAD | termios.CLOCAL) & ~(termios.PARENB | termios.CSTOPB)
        attr[termios.CC][termios.VMIN] = 0
        attr[termios.CC][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, attr)
        termios.tcflush(fd, termios.TCIOFLUSH)

        n = os.write(fd, payload)
        if n != len(payload):
            print(f"error: short write {n}/{len(payload)}", file=sys.stderr)
            return 1
        termios.tcdrain(fd)
        print(f"OK: wrote {n} bytes to {tty} @ {args.baud} baud: {payload.hex(' ')}")
        return 0
    finally:
        os.close(fd)


if __name__ == "__main__":
    sys.exit(main())
