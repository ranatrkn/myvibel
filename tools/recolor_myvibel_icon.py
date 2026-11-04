"""Recolor app icon: left/My dark purple, right burgundy, star pink."""

from pathlib import Path

from PIL import Image

ROOT = Path(r"C:\projelerim\myvibel\assets\icon")
FILES = [ROOT / "myvibel_ikon.png", ROOT / "myvibel_launcher.png"]

MOR_EDGE = (48, 10, 78)
MOR_MID = (86, 28, 128)
MOR_CORE = (132, 68, 176)

BORDO_EDGE = (72, 6, 22)
BORDO_MID = (120, 16, 40)
BORDO_CORE = (168, 42, 72)

PINK_EDGE = (190, 48, 98)
PINK_MID = (235, 90, 138)
PINK_CORE = (255, 168, 198)

STAR_CX, STAR_CY, STAR_R = 875, 525, 42


def mix(c0, c1, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))


def shade(lum, edge, mid, core):
    if lum < 0.42:
        return mix(edge, mid, lum / 0.42)
    return mix(mid, core, (lum - 0.42) / 0.58)


def recolor(path: Path) -> None:
    src = Image.open(path).convert("RGBA")
    px = src.load()
    w, h = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dest = out.load()
    sx = STAR_CX * w / 1024
    sy = STAR_CY * h / 1024
    sr = STAR_R * w / 1024

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            if lum < 0.055 and a > 180:
                dest[x, y] = (8, 0, 18, a)
                continue
            dist = ((x - sx) ** 2 + (y - sy) ** 2) ** 0.5
            t = x / max(1, w - 1)
            if dist <= sr and lum > 0.28:
                col = shade(min(1.0, lum + 0.15), PINK_EDGE, PINK_MID, PINK_CORE)
            else:
                if t < 0.40:
                    pal = (MOR_EDGE, MOR_MID, MOR_CORE)
                elif t > 0.58:
                    pal = (BORDO_EDGE, BORDO_MID, BORDO_CORE)
                else:
                    k = (t - 0.40) / 0.18
                    pal = (
                        mix(MOR_EDGE, BORDO_EDGE, k),
                        mix(MOR_MID, BORDO_MID, k),
                        mix(MOR_CORE, BORDO_CORE, k),
                    )
                col = shade(lum, *pal)
            dest[x, y] = (*col, a)

    out.save(path, "PNG")
    print("saved", path.name)


def main() -> None:
    for f in FILES:
        recolor(f)


if __name__ == "__main__":
    main()
