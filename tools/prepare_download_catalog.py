#!/usr/bin/env python3
"""Build a thumbnail-only app catalog and an HTTPS catalog from validated local assets."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import quote, urlparse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--destination', required=True, type=Path)
    parser.add_argument('--remote-catalog', required=True, type=Path)
    parser.add_argument('--base-url', required=True)
    args = parser.parse_args()
    if urlparse(args.base_url).scheme != 'https':
        raise SystemExit('Download assets require HTTPS.')
    if args.destination.exists():
        raise SystemExit('Use a new output directory; existing assets are never overwritten.')
    themes = json.loads((args.source / 'catalog.json').read_text())['themes']
    # Validate all artifacts before preparing the lightweight catalog.
    for theme in themes:
        package = args.source / theme['packageURL']
        if hashlib.sha256(package.read_bytes()).hexdigest() != theme['sha256']:
            raise SystemExit('Package changed: ' + theme['id'])
        for key in ['previewURL', 'previewVideoURL']:
            if not (args.source / theme[key]).is_file():
                raise SystemExit('Missing asset: ' + theme[key])
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries',
            'format=duration:stream=width,height', '-of', 'json', str(args.source / theme['previewVideoURL'])]))
        if float(probe['format']['duration']) < 2.9:
            raise SystemExit('Incomplete reference video: ' + theme['id'])
    args.destination.mkdir(parents=True)
    local, remote = [], []
    for theme in themes:
        thumbnail = args.destination / theme['previewURL']
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(args.source / theme['previewURL']),
                        '-vf', 'scale=390:-2', '-frames:v', '1', '-q:v', '5', str(thumbnail)], check=True)
        online = dict(theme)
        for key in ['packageURL', 'previewURL', 'previewVideoURL']:
            online[key] = args.base_url.rstrip('/') + '/' + quote(theme[key])
        bundled = dict(online, previewURL=thumbnail.name)
        bundled['fullResolutionPreviewURL'] = online['previewURL']
        local.append(bundled)
        remote.append(online)
    for path, entries in [(args.destination / 'catalog.json', local), (args.remote_catalog, remote)]:
        path.write_text(json.dumps({'themes': entries}, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'themes': len(local), 'bundledBytes': sum(p.stat().st_size for p in args.destination.iterdir()),
                      'bundledPackages': len(list(args.destination.glob('*.tendies'))),
                      'bundledVideos': len(list(args.destination.glob('*.mp4')))}, indent=2))


if __name__ == '__main__':
    main()
