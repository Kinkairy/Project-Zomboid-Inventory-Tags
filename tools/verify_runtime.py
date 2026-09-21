#!/usr/bin/env python3
"""Read-only verification of the complete approved LT9 runtime payload."""
import hashlib
import json
from pathlib import Path


def object_hash(kind, data):
    return hashlib.sha1(kind + b' ' + str(len(data)).encode() + b'\0' + data).digest()


def tree_hash(folder):
    data = b''
    for path in sorted(folder.iterdir(), key=lambda p: (p.name + ('/' if p.is_dir() else '')).encode('utf-8')):
        if path.is_symlink():
            raise ValueError('Symlink is not an approved runtime file: ' + str(path))
        directory = path.is_dir()
        oid = tree_hash(path) if directory else object_hash(b'blob', path.read_bytes())
        data += (b'40000' if directory else b'100644') + b' ' + path.name.encode('utf-8') + b'\0' + oid
    return object_hash(b'tree', data)


def main():
    root = Path(__file__).resolve().parents[1]
    payload = root / 'workshop/Contents/mods/InventoryTags'
    manifest = json.loads((root / 'runtime-sha256.json').read_text(encoding='utf-8'))
    actual = {p.relative_to(payload).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in payload.rglob('*') if p.is_file()}
    if actual != manifest or len(actual) != 35:
        bad = sorted(k for k in set(actual) | set(manifest) if actual.get(k) != manifest.get(k))
        raise SystemExit('FAIL: runtime differs: ' + ', '.join(bad))
    digest = tree_hash(payload).hex()
    if digest != '7e5cb554bf867b9c7cb27b21787f26317be6d113':
        raise SystemExit('FAIL: unexpected runtime tree ' + digest)
    print('PASS: 35 exact LT9 files; runtime tree ' + digest)


if __name__ == '__main__':
    main()
