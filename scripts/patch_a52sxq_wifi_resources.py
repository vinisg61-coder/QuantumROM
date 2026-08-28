#!/usr/bin/env python3
"""Build and install the A52s Wi-Fi resource overlay.

The overlay is intentionally target-specific. It uses the actual Wi-Fi resource
APK shipped by the donor APEX as the aapt2 link reference, so resource IDs and
package names are not guessed. It never modifies vendor, odm, kernel, boot or
dtbo. If the donor layout is not understood, it fails closed.
"""
from __future__ import annotations

import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], *, cwd: Path | None = None, capture: bool = False) -> str:
    print("[A52SXQ-WIFI-RRO]", " ".join(cmd))
    result = subprocess.run(cmd, cwd=cwd, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else ""


def first_existing(paths: list[Path]) -> Path | None:
    for path in paths:
        if path.is_file():
            return path
    return None


def main() -> int:
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <EXTRACTED_FIRM_DIR> <STOCK_DEVICE> <APKTOOL> <WORK_DIR>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    device = sys.argv[2]
    apktool = Path(sys.argv[3]).resolve()
    work = Path(sys.argv[4]).resolve() / "a52sxq-wifi-rro"
    source = Path(__file__).resolve().parents[1] / "QuantumROM" / "Devices" / "SM-A528B" / "wifi_overlay"
    if device != "SM-A528B":
        print(f"[A52SXQ-WIFI-RRO] skip: device={device}")
        return 0
    if not source.is_dir() or not (source / "AndroidManifest.xml").is_file():
        raise SystemExit("[A52SXQ-WIFI-RRO] missing overlay source")
    if not (source / "res" / "values" / "config.xml").is_file():
        raise SystemExit("[A52SXQ-WIFI-RRO] missing overlay resources")

    apex_dirs = [root / "system" / "system" / "apex", root / "system" / "apex"]
    apexes: list[Path] = []
    for directory in apex_dirs:
        apexes.extend(sorted(directory.glob("com.android.wifi*.apex")))
        apexes.extend(sorted(directory.glob("com.google.android.wifi*.apex")))
    if not apexes:
        raise SystemExit("[A52SXQ-WIFI-RRO] Wi-Fi APEX not found; refusing silent no-op")

    seven = shutil.which("7z") or shutil.which("7zz") or shutil.which("7zr")
    debugfs = shutil.which("debugfs")
    if not seven or not debugfs:
        raise SystemExit("[A52SXQ-WIFI-RRO] 7z/7zz and debugfs are required")
    aapt2 = work / "aapt2"
    work.mkdir(parents=True, exist_ok=True)
    if not aapt2.exists():
        with aapt2.open("wb") as out:
            subprocess.run(["unzip", "-p", str(apktool), "prebuilt/linux/aapt2"], check=True, stdout=out)
        aapt2.chmod(0o755)

    target_apk: Path | None = None
    for index, apex in enumerate(apexes):
        payload = work / f"payload-{index}.img"
        apex_work = work / f"apex-{index}"
        apex_work.mkdir(exist_ok=True)
        try:
            run([seven, "e", "-y", str(apex), "apex_payload.img", f"-o{apex_work}"])
        except subprocess.CalledProcessError:
            continue
        payload = apex_work / "apex_payload.img"
        if not payload.is_file():
            continue
        for internal in (
            "/app/ServiceWifiResourcesGoogle.apk",
            "/app/ServiceWifiResources.apk",
            "/app/WifiResourcesGoogle.apk",
            "/app/WifiResources.apk",
            "/etc/permissions/ServiceWifiResourcesGoogle.apk",
        ):
            candidate = apex_work / (internal.strip("/").replace("/", "_"))
            try:
                run([debugfs, "-R", f"dump {internal} {candidate}", str(payload)])
            except subprocess.CalledProcessError:
                continue
            if candidate.is_file() and candidate.stat().st_size > 0:
                target_apk = candidate
                break
        if target_apk:
            break
    if not target_apk:
        raise SystemExit("[A52SXQ-WIFI-RRO] Wi-Fi Resource APK not found inside donor APEX")

    package_name = run([str(aapt2), "dump", "packagename", str(target_apk)], capture=True)
    if package_name not in {"com.google.android.wifi.resources", "com.android.wifi.resources"}:
        raise SystemExit(f"[A52SXQ-WIFI-RRO] unexpected target package: {package_name}")
    manifest = source / "AndroidManifest.xml"
    manifest_text = manifest.read_text(encoding="utf-8")
    if f'android:targetPackage="{package_name}"' not in manifest_text:
        raise SystemExit(f"[A52SXQ-WIFI-RRO] manifest target does not match {package_name}")

    compiled = work / "compiled.zip"
    overlay_apk = work / "A52sWifiResourcesOverlay.apk"
    run([str(aapt2), "compile", "--dir", str(source / "res"), "-o", str(compiled)])
    run([str(aapt2), "link", "--auto-add-overlay", "--manifest", str(manifest),
         "--min-sdk-version", "30", "--target-sdk-version", "30",
         "-I", str(target_apk), "-o", str(overlay_apk), str(compiled)])
    destination = root / "product" / "overlay"
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(overlay_apk, destination / "A52sWifiResourcesOverlay.apk")
    print(f"[A52SXQ-WIFI-RRO] installed package={package_name} path={destination / 'A52sWifiResourcesOverlay.apk'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(f"[A52SXQ-WIFI-RRO] command failed with exit={exc.returncode}", file=sys.stderr)
        raise
