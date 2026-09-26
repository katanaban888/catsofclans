#!/usr/bin/env python3
"""Обрабатывает сырые сгенерированные арты (raw/*.png) в ассет-каталог.

Генератор картинок отдаёт PNG с «запечённым» шахматным фоном прозрачности
(два серых цвета ~120 и ~181). Этот скрипт:
  1. заливает фон (flood-fill от краёв) в настоящую прозрачность;
  2. обрезает по альфе с небольшим отступом;
  3. уменьшает до целевого размера;
  4. раскладывает по CatClansApp/Assets.xcassets/<name>.imageset/.

Запуск:  python3 Scripts/process_assets.py
Можно передать имена ассетов как аргументы, чтобы обработать только их.
"""
import json
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw")
ASSETS = os.path.join(ROOT, "CatClansApp", "Assets.xcassets")

# имя ассета -> (сырой файл, целевой размер стороны)
ASSET_MAP = {
    # Здания
    "b_home1":       ("building_home1.png", 384),
    "b_home2":       ("building_home2.png", 384),
    "b_home3":       ("building_home3.png", 384),
    "b_workshop":    ("building_workshop.png", 384),
    "b_fishtrap":    ("building_fishtrap.png", 384),
    "b_creambarrel": ("building_creambarrel.png", 384),
    "b_toyshelf":    ("building_toyshelf.png", 384),
    "b_academy":     ("building_academy.png", 384),
    "b_wall":        ("building_wall.png", 384),
    "b_cannon":      ("building_cannon.png", 384),
    "b_sniper":      ("building_sniper.png", 384),
    "b_trap":        ("building_trap.png", 384),
    # Юниты игрока
    "u_kitten":  ("unit_kitten.png", 192),
    "u_warrior": ("unit_warrior.png", 192),
    "u_mouser":  ("unit_mouser.png", 192),
    "u_wizard":  ("unit_wizard.png", 192),
    "u_tiger":   ("unit_tiger.png", 192),
    # Враги
    "u_hamster":   ("unit_hamster.png", 160),
    "u_raccoon":   ("unit_raccoon.png", 160),
    "u_banditcat": ("unit_banditcat.png", 160),
    "u_dog":       ("unit_dog.png", 160),
    "u_wolf":      ("unit_wolf.png", 160),
    "u_alphawolf": ("unit_alphawolf.png", 160),
    # Ресурсы
    "r_fish":  ("res_fish.png", 128),
    "r_cream": ("res_cream.png", 128),
    "r_yarn":  ("res_yarn.png", 128),
    "r_mouse": ("res_mouse.png", 128),
    # Кнопки
    "btn_shop":     ("btn_shop.png", 128),
    "btn_attack":   ("btn_attack.png", 128),
    "btn_army":     ("btn_army.png", 128),
    "btn_settings": ("btn_settings.png", 128),
    # Фон карты и декор
    "map_bg":  ("map_bg.png", 1024),
    "d_tree":  ("decor_tree.png", 160),
    "d_bush":  ("decor_bush.png", 160),
    "d_rock":  ("decor_rock.png", 160),
    "d_flower": ("decor_flower.png", 160),
    # Эффекты
    "fx_boom": ("fx_boom.png", 192),
    "fx_win":  ("fx_win.png", 192),
}


def is_checker(px) -> bool:
    """Пиксель «шахматного» фона: серый, каналы почти равны."""
    r, g, b = px[0], px[1], px[2]
    if max(r, g, b) - min(r, g, b) > 18:
        return False
    return 90 <= r <= 210


def remove_checker_background(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    seen = bytearray(w * h)
    dq = deque()

    def seed(x, y):
        if is_checker(px[x, y]):
            idx = y * w + x
            if not seen[idx]:
                seen[idx] = 1
                dq.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while dq:
        x, y = dq.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                idx = ny * w + nx
                if not seen[idx] and is_checker(px[nx, ny]):
                    seen[idx] = 1
                    dq.append((nx, ny))

    out = img.convert("RGBA")
    op = out.load()
    for y in range(h):
        for x in range(w):
            if seen[y * w + x]:
                r, g, b, a = op[x, y]
                op[x, y] = (r, g, b, 0)
    return out


def process(name: str, raw_file: str, target: int) -> bool:
    src = os.path.join(RAW, raw_file)
    if not os.path.exists(src):
        return False
    img = Image.open(src)
    img = remove_checker_background(img)

    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        m = 4
        x0 = max(0, x0 - m)
        y0 = max(0, y0 - m)
        x1 = min(img.width, x1 + m)
        y1 = min(img.height, y1 + m)
        img = img.crop((x0, y0, x1, y1))

    # Вписать в квадрат target×target, сохраняя пропорции.
    w, h = img.size
    scale = min(target / w, target / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.LANCZOS)

    imageset = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(imageset, exist_ok=True)
    png_path = os.path.join(imageset, name + ".png")
    img.save(png_path, "PNG", optimize=True)

    contents = {
        "images": [
            {"idiom": "universal", "filename": name + ".png", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(imageset, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump(contents, fh, indent=2)
    return True


def main() -> None:
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    os.makedirs(ASSETS, exist_ok=True)
    root_contents = {"info": {"author": "xcode", "version": 1}}
    with open(os.path.join(ASSETS, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump(root_contents, fh, indent=2)

    done, missing = [], []
    for name, (raw_file, target) in ASSET_MAP.items():
        if only and name not in only:
            continue
        if process(name, raw_file, target):
            done.append(name)
        else:
            missing.append(name)
    print(f"processed: {len(done)} -> {', '.join(done) if done else '-'}")
    if missing:
        print(f"missing raw: {', '.join(missing)}")


if __name__ == "__main__":
    main()
