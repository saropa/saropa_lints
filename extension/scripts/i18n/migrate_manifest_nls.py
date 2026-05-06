#!/usr/bin/env python3
"""Migrate localizable package.json strings to package.nls keys."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PACKAGE_JSON = ROOT / "package.json"
PACKAGE_NLS = ROOT / "package.nls.json"


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def is_key_ref(value: str) -> bool:
    return value.startswith("%") and value.endswith("%")


def slug(value: str) -> str:
    value = value.replace("saropaLints.", "")
    value = re.sub(r"[^a-zA-Z0-9]+", ".", value)
    value = re.sub(r"\.+", ".", value).strip(".")
    return value or "value"


class KeyStore:
    def __init__(self, nls: dict[str, str]) -> None:
        self.nls = nls
        self.reverse: dict[str, str] = {}
        for k, v in nls.items():
            if isinstance(v, str):
                self.reverse.setdefault(v, k)

    def put(self, preferred: str, value: str) -> str:
        existing = self.reverse.get(value)
        if existing:
            return existing
        key = preferred
        i = 2
        while key in self.nls and self.nls[key] != value:
            key = f"{preferred}.{i}"
            i += 1
        self.nls[key] = value
        self.reverse[value] = key
        return key


def localize_field(
    obj: dict[str, Any],
    field: str,
    key: str,
    store: KeyStore,
) -> int:
    value = obj.get(field)
    if not isinstance(value, str) or is_key_ref(value):
        return 0
    final_key = store.put(key, value)
    obj[field] = f"%{final_key}%"
    return 1


def migrate() -> tuple[int, dict[str, Any], dict[str, str]]:
    package = load_json(PACKAGE_JSON)
    nls = load_json(PACKAGE_NLS)
    if not isinstance(nls, dict):
        raise RuntimeError("package.nls.json must be an object")
    store = KeyStore(nls)
    changed = 0

    changed += localize_field(package, "displayName", "extension.displayName", store)
    changed += localize_field(package, "description", "extension.description", store)

    contributes = package.get("contributes")
    if isinstance(contributes, dict):
        views_containers = contributes.get("viewsContainers")
        if isinstance(views_containers, dict):
            activity = views_containers.get("activitybar")
            if isinstance(activity, list):
                for entry in activity:
                    if isinstance(entry, dict):
                        cid = slug(str(entry.get("id", "container")))
                        changed += localize_field(entry, "title", f"viewsContainer.{cid}.title", store)

        views = contributes.get("views")
        if isinstance(views, dict):
            for group_name, entries in views.items():
                if isinstance(entries, list):
                    for entry in entries:
                        if isinstance(entry, dict):
                            vid = slug(str(entry.get("id", f"{group_name}.view")))
                            changed += localize_field(entry, "name", f"view.{vid}.name", store)

        views_welcome = contributes.get("viewsWelcome")
        if isinstance(views_welcome, list):
            for entry in views_welcome:
                if isinstance(entry, dict):
                    view_id = slug(str(entry.get("view", "view")))
                    changed += localize_field(entry, "contents", f"viewsWelcome.{view_id}.contents", store)

        commands = contributes.get("commands")
        if isinstance(commands, list):
            for entry in commands:
                if isinstance(entry, dict):
                    command_id = slug(str(entry.get("command", "command")))
                    changed += localize_field(entry, "title", f"command.{command_id}.title", store)
                    changed += localize_field(entry, "category", f"command.{command_id}.category", store)

        configuration = contributes.get("configuration")
        if isinstance(configuration, list):
            for section in configuration:
                if not isinstance(section, dict):
                    continue
                section_title = section.get("title")
                section_key = slug(str(section_title if isinstance(section_title, str) else "section"))
                changed += localize_field(section, "title", f"config.section.{section_key}.title", store)

                properties = section.get("properties")
                if not isinstance(properties, dict):
                    continue
                for prop_name, prop in properties.items():
                    if not isinstance(prop, dict):
                        continue
                    prop_key = slug(prop_name)
                    changed += localize_field(prop, "description", f"config.property.{prop_key}.description", store)
                    changed += localize_field(
                        prop,
                        "markdownDescription",
                        f"config.property.{prop_key}.markdownDescription",
                        store,
                    )
                    enum_desc = prop.get("enumDescriptions")
                    if isinstance(enum_desc, list):
                        for idx, item in enumerate(enum_desc):
                            if isinstance(item, str) and not is_key_ref(item):
                                k = store.put(
                                    f"config.property.{prop_key}.enumDescription.{idx + 1}",
                                    item,
                                )
                                enum_desc[idx] = f"%{k}%"
                                changed += 1

        walkthroughs = contributes.get("walkthroughs")
        if isinstance(walkthroughs, list):
            for walkthrough in walkthroughs:
                if not isinstance(walkthrough, dict):
                    continue
                wid = slug(str(walkthrough.get("id", "walkthrough")))
                changed += localize_field(walkthrough, "title", f"walkthrough.{wid}.title", store)
                changed += localize_field(walkthrough, "description", f"walkthrough.{wid}.description", store)
                steps = walkthrough.get("steps")
                if isinstance(steps, list):
                    for step in steps:
                        if not isinstance(step, dict):
                            continue
                        sid = slug(str(step.get("id", "step")))
                        changed += localize_field(step, "title", f"walkthrough.step.{sid}.title", store)
                        changed += localize_field(step, "description", f"walkthrough.step.{sid}.description", store)

    return changed, package, store.nls


def main() -> int:
    changed, package, nls = migrate()
    dump_json(PACKAGE_JSON, package)
    dump_json(PACKAGE_NLS, nls)
    print(f"Migrated fields: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

