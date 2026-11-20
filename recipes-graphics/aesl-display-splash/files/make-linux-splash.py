#!/usr/bin/env python3
"""Render common desktop/framebuffer art without changing the U-Boot bitmap."""
import importlib.util
import sys
from pathlib import Path

from PIL import Image


def render(machine, source, desktop, framebuffer):
    source, desktop, framebuffer = map(Path, (source, desktop, framebuffer))
    if machine == "imx8mm-jaguar-dt510":
        spec = importlib.util.spec_from_file_location("uboot_splash", source.parent / "make-splash.py")
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        bitmap = desktop.with_suffix(".bmp")
        generator.render(source, bitmap)  # Includes the confirmed bitmap SHA-256 gate.
        with Image.open(bitmap) as image:
            image.save(desktop)
            image.save(framebuffer)
    else:
        with Image.open(source) as image:
            image = image.convert("RGB")
            image.save(desktop)
            # Match Screen's existing DSI-1 rotate-90 output policy. Weston
            # consumes logical landscape art; PSplash writes native panel pixels.
            if machine == "imx8mm-jaguar-screen":
                image = image.transpose(Image.Transpose.ROTATE_90)
            image.save(framebuffer)


if __name__ == "__main__":
    render(*sys.argv[1:])
