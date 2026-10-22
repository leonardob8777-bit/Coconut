#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only desktop helper. Requires pymobiledevice3 11.33.1 on macOS.

Uses the existing paired native tunnel. Never installs, restores, writes to
the device, pairs it again, or transfers files into an iPhone application.
The output is a PRIVATE build resource, not for a public repository.
"""
import argparse
import asyncio
import json
from pathlib import Path
import uuid


async def read_uuid(udid, output):
    from pymobiledevice3.remote.native_tunnel import NativeRemotedTunnel
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    async with NativeRemotedTunnel(serial=udid) as rsd:
        async with InstallationProxyService(rsd) as proxy:
            apps = await proxy.get_apps(application_type="Any", bundle_identifiers=["com.apple.PosterBoard"])
        container = apps.get("com.apple.PosterBoard", {}).get("Container")
        if not container or not rsd.product_type:
            raise RuntimeError("El servicio no devolvió el contenedor de PosterBoard o el modelo.")
        value = str(uuid.UUID(container.rstrip("/").split("/")[-1])).upper()
        output.write_text(json.dumps({"productType": rsd.product_type, "posterBoardUUID": value}, indent=2) + "\n")
        print("UUID de PosterBoard validado y guardado localmente. No se escribió en el dispositivo.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--output", type=Path, default=Path("App/InstallerBootstrap-private.json"))
    arguments = parser.parse_args()
    asyncio.run(asyncio.wait_for(read_uuid(arguments.udid, arguments.output), timeout=35))
