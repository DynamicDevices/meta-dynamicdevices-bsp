#!/usr/bin/env python3
"""Run display-filter regressions with pinned U-Boot SLRE, not host regex.

Native test only: not a Hush, BitBake or physical boot test.
Assisted-by: Briar
"""
import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile

BSP = Path(__file__).resolve().parents[1]
SOURCE_SHA = {
    "lib/slre.c": "005f0b2a8b629f907e3f9d857f082752caa5a1942a6af667b111a314da16b684",
    "include/slre.h": "39fdedf5fb488ae75173dc37a93de2cc4dad76c7d281a6a032af7b6d4f3f8e38",
}
REVISION = "adbe53791d8f3cc2d7ecf2a3f308494d561def9e"


def run(command, **kwargs):
    return subprocess.run(command, check=True, capture_output=True, text=True,
                          timeout=30, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True,
                        help="U-Boot source directory containing lib/slre.c and include/slre.h")
    args = parser.parse_args()
    for name, expected in SOURCE_SHA.items():
        actual = hashlib.sha256((args.source / name).read_bytes()).hexdigest()
        if actual != expected:
            raise RuntimeError(f"Pinned U-Boot source mismatch: {name}")
    fragment = (BSP / "recipes-bsp/u-boot/u-boot-ostree-scr-fit/display-bootargs.cmd").read_text()
    pattern = re.search(r'setexpr aesl_display_keep sub "([^"]+)"', fragment)[1]
    with tempfile.TemporaryDirectory(prefix="dt510-slre-") as temp:
        root = Path(temp)
        # SLRE_TEST selects the engine's native standard-library includes;
        # rename only its bundled example main, leaving all regex code intact.
        run(["cc", "-DSLRE_TEST", "-Dmain=uboot_slre_example_main",
             "-idirafter", str(args.source / "include"), "-c",
             str(args.source / "lib/slre.c"), "-o", str(root / "slre.o")])
        probe = root / "probe"
        run(["cc", "-idirafter", str(args.source / "include"),
             str(BSP / "scripts/display-bootargs-slre-probe.c"),
             str(root / "slre.o"), "-o", str(probe)])

        def matches(expression, value):
            result = subprocess.run([str(probe), expression, value],
                                    capture_output=True, text=True, timeout=5)
            if result.returncode not in (0, 1):
                raise RuntimeError(f"SLRE probe failed: {result.stderr[:300]}")
            return result.returncode == 0

        # Freeze the actual 707 defect as well as its repair: ranges are literal
        # sets in SLRE, so [0-9] accepts '-' but not '1'.
        old = "^console=tty[0-9]+$"
        assert not matches(old, "console=tty1")
        assert matches(old, "console=tty-")
        for n in list(range(64)) + [999]:
            assert matches(pattern, f"console=tty{n}"), n
        retained = ["console=ttymxc1,115200", "console=ttyS0,115200",
                    "console=ttyAMA0", "earlycon=ec_imx6q,0x30890000,115200",
                    "root=/dev/mmcblk2p2", "ostree=/ostree/boot.0/lmp/hash/0",
                    "rootfstype=ext4", "audit=1", "console=tty-", "console=tty"]
        for value in retained:
            assert not matches(pattern, value), value
        # Exercise the actual fragment plus its environment operations. sh
        # models control flow, but the compiled U-Boot engine decides matches.
        shim = r'''
setenv() {
    key=$1; shift
    if test "$#" = 0; then unset "$key"; else export "$key=$*"; fi
}
setexpr() {
    test "$FAIL_REGEX" != 1 || return 1
    key=$1; shift
    test "$1" = sub || return 2
    "$UBOOT_SLRE_PROBE" "$2" "$4" || return $?
    export "$key=$3"
}
'''
        values = ["console=tty1", *retained, "console=tty0", "console=tty63"]
        for failure in (False, True):
            for mode in ("", " video=HDMI-A-1:1280x720@60e"):
                env = dict(os.environ, bootargs=" ".join(values),
                           FAIL_REGEX=str(int(failure)), UBOOT_SLRE_PROBE=str(probe))
                script = shim + fragment.replace("@@AESL_DISPLAY_MODE@@", mode)
                script += '\nprintf "AESL_ARGS=%s\\n" "$bootargs"\n'
                output = run(["sh", "-e", "-c", script], env=env).stdout
                actual = output.removeprefix("AESL_ARGS=").split()
                expected = values if failure else retained
                expected = expected + ["splash", "logo.nologo", "vt.global_cursor_default=0"] + mode.split()
                assert actual == expected, (actual, expected)
        print(f"PASS: U-Boot {REVISION} SLRE; 707 defect reproduced; "
              "65 VT sinks removed; serial/root/OTA retained; mode and failure paths pass.")


if __name__ == "__main__":
    main()
