#!/usr/bin/env python3
"""Verify an unsigned public Coconut IPA against the tagged source catalog."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()

    source_catalog = Path(__file__).resolve().parents[1] / "App/BundledCatalog"
    with tempfile.TemporaryDirectory(prefix="coconut-public-ipa-") as temporary:
        with zipfile.ZipFile(args.ipa) as archive:
            assert archive.testzip() is None, "IPA ZIP CRC failed"
            names = archive.namelist()
            assert all(not Path(name).is_absolute() and ".." not in Path(name).parts for name in names)
            assert any(name.startswith("Payload/CoconutLab.app/") for name in names)
            assert not any(name.startswith("__MACOSX/") for name in names)
            archive.extractall(temporary)

        app = Path(temporary) / "Payload/CoconutLab.app"
        assert app.is_dir()
        info = plistlib.loads((app / "Info.plist").read_bytes())
        assert info["CFBundleShortVersionString"] == args.version
        assert info["CFBundleVersion"] == args.build
        assert info["CFBundleIdentifier"] == "dev.leonardobaptiste.coconut.lab"
        assert info["MinimumOSVersion"] == "17.0"
        assert info["UIRequiredDeviceCapabilities"] == ["arm64e"]
        assert info["CFBundleDevelopmentRegion"] == "en"
        assert not list(app.rglob("embedded.mobileprovision"))
        assert not list(app.rglob("_CodeSignature"))
        assert not list(app.rglob("*.tendies"))
        assert not list(app.rglob("*.mp4"))
        assert not list(app.rglob("*private*"))
        for language in ("en", "es"):
            assert (app / f"{language}.lproj/Localizable.strings").is_file()
        for notice in ("AGPL-3.0.txt", "GPL-3.0.txt", "ZIPFoundation-MIT.txt"):
            assert (app / notice).is_file()

        catalog = app / "BundledCatalog"
        assert {p.name for p in catalog.iterdir()} == {p.name for p in source_catalog.iterdir()}
        for path in source_catalog.iterdir():
            assert (catalog / path.name).read_bytes() == path.read_bytes(), path.name
        themes = json.loads((catalog / "catalog.json").read_text())["themes"]
        assert len(themes) == len({theme["id"] for theme in themes})
        for theme in themes:
            assert (catalog / theme["previewURL"]).is_file(), theme["id"]
            assert all(theme[key].startswith("https://") for key in ("packageURL", "fullResolutionPreviewURL"))
            assert theme.get("previewVideoURL", "").startswith("https://"), theme["id"]

        signature = subprocess.run(["codesign", "-dv", str(app)], capture_output=True, text=True)
        assert signature.returncode != 0 and "not signed" in signature.stderr.lower(), signature.stderr
        architectures = subprocess.check_output(["lipo", "-archs", str(app / "CoconutLab")], text=True).split()
        assert architectures == ["arm64e"], architectures

    result = {
        "ipa": args.ipa.name,
        "version": args.version,
        "build": args.build,
        "bundleID": info["CFBundleIdentifier"],
        "sizeBytes": args.ipa.stat().st_size,
        "sha256": hashlib.sha256(args.ipa.read_bytes()).hexdigest(),
        "architectures": architectures,
        "bundledThemes": len(themes),
        "bundledCatalogSHA256": hashlib.sha256((source_catalog / "catalog.json").read_bytes()).hexdigest(),
        "bundledPackages": 0,
        "bundledVideos": 0,
        "signed": False,
        "provisioningProfile": False,
        "deviceInstallationTested": False,
        "checkedAtUTC": datetime.now(timezone.utc).isoformat(),
    }
    output = args.ipa.parent / "unsigned-verification.json"
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
