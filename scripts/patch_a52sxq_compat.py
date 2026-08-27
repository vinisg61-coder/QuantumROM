#!/usr/bin/env python3
"""Apply SM-A528B userspace compatibility fixes to an extracted firmware tree.

The A52s stock 5.4 kernel does not expose the out-of-tree schedtune cgroup
controller used by some newer donor profiles.  Android init treats that
controller as mandatory when it is not marked optional, which can prevent
apexd-bootstrap from creating its process group and cause an intentional
reboot.  This helper applies the smallest upstream-aligned change:

* mark a donor schedtune cgroup entry optional;
* redirect schedtune JoinCgroup actions to the existing cpu controller;
* map STunePreferIdle to UClampLatencySensitive when available and drop the
  obsolete STuneBoost/STunePreferIdle attributes/actions otherwise;
* install the target vendor cgroups override when no vendor file exists.

It is intentionally limited to SM-A528B/a52sxq and never touches kernel or
native vendor binaries.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


DEVICE_NAMES = {"SM-A528B", "a52sxq"}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def save_json(path: Path, data: Any) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False)
        stream.write("\n")


def patch_cgroups(data: Any) -> bool:
    changed = False
    if not isinstance(data, dict):
        return False
    entries = data.get("Cgroups", [])
    if isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, dict) and entry.get("Controller") == "schedtune":
                if entry.get("Optional") is not True:
                    entry["Optional"] = True
                    changed = True
    return changed


def patch_task_profiles(data: Any) -> bool:
    if not isinstance(data, dict):
        return False

    changed = False
    attributes = data.get("Attributes", [])
    has_uclamp_latency = any(
        isinstance(attr, dict) and attr.get("Name") == "UClampLatencySensitive"
        for attr in attributes
    ) if isinstance(attributes, list) else False

    if isinstance(attributes, list):
        kept_attributes = []
        for attr in attributes:
            if not isinstance(attr, dict):
                kept_attributes.append(attr)
                continue
            if attr.get("Controller") == "schedtune" or attr.get("Name") in {
                "STuneBoost",
                "STunePreferIdle",
            }:
                changed = True
                continue
            kept_attributes.append(attr)
        data["Attributes"] = kept_attributes

    profiles = data.get("Profiles", [])
    if isinstance(profiles, list):
        for profile in profiles:
            if not isinstance(profile, dict):
                continue
            actions = profile.get("Actions", [])
            if not isinstance(actions, list):
                continue
            kept_actions = []
            for action in actions:
                if not isinstance(action, dict):
                    kept_actions.append(action)
                    continue
                name = action.get("Name")
                params = action.get("Params")
                if not isinstance(params, dict):
                    kept_actions.append(action)
                    continue

                if name == "JoinCgroup" and params.get("Controller") == "schedtune":
                    params["Controller"] = "cpu"
                    changed = True

                if name == "SetAttribute" and params.get("Name") == "STunePreferIdle":
                    if has_uclamp_latency:
                        params["Name"] = "UClampLatencySensitive"
                        changed = True
                    else:
                        changed = True
                        continue

                if name == "SetAttribute" and params.get("Name") == "STuneBoost":
                    changed = True
                    continue

                kept_actions.append(action)
            profile["Actions"] = kept_actions

    return changed


def candidate_files(root: Path) -> tuple[list[Path], list[Path]]:
    cgroup_files = [
        root / "system" / "system" / "etc" / "task_profiles" / "cgroups.json",
        root / "system" / "etc" / "task_profiles" / "cgroups.json",
        root / "vendor" / "etc" / "cgroups.json",
    ]
    cgroup_files += sorted(root.glob("system/system/etc/task_profiles/cgroups_*.json"))
    cgroup_files += sorted(root.glob("system/etc/task_profiles/cgroups_*.json"))

    task_files = [
        root / "system" / "system" / "etc" / "task_profiles" / "task_profiles.json",
        root / "system" / "etc" / "task_profiles" / "task_profiles.json",
        root / "vendor" / "etc" / "task_profiles.json",
    ]
    task_files += sorted(root.glob("system/system/etc/task_profiles/task_profiles_*.json"))
    task_files += sorted(root.glob("system/etc/task_profiles/task_profiles_*.json"))
    return cgroup_files, task_files


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <EXTRACTED_FIRMWARE_DIR> <STOCK_DEVICE>", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    device = sys.argv[2]
    if device not in DEVICE_NAMES:
        print(f"[A52SXQ-CGROUPS] skipped for {device}")
        return 0
    if not root.is_dir():
        print(f"[A52SXQ-CGROUPS] extracted firmware directory not found: {root}", file=sys.stderr)
        return 1

    cgroup_files, task_files = candidate_files(root)
    changed_cgroups = 0
    changed_tasks = 0

    for path in cgroup_files:
        if not path.is_file():
            continue
        try:
            data = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"[A52SXQ-CGROUPS] cannot parse {path}: {exc}", file=sys.stderr)
            return 1
        if patch_cgroups(data):
            save_json(path, data)
            changed_cgroups += 1
            print(f"[A52SXQ-CGROUPS] marked schedtune optional: {path}")

    for path in task_files:
        if not path.is_file():
            continue
        try:
            data = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"[A52SXQ-CGROUPS] cannot parse {path}: {exc}", file=sys.stderr)
            return 1
        if patch_task_profiles(data):
            save_json(path, data)
            changed_tasks += 1
            print(f"[A52SXQ-CGROUPS] removed/redirected schedtune profiles: {path}")

    vendor_override = root / "vendor" / "etc" / "cgroups.json"
    if not vendor_override.exists():
        vendor_override.parent.mkdir(parents=True, exist_ok=True)
        save_json(
            vendor_override,
            {
                "Cgroups": [
                    {
                        "Controller": "schedtune",
                        "Path": "/dev/stune",
                        "Mode": "0755",
                        "UID": "system",
                        "GID": "system",
                        "Optional": True,
                    }
                ]
            },
        )
        print(f"[A52SXQ-CGROUPS] installed vendor override: {vendor_override}")
    elif vendor_override not in cgroup_files:
        print(f"[A52SXQ-CGROUPS] vendor cgroups override already present: {vendor_override}")

    print(
        f"[A52SXQ-CGROUPS] complete: cgroups_files_changed={changed_cgroups}, "
        f"task_profile_files_changed={changed_tasks}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
