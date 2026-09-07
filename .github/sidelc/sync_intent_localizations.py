#!/usr/bin/env python3
"""Copy the localization tables used by the embedded SideStore intents."""

import argparse
import json
import plistlib
import subprocess
from pathlib import Path


def read_strings(path):
    if not path.exists():
        return {}
    return plistlib.loads(subprocess.check_output(
        ["plutil", "-convert", "binary1", "-o", "-", str(path)]
    ))


def resource_keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in {"key", "formatString"} and isinstance(child, str):
                yield child
            else:
                yield from resource_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from resource_keys(child)


def sync(host, verify_only=False):
    source = host / "Frameworks/SideStoreApp.framework"
    metadata = json.loads((host / "Metadata.appintents/extract.actionsdata").read_text())
    # Dialog strings are emitted at runtime and may not appear in actionsdata.
    keys = set(resource_keys(metadata.get("actions", {}))) | {"All apps have been refreshed."}
    for shortcut in metadata.get("autoShortcuts", []):
        keys.update(resource_keys(shortcut.get("shortTitle", {})))
    for localization in source.glob("*.lproj"):
        translations = read_strings(localization / "Localizable.strings")
        tables = {
            "Localizable": {key: translations[key] for key in keys if key in translations},
            **{name: read_strings(localization / (name + ".strings"))
               for name in ("AppShortcuts", "Intents", "ViewApp")},
        }
        for name, entries in tables.items():
            if not entries:
                continue
            destination = host / localization.name / (name + ".strings")
            existing = read_strings(destination)
            if not verify_only:
                # Merge only intent keys; preserve all unrelated host translations.
                existing.update(entries)
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(plistlib.dumps(existing, fmt=plistlib.FMT_BINARY))
            for key, value in entries.items():
                if existing.get(key) != value:
                    raise ValueError(f"Missing intent translation: {destination}: {key}")

    required = {
        "Localizable": keys,
        "AppShortcuts": {phrase["key"] for shortcut in metadata.get("autoShortcuts", [])
                         for phrase in shortcut.get("phraseTemplates", [])},
        "Intents": {"2b6Xto", "62S1rm", "cJxa2I", "DKTGdO", "3WMWsJ", "BjInD3"},
        "ViewApp": {"7aGoWn", "sb9c7F", "QwLCXY", "cUl1NZ"},
    }
    for name, required_keys in required.items():
        table = read_strings(host / "zh-Hans.lproj" / (name + ".strings"))
        for key in required_keys:
            if key and (not table.get(key) or table[key] == key):
                raise ValueError(f"Missing Simplified Chinese intent translation: {name}: {key}")
    settings = read_strings(source / "zh-Hans.lproj/Localizable.strings")
    for key in ("Wipe Database on Next Start", "Wireless Pairing", "Ready to pair",
                "Start Pairing Server", "Select Device To Pair", "Select Server Interface"):
        if not settings.get(key) or settings[key] == key:
            raise ValueError(f"Missing embedded SideStore translation: {key}")
    launch_extension = host / "PlugIns/LaunchAppExtension.appex"
    launch_metadata = json.loads((launch_extension / "Metadata.appintents/extract.actionsdata").read_text())
    launch_strings = read_strings(launch_extension / "zh-Hans.lproj/Localizable.strings")
    for key in resource_keys(launch_metadata.get("actions", {})):
        if key and (not launch_strings.get(key) or launch_strings[key] == key):
            raise ValueError(f"Missing Launch App shortcut translation: {key}")
    print("Packaged SideStore intent and settings localizations verified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    sync(args.host, args.verify_only)
