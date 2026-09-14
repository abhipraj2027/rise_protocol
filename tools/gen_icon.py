"""Generate Rise Protocol's app icon: a rising-sun mark (amber glow on
near-black) matching the in-app palette, as legacy launcher icons, Android
adaptive-icon layers, the Play Store hi-res listing icon, and the web
favicon/PWA icons. No external assets — pure PIL drawing.

Run from the repo root:  python tools/gen_icon.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

BG = (10, 10, 12, 255)          # AppTokens.dark().surface0
SUN_CORE = (255, 214, 168, 255)  # brighter than brand, for the hot centre
SUN_EDGE = (242, 166, 94, 255)   # AppTokens.dark().brand
GLOW = (242, 166, 94, 255)

SS = 4  # supersampling factor for crisp anti-aliased edges


def draw_mark(canvas_size: int, content_scale: float) -> Image.Image:
    """A sun disc low in frame with a soft glow and a few rising rays,
    transparent background, centred in a `canvas_size` square. content_scale
    shrinks the mark within the canvas (1.0 = legacy icon fill; ~0.55 = the
    adaptive-icon foreground safe zone)."""
    s = canvas_size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    cx, cy = s / 2, s * (0.62)
    r = s * 0.20 * content_scale / 0.62  # sun radius, scaled with content

    # Soft outer glow: several fading discs, blurred.
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i, mult in enumerate((2.6, 2.1, 1.6, 1.25)):
        alpha = int(26 * (i + 1) / 4)
        rr = r * mult
        gd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(*GLOW[:3], alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=s * 0.03))
    img = Image.alpha_composite(img, glow)

    # Rising rays behind the disc.
    rays = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    n_rays = 5
    for i in range(n_rays):
        angle = math.radians(-90 + (i - (n_rays - 1) / 2) * 26)
        length = r * (2.5 if i == (n_rays - 1) / 2 else 2.0)
        width = r * 0.16
        x0 = cx + math.cos(angle) * r * 0.85
        y0 = cy + math.sin(angle) * r * 0.85
        x1 = cx + math.cos(angle) * (r * 0.85 + length)
        y1 = cy + math.sin(angle) * (r * 0.85 + length)
        rd.line([x0, y0, x1, y1], fill=SUN_EDGE, width=max(2, int(width)))
    rays = rays.filter(ImageFilter.GaussianBlur(radius=s * 0.006))
    img = Image.alpha_composite(img, rays)

    # The sun disc itself, radial-gradient core-to-edge.
    disc = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dd = ImageDraw.Draw(disc)
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        rr = r * t
        col = tuple(int(SUN_CORE[c] * (1 - t) + SUN_EDGE[c] * t) for c in range(3))
        dd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(*col, 255))
    img = Image.alpha_composite(img, disc)

    return img.resize((canvas_size, canvas_size), Image.LANCZOS)


def legacy_icon(size: int) -> Image.Image:
    bg = Image.new("RGBA", (size, size), BG)
    mark = draw_mark(size, content_scale=0.62)
    return Image.alpha_composite(bg, mark)


def adaptive_foreground(size: int) -> Image.Image:
    # Adaptive icons render on a 108dp canvas but OEM masks can crop toward
    # a ~66dp safe zone — keep the mark well inside that.
    return draw_mark(size, content_scale=0.40)


def write(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"wrote {path} ({img.size[0]}x{img.size[1]})")


def main() -> None:
    # Legacy launcher icons (used pre-API26 and as the flat fallback).
    legacy_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in legacy_sizes.items():
        write(
            legacy_icon(size),
            f"android/app/src/main/res/{folder}/ic_launcher.png",
        )

    # Adaptive-icon foreground layers (108dp canvas at each density scale).
    adaptive_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    for folder, size in adaptive_sizes.items():
        write(
            adaptive_foreground(size),
            f"android/app/src/main/res/{folder}/ic_launcher_foreground.png",
        )

    # Play Store hi-res listing icon (uploaded directly in Play Console, not
    # bundled in the app) and a square marketing-size PNG for convenience.
    write(legacy_icon(512), "store_assets/icon-512.png")

    # Web favicon / PWA icons, matching.
    write(legacy_icon(16), "web/favicon.png")
    write(legacy_icon(192), "web/icons/Icon-192.png")
    write(legacy_icon(512), "web/icons/Icon-512.png")
    write(legacy_icon(192), "web/icons/Icon-maskable-192.png")
    write(legacy_icon(512), "web/icons/Icon-maskable-512.png")


if __name__ == "__main__":
    main()
