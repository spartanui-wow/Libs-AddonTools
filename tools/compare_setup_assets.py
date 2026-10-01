from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parents[1]
SPARTAN = ROOT.parent / "SpartanUI"
OUTPUT = Path(__file__).parent / "output"
MINIMAL = ROOT / "Media" / "UI" / "Kits" / "minimal"
WAR = SPARTAN / "images" / "kits" / "war"
REFERENCE = ROOT / ".impeccable" / "mocks" / "decision" / "assigned.png"
FONT = ROOT / "Media" / "Fonts" / "RobotoCondensed-Bold.ttf"
SIZE = (1024, 650)
TITLE_HEIGHT = 36
FOOTER_HEIGHT = 52
CONTENT_INSET = 18
RAIL_WIDTH = 218
CONTENT_GAP = 12


def font(size):
    return ImageFont.truetype(FONT, size)


def cover(path, size):
    image = Image.open(path).convert("RGBA")
    scale = max(size[0] / image.width, size[1] / image.height)
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (image.width - size[0]) // 2
    top = (image.height - size[1]) // 2
    return image.crop((left, top, left + size[0], top + size[1]))


def tile(path, size):
    source = Image.open(path).convert("RGBA")
    output = Image.new("RGBA", size)
    for y in range(0, size[1], source.height):
        for x in range(0, size[0], source.width):
            output.alpha_composite(source, (x, y))
    return output


def tint(image, color, alpha=255):
    mask = image.getchannel("A")
    output = Image.new("RGBA", image.size, (*color, alpha))
    output.putalpha(ImageEnhance.Brightness(mask).enhance(alpha / 255))
    return output


def frame_9slice(canvas, folder, corner, edge):
    width, height = canvas.size
    corners = {
        "top-left": (0, 0),
        "top-right": (width - corner, 0),
        "bottom-left": (0, height - corner),
        "bottom-right": (width - corner, height - corner),
    }
    for name, point in corners.items():
        piece = Image.open(folder / f"frame-{name}.png").convert("RGBA").resize((corner, corner), Image.Resampling.LANCZOS)
        canvas.alpha_composite(piece, point)
    horizontal = width - corner * 2
    vertical = height - corner * 2
    for name, point in (("top", (corner, 0)), ("bottom", (corner, height - edge))):
        canvas.alpha_composite(tile(folder / f"frame-{name}.png", (horizontal, edge)), point)
    for name, point in (("left", (0, corner)), ("right", (width - edge, corner))):
        canvas.alpha_composite(tile(folder / f"frame-{name}.png", (edge, vertical)), point)


def three_slice(canvas, folder, name, box):
    x, y, width, height = box
    cap = min(16, width // 3)
    left = Image.open(folder / f"{name}-left.png").convert("RGBA").resize((cap, height), Image.Resampling.LANCZOS)
    center = Image.open(folder / f"{name}-center.png").convert("RGBA").resize((width - cap * 2, height), Image.Resampling.LANCZOS)
    right = Image.open(folder / f"{name}-right.png").convert("RGBA").resize((cap, height), Image.Resampling.LANCZOS)
    canvas.alpha_composite(left, (x, y))
    canvas.alpha_composite(center, (x + cap, y))
    canvas.alpha_composite(right, (x + width - cap, y))


def text(draw, xy, value, size, color, anchor=None):
    draw.text(xy, value, font=font(size), fill=color, anchor=anchor, stroke_width=1, stroke_fill=(0, 0, 0, 210))


def draw_flag_rail(canvas, current):
    x = 35
    y0 = 92
    rows = [y0 + index * 44 for index in range(5)]
    gold = Image.open(WAR / "pole-gold.png").convert("RGBA").resize((16, rows[current] - rows[0] + 20))
    silver = Image.open(WAR / "pole-silver.png").convert("RGBA").resize((12, rows[-1] - rows[current] + 24))
    canvas.alpha_composite(gold, (x - 8, rows[0] - 10))
    canvas.alpha_composite(silver, (x - 6, rows[current] + 8))
    labels = ["Welcome", "Look", "Frames", "Extras", "Done"]
    draw = ImageDraw.Draw(canvas)
    for index, (y, label) in enumerate(zip(rows, labels)):
        if index == current:
            flag = tint(Image.open(WAR / "flag-hang-cloth.png").convert("RGBA").resize((40, 58)), (154, 24, 20))
            trim = Image.open(WAR / "flag-hang-trim.png").convert("RGBA").resize((40, 58))
            canvas.alpha_composite(flag, (x - 20, y - 23))
            canvas.alpha_composite(trim, (x - 20, y - 23))
            color = (245, 238, 222, 255)
        else:
            asset = "node-done.png" if index < current else "node-upcoming.png"
            node = Image.open(WAR / asset).convert("RGBA").resize((20, 20))
            canvas.alpha_composite(node, (x - 10, y - 10))
            color = (196, 190, 176, 255)
        text(draw, (58, y), label, 16, color, "lm")


def draw_minimal_rail(canvas, current):
    draw = ImageDraw.Draw(canvas)
    x = 36
    rows = [92 + index * 44 for index in range(5)]
    draw.line((x, rows[0], x, rows[-1]), fill=(112, 126, 140, 190), width=1)
    labels = ["Welcome", "Look", "Frames", "Extras", "Done"]
    for index, (y, label) in enumerate(zip(rows, labels)):
        marker = Image.open(MINIMAL / ("check.png" if index < current else "active-marker.png")).convert("RGBA").resize((18, 18))
        marker = tint(marker, (226, 31, 31) if index == current else (145, 158, 170))
        canvas.alpha_composite(marker, (x - 9, y - 9))
        text(draw, (58, y), label, 16, (238, 241, 245, 255) if index == current else (184, 191, 200, 255), "lm")


def draw_cards(canvas, war):
    draw = ImageDraw.Draw(canvas)
    start_x = CONTENT_INSET + RAIL_WIDTH + CONTENT_GAP + 14
    y = 180
    gap = 10
    available = SIZE[0] - start_x - CONTENT_INSET - 14
    width = (available - gap * 2) // 3
    height = 310
    looks = ("War", "Midnight", "ModernFlat")
    labels = ("War", "Midnight", "Modern Flat")
    for index, (look, label) in enumerate(zip(looks, labels)):
        x = start_x + index * (width + gap)
        fill = (27, 31, 31, 246) if war else (24, 29, 35, 248)
        rim = (226, 62, 38, 255) if index == 0 else ((173, 135, 79, 255) if war else (132, 148, 162, 230))
        draw.rounded_rectangle((x, y, x + width, y + height), radius=8, fill=fill, outline=rim, width=3 if index == 0 else 1)
        art = cover(SPARTAN / "images" / "setup" / "backdrops" / f"{look}.png", (width - 10, 240))
        canvas.alpha_composite(art, (x + 5, y + 5))
        draw.rectangle((x + 5, y + 245, x + width - 5, y + 246), fill=rim)
        text(draw, (x + width // 2, y + 278), label, 18, (242, 241, 237, 255), "mm")
        if index == 0:
            draw.rounded_rectangle((x + width - 104, y + 10, x + width - 10, y + 34), radius=4, fill=(142, 29, 24, 242), outline=(218, 166, 70, 255))
            text(draw, (x + width - 57, y + 22), "Recommended", 11, (255, 247, 230, 255), "mm")


def build(kit):
    war = kit == "war"
    folder = WAR if war else MINIMAL
    canvas = Image.new("RGBA", SIZE, (12, 17, 22, 255))
    if war:
        canvas.alpha_composite(cover(WAR / "map-panel.png", SIZE), (0, 0))
        canvas.alpha_composite(Image.new("RGBA", SIZE, (17, 13, 9, 70)), (0, 0))
    else:
        canvas.alpha_composite(Image.new("RGBA", SIZE, (9, 12, 16, 245)), (0, 0))
        material = tile(MINIMAL / "material-tile.png", SIZE)
        material.putalpha(18)
        canvas.alpha_composite(material, (0, 0))

    header = Image.open(folder / "header-plate.png").convert("RGBA").resize((SIZE[0], TITLE_HEIGHT), Image.Resampling.LANCZOS)
    footer = Image.open(folder / "header-plate.png").convert("RGBA").resize((SIZE[0], FOOTER_HEIGHT), Image.Resampling.LANCZOS)
    canvas.alpha_composite(header, (0, 0))
    canvas.alpha_composite(footer, (0, SIZE[1] - FOOTER_HEIGHT))
    draw = ImageDraw.Draw(canvas)
    text(draw, (SIZE[0] // 2, TITLE_HEIGHT // 2), "SpartanUI Setup", 18, (238, 235, 225, 255), "mm")

    content_top = 46
    content_bottom = SIZE[1] - 62
    rail = (CONTENT_INSET, content_top, CONTENT_INSET + RAIL_WIDTH, content_bottom)
    panel_left = rail[2] + CONTENT_GAP
    panel = (panel_left, content_top, SIZE[0] - CONTENT_INSET, content_bottom)
    draw.rectangle(rail, fill=(20, 31, 38, 214) if war else (15, 20, 26, 238), outline=(120, 95, 55, 180) if war else (100, 116, 130, 180))
    draw.rectangle(panel, fill=(24, 32, 37, 222) if war else (23, 29, 36, 248), outline=(120, 95, 55, 180) if war else (100, 116, 130, 180))
    text(draw, (CONTENT_INSET + 14, 66), "SpartanUI", 18, (238, 235, 225, 255))
    triangle = Image.open(folder / "triangle.png").convert("RGBA").resize((14, 14))
    canvas.alpha_composite(triangle, (rail[2] - 28, 68))
    if war:
        draw_flag_rail(canvas, 1)
    else:
        draw_minimal_rail(canvas, 1)

    text(draw, (panel_left + 14, 72), "SpartanUI", 14, (184, 173, 150, 255) if war else (184, 194, 204, 255))
    text(draw, (panel_left + 14, 108), "Pick a look", 26, (237, 232, 217, 255) if war else (238, 242, 246, 255))
    text(draw, (panel_left + 14, 142), "This sets the art, frames, action bars and minimap together.", 14, (184, 173, 150, 255) if war else (184, 194, 204, 255))
    draw_cards(canvas, war)

    three_slice(canvas, folder, "button-secondary", (CONTENT_INSET + 14, SIZE[1] - 43, 110, 32))
    three_slice(canvas, folder, "button-primary", (SIZE[0] - CONTENT_INSET - 134, SIZE[1] - 43, 120, 32))
    draw = ImageDraw.Draw(canvas)
    text(draw, (CONTENT_INSET + 69, SIZE[1] - 27), "Back", 14, (243, 241, 235, 255), "mm")
    text(draw, (SIZE[0] - CONTENT_INSET - 74, SIZE[1] - 27), "Next", 14, (255, 248, 238, 255), "mm")
    text(draw, (SIZE[0] // 2, SIZE[1] - 27), "Step 2 of 5", 11, (202, 200, 194, 255), "mm")

    frame_9slice(canvas, folder, 32 if war else 16, 12 if war else 1)
    return canvas.convert("RGB")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    war = build("war")
    minimal = build("minimal")
    war.save(OUTPUT / "kit_war.png", optimize=True)
    minimal.save(OUTPUT / "kit_minimal.png", optimize=True)

    reference = Image.open(REFERENCE).convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
    difference = ImageStat.Stat(ImageChops.difference(reference, war)).mean
    mean_difference = sum(difference) / len(difference)
    print(f"War render versus approved mock mean channel difference: {mean_difference:.2f}/255")
    print("Structural comparison: same wide frame, title/footer bands, left route rail, three-card decision, and inset footer actions.")
    print("Known evidence limit: PIL cannot render live client atlases, exact font rasterization, or secure frame behavior.")
    print(OUTPUT / "kit_war.png")
    print(OUTPUT / "kit_minimal.png")


if __name__ == "__main__":
    main()
