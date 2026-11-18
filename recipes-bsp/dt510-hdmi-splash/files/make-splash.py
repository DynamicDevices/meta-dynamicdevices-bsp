#!/usr/bin/env python3
"""Letterbox existing AESL landscape artwork; never stretch or rotate HDMI."""
import sys
import hashlib
from pathlib import Path
from PIL import Image, ImageOps


def render(source, destination):
    with Image.open(source) as image:
        if image.size != (1920, 1200):
            raise ValueError('expected canonical 1920x1200 AESL artwork')
        image = image.convert('RGB')
        background = image.getpixel((0, 0))
        fitted = ImageOps.contain(image, (1280, 720), Image.Resampling.LANCZOS)
        canvas = Image.new('RGB', (1280, 720), background)
        canvas.paste(fitted, ((1280 - fitted.width) // 2, (720 - fitted.height) // 2))
        canvas.save(destination, format='BMP')
    # The signed script carries this digest. Fail the build on rendering drift
    # instead of shipping artwork that the boot script would necessarily reject.
    expected = '64b2f36f6305a8012d9dbab4ec2a266aba9f023bb4f4294eb30754dd37573da3'
    if hashlib.sha256(Path(destination).read_bytes()).hexdigest() != expected:
        raise ValueError('rendered splash differs from the signed boot-script digest')


if __name__ == '__main__':
    render(sys.argv[1], sys.argv[2])
