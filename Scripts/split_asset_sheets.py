#!/usr/bin/env python3
"""Split the original generated September 2026 sheets in raw/ before processing."""
from pathlib import Path
from PIL import Image

RAW = Path(__file__).resolve().parent.parent / "raw"
SHEETS = [
    ("enemies.png", 3, [0, 480, 1024],
     ["unit_hamster", "unit_raccoon", "unit_banditcat", "unit_dog", "unit_wolf", "unit_alphawolf"]),
    ("props.png", 3, [0, 560, 1024],
     ["building_sniper", "building_trap", "res_fish", "res_cream", "res_yarn", "res_mouse"]),
    ("decor_buttons.png", 4, [0, 444, 887],
     ["btn_shop", "btn_attack", "btn_army", "btn_settings", "decor_tree", "decor_bush", "decor_rock", "decor_flower"]),
    ("effects.png", 2, [0, 887], ["fx_boom", "fx_win"]),
]

if __name__ == "__main__":
    for filename, columns, rows, names in SHEETS:
        with Image.open(RAW / filename) as image:
            for i, name in enumerate(names):
                row, col = divmod(i, columns)
                edges = [i * image.width // columns for i in range(columns + 1)]
                if filename == "enemies.png" and row == 1:
                    edges[2] = 980  # Alpha wolf's gauntlet extends left of its nominal cell.
                image.crop((edges[col], rows[row], edges[col + 1], rows[row + 1])).save(RAW / f"{name}.png")
