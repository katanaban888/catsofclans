#!/usr/bin/env python3
"""Static asset/target/UI-route validation. Does NOT claim to launch or build iOS.

Requires Pillow. Run after generate_xcode_project.py. Exits nonzero on missing,
corrupt or incorrectly referenced assets, including the formerly missing cats.
"""
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "CatClansApp/Assets.xcassets"
NEW = {"u_kitten", "u_warrior", "u_mouser", "u_wizard", "u_tiger",
       "b_yarnmill", "b_expedition", "b_bivouac"}


def main():
    mapping = (ROOT / "CatClansApp/Assets.swift").read_text()
    required = set(re.findall(r'return "([ub]_[a-z0-9]+)"', mapping))
    assert NEW <= required
    for name in required:
        assert (CATALOG / f"{name}.imageset/Contents.json").is_file(), name
    count = 0
    for manifest in CATALOG.rglob("Contents.json"):
        data = json.loads(manifest.read_text())
        name = manifest.parent.stem
        files = [item["filename"] for item in data.get("images", []) if "filename" in item]
        if name in required:
            assert files == [name + ".png"], (name, files)
        for filename in files:
            path = manifest.parent / filename
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                assert image.format == "PNG" and min(image.size) > 0, path
                if name in required:
                    assert image.mode == "RGBA", name
                    alpha = image.getchannel("A")
                    assert alpha.getextrema() == (0, 255), (name, "no real alpha")
                    if name in NEW:
                        x0, y0, x1, y1 = alpha.getbbox()
                        assert x0 >= 4 and y0 >= 4 and x1 <= image.width - 4 and y1 <= image.height - 4, (name, "clipped")
                        coverage = sum(alpha.histogram()[1:]) / (image.width * image.height)
                        assert 0.15 < coverage < 0.90, (name, coverage)
            count += 1
    project = (ROOT / "CatClans.xcodeproj/project.pbxproj").read_text()
    # Check actual target -> Resources phase -> catalog membership, not just a file ref.
    phase = re.search(r'(\w+) /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;.*?\n\s*\};', project, re.S)
    assert phase and 'Assets.xcassets in Resources' in phase.group()
    target = re.search(r'/\* CatClans \*/ = \{\s*isa = PBXNativeTarget;.*?\n\s*\};', project, re.S)
    assert target and phase.group(1) in target.group()
    assert 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in project
    assert 'UIImage(named: asset, in: .main, compatibleWith: nil)' in mapping
    assert 'assert(image != nil' in mapping
    unit_wrapper = mapping.split('struct UnitSpriteView: View')[1].split('/// Иконка ресурса')[0]
    assert 'RequiredSpriteView' in unit_wrapper and 'fallbackEmoji:' not in unit_wrapper
    for filename in ['ArmyPanel.swift', 'BattleView.swift', 'AttackView.swift']:
        text = (ROOT / 'CatClansApp/Views' / filename).read_text()
        assert 'UnitSpriteView(' in text, filename
        assert not re.search(r'Text\([^\n]*\b(?:unit|u|snap|job\.unit)\.emoji', text), filename
    for path in (ROOT / 'CatClansApp').rglob('*.swift'):
        text = path.read_text()
        assert not re.search(r'\b(NavigationStack|MagnifyGesture|ViewThatFits)\b', text), path
    print(f'PASS: {count} PNGs/JSON; {len(required)} mandatory sprites; all 8 new alpha/crop checks')
    print('PASS: catalog is in CatClans Resources; army/training/preview/battle/tray use UnitSpriteView')
    print('Static validation only: no Swift compilation, actool, bundle launch or device UI verification.')


if __name__ == '__main__':
    main()
