#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Render local CAML artwork without simulator UI. Does not modify .tendies archives.

Build tools/GalleryRenderer for the simulator, install it, then pass --simulator UUID.
Uses UIKit/Core Animation to represent the real layered composition, not an AI image.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'dev.leonardobaptiste.coconut.cleanrender'

def sim(identifier, *args, **kwargs):
    return subprocess.run(['xcrun', 'simctl', *args[:1], identifier, *args[1:]], **kwargs)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--seconds', type=float, default=4)
    parser.add_argument('--themes', nargs='*')
    parser.add_argument('--width', type=int, default=780)
    parser.add_argument('--fast', action='store_true')
    parser.add_argument('--folder', type=Path, default=ROOT / 'App/BundledCatalog')
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--batch', action='store_true')
    parser.add_argument('--stills-only', action='store_true')
    args = parser.parse_args()
    folder = args.folder.resolve()
    themes = json.loads((folder / 'catalog.json').read_text())['themes']
    if args.themes: themes = [t for t in themes if t['id'] in args.themes]
    if args.batch:
        with tempfile.TemporaryDirectory(prefix='coconut-gallery-batch-') as temporary:
            entries = []
            for theme in themes:
                target = Path(temporary) / theme['id']
                with zipfile.ZipFile(folder / theme['packageURL']) as archive:
                    for entry in archive.infolist():
                        if Path(entry.filename).is_absolute() or '..' in Path(entry.filename).parts:
                            raise ValueError('Unsafe package path')
                    archive.extractall(target)
                image = folder / (theme['id'] + '-artwork.jpg')
                video = folder / (theme['id'] + '-motion.mp4')
                for old in [image, Path(str(image) + '.done')]: old.unlink(missing_ok=True)
                if not args.stills_only:
                    for old in [video, Path(str(video) + '.done')]: old.unlink(missing_ok=True)
                entries.append(dict(wallpaper=str(next(target.rglob('*.wallpaper'))), image=str(image), video=str(video)))
            manifest = Path(temporary) / 'batch.json'
            manifest.write_text(json.dumps(entries))
            sim(args.simulator, 'terminate', BUNDLE, capture_output=True)
            env = dict(os.environ, SIMCTL_CHILD_WALL_BATCH_JSON=str(manifest), SIMCTL_CHILD_WALL_CLEAN='1',
                       SIMCTL_CHILD_WALL_STATIC='1', SIMCTL_CHILD_WALL_SECONDS=str(args.seconds), SIMCTL_CHILD_WALL_EXPORT_WIDTH=str(args.width),
                       SIMCTL_CHILD_WALL_STILLS_ONLY='1' if args.stills_only else '0',
                       SIMCTL_CHILD_WALL_FAST='1' if args.fast else '0')
            sim(args.simulator, 'launch', BUNDLE, env=env, check=True, stdout=subprocess.DEVNULL)
            try:
                for index, entry in enumerate(entries):
                    done = Path(entry['image' if args.stills_only else 'video'] + '.done')
                    deadline = time.monotonic() + 180
                    while not done.is_file():
                        if time.monotonic() >= deadline: raise RuntimeError('Missing batch export: ' + themes[index]['id'])
                        time.sleep(0.2)
                    done.unlink()
                    print(f'{index + 1}/{len(entries)} {themes[index]["name"]}: clean artwork' + ('' if args.stills_only else ' + motion'), flush=True)
            finally:
                sim(args.simulator, 'terminate', BUNDLE, capture_output=True)
        return
    with tempfile.TemporaryDirectory(prefix='coconut-gallery-render-') as temporary:
        for index, theme in enumerate(themes):
            if args.resume and (folder / (theme['id'] + '-artwork.jpg')).is_file() and (folder / (theme['id'] + '-motion.mp4')).is_file() and not (folder / (theme['id'] + '-motion.mp4.done')).exists():
                continue
            target = Path(temporary) / theme['id']
            with zipfile.ZipFile(folder / theme['packageURL']) as archive:
                for entry in archive.infolist():
                    if Path(entry.filename).is_absolute() or '..' in Path(entry.filename).parts:
                        raise ValueError('Unsafe package path')
                archive.extractall(target)
            wallpaper = next(target.rglob('*.wallpaper'))
            sim(args.simulator, 'terminate', BUNDLE, capture_output=True)
            image = folder / (theme['id'] + '-artwork.jpg')
            image.unlink(missing_ok=True)
            video = folder / (theme['id'] + '-motion.mp4')
            done = Path(str(video) + '.done')
            done.unlink(missing_ok=True)
            video.unlink(missing_ok=True)
            env = dict(os.environ, SIMCTL_CHILD_WALL_DIR=str(wallpaper), SIMCTL_CHILD_WALL_CLEAN='1',
                       SIMCTL_CHILD_WALL_STATIC='1', SIMCTL_CHILD_WALL_OUTPUT=str(image),
                       SIMCTL_CHILD_WALL_VIDEO=str(video), SIMCTL_CHILD_WALL_SECONDS=str(args.seconds), SIMCTL_CHILD_WALL_EXPORT_WIDTH=str(args.width),
                       SIMCTL_CHILD_WALL_FAST='1' if args.fast else '0')
            sim(args.simulator, 'launch', BUNDLE, env=env, check=True, stdout=subprocess.DEVNULL)
            deadline = time.monotonic() + 45
            while not done.is_file():
                if time.monotonic() >= deadline: raise RuntimeError('Missing clean export: ' + theme['id'])
                time.sleep(0.2)
            done.unlink()
            print(f'{index + 1}/{len(themes)} {theme["name"]}: clean artwork + motion', flush=True)
    sim(args.simulator, 'terminate', BUNDLE, capture_output=True)

if __name__ == '__main__': main()
