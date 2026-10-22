#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Original synthetic ZIP inputs. These are NOT valid visual wallpapers."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_STORED
import stat

ROOT = Path(__file__).resolve().parents[1] / "Tests/WallpaperPackageManagerTests/Fixtures"
ROOT.mkdir(parents=True, exist_ok=True)
marker = "descriptor/TEST-ONLY/com.apple.posterkit.provider.descriptor.identifier"
base = [(marker, b"10001"), ("descriptor/TEST-ONLY/versions/1/contents/TEST-ONLY.txt",
                                b"Synthetic Coconut test. No visual assets. Never install.")]

def write(name, entries):
    with ZipFile(ROOT / (name + ".tendies"), "w", compression=ZIP_STORED) as archive:
        for path, contents in entries:
            info = ZipInfo(path, date_time=(2026, 10, 16, 0, 0, 0))
            archive.writestr(info, contents)

write("synthetic-descriptor", base)
write("synthetic-video", [(p.replace("descriptor/", "video-descriptor/", 1), d) for p, d in base])
write("traversal", base + [("../escape", b"no")])
write("absolute", base + [("/tmp/escape", b"no")])
write("backslash", base + [("descriptor\\escape", b"no")])
write("case-collision", base + [(marker.upper(), b"10002")])
write("file-parent", base + [("parent", b"x"), ("parent/child", b"x")])
write("container", [("container/Library/test", b"x")])
write("incomplete", [(marker, b"10001")])
write("multiple", base + [(p.replace("TEST-ONLY/", "OTHER/"), d) for p, d in base])
write("empty", [])
link = ZipInfo("descriptor/TEST-ONLY/link")
link.create_system = 3
link.external_attr = (stat.S_IFLNK | 0o777) << 16
write("symlink", base)
with ZipFile(ROOT / "symlink.tendies", "a") as archive:
    archive.writestr(link, "/tmp/escape")
data = (ROOT / "synthetic-descriptor.tendies").read_bytes()
assert b"10001" in data
(ROOT / "bad-crc.tendies").write_bytes(data.replace(b"10001", b"99999", 1))
(ROOT / "not-zip.tendies").write_bytes(b"Not a ZIP")
print("Synthetic fixtures generated in", ROOT)
