from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "Media" / "Setup"
STAGE_SOURCE = Path(r"C:\Users\jerem\.codex\generated_images\01a0ef0b-ae2c-7a31-abe0-399759fcc576\exec-3bf0227f-85a9-4285-8683-ecdaa02bdbbb.png")
WAR_SOURCE = Path(r"C:\Users\jerem\.codex\generated_images\01a0ef0b-ae2c-7a31-abe0-399759fcc576\exec-676fc2e2-4798-46ea-89cb-d2d709ec8b01.png")


def downsample(image, size):
    return image.resize(size, Image.Resampling.LANCZOS)


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def backdrop(source, target, brightness, blur):
    image = Image.open(source).convert("RGB")
    image = image.resize((1024, 512), Image.Resampling.LANCZOS)
    image = image.filter(ImageFilter.GaussianBlur(blur))
    image = ImageEnhance.Brightness(image).enhance(brightness)
    image = ImageEnhance.Color(image).enhance(0.72)
    save(image, target)


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


def glass_assets(folder):
    scale = 4
    size = 128
    shadow = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle((18 * scale, 20 * scale, 110 * scale, 112 * scale), radius=18 * scale, fill=(0, 0, 0, 210))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10 * scale))
    save(downsample(shadow, (size, size)), folder / "soft-shadow.png")

    rim = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(rim)
    draw.rounded_rectangle((4 * scale, 4 * scale, 124 * scale, 124 * scale), radius=18 * scale, outline=(190, 195, 204, 120), width=2 * scale)
    draw.rounded_rectangle((7 * scale, 7 * scale, 121 * scale, 121 * scale), radius=15 * scale, outline=(255, 255, 255, 32), width=1 * scale)
    save(downsample(rim, (size, size)), folder / "glass-rim.png")


def switch_assets(folder, warm=False):
    track_color = (73, 67, 58, 255) if warm else (72, 75, 82, 255)
    outline = (155, 132, 91, 220) if warm else (157, 162, 171, 220)
    rounded_asset(folder / "switch-track.png", track_color, outline, (128, 64), 30)

    scale = 4
    knob = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(knob)
    draw.ellipse((7 * scale, 7 * scale, 57 * scale, 57 * scale), fill=(235, 236, 239, 255), outline=(255, 255, 255, 220), width=2 * scale)
    save(downsample(knob, (64, 64)), folder / "switch-knob.png")


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


def war_assets(folder):
    scale = 4
    waypoint = Image.new("RGBA", (64 * scale, 64 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(waypoint)
    draw.ellipse((9 * scale, 9 * scale, 55 * scale, 55 * scale), fill=(47, 42, 34, 255), outline=(187, 151, 87, 255), width=5 * scale)
    draw.ellipse((24 * scale, 24 * scale, 40 * scale, 40 * scale), fill=(225, 204, 158, 255))
    save(downsample(waypoint, (64, 64)), folder / "waypoint.png")

    banner = Image.new("RGBA", (128 * scale, 96 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(banner)
    draw.polygon(
        [(8 * scale, 10 * scale), (112 * scale, 10 * scale), (120 * scale, 38 * scale), (105 * scale, 48 * scale), (116 * scale, 82 * scale), (63 * scale, 68 * scale), (10 * scale, 82 * scale), (21 * scale, 48 * scale), (6 * scale, 38 * scale)],
        fill=(218, 218, 218, 245),
        outline=(255, 255, 255, 255),
    )
    save(downsample(banner, (128, 64)), folder / "banner.png")

    oak = Image.new("RGB", (256, 256), (57, 34, 20))
    draw = ImageDraw.Draw(oak)
    for y in range(0, 256, 11):
        tone = 42 + (y * 13 % 24)
        draw.line((0, y, 256, y + ((y // 11) % 3) - 1), fill=(tone + 18, tone, max(tone - 10, 0)), width=3)
    oak = oak.filter(ImageFilter.GaussianBlur(0.45))
    save(oak, folder / "oak-tile.png")

    brass = Image.new("RGB", (128, 128), (112, 84, 42))
    draw = ImageDraw.Draw(brass)
    for i in range(0, 128, 3):
        value = 92 + (i * 7 % 38)
        draw.line((i, 0, i, 128), fill=(value + 34, value + 12, max(value - 24, 0)))
    brass = brass.filter(ImageFilter.GaussianBlur(1.2))
    save(brass, folder / "brass-tile.png")

    slate = Image.new("RGB", (256, 256), (35, 43, 47))
    draw = ImageDraw.Draw(slate)
    for offset in range(18, 240, 30):
        points = []
        for x in range(-20, 280, 12):
            y = offset + int(6 * __import__("math").sin((x + offset) / 23))
            points.append((x, y))
        draw.line(points, fill=(70, 81, 83), width=1)
    slate = slate.filter(ImageFilter.GaussianBlur(0.35))
    save(slate, folder / "map-slate-tile.png")


def main():
    stage = MEDIA / "stage"
    war = MEDIA / "wartable"
    backdrop(STAGE_SOURCE, stage / "backdrop.png", 0.48, 5.0)
    backdrop(WAR_SOURCE, war / "backdrop.png", 0.58, 1.7)
    for folder, warm in ((stage, False), (war, True)):
        glass_assets(folder)
        switch_assets(folder, warm)
        marker_assets(folder, warm)
        rounded_asset(folder / "button.png", (48, 50, 56, 246), (154, 159, 168, 190), (256, 64), 18)
        rounded_asset(folder / "button-filled.png", (255, 255, 255, 246), (255, 255, 255, 150), (256, 64), 18)
    war_assets(war)


if __name__ == "__main__":
    main()
