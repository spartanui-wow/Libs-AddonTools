import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
MINIMAL_KIT = ROOT / "Media" / "UI" / "Kits" / "minimal"
SPARTAN_WAR_KIT = ROOT.parent / "SpartanUI" / "images" / "kits" / "war"
WAR_PAINTED = Path(__file__).parent / "source" / "wartable-painted"
WAR_TRIM_SOURCE = WAR_PAINTED / "trim-kit-source.png"
MAP_PANEL_SOURCE = Path(__file__).parent / "source" / "map-panel-original.png"
MAP_RAIL_SOURCE = Path(__file__).parent / "source" / "map-rail-original.png"
FLAG_SOURCE = Path(__file__).parent / "source" / "wartable-flag-original.png"
MAP_CHECK = Path(__file__).parent / "output" / "map_check.png"
FRAME_CHECK = Path(__file__).parent / "output" / "frame_check.png"
RAIL_COMPARE = Path(__file__).parent / "output" / "rail_compare.png"
MAP_REFERENCE = ROOT / ".impeccable" / "mocks" / "decision" / "assigned.png"
RAIL_REFERENCE = ROOT / ".impeccable" / "mocks" / "decision" / "rail-reference.png"
MAP_BASE = (24, 34, 42)
MAP_INK_CAP = (52, 66, 76)
BODY_TEXT = (237, 232, 217)
SECONDARY_TEXT = (184, 173, 150)
STAGE_BACKDROPS = Path(__file__).parent / "source" / "stage-backdrops"
SPARTAN_BACKDROPS = ROOT.parent / "SpartanUI" / "images" / "setup" / "backdrops"
THEME_BACKDROPS = (
    "War",
    "Classic",
    "Midnight",
    "Fel",
    "Arcane",
    "Digital",
    "Tribal",
    "Minimal",
    "Transparent",
    "ModernFlat",
    "HealerGrid",
    "ClassicDark",
)

FRAME_BEAM = 24
BRASS_DARK = (83, 52, 20, 255)
BRASS_MID = (177, 126, 54, 255)
BRASS_LIGHT = (239, 203, 112, 255)


def downsample(image, size):
    return image.resize(size, Image.Resampling.LANCZOS)


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def channel_percentile(image, percentile):
    histogram = image.histogram()
    threshold = image.width * image.height * percentile
    total = 0
    for value, count in enumerate(histogram):
        total += count
        if total >= threshold:
            return value
    return 255


def map_value(image):
    gray = ImageOps.grayscale(image)
    low = channel_percentile(gray, 0.08)
    high = max(low + 1, channel_percentile(gray, 0.995))

    def tone(value, channel):
        normalized = max(0.0, min(1.0, (value - low) / (high - low)))
        ink = normalized**1.65
        return round(MAP_BASE[channel] + (MAP_INK_CAP[channel] - MAP_BASE[channel]) * ink)

    return Image.merge(
        "RGB",
        tuple(gray.point([tone(value, channel) for value in range(256)]) for channel in range(3)),
    )


def relative_luminance(color):
    def linear(channel):
        channel /= 255
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    red, green, blue = (linear(channel) for channel in color)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast_ratio(first, second):
    light, dark = sorted((relative_luminance(first), relative_luminance(second)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def luminance_percentile_pixel(image, percentile):
    pixels = list(image.get_flattened_data())
    pixels.sort(key=relative_luminance)
    return pixels[min(len(pixels) - 1, round((len(pixels) - 1) * percentile))]


def map_check(panel, rail):
    panel_preview = panel.crop((0, 182, 1024, 842)).resize((870, 560), Image.Resampling.LANCZOS)
    rail_preview = rail.resize((218, 560), Image.Resampling.LANCZOS)
    generated = Image.new("RGB", (1088, 560), MAP_BASE)
    generated.paste(rail_preview, (0, 0))
    generated.paste(panel_preview, (218, 0))

    draw = ImageDraw.Draw(generated)
    font_path = ROOT / "Media" / "Fonts" / "RobotoCondensed-Bold.ttf"
    title_font = ImageFont.truetype(str(font_path), 38)
    body_font = ImageFont.truetype(str(font_path), 21)
    draw.text((258, 60), "Pick a look", font=title_font, fill=BODY_TEXT, stroke_width=1, stroke_fill=(10, 15, 19))
    draw.text(
        (258, 112),
        "This sets the art, frames, action bars and minimap together.",
        font=body_font,
        fill=SECONDARY_TEXT,
        stroke_width=1,
        stroke_fill=(10, 15, 19),
    )

    reference = Image.open(MAP_REFERENCE).convert("RGB").crop((278, 50, 1535, 922))
    reference = reference.resize((round(reference.width * 560 / reference.height), 560), Image.Resampling.LANCZOS)
    comparison = Image.new("RGB", (generated.width + 24 + reference.width, 560), (12, 17, 22))
    comparison.paste(generated, (0, 0))
    comparison.paste(reference, (generated.width + 24, 0))
    save(comparison, MAP_CHECK)


def map_panel(folder):
    panel_source = Image.open(MAP_PANEL_SOURCE).convert("RGB")
    panel_band = panel_source.resize((1024, round(1024 * panel_source.height / panel_source.width)), Image.Resampling.LANCZOS)
    top = (1024 - panel_band.height) // 2
    quiet = panel_band.crop((360, 160, 664, 523)).resize((1024, 1024), Image.Resampling.LANCZOS)
    panel = quiet.filter(ImageFilter.GaussianBlur(12))
    mask = Image.new("L", panel_band.size, 255)
    mask_draw = ImageDraw.Draw(mask)
    for offset in range(12):
        alpha = round(255 * offset / 11)
        mask_draw.line((0, offset, panel_band.width, offset), fill=alpha)
        mask_draw.line((0, panel_band.height - 1 - offset, panel_band.width, panel_band.height - 1 - offset), fill=alpha)
    panel.paste(panel_band, (0, top), mask)
    panel = map_value(panel)

    rail_source = Image.open(MAP_RAIL_SOURCE).convert("RGB")
    rail = ImageOps.fit(rail_source, (256, 1024), Image.Resampling.LANCZOS, centering=(0.12, 0.5))
    rail = map_value(rail)

    save(panel, folder / "map-panel.png")
    save(rail, folder / "map-rail.png")
    map_check(panel, rail)

    for name, image in (("map-panel.png", panel), ("map-rail.png", rail)):
        pixel = luminance_percentile_pixel(image, 0.99)
        print(
            f"{name}: base={MAP_BASE}, max={tuple(max(channel.getextrema()) for channel in image.split())}, "
            f"p99={pixel}, secondary-contrast={contrast_ratio(SECONDARY_TEXT, pixel):.3f}:1, "
            f"body-contrast={contrast_ratio(BODY_TEXT, pixel):.3f}:1"
        )


def backdrop(source, target, brightness, blur, color=0.95):
    image = Image.open(source).convert("RGB")
    image = image.resize((1024, 512), Image.Resampling.LANCZOS)
    image = image.filter(ImageFilter.GaussianBlur(blur))
    image = ImageEnhance.Brightness(image).enhance(brightness)
    image = ImageEnhance.Color(image).enhance(color)
    save(image, target)


def mirrored_tile(source, target, size):
    half = (size[0] // 2, size[1] // 2)
    source_image = Image.open(source).convert("RGB").resize(half, Image.Resampling.LANCZOS)
    image = Image.new("RGB", size)
    image.paste(source_image, (0, 0))
    image.paste(ImageOps.mirror(source_image), (half[0], 0))
    image.paste(ImageOps.flip(source_image), (0, half[1]))
    image.paste(ImageOps.mirror(ImageOps.flip(source_image)), half)
    save(image, target)


def clean_alpha(image, cutoff=6):
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 0 if value <= cutoff else value)
    cleaned = image.copy()
    cleaned.putalpha(alpha)
    empty = alpha.point(lambda value: 255 if value == 0 else 0)
    cleaned.paste((0, 0, 0, 0), (0, 0, image.width, image.height), empty)
    return cleaned


def pad_to(image, size):
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas


def seamless_horizontal(source, size):
    half_width = size[0] // 2
    half = ImageOps.fit(source, (half_width, size[1]), Image.Resampling.LANCZOS)
    strip = Image.new("RGBA", size)
    strip.paste(half, (0, 0))
    strip.paste(ImageOps.mirror(half), (half_width, 0))
    return strip


def opaque_over(image, color):
    background = Image.new("RGBA", image.size, color)
    background.alpha_composite(image.convert("RGBA"))
    background.putalpha(255)
    return background


def brass_texture(frame, size):
    source = frame.crop((38, 38, 154, 154)).convert("L")
    source = ImageOps.autocontrast(ImageOps.fit(source, size, Image.Resampling.LANCZOS), cutoff=1)
    return ImageOps.colorize(source, BRASS_DARK[:3], BRASS_LIGHT[:3]).convert("RGBA")


def corner_bracket(frame):
    scale = 4
    size = 64
    bracket_extent = 48
    mask = Image.new("L", (size * scale, size * scale), 0)
    draw = ImageDraw.Draw(mask)
    points = [
        (0, 0),
        (bracket_extent * scale, 0),
        (bracket_extent * scale, 9 * scale),
        (35 * scale, 11 * scale),
        (33 * scale, 18 * scale),
        (18 * scale, 33 * scale),
        (11 * scale, 35 * scale),
        (9 * scale, bracket_extent * scale),
        (0, bracket_extent * scale),
    ]
    draw.polygon(points, fill=255)
    draw.line(points + [points[0]], fill=225, width=2 * scale, joint="curve")

    texture = brass_texture(frame, mask.size)
    plate = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    plate.paste(texture, mask=mask)
    plate_draw = ImageDraw.Draw(plate)
    plate_draw.line(
        [(2 * scale, 2 * scale), (43 * scale, 2 * scale), (32 * scale, 12 * scale), (18 * scale, 34 * scale), (2 * scale, 43 * scale)],
        fill=BRASS_LIGHT,
        width=scale,
        joint="curve",
    )
    plate_draw.line(
        [(47 * scale, 7 * scale), (34 * scale, 10 * scale), (31 * scale, 18 * scale), (18 * scale, 31 * scale), (10 * scale, 34 * scale), (7 * scale, 47 * scale)],
        fill=BRASS_DARK,
        width=2 * scale,
        joint="curve",
    )

    center = (12 * scale, 12 * scale)
    for radius, color in ((7, BRASS_DARK), (6, BRASS_MID), (4, BRASS_LIGHT), (2, (248, 222, 151, 255))):
        plate_draw.ellipse(
            ((center[0] - radius * scale, center[1] - radius * scale), (center[0] + radius * scale, center[1] + radius * scale)),
            fill=color,
        )
    plate_draw.ellipse(
        ((8 * scale, 8 * scale), (10 * scale, 10 * scale)),
        fill=(255, 242, 194, 230),
    )
    return clean_alpha(plate.resize((size, size), Image.Resampling.LANCZOS))


def frame_assets(source, folder):
    frame = Image.open(source).convert("RGBA")
    beam_source = frame.crop((220, 42, 1034, 160))
    top = seamless_horizontal(beam_source, (256, FRAME_BEAM))
    top = opaque_over(top, (46, 28, 17, 255))
    bottom = ImageOps.flip(top)
    left = top.transpose(Image.Transpose.ROTATE_90)
    right = top.transpose(Image.Transpose.ROTATE_270)

    top_left = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    top_left.alpha_composite(top.crop((192, 0, 256, FRAME_BEAM)), (0, 0))
    top_left.alpha_composite(left.crop((0, 192, FRAME_BEAM, 256)), (0, 0))
    top_left.alpha_composite(corner_bracket(frame))
    top_left = clean_alpha(top_left)

    pieces = {
        "frame-top-left.png": top_left,
        "frame-top-right.png": ImageOps.mirror(top_left),
        "frame-bottom-left.png": ImageOps.flip(top_left),
        "frame-bottom-right.png": ImageOps.flip(ImageOps.mirror(top_left)),
        "frame-top.png": top,
        "frame-bottom.png": bottom,
        "frame-left.png": left,
        "frame-right.png": right,
    }
    padded = {
        "frame-top.png": (256, 32),
        "frame-bottom.png": (256, 32),
        "frame-left.png": (32, 256),
        "frame-right.png": (32, 256),
    }
    for name, image in pieces.items():
        image = clean_alpha(image)
        if name in padded:
            image = pad_to(image, padded[name])
        save(image, folder / name)
    frame_check(pieces)


def paste_tiled(canvas, tile, box):
    left, top, right, bottom = box
    for y in range(top, bottom, tile.height):
        for x in range(left, right, tile.width):
            width = min(tile.width, right - x)
            height = min(tile.height, bottom - y)
            canvas.alpha_composite(tile.crop((0, 0, width, height)), (x, y))


def frame_check(pieces):
    width, height = 1024, 650
    corner_size = 32
    beam_size = 12
    preview = Image.new("RGBA", (width, height), (21, 29, 34, 255))
    top = pieces["frame-top.png"].resize((128, beam_size), Image.Resampling.LANCZOS)
    bottom = pieces["frame-bottom.png"].resize((128, beam_size), Image.Resampling.LANCZOS)
    left = pieces["frame-left.png"].resize((beam_size, 128), Image.Resampling.LANCZOS)
    right = pieces["frame-right.png"].resize((beam_size, 128), Image.Resampling.LANCZOS)
    paste_tiled(preview, top, (corner_size, 0, width - corner_size, beam_size))
    paste_tiled(preview, bottom, (corner_size, height - beam_size, width - corner_size, height))
    paste_tiled(preview, left, (0, corner_size, beam_size, height - corner_size))
    paste_tiled(preview, right, (width - beam_size, corner_size, width, height - corner_size))
    positions = {
        "frame-top-left.png": (0, 0),
        "frame-top-right.png": (width - corner_size, 0),
        "frame-bottom-left.png": (0, height - corner_size),
        "frame-bottom-right.png": (width - corner_size, height - corner_size),
    }
    for name, position in positions.items():
        corner = pieces[name].resize((corner_size, corner_size), Image.Resampling.LANCZOS)
        preview.alpha_composite(corner, position)
    save(preview, FRAME_CHECK)


def tint_vertex(image, color):
    tint = Image.new("RGBA", image.size, (*color, 255))
    colored = Image.new("RGBA", image.size, (0, 0, 0, 0))
    colored_rgb = ImageChops.multiply(image.convert("RGB"), tint.convert("RGB"))
    colored.paste(colored_rgb, mask=image.getchannel("A"))
    colored.putalpha(image.getchannel("A"))
    return colored


def antialiased_polygon(size, points):
    scale = 4
    mask = Image.new("L", (size[0] * scale, size[1] * scale), 0)
    ImageDraw.Draw(mask).polygon([(x * scale, y * scale) for x, y in points], fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)


def neutral_cloth(source, source_box, size, mask, top=12, bottom=116):
    crop = source.crop(source_box).convert("L")
    crop = ImageOps.autocontrast(crop, cutoff=1)
    texture = ImageOps.fit(crop, size, Image.Resampling.LANCZOS)
    texture = ImageEnhance.Contrast(texture).enhance(1.12)
    pixels = texture.load()
    span = max(1, bottom - top)
    for y in range(size[1]):
        position = max(0.0, min(1.0, (y - top) / span))
        top_light = 24 * __import__("math").exp(-((position - 0.08) / 0.10) ** 2)
        underside = 28 * max(0.0, (position - 0.68) / 0.32)
        for x in range(size[0]):
            value = pixels[x, y]
            pixels[x, y] = max(78, min(244, round(88 + value * 0.60 + top_light - underside)))
    return clean_alpha(Image.merge("RGBA", (texture, texture, texture, mask)))


def seamless_flag_texture(source):
    crop = source.crop((610, 250, 930, 495)).convert("L")
    crop = ImageOps.autocontrast(crop, cutoff=1)
    half = ImageOps.fit(crop, (32, 105), Image.Resampling.LANCZOS)
    texture = Image.new("L", (64, 105))
    texture.paste(half, (0, 0))
    texture.paste(ImageOps.mirror(half), (32, 0))
    texture.putpixel((63, 0), texture.getpixel((0, 0)))
    return texture


def painted_trim(size, lines=(), circles=()):
    scale = 4
    canvas = Image.new("RGBA", (size[0] * scale, size[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    for points, widths in lines:
        scaled = [(round(x * scale), round(y * scale)) for x, y in points]
        dark_width, mid_width, light_width = (round(width * scale) for width in widths)
        draw.line(scaled, fill=(69, 39, 14, 255), width=dark_width, joint="curve")
        draw.line(scaled, fill=(154, 91, 30, 255), width=mid_width, joint="curve")
        draw.line(scaled, fill=(224, 166, 69, 255), width=light_width, joint="curve")
    for center, radius in circles:
        cx, cy = (round(value * scale) for value in center)
        for inset, color in (
            (0, (65, 38, 14, 255)),
            (2, (164, 101, 34, 255)),
            (4, (229, 174, 72, 255)),
        ):
            r = max(1, round((radius - inset) * scale))
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
        r = max(1, round(radius * 0.26 * scale))
        draw.ellipse((cx - radius * scale * 0.42, cy - radius * scale * 0.48, cx - radius * scale * 0.42 + 2 * r, cy - radius * scale * 0.48 + 2 * r), fill=(255, 232, 151, 210))
    return clean_alpha(canvas.resize(size, Image.Resampling.LANCZOS))


def fit_source_part(source, box, canvas_size, visible_size):
    part = clean_alpha(source.crop(box))
    alpha_box = part.getchannel("A").getbbox()
    if not alpha_box:
        raise ValueError(f"Flag source crop has no visible pixels: {box}")
    part = part.crop(alpha_box)
    part.thumbnail(visible_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(part, ((canvas.width - part.width) // 2, (canvas.height - part.height) // 2))
    return clean_alpha(canvas)


def rod_from_source(source, box, canvas_size, rod_width):
    section = source.crop(box).convert("RGBA")
    section = section.resize((1, section.height), Image.Resampling.LANCZOS).transpose(Image.Transpose.ROTATE_90)
    section = section.resize((rod_width, 1), Image.Resampling.LANCZOS)
    rod = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    strip = section.resize((rod_width, canvas_size[1]), Image.Resampling.NEAREST)
    rod.alpha_composite(strip, ((canvas_size[0] - rod_width) // 2, 0))
    return clean_alpha(rod)


def flag_rail_assets(folder):
    source = Image.open(FLAG_SOURCE).convert("RGBA")

    hang_mask = antialiased_polygon((128, 256), [(16, 64), (112, 64), (109, 200), (64, 170), (19, 200)])
    hang_cloth = neutral_cloth(source, (95, 165, 414, 608), (128, 256), hang_mask, 64, 198)
    hang_border = [(16, 64), (112, 64), (109, 200), (64, 170), (19, 200), (16, 64)]
    hang_trim = painted_trim(
        (128, 256),
        lines=[
            ([(15, 48), (113, 48)], (10, 7, 2)),
            (hang_border, (7, 4, 1)),
        ],
        circles=[((14, 48), 10), ((114, 48), 10)],
    )

    texture = seamless_flag_texture(source)
    mid_mask = Image.new("L", (64, 128), 0)
    ImageDraw.Draw(mid_mask).rectangle((0, 12, 63, 116), fill=255)
    mid_luma = Image.new("L", (64, 128), 0)
    mid_luma.paste(texture, (0, 12))
    pennant_mid_cloth = neutral_cloth(mid_luma.convert("RGBA"), (0, 0, 64, 128), (64, 128), mid_mask, 12, 116)
    pennant_mid_cloth.paste(pennant_mid_cloth.crop((0, 0, 1, 128)), (63, 0))
    pennant_mid_trim = painted_trim(
        (64, 128),
        lines=[
            ([(0, 12), (63, 12)], (7, 4, 1)),
            ([(0, 116), (63, 116)], (7, 4, 1)),
        ],
    )
    pennant_mid_trim.paste(pennant_mid_trim.crop((0, 0, 1, 128)), (63, 0))

    right_mask = antialiased_polygon((64, 128), [(0, 12), (58, 12), (43, 64), (58, 116), (0, 116)])
    right_luma = Image.new("L", (64, 128), 0)
    right_luma.paste(texture, (0, 12))
    pennant_right_cloth = neutral_cloth(right_luma.convert("RGBA"), (0, 0, 64, 128), (64, 128), right_mask, 12, 116)
    pennant_right_cloth.paste(pennant_mid_cloth.crop((63, 0, 64, 128)), (0, 0))
    pennant_right_trim = painted_trim(
        (64, 128),
        lines=[
            ([(0, 12), (58, 12), (43, 64), (58, 116), (0, 116)], (7, 4, 1)),
        ],
    )
    pennant_right_trim.paste(pennant_mid_trim.crop((63, 0, 64, 128)), (0, 0))

    assets = {
        "flag-hang-cloth.png": hang_cloth,
        "flag-hang-trim.png": hang_trim,
        "pennant-mid-cloth.png": pennant_mid_cloth,
        "pennant-mid-trim.png": pennant_mid_trim,
        "pennant-right-cloth.png": pennant_right_cloth,
        "pennant-right-trim.png": pennant_right_trim,
        "node-flag.png": fit_source_part(source, (135, 650, 438, 990), (64, 64), (60, 60)),
        "node-done.png": fit_source_part(source, (545, 716, 724, 902), (64, 64), (56, 56)),
        "node-upcoming.png": fit_source_part(source, (835, 648, 1155, 992), (64, 64), (56, 56)),
        "pole-gold.png": rod_from_source(source, (180, 1005, 910, 1082), (32, 128), 16),
        "pole-silver.png": rod_from_source(source, (180, 1115, 900, 1192), (32, 128), 10),
        "dot-silver.png": fit_source_part(source, (1060, 1046, 1180, 1165), (16, 16), (10, 10)),
    }
    for name, image in assets.items():
        save(image, folder / name)
    validate_flag_rail(folder)
    rail_compare(folder)


def validate_flag_rail(folder):
    expected = {
        "flag-hang-cloth.png": (128, 256),
        "flag-hang-trim.png": (128, 256),
        "pennant-mid-cloth.png": (64, 128),
        "pennant-mid-trim.png": (64, 128),
        "pennant-right-cloth.png": (64, 128),
        "pennant-right-trim.png": (64, 128),
        "node-flag.png": (64, 64),
        "node-done.png": (64, 64),
        "node-upcoming.png": (64, 64),
        "pole-gold.png": (32, 128),
        "pole-silver.png": (32, 128),
        "dot-silver.png": (16, 16),
    }
    images = {name: Image.open(folder / name).convert("RGBA") for name in expected}
    for name, size in expected.items():
        if images[name].size != size:
            raise AssertionError(f"{name}: expected {size}, got {images[name].size}")
        if any(value & (value - 1) for value in size):
            raise AssertionError(f"{name}: canvas dimensions must be powers of two")
        if not images[name].getchannel("A").getbbox():
            raise AssertionError(f"{name}: image is empty")
    for name in ("flag-hang-cloth.png", "pennant-mid-cloth.png", "pennant-right-cloth.png"):
        red, green, blue, _ = images[name].split()
        if ImageChops.difference(red, green).getbbox() or ImageChops.difference(red, blue).getbbox():
            raise AssertionError(f"{name}: tintable cloth must remain neutral grayscale")
    for name in ("pennant-mid-cloth.png", "pennant-mid-trim.png"):
        assert_same(images[name].crop((0, 0, 1, 128)), images[name].crop((63, 0, 64, 128)), f"{name} horizontal tile")
    assert_same(images["pennant-mid-cloth.png"].crop((63, 0, 64, 128)), images["pennant-right-cloth.png"].crop((0, 0, 1, 128)), "pennant cloth join")
    assert_same(images["pennant-mid-trim.png"].crop((63, 0, 64, 128)), images["pennant-right-trim.png"].crop((0, 0, 1, 128)), "pennant trim join")
    for name in ("pole-gold.png", "pole-silver.png"):
        assert_same(images[name].crop((0, 0, 32, 1)), images[name].crop((0, 127, 32, 128)), f"{name} vertical tile")
    if images["node-upcoming.png"].crop((25, 25, 39, 39)).getchannel("A").getbbox():
        raise AssertionError("node-upcoming.png: center must be transparent")
    if images["flag-hang-trim.png"].crop((40, 104, 88, 152)).getchannel("A").getbbox():
        raise AssertionError("flag-hang-trim.png: node boss must not be baked into the trim")
    print("Validated 12 flag-rail PNGs: power-of-two dimensions, alpha, neutral cloth, transparent ring, absent baked boss, and tile seams.")


def paste_vertical_rod(canvas, rod, x, top, bottom):
    width = rod.width
    for y in range(top, bottom, rod.height):
        height = min(rod.height, bottom - y)
        canvas.alpha_composite(rod.crop((0, 0, width, height)), (x - width // 2, y))


def rail_compare(folder):
    panel_size = (round(280 * 2 / 3), round(410 * 2 / 3))
    reference = Image.open(RAIL_REFERENCE).convert("RGBA").resize(panel_size, Image.Resampling.LANCZOS)
    background = ImageOps.fit(Image.open(folder / "map-rail.png").convert("RGBA"), panel_size, Image.Resampling.LANCZOS)
    composed = ImageEnhance.Brightness(background).enhance(0.70)

    def game_asset(name, size):
        return Image.open(folder / name).convert("RGBA").resize(size, Image.Resampling.LANCZOS)

    center_x = 38
    rows = (57, 102, 148, 194)
    gold_rod = game_asset("pole-gold.png", (8, 32))
    silver_rod = game_asset("pole-silver.png", (8, 32))
    paste_vertical_rod(composed, gold_rod, center_x, rows[0], 91)
    paste_vertical_rod(composed, silver_rod, center_x, 116, rows[2])
    dot = game_asset("dot-silver.png", (4, 4))
    for y in (164, 172, 180):
        composed.alpha_composite(dot, (center_x - 2, y - 2))

    mid_cloth = tint_vertex(game_asset("pennant-mid-cloth.png", (16, 32)), (158, 26, 20))
    mid_trim = game_asset("pennant-mid-trim.png", (16, 32))
    right_cloth = tint_vertex(game_asset("pennant-right-cloth.png", (16, 32)), (158, 26, 20))
    right_trim = game_asset("pennant-right-trim.png", (16, 32))
    pennant_x = center_x
    pennant_y = rows[1] - 16
    for offset in (0, 16, 32):
        composed.alpha_composite(mid_cloth, (pennant_x + offset, pennant_y))
        composed.alpha_composite(mid_trim, (pennant_x + offset, pennant_y))
    half_cloth = mid_cloth.crop((0, 0, 8, 32))
    half_trim = mid_trim.crop((0, 0, 8, 32))
    composed.alpha_composite(half_cloth, (pennant_x + 48, pennant_y))
    composed.alpha_composite(half_trim, (pennant_x + 48, pennant_y))
    composed.alpha_composite(right_cloth, (pennant_x + 56, pennant_y))
    composed.alpha_composite(right_trim, (pennant_x + 56, pennant_y))

    hang_cloth = tint_vertex(game_asset("flag-hang-cloth.png", (32, 64)), (158, 26, 20))
    hang_trim = game_asset("flag-hang-trim.png", (32, 64))
    hang_pos = (center_x - 16, rows[1] - 32)
    composed.alpha_composite(hang_cloth, hang_pos)
    composed.alpha_composite(hang_trim, hang_pos)
    composed.alpha_composite(game_asset("node-flag.png", (16, 16)), (center_x - 8, rows[1] - 8))
    composed.alpha_composite(game_asset("node-done.png", (14, 14)), (center_x - 7, rows[0] - 7))
    for row in rows[2:]:
        composed.alpha_composite(game_asset("node-upcoming.png", (14, 14)), (center_x - 7, row - 7))

    draw = ImageDraw.Draw(composed)
    font = ImageFont.truetype(str(ROOT / "Media" / "Fonts" / "RobotoCondensed-Bold.ttf"), 16)
    text_fill = (222, 223, 220, 255)
    shadow = (15, 18, 19, 255)
    draw.text((23, 14), "SpartanUI", font=font, fill=(239, 235, 225, 255), stroke_width=1, stroke_fill=shadow, anchor="la")
    draw.text((62, rows[0]), "Welcome", font=font, fill=text_fill, stroke_width=1, stroke_fill=shadow, anchor="lm")
    draw.text((62, rows[1]), "Look", font=font, fill=(255, 255, 255, 255), stroke_width=1, stroke_fill=shadow, anchor="lm")
    draw.text((62, rows[2]), "Frames", font=font, fill=text_fill, stroke_width=1, stroke_fill=shadow, anchor="lm")
    draw.text((62, rows[3]), "Extras", font=font, fill=text_fill, stroke_width=1, stroke_fill=shadow, anchor="lm")
    check = game_asset("check-brass.png", (11, 11))
    composed.alpha_composite(check, (121, rows[0] - 6))

    top_gap = 16
    flag_crop = (20, 76, 122, 128)
    ref_zoom = reference.crop(flag_crop).resize((306, 156), Image.Resampling.NEAREST)
    made_zoom = composed.crop(flag_crop).resize((306, 156), Image.Resampling.NEAREST)
    comparison = Image.new("RGBA", (620, panel_size[1] + top_gap + 156), (12, 17, 22, 255))
    top_left = (620 - (panel_size[0] * 2 + top_gap)) // 2
    comparison.alpha_composite(reference, (top_left, 0))
    comparison.alpha_composite(composed, (top_left + panel_size[0] + top_gap, 0))
    comparison.alpha_composite(ref_zoom, (0, panel_size[1] + top_gap))
    comparison.alpha_composite(made_zoom, (314, panel_size[1] + top_gap))
    save(comparison, RAIL_COMPARE)


def assert_same(first, second, label):
    if first.size != second.size or ImageChops.difference(first.convert("RGBA"), second.convert("RGBA")).getbbox():
        raise AssertionError(f"Seam mismatch: {label}")


def rounded_asset(path, fill, outline, size=(256, 80), radius=24):
    scale = 4
    image = Image.new("RGBA", (size[0] * scale, size[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (4 * scale, 4 * scale, (size[0] - 4) * scale, (size[1] - 4) * scale),
        radius=radius * scale,
        fill=fill,
        outline=outline,
        width=2 * scale,
    )
    save(downsample(image, size), path)


def switch_assets(folder, warm=False):
    track_color = (73, 67, 58, 255) if warm else (72, 75, 82, 255)
    outline = (155, 132, 91, 220) if warm else (157, 162, 171, 220)
    rounded_asset(folder / "switch-track.png", track_color, outline, (128, 64), 30)

    scale = 4
    knob = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(knob)
    draw.ellipse((7 * scale, 7 * scale, 57 * scale, 57 * scale), fill=(235, 236, 239, 255), outline=(255, 255, 255, 220), width=2 * scale)
    save(downsample(knob, (64, 64)), folder / "switch-knob.png")

    ring = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((3 * scale, 3 * scale, 61 * scale, 61 * scale), outline=(255, 255, 255, 255), width=7 * scale)
    save(downsample(ring, (64, 64)), folder / "radio-ring.png")


def marker_assets(folder, warm=False):
    scale = 4
    metal = (174, 143, 85, 255) if warm else (164, 169, 178, 255)
    marker = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(marker)
    draw.ellipse((7 * scale, 7 * scale, 57 * scale, 57 * scale), fill=(36, 38, 43, 255), outline=metal, width=4 * scale)
    draw.ellipse((25 * scale, 25 * scale, 39 * scale, 39 * scale), fill=(220, 223, 228, 255))
    save(downsample(marker, (64, 64)), folder / "chapter-marker.png")

    check = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(check)
    draw.ellipse((7 * scale, 7 * scale, 57 * scale, 57 * scale), fill=(44, 114, 71, 255), outline=(91, 174, 112, 255), width=3 * scale)
    draw.line((19 * scale, 33 * scale, 29 * scale, 43 * scale, 47 * scale, 21 * scale), fill=(239, 244, 240, 255), width=5 * scale, joint="curve")
    save(downsample(check, (64, 64)), folder / "chapter-check.png")

    chevron = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(chevron)
    draw.line((23 * scale, 16 * scale, 43 * scale, 32 * scale, 23 * scale, 48 * scale), fill=(224, 226, 230, 255), width=5 * scale, joint="curve")
    save(downsample(chevron, (64, 64)), folder / "chevron.png")


def split_button(folder, name, fill, outline):
    full = folder / f"{name}-full.png"
    rounded_asset(full, fill, outline, (256, 64), 16)
    image = Image.open(full).convert("RGBA")
    save(image.crop((0, 0, 32, 64)), folder / f"{name}-left.png")
    center = image.crop((32, 0, 224, 64)).resize((64, 64), Image.Resampling.LANCZOS)
    center.paste(center.crop((0, 0, 1, 64)), (63, 0))
    save(center, folder / f"{name}-center.png")
    save(image.crop((224, 0, 256, 64)), folder / f"{name}-right.png")
    full.unlink()


def simple_shadow(folder):
    scale = 4
    image = Image.new("RGBA", (128 * scale, 128 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((18 * scale, 18 * scale, 110 * scale, 110 * scale), fill=(0, 0, 0, 190))
    image = image.filter(ImageFilter.GaussianBlur(10 * scale))
    save(downsample(image, (128, 128)), folder / "shadow.png")


def check_brass_asset(folder):
    scale = 4
    image = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    points = [(14 * scale, 32 * scale), (21 * scale, 37 * scale), (27 * scale, 46 * scale), (36 * scale, 34 * scale), (51 * scale, 17 * scale)]
    draw.line(points, fill=BRASS_DARK, width=9 * scale, joint="curve")
    draw.line(points, fill=BRASS_MID, width=6 * scale, joint="curve")
    draw.line([(15 * scale, 29 * scale), (23 * scale, 35 * scale), (28 * scale, 41 * scale), (48 * scale, 17 * scale)], fill=BRASS_LIGHT, width=2 * scale, joint="curve")
    save(clean_alpha(image.resize((64, 64), Image.Resampling.LANCZOS)), folder / "check-brass.png")


def triangle_asset(folder):
    scale = 4
    image = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon(((20 * scale, 14 * scale), (48 * scale, 32 * scale), (20 * scale, 50 * scale)), fill=(222, 215, 195, 255))
    save(image.resize((64, 64), Image.Resampling.LANCZOS), folder / "triangle.png")


def minimal_kit_assets(folder):
    folder.mkdir(parents=True, exist_ok=True)
    line = (137, 151, 164, 230)
    faint = (54, 66, 78, 160)
    for name, point in (("top-left", "tl"), ("top-right", "tr"), ("bottom-left", "bl"), ("bottom-right", "br")):
        image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        x = 0 if point.endswith("l") else 15
        y = 0 if point.startswith("t") else 15
        draw.line((x, 0, x, 15), fill=line, width=1)
        draw.line((0, y, 15, y), fill=line, width=1)
        save(image, folder / f"frame-{name}.png")
    for name in ("top", "bottom"):
        image = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
        ImageDraw.Draw(image).line((0, 0 if name == "top" else 15, 31, 0 if name == "top" else 15), fill=line, width=1)
        save(image, folder / f"frame-{name}.png")
    for name in ("left", "right"):
        image = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
        ImageDraw.Draw(image).line((0 if name == "left" else 15, 0, 0 if name == "left" else 15, 31), fill=line, width=1)
        save(image, folder / f"frame-{name}.png")

    header = Image.new("RGBA", (256, 32), (21, 27, 34, 248))
    draw = ImageDraw.Draw(header)
    draw.line((0, 31, 255, 31), fill=line, width=1)
    draw.line((0, 0, 255, 0), fill=(194, 204, 214, 45), width=1)
    save(header, folder / "header-plate.png")
    divider = Image.new("RGBA", (256, 16), (0, 0, 0, 0))
    ImageDraw.Draw(divider).line((0, 8, 255, 8), fill=line, width=1)
    save(divider, folder / "divider.png")

    split_button(folder, "button-primary", (255, 255, 255, 255), (255, 255, 255, 210))
    split_button(folder, "button-secondary", (48, 58, 69, 255), line)
    marker_assets(folder, False)
    (folder / "chapter-marker.png").replace(folder / "active-marker.png")
    (folder / "chapter-check.png").replace(folder / "check.png")
    (folder / "chevron.png").replace(folder / "triangle.png")
    switch_assets(folder, False)

    well = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(well)
    draw.rectangle((1, 1, 62, 62), fill=(9, 13, 17, 220), outline=faint, width=2)
    draw.rectangle((5, 5, 58, 58), outline=(0, 0, 0, 180), width=2)
    save(well, folder / "inset-well.png")
    tile = Image.new("RGBA", (64, 64), (31, 40, 48, 255))
    tile_draw = ImageDraw.Draw(tile)
    for y in range(0, 64, 8):
        tile_draw.line((0, y, 63, y), fill=(255, 255, 255, 5), width=1)
    save(tile, folder / "material-tile.png")
    save(Image.new("RGBA", (32, 32), (0, 0, 0, 0)), folder / "corner-ornament.png")
    simple_shadow(folder)


def crop_fit(source, box, size):
    image = clean_alpha(source.crop(box))
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas


def war_trim_assets(folder):
    source = Image.open(WAR_TRIM_SOURCE).convert("RGBA")
    save(crop_fit(source, (35, 35, 1215, 220), (512, 64)), folder / "header-plate.png")
    divider = crop_fit(source, (35, 255, 1215, 365), (512, 32))
    save(divider, folder / "divider.png")
    save(crop_fit(source, (560, 255, 700, 365), (64, 64)), folder / "divider-ornament.png")
    inset = crop_fit(source, (215, 390, 1040, 1254), (256, 256))
    save(inset, folder / "inset-well.png")
    save(crop_fit(source, (215, 390, 400, 580), (64, 64)), folder / "corner-ornament.png")
    split_button(folder, "button-primary", (130, 24, 20, 255), (225, 176, 76, 255))
    split_button(folder, "button-secondary", (33, 38, 40, 255), (173, 135, 79, 255))
    simple_shadow(folder)


def war_kit_assets(folder):
    folder.mkdir(parents=True, exist_ok=True)
    frame_assets(WAR_PAINTED / "frame-original.png", folder)
    mirrored_tile(WAR_PAINTED / "map-slate-original.png", folder / "map-slate-tile.png", (512, 512))
    mirrored_tile(WAR_PAINTED / "oak-original.png", folder / "oak-tile.png", (512, 256))
    map_panel(folder)
    check_brass_asset(folder)
    triangle_asset(folder)
    flag_rail_assets(folder)
    switch_assets(folder, True)
    war_trim_assets(folder)


def validate_kit(folder):
    for path in folder.glob("*.png"):
        image = Image.open(path)
        if any(value & (value - 1) for value in image.size):
            raise AssertionError(f"{path.name}: canvas dimensions must be powers of two")


def main():
    parser = argparse.ArgumentParser(description="Build LibsAddonTools setup raster assets.")
    parser.add_argument(
        "--only",
        choices=("all", "minimal", "war", "frame-rail", "flag-rail"),
        default="all",
        help="Limit generation to one shared trim kit or one War kit asset family.",
    )
    args = parser.parse_args()
    if args.only == "frame-rail":
        frame_assets(WAR_PAINTED / "frame-original.png", SPARTAN_WAR_KIT)
        return
    if args.only == "flag-rail":
        flag_rail_assets(SPARTAN_WAR_KIT)
        return
    if args.only in ("all", "minimal"):
        minimal_kit_assets(MINIMAL_KIT)
        validate_kit(MINIMAL_KIT)
    if args.only in ("all", "war"):
        war_kit_assets(SPARTAN_WAR_KIT)
        validate_kit(SPARTAN_WAR_KIT)
    if args.only == "all":
        for theme in THEME_BACKDROPS:
            backdrop(STAGE_BACKDROPS / f"{theme}-original.png", SPARTAN_BACKDROPS / f"{theme}.png", 0.92, 2.2)


if __name__ == "__main__":
    main()
