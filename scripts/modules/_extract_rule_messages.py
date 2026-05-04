#!/usr/bin/env python3
"""
Extract all Saropa lint rules and their messages from *_rules.dart files.

- Finds all LintCode definitions in *_rules.dart files
- Outputs a JSON array of objects with: name, problemMessage, correctionMessage, errorSeverity, file

Usage: python scripts/extract_rule_messages.py
"""
import json
from pathlib import Path
from datetime import datetime

# Three .parents up: scripts/modules/_extract_rule_messages.py → scripts/modules/
# → scripts/ → repo root. The script lived at scripts/extract_rule_messages.py
# originally (two .parents was correct then); after moving into modules/ the
# path was never updated, so SRC_DIR resolved to scripts/lib/src/rules (missing)
# and the rglob below silently returned zero files.
_REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = _REPO_ROOT / "lib" / "src" / "rules"
# Directory creation moved into the `__main__` guard below so importing
# this module does not eagerly mkdir `reports/`.
REPORTS_DIR = _REPO_ROOT / "reports"



def extract_lintcodes_from_file(file_path):
    import re
    results = []
    with open(file_path, encoding="utf-8") as f:
        lines = f.readlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if "LintCode(" in line:
            block = []
            paren_count = line.count('(') - line.count(')')
            block.append(line)
            i += 1
            # Capture the full LintCode block (handle nested parens)
            while i < len(lines) and paren_count > 0:
                block.append(lines[i])
                paren_count += lines[i].count('(') - lines[i].count(')')
                i += 1
            block_text = "".join(block)
            # Extract fields, tolerant of order and multiline
            def extract_multiline(field, text):
                m = re.search(rf"{field}: *(['\"])(.*?)\1", text, re.DOTALL)
                if m:
                    return m.group(2).replace("\n", " ").strip()
                return None
            def extract_severity(text):
                m = re.search(r"errorSeverity: *([A-Za-z0-9_.]+)", text)
                return m.group(1) if m else None
            name = extract_multiline("name", block_text)
            problem = extract_multiline("problemMessage", block_text)
            correction = extract_multiline("correctionMessage", block_text)
            severity = extract_severity(block_text)
            results.append({
                "name": name,
                "problemMessage": problem,
                "correctionMessage": correction,
                "errorSeverity": severity,
                "file": Path(file_path).name
            })
        else:
            i += 1
    return results

# Guard the CLI body so importing this module (e.g. from tests asserting
# the SRC_DIR path) does not write a JSON dump to `reports/` as a side
# effect. The script is still runnable directly via `python -m` or
# `python scripts/modules/_extract_rule_messages.py`.
if __name__ == "__main__":
    REPORTS_DIR.mkdir(exist_ok=True)
    all_results = []
    # Recurse — rule files live under nested category dirs (widget/, packages/,
    # platforms/, …). A flat `glob("*_rules.dart")` only matched `all_rules.dart`
    # (the barrel export, zero LintCodes) and produced an empty JSON dump.
    # Skip the barrel explicitly to mirror _audit_dx.extract_rule_messages.
    for file in sorted(SRC_DIR.rglob("*_rules.dart")):
        if file.name == "all_rules.dart":
            continue
        all_results.extend(extract_lintcodes_from_file(file))

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = REPORTS_DIR / f"all_rule_messages_{timestamp}.json"
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False)

    print(f"Extracted {len(all_results)} rules to {out_path}")
