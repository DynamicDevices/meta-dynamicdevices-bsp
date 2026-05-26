#!/usr/bin/env python3
"""Sanity-check kernel patch files for common do_patch failures."""
from __future__ import annotations

import sys
from pathlib import Path

ALLOWED_PREFIXES = (
    "diff --git ",
    "index ",
    "--- ",
    "+++ ",
    "@@ ",
    "\\ No newline",
    "From ",
    "Date: ",
    "Subject: ",
    "Signed-off-by:",
)


def _in_patch_body(lines: list[str]) -> int:
    for i, line in enumerate(lines):
        if line.startswith("diff --git ") or line.startswith("--- a/") or line.startswith("--- "):
            return i
    return 0


def validate_patch(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    errors: list[str] = []
    in_diff = False
    for i, line in enumerate(lines, start=1):
        if not in_diff:
            if line.startswith("diff --git ") or line.startswith("--- "):
                in_diff = True
            continue
        if any(line.startswith(p) for p in ALLOWED_PREFIXES):
            continue
        if line.startswith((" ", "-", "+")):
            continue
        if line.strip() == "":
            continue
        # Email / stat headers before first diff are OK
        if not in_diff:
            continue
        errors.append(
            f"{path}:{i}: orphan line in patch body (must start with ' ', '-', '+', or @@): "
            f"{line[:72]!r}"
        )
    return errors


def main() -> int:
    rc = 0
    for arg in sys.argv[1:]:
        path = Path(arg)
        errs = validate_patch(path)
        if errs:
            rc = 1
            for e in errs:
                print(f"ERROR: {e}", file=sys.stderr)
        else:
            print(f"OK: {path}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
