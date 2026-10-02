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


def title_frame():
    """A plaque that holds a window's title on its top edge, cut in three (left cap, middle, right cap).

    Two layers so a kit can tint them separately: the fill (the kit's raised surface) and the
    edges (its trim). The ends come to a point; a second line inside the first makes it read as a
    frame. Caps are 24px, the middle 16px; everything is 32px tall.
    """
    cap, mid, h = 24, 16, 32
    w = cap * 2 + mid
    W, H = w * S, h * S
    top, bottom = 5 * S, 27 * S
    tip = 2 * S
    bevel = 11 * S
    outer = [(tip, H // 2), (tip + bevel, top), (W - tip - bevel, top), (W - tip, H // 2), (W - tip - bevel, bottom), (tip + bevel, bottom)]

    # Fill: light at the top, a little darker below, so the plaque looks raised once tinted
    shape = Image.new('L', (W, H), 0)
    ImageDraw.Draw(shape).polygon(outer, fill=255)
    shade = Image.new('L', (W, H), 0)
    draw = ImageDraw.Draw(shade)
    for y in range(H):
        t = (y - top) / max(bottom - top, 1)
        draw.line([(0, y), (W, y)], fill=int(255 - 45 * min(max(t, 0), 1)))
    fill = Image.merge('RGBA', (shade, shade, shade, shape))

    # Edges: the outline, then a thinner line inside it
    inset = 3 * S
    inner = [(tip + inset * 1.4, H // 2), (tip + bevel + inset * 0.6, top + inset), (W - tip - bevel - inset * 0.6, top + inset),
             (W - tip - inset * 1.4, H // 2), (W - tip - bevel - inset * 0.6, bottom - inset), (tip + bevel + inset * 0.6, bottom - inset)]
    lines = Image.new('L', (W, H), 0)
    draw = ImageDraw.Draw(lines)
    draw.line(outer + [outer[0]], fill=255, width=int(1.6 * S), joint='curve')
    draw.line(inner + [inner[0]], fill=150, width=int(0.9 * S), joint='curve')
    edge = Image.merge('RGBA', (Image.new('L', (W, H), 255),) * 3 + (lines,))

    pieces = {}
    for name, image in (('fill', fill), ('edge', edge)):
        small = shrink(image, (w, h))
        pieces[name + '-left'] = small.crop((0, 0, cap, h))
        # The middle repeats sideways; cut it from the plain stretch between the ends
        pieces[name + '-center'] = small.crop((cap, 0, cap + mid, h))
        pieces[name + '-right'] = small.crop((cap + mid, 0, w, h))
    return pieces


def main():
    switch_track().save(OUT / 'switch-track.png')
    switch_knob().save(OUT / 'switch-knob.png')
    check().save(OUT / 'check.png')
    for name, image in title_frame().items():
        image.save(OUT / ('title-frame-' + name + '.png'))
    print('written to', OUT)


if __name__ == '__main__':
    main()
