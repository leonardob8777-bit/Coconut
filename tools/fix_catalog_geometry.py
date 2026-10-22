#!/usr/bin/env python3
"""Correct the coordinate-system metadata of the five Coconut-authored packages.

Coconut recipes use top-left coordinates. CAPackage exposes index.xml's
geometryFlipped to the host; UIKit previews previously ignored this flag.
Only index.xml changes. Image bytes and CAML states remain untouched.
"""
import hashlib, json, plistlib, shutil, zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
NAMES = ['arcoiris', 'escalera', 'capibara', 'globos', 'cabana']

def repair(source, destination):
    changed = 0
    with zipfile.ZipFile(source) as old, zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as new:
        for entry in old.infolist():
            data = old.read(entry)
            if entry.filename.endswith('.ca/index.xml'):
                metadata = plistlib.loads(data)
                if metadata['geometryFlipped'] is False:
                    metadata['geometryFlipped'] = True
                    data = plistlib.dumps(metadata, fmt=plistlib.FMT_XML, sort_keys=False)
                    changed += 1
            new.writestr(entry, data)
    return changed

if __name__ == '__main__':
    backup = ROOT / 'build/layout-fix/original-packages'
    backup.mkdir(parents=True, exist_ok=True)
    updates = []
    for name in NAMES:
        source = ROOT / 'preview' / (name + '.tendies')
        original = backup / source.name
        if not original.exists(): shutil.copy2(source, original)
        repaired = source.with_suffix('.corrected.tendies')
        count = repair(original, repaired)
        assert count == 3, (name, count)
        with zipfile.ZipFile(original) as before, zipfile.ZipFile(repaired) as after:
            assert before.namelist() == after.namelist()
            for member in before.namelist():
                if member.endswith('.ca/index.xml'):
                    a, b = plistlib.loads(before.read(member)), plistlib.loads(after.read(member))
                    assert b.pop('geometryFlipped') is True
                    assert a.pop('geometryFlipped') is False
                    assert a == b
                else: assert before.read(member) == after.read(member), member
        repaired.replace(source)
        updates.append({'fileName': source.name,
                        'oldSHA256': hashlib.sha256(original.read_bytes()).hexdigest(),
                        'newSHA256': hashlib.sha256(source.read_bytes()).hexdigest()})
    (ROOT / 'App/BundledPackageUpdates.json').write_text(json.dumps(updates, indent=2)+'\n')
    print('Corrected 15 coordinate declarations; CAML and image bytes unchanged.')
