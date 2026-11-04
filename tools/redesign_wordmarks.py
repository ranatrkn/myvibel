"""Generate clean dark/light MyVibel wordmarks from scratch."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"C:\projelerim\myvibel\assets\icon")
FONT_PATH = Path(r"C:\projelerim\myvibel\assets\fonts\Outfit-Variable.ttf")

OUT_DARK = ROOT / "myvibel_yazi_dark.png"
OUT_LIGHT = ROOT / "myvibel_yazi_light.png"


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


def _draw_segment(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    text: str,
    font: ImageFont.FreeTypeFont,
    stroke: tuple[int, int, int],
    base: tuple[int, int, int],
    highlight: tuple[int, int, int],
) -> tuple[int, int, int, int]:
    # Main body
    draw.text(
        (x, y),
        text,
        font=font,
        fill=(*base, 255),
        stroke_width=10,
        stroke_fill=(*stroke, 255),
    )
    # Top highlight
    draw.text((x + 1, y - 7), text, font=font, fill=(*highlight, 120))
    return draw.textbbox((x, y), text, font=font, stroke_width=10)


def _star(size: int, c1: tuple[int, int, int], c2: tuple[int, int, int]) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = size // 2
    q = max(2, size // 5)
    pts = [(m, 0), (m + q, m - q), (size, m), (m + q, m + q), (m, size), (m - q, m + q), (0, m), (m - q, m - q)]
    d.polygon(pts, fill=(*c1, 255))
    d.ellipse((m - q // 2, m - q // 2, m + q // 2, m + q // 2), fill=(*c2, 255))
    return im


def generate(
    out_path: Path,
    my_stroke: tuple[int, int, int],
    my_base: tuple[int, int, int],
    my_highlight: tuple[int, int, int],
    v_stroke: tuple[int, int, int],
    v_base: tuple[int, int, int],
    v_highlight: tuple[int, int, int],
    star_c1: tuple[int, int, int],
    star_c2: tuple[int, int, int],
) -> None:
    font = _font(250)
    canvas = Image.new("RGBA", (1320, 440), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    y = 90
    x_my = 30

    my_box = _draw_segment(d, x_my, y, "My", font, my_stroke, my_base, my_highlight)
    x_v = my_box[2] + 8
    v_box = _draw_segment(d, x_v, y, "Vibel", font, v_stroke, v_base, v_highlight)

    # Position star above the "i" in "Vibel".
    f = _font(250)
    dummy = Image.new("L", (1000, 400), 0)
    dd = ImageDraw.Draw(dummy)
    bbox_vi = dd.textbbox((0, 0), "Vi", font=f)
    bbox_vib = dd.textbbox((0, 0), "Vib", font=f)
    i_center_local = (bbox_vi[2] + bbox_vib[2]) // 2
    sx = x_v + i_center_local - 24
    sy = v_box[1] - 32
    canvas.alpha_composite(_star(48, star_c1, star_c2), (sx, sy))

    # Trim transparent border.
    bb = canvas.getbbox()
    if bb:
        canvas = canvas.crop(bb)
    canvas.save(out_path, "PNG")


def main() -> None:
    generate(
        OUT_DARK,
        my_stroke=(42, 10, 76),
        my_base=(90, 34, 140),
        my_highlight=(148, 96, 198),
        v_stroke=(64, 8, 24),
        v_base=(124, 26, 50),
        v_highlight=(180, 70, 94),
        star_c1=(220, 92, 146),
        star_c2=(255, 170, 205),
    )
    generate(
        OUT_LIGHT,
        my_stroke=(106, 76, 150),
        my_base=(164, 128, 206),
        my_highlight=(214, 188, 238),
        v_stroke=(150, 86, 106),
        v_base=(208, 126, 146),
        v_highlight=(238, 176, 192),
        star_c1=(244, 146, 182),
        star_c2=(255, 212, 226),
    )
    print("generated", OUT_DARK.name, OUT_LIGHT.name)


if __name__ == "__main__":
    main()
