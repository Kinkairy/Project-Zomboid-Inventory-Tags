#!/usr/bin/env python3
"""Check LT9 trilingual outputs; only --write changes generated runtime files."""
import argparse
import json
import re
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    root = here.parent / 'workshop/Contents/mods/InventoryTags/common/media/lua'
    source = json.loads((here / 'catalog.json').read_text(encoding='utf-8'))
    langs = ('EN', 'CN', 'CH')
    data = {}
    for section in ('IG_UI', 'Sandbox'):
        data[section] = {lang: {} for lang in langs}
        rows = source[section]
        if not rows:
            raise ValueError('Empty section: ' + section)
        for row in rows:
            if len(row) != 4 or not all(isinstance(x, str) and x for x in row):
                raise ValueError('Expected nonempty key/EN/CN/CH row')
            key = row[0]
            if key in data[section]['EN']:
                raise ValueError('Duplicate key: ' + key)
            if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', key):
                raise ValueError('Invalid key: ' + key)
            tokens = [sorted(re.findall(r'%(?:\d+|[sdf])|\{[^{}]+\}', v)) for v in row[1:]]
            if tokens[0] != tokens[1] or tokens[0] != tokens[2]:
                raise ValueError('Placeholder mismatch: ' + key)
            for lang, value in zip(langs, row[1:]):
                data[section][lang][key] = value
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    outputs = {}
    for section, translations in data.items():
        for lang, values in translations.items():
            folder = root / 'shared/Translate' / lang
            outputs[folder / (section + '.json')] = json.dumps(values, ensure_ascii=False, indent=2) + '\n'
            lines = [section + '_' + lang + ' = {']
            lines.extend('    ' + key + ' = ' + quote(value) + ',' for key, value in values.items())
            outputs[folder / (section + '_' + lang + '.txt')] = '\n'.join(lines + ['}', ''])
    lines = ['require "InventoryTags/InventoryTags_Core"', 'local IT=InventoryTags', 'local fallback={']
    for lang in langs:
        lines.append('    [' + quote(lang) + '] = {')
        for key, value in data['IG_UI'][lang].items():
            short = key.removeprefix('IGUI_InventoryTags_')
            lines.append('        [' + quote(short) + '] = ' + quote(value) + ',')
        lines.append('    },')
    lines.append('}')
    outputs[root / 'client/InventoryTags/InventoryTags_Text.lua'] = '\n'.join(lines) + '\n' + (here / 'fallback-tail.lua').read_text(encoding='utf-8')
    mismatches = []
    for path, text in outputs.items():
        expected = text.encode('utf-8')
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
        elif not path.is_file() or path.read_bytes() != expected:
            mismatches.append(str(path.relative_to(root)))
    if mismatches:
        raise SystemExit('FAIL: generated files differ: ' + ', '.join(mismatches))
    print(('WROTE' if args.write else 'PASS') + ': 13 trilingual outputs; EN/CN/CH keys and placeholders match.')


if __name__ == '__main__':
    main()
