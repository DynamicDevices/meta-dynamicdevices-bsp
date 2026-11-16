#!/usr/bin/env python3
"""Regenerate the bench-tested 1080p pattern. Development dependency: Pillow.

Assets are committed so Yocto and the board need neither Pillow nor font files.
Use DejaVuSans.ttf to reproduce the original lab pattern.
"""
import argparse
import gzip
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def generate(output, font_path):
    w, h = 1920, 1080
    im = Image.new('RGB', (w, h), '#161616')
    d = ImageDraw.Draw(im)
    large = ImageFont.truetype(str(font_path), 46)
    medium = ImageFont.truetype(str(font_path), 29)
    small = ImageFont.truetype(str(font_path), 23)
    colours = ['#ffffff', '#ff3030', '#ff9600', '#ffff00', '#20ff20', '#00ffff', '#2080ff', '#df40ff']
    for n, colour in enumerate(colours):
        p = n * 16
        d.rectangle((p, p, w-1-p, h-1-p), outline=colour, width=16)
    for edge, centre in [('TOP', (960, 215)), ('BOTTOM', (960, 865))]:
        d.text(centre, edge + ' EDGE', font=large, fill='white', anchor='mm')
    for n, colour in enumerate(colours):
        p, label = n*16, f'{n*16}-{n*16+15}'
        x = 430+n*145
        d.line((x, p, x, 150), fill='black' if n < 4 else 'white', width=3)
        d.rectangle((x-58, 145, x+58, 177), fill='#161616')
        d.text((x, 161), label, font=small, fill=colour, anchor='mm')
        d.line((x, h-1-p, x, h-151), fill='black' if n < 4 else 'white', width=3)
        d.rectangle((x-58, h-178, x+58, h-146), fill='#161616')
        d.text((x, h-162), label, font=small, fill=colour, anchor='mm')
        y = 275+n*72
        d.line((p, y, 155, y), fill='black' if n < 4 else 'white', width=3)
        d.rectangle((145, y-18, 275, y+18), fill='#161616')
        d.text((210, y), label, font=small, fill=colour, anchor='mm')
        d.line((w-1-p, y, w-156, y), fill='black' if n < 4 else 'white', width=3)
        d.rectangle((w-276, y-18, w-146, y+18), fill='#161616')
        d.text((w-211, y), label, font=small, fill=colour, anchor='mm')
    lines = [(330, 'DT510 — EDGE CROPPING TEST', large),
             (390, '1920 x 1080 native pixels — no mode change', medium),
             (462, 'WHITE must touch all four screen edges.', medium),
             (512, 'Missing colours mean the picture is being cropped.', medium),
             (562, 'Report the FIRST visible colour at each edge:', medium),
             (612, 'LEFT / RIGHT / TOP / BOTTOM', medium)]
    for y, text, font in lines:
        d.text((960, y), text, font=font, fill='white', anchor='mm')
    for i, colour in enumerate(colours):
        x = 390+i*145
        d.rectangle((x, 680, x+120, 720), fill=colour)
        d.text((x+60, 743), f'{i*16}-{i*16+15}px', font=small, fill='white', anchor='mm')
    d.text((960, 805), 'Example: yellow first = about 48–63 pixels cropped.',
           font=medium, fill='white', anchor='mm')
    output.mkdir(parents=True, exist_ok=True)
    im.save(output / 'overscan-1920x1080.png')
    (output / 'overscan-1920x1080.bgrx.gz').write_bytes(
        gzip.compress(im.tobytes('raw', 'BGRX'), compresslevel=9, mtime=0))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] /
                        'recipes-bsp/dt510-hdmi-test/files')
    parser.add_argument('--font', type=Path,
                        default=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
    args = parser.parse_args()
    generate(args.output, args.font)
