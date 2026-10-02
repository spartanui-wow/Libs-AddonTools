"""Switch track, switch knob and check mark for the minimal window kit.

python tools/generate_controls.py

Drawn at 4x and shrunk for smooth edges. The track and the check are light so the game can tint
them (the accent colour when a switch is on, the kit's tick colour for a check); the knob keeps its
own colours.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / 'Media' / 'UI' / 'Kits' / 'minimal'
S = 4


def shrink(image, size):
    return image.resize(size, Image.LANCZOS)


def switch_track():
    w, h = 128 * S, 64 * S
    pad = 6 * S
    box = (pad, pad, w - pad, h - pad)
    radius = (h - 2 * pad) // 2
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    # Light body, a little darker at the top: the pill reads as a groove once tinted
    body = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(body)
    for y in range(h):
        t = (y - pad) / max(h - 2 * pad, 1)
        draw.line([(0, y), (w, y)], fill=int(200 + 40 * min(max(t, 0), 1)))
    # Inner shadow along the top edge
    inner = Image.new('L', (w, h), 0)
    ImageDraw.Draw(inner).rounded_rectangle((pad, pad + 5 * S, w - pad, h - pad + 5 * S), radius=radius, fill=255)
    shadow = ImageChops.subtract(mask, inner).filter(ImageFilter.GaussianBlur(3 * S))
    body = ImageChops.subtract(body, shadow.point(lambda v: v * 0.55))
    image = Image.merge('RGBA', (body, body, body, mask))
    # Thin rim, lighter than the body
    rim = Image.new('L', (w, h), 0)
    ImageDraw.Draw(rim).rounded_rectangle(box, radius=radius, outline=255, width=2 * S)
    rim_layer = Image.new('RGBA', (w, h), (255, 255, 255, 0))
    rim_layer.putalpha(rim.point(lambda v: v * 0.35))
    image.alpha_composite(rim_layer)
    return shrink(image, (128, 64))


def switch_knob():
    w = h = 64 * S
    image = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    # Soft drop shadow
    shadow = Image.new('L', (w, h), 0)
    ImageDraw.Draw(shadow).ellipse((10 * S, 13 * S, w - 10 * S, h - 7 * S), fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(4 * S))
    image.alpha_composite(Image.merge('RGBA', (Image.new('L', (w, h), 0),) * 3 + (shadow,)))
    # Body: warm off-white, shaded toward the bottom
    box = (9 * S, 8 * S, w - 9 * S, h - 10 * S)
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    shade = Image.new('RGB', (w, h))
    draw = ImageDraw.Draw(shade)
    for y in range(h):
        t = (y - box[1]) / (box[3] - box[1])
        t = min(max(t, 0), 1)
        draw.line([(0, y), (w, y)], fill=(int(250 - 34 * t), int(246 - 36 * t), int(238 - 40 * t)))
    body = shade.convert('RGBA')
    body.putalpha(mask)
    image.alpha_composite(body)
    # Rim
    rim = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(rim).ellipse(box, outline=(60, 50, 40, 150), width=2 * S)
    image.alpha_composite(rim)
    return shrink(image, (64, 64))


def check():
    w = h = 64 * S
    points = [(14 * S, 34 * S), (27 * S, 47 * S), (51 * S, 18 * S)]
    outline = Image.new('L', (w, h), 0)
    ImageDraw.Draw(outline).line(points, fill=255, width=16 * S, joint='curve')
    stroke = Image.new('L', (w, h), 0)
    ImageDraw.Draw(stroke).line(points, fill=255, width=9 * S, joint='curve')
    for x, y in (points[0], points[2]):
        r = 4.5 * S
        ImageDraw.Draw(stroke).ellipse((x - r, y - r, x + r, y + r), fill=255)
        r = 8 * S
        ImageDraw.Draw(outline).ellipse((x - r, y - r, x + r, y + r), fill=255)
    # A dark edge keeps a tinted check readable on light and dark panels alike
    image = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    edge = Image.merge('RGBA', (Image.new('L', (w, h), 20),) * 3 + (outline.point(lambda v: v * 0.7),))
    image.alpha_composite(edge)
    image.alpha_composite(Image.merge('RGBA', (Image.new('L', (w, h), 255),) * 3 + (stroke,)))
    return shrink(image, (64, 64))


def main():
    switch_track().save(OUT / 'switch-track.png')
    switch_knob().save(OUT / 'switch-knob.png')
    check().save(OUT / 'check.png')
    print('written to', OUT)


if __name__ == '__main__':
    main()
