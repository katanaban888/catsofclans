#!/usr/bin/env python3
"""Split this session's generated sheets using measured white/transparent gutters.

python3 Scripts/split_generated_assets.py
The cat sheet actually has TWO rows: only the top row is used. No square-sheet
or hardcoded pixel-size assumptions; whitespace cuts are measured independently.
Raw inputs/outputs remain in ignored raw/. Requires Pillow.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def split_row(source, names, rows=1, row=0):
    image = Image.open(source).convert("RGBA")
    width, height = image.size
    image = image.crop((0, round(height * row / rows), width, round(height * (row + 1) / rows)))
    pixels = image.load()
    occupied = [any(pixels[x, y][3] > 20 and min(pixels[x, y][:3]) < 225
                    for y in range(image.height)) for x in range(width)]
    first, last = occupied.index(True), width - 1 - occupied[::-1].index(True)
    gaps = []
    start = None
    for x in range(first, last + 1):
        if not occupied[x] and start is None:
            start = x
        elif occupied[x] and start is not None:
            gaps.append((x - start, (x + start) // 2))
            start = None
    gutters = sorted(gaps, reverse=True)[:len(names) - 1]
    if len(gutters) != len(names) - 1 or any(length < width * 0.01 for length, _ in gutters):
        raise ValueError(f"Cannot safely isolate {len(names)} sprites in {source}; inspect the actual sheet")
    cuts = [0] + sorted(center for _, center in gutters) + [width]
    for name, left, right in zip(names, cuts, cuts[1:]):
        image.crop((left, 0, right, image.height)).save(ROOT / "raw" / f"{name}.png")
    print(f"{source.name}: {width}x{height}; row={row}/{rows}; measured cuts={cuts}")


if __name__ == "__main__":
    split_row(ROOT / "raw/player_cats.png", ["unit_" + n for n in
              ["kitten", "warrior", "mouser", "wizard", "tiger"]], rows=2)
    split_row(ROOT / "raw/new_buildings.png", ["building_" + n for n in
              ["yarnmill", "expedition", "bivouac"]])
