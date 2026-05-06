#!/usr/bin/env python3
"""Audit localization coverage for extension manifest and dashboards."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PACKAGE_JSON = ROOT / "package.json"
REPORT_PATH = ROOT / "reports" / "i18n_coverage_report.md"
SCANNED_DIRS = [ROOT / "src" / "views", ROOT / "src" / "vibrancy" / "views"]
CODE_GLOB = ("*.ts",)
STRING_RE = re.compile(r"""(?P<q>['"])(?P<t>[^'"\n]{3,})(?P=q)""")


def walk_manifest_strings(node: Any, path: str = "$") -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    if isinstance(node, dict):
        for key, value in node.items():
            child = f"{path}.{key}"
            if key in {"title", "description", "markdownDescription", "name", "contents"} and isinstance(value, str):
                out.append((child, value))
            out.extend(walk_manifest_strings(value, child))
    elif isinstance(node, list):
        for i, value in enumerate(node):
            out.extend(walk_manifest_strings(value, f"{path}[{i}]"))
    return out


def is_nls_ref(value: str) -> bool:
    return value.startswith("%") and value.endswith("%")


def collect_view_strings() -> list[tuple[str, int, str]]:
    findings: list[tuple[str, int, str]] = []
    for base in SCANNED_DIRS:
        if not base.exists():
            continue
        files: list[Path] = []
        for glob in CODE_GLOB:
            files.extend(sorted(base.rglob(glob)))
        for file in files:
            text = file.read_text(encoding="utf-8")
            for i, line in enumerate(text.splitlines(), start=1):
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("*"):
                    continue
                for m in STRING_RE.finditer(line):
                    literal = m.group("t")
                    if literal.startswith("saropaLints.") or literal.startswith("$("):
                        continue
                    findings.append((str(file.relative_to(ROOT)), i, literal))
    return findings


def main() -> int:
    pkg = json.loads(PACKAGE_JSON.read_text(encoding="utf-8"))
    manifest = walk_manifest_strings(pkg)
    inline_manifest = [(p, v) for p, v in manifest if not is_nls_ref(v)]
    view_strings = collect_view_strings()

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    lines.append("# i18n Coverage Audit")
    lines.append("")
    lines.append(f"- Manifest localizable fields scanned: **{len(manifest)}**")
    lines.append(f"- Manifest fields still inline (not `%key%`): **{len(inline_manifest)}**")
    lines.append(f"- Dashboard/view string literals found (heuristic): **{len(view_strings)}**")
    lines.append("")
    lines.append("## Manifest Inline Fields")
    lines.append("")
    if not inline_manifest:
        lines.append("- None")
    else:
        for path, value in inline_manifest[:300]:
            preview = value.replace("\n", "\\n")
            lines.append(f"- `{path}`: `{preview}`")
        if len(inline_manifest) > 300:
            lines.append(f"- ... and {len(inline_manifest) - 300} more")
    lines.append("")
    lines.append("## Dashboard/View Literal Findings")
    lines.append("")
    if not view_strings:
        lines.append("- None")
    else:
        for file, line, value in view_strings[:500]:
            lines.append(f"- `{file}`:{line} -> `{value}`")
        if len(view_strings) > 500:
            lines.append(f"- ... and {len(view_strings) - 500} more")

    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {REPORT_PATH}")
    print(f"inline_manifest={len(inline_manifest)} view_literals={len(view_strings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

