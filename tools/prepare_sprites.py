"""Prepare painted Rocky frames for the game.

Usage (from the project folder):
    pip install pillow numpy
    python tools/prepare_sprites.py C:\\path\\to\\raw_frames

Raw frames must be named run_1, run_2, run_3, run_4, jump, idle_1, idle_2, hurt
(any image type: .png .jpg .webp). Only run_1 is required.
Rocky must face RIGHT, on a plain (white or single-colour) or transparent background.

For each frame this script:
  1. removes a plain background (keeps existing transparency),
  2. trims empty space so the feet sit on the bottom edge,
  3. scales every frame by the SAME factor (run_1 becomes 360 px wide),
  4. saves it to assets/sprites/<name>.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

NAMES = ["run_1", "run_2", "run_3", "run_4", "jump", "idle_1", "idle_2", "hurt"]
TARGET_WIDTH = 360        # run_1 width in pixels (sharp on phones, small APK)
TOLERANCE = 38            # how different from the background colour counts as dog


def remove_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    a = np.array(img)
    if a[..., 3].min() < 250:          # already has transparency
        return img
    rgb = a[..., :3].astype(int)
    h, w = rgb.shape[:2]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    close = np.abs(rgb - bg).sum(axis=2) < TOLERANCE * 3
    # flood fill from the edges so background-coloured spots INSIDE the dog stay
    mask = np.zeros((h, w), bool)
    stack = [(y, x) for x in range(w) for y in (0, h - 1)] + \
            [(y, x) for y in range(h) for x in (0, w - 1)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and close[y, x] and not mask[y, x]:
            mask[y, x] = True
            stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    alpha = Image.fromarray(np.where(mask, 0, 255).astype(np.uint8))
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.2))   # soft fur edge
    img.putalpha(alpha)
    return img


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1])
    out = Path(__file__).resolve().parent.parent / "assets" / "sprites"
    out.mkdir(parents=True, exist_ok=True)

    frames = {}
    for name in NAMES:
        files = [f for f in src.glob(name + ".*") if f.suffix.lower() in
                 (".png", ".jpg", ".jpeg", ".webp")]
        if files:
            im = remove_background(Image.open(files[0]))
            frames[name] = im.crop(im.getbbox())
    if "run_1" not in frames:
        sys.exit("run_1 is required")

    scale = TARGET_WIDTH / frames["run_1"].width
    for name, im in frames.items():
        size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
        im.resize(size, Image.LANCZOS).save(out / f"{name}.png", optimize=True)
        print(f"{name}.png  {size[0]}x{size[1]}")
    print(f"\nSaved to {out}. Stop the app and run it again (full restart).")


if __name__ == "__main__":
    main()
