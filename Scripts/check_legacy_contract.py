#!/usr/bin/env python3
"""Compare protected legacy files/entries/RNG call order with the session base.
This is a source invariant check, NOT a substitute for XCTest.
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = 'fad14f7501c4c7ede1ceb0b645768c359da8ddba'


def original(path):
    return subprocess.check_output(['git', 'show', f'{BASE}:{path}'], cwd=ROOT)


def main():
    protected = ['Sources/CatClansKit/Support/RNG.swift',
                 'Sources/CatClansKit/Model/Units.swift',
                 'Sources/CatClansKit/Battle/EnemyGenerator.swift']
    tests = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', BASE, 'Tests'], cwd=ROOT).decode().splitlines()
    for path in protected + tests:
        assert original(path) == (ROOT / path).read_bytes(), f'Legacy file modified: {path}'
    path = 'Sources/CatClansKit/Model/Buildings.swift'
    entry = r'        d\[\.(\w+)\] = BuildingDef\(.*?\n        \)'
    old = {m.group(1): m.group(0) for m in re.finditer(entry, original(path).decode(), re.S)}
    new = {m.group(1): m.group(0) for m in re.finditer(entry, (ROOT / path).read_text(), re.S)}
    for name, text in old.items():
        assert new[name] == text, f'Legacy balance changed: {name}'
    path = 'Sources/CatClansKit/Battle/BattleSim.swift'
    rng_lines = lambda text: [line.strip() for line in text.splitlines() if 'rng.' in line]
    assert rng_lines(original(path).decode()) == rng_lines((ROOT / path).read_text()), 'RNG calls changed'
    print(f'PASS: {len(tests)} existing test files, RNG, UnitTable and EnemyGenerator byte-identical')
    print(f'PASS: all {len(old)} original BuildingTable entries and BattleSim RNG call lines unchanged')


if __name__ == '__main__':
    main()
