#!/usr/bin/env python3
"""Verify the exported lightweight Coconut IPA without installing it."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / 'App/BundledCatalog'
    with tempfile.TemporaryDirectory(prefix='coconut-ipa-verification-') as temporary:
        with zipfile.ZipFile(args.ipa) as archive:
            assert archive.testzip() is None
            for entry in archive.namelist():
                assert not Path(entry).is_absolute() and '..' not in Path(entry).parts
            archive.extractall(temporary)
        app = Path(temporary) / 'Payload/CoconutLab.app'
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        assert info['CFBundleShortVersionString'] == '0.6.23'
        assert info['CFBundleVersion'] == '33'
        assert not list(app.rglob('*private*')), 'Private setup resources must not be bundled'
        assert info['CFBundleIdentifier'] == 'dev.leonardobaptiste.coconut.lab'
        assert info['CFBundleDevelopmentRegion'] == 'en'
        for code in ['en', 'es']:
            assert (app / f'{code}.lproj/Localizable.strings').exists()
        catalog = app / 'BundledCatalog'
        themes = json.loads((catalog / 'catalog.json').read_text())['themes']
        expected = json.loads((source / 'catalog.json').read_text())['themes']
        assert len(themes) == len(expected)
        assert len({t['id'] for t in themes}) == len(themes)
        assert not list(app.rglob('*.tendies')), 'A test fixture or wallpaper leaked into the app'
        assert not list(app.rglob('*.mp4')), 'Reference videos must stay remote'
        assert {p.name for p in catalog.iterdir()} == {p.name for p in source.iterdir()}
        for path in catalog.iterdir():
            assert path.read_bytes() == (source / path.name).read_bytes(), path.name
        for theme in themes:
            assert (catalog / theme['previewURL']).exists()
            for key in ['packageURL', 'fullResolutionPreviewURL']:
                assert theme[key].startswith('https://')
            assert theme.get('previewVideoURL', '').startswith('https://'), f'Missing motion preview: {theme["id"]}'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)
        profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')], stderr=subprocess.DEVNULL))
        assert profile['ExpirationDate'] > datetime.now(timezone.utc).replace(tzinfo=None)
        assert profile['Entitlements']['application-identifier'].endswith('.' + info['CFBundleIdentifier'])
        sha = hashlib.sha256(args.ipa.read_bytes()).hexdigest()
        result = dict(ipa=args.ipa.name, version=info['CFBundleShortVersionString'], build=info['CFBundleVersion'],
                      sizeBytes=args.ipa.stat().st_size, sha256=sha, bundledThemes=len(themes),
                      bundledBytes=sum(p.stat().st_size for p in catalog.iterdir()), bundledPackages=0, bundledVideos=0,
                      signatureVerified=True, profileExpiresUTC=profile['ExpirationDate'].isoformat() + 'Z',
                      provisionedDevices=len(profile.get('ProvisionedDevices', [])), deviceInstallationTested=False)
        (args.ipa.parent / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
        (args.ipa.parent / 'SHA256SUMS.txt').write_text(f'{sha}  {args.ipa.name}\n')
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
