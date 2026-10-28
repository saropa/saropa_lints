#!/usr/bin/env python3
"""Generate test/aggregate/*_aggregate.dart entry files plus manifest.json.

Merging ~400 test files into ~14 entry files cuts per-file compile overhead.
Output is regenerated from scratch on every run.
"""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEST = ROOT / "test"
OUT = TEST / "aggregate"

# aggregate name -> test dirs (relative to test/). 'split' dirs are halved.
GROUPS = {
    "rules_packages_a": [("rules/packages", 0)],
    "rules_packages_b": [("rules/packages", 1)],
    "rules_widget": [("rules/widget", None)],
    "rules_ui_media": [f"rules/{d}" for d in
                       ("ui", "media", "hardware", "commerce", "network", "resources")],
    "rules_core": [f"rules/{d}" for d in ("core", "flow", "codegen")],
    "rules_code_quality": ["rules/code_quality"],
    "rules_platforms_data": ["rules/platforms", "rules/data"],
    "rules_policy": [f"rules/{d}" for d in
                     ("stylistic", "config", "security", "architecture", "testing")],
    "integrity_a": [("integrity", 0)],
    "integrity_b": [("integrity", 1)],
    "project_health": ["project_health"],
    "report": ["report"],
    "app": ["config", "baseline", "init", "bin", "lsp"],
    "tools": ["scan", "cli", "native"],
    "misc": ["utils", "support", "."],  # '.' = root-level test/*.dart
}
# aggregate -> number of balanced sub-aggregates (name_1.._N), split by WEIGHTS.
SPLIT = {"report": 3, "tools": 2, "integrity_a": 2, "integrity_b": 2}
# Measured seconds for heavy files (others default to 1). Re-measure when stale.
WEIGHTS = {
    "test/scan/scan_cli_args_test.dart": 258,
    "test/report/violation_export_test.dart": 80,
    "test/report/diagnostic_statistics_test.dart": 36,
    "test/report/violation_parser_test.dart": 20,
    "test/integrity/code_line_counting_test.dart": 20,
    "test/integrity/handle_throwing_invocations_metadata_crash_test.dart": 20,
    "test/integrity/no_op_stub_registration_guard_test.dart": 11,
    "test/integrity/fixture_integrity_test.dart": 10,
    "test/integrity/stub_test_guard_test.dart": 26,
    "test/integrity/rule_lane_test.dart": 23,
}
EXCLUDED_DIRS = ("fixtures", "aggregate")
ANNOT = re.compile(r"^@(Tags|TestOn|Timeout|OnPlatform|Skip)", re.M)
IMPORT_TEST = re.compile(
    r"""^\s*(?:import|export)\s+['"][^'"]*_test\.dart['"]""", re.M)
SYNC_MAIN = re.compile(r"^void\s+main\s*\(\s*\)\s*\{", re.M)
TEST_CALL = re.compile(r"\b(?:test|testWidgets)\s*\(")


# file (repo-relative) -> reason; skipped files land in left_out.
R = "fails in shared isolate (resolved-harness state), passes standalone"
SKIP_AGGREGATE = {
    "test/report/progress_tracker_max_issues_test.dart":
        "shares process-global singleton state with earlier report tests; passes standalone",
    "test/rules/flow/flow_fp_test.dart": R,
    "test/rules/flow/prefer_typed_exceptions_test.dart": R,
    "test/rules/architecture/prefer_static_method_resolved_test.dart": R,
    "test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart": R,
    "test/rules/security/security_auth_storage_fp_test.dart": R,
    "test/rules/security/security_network_input_fp_test.dart": R,
    "test/rules/stylistic/formatting_rules_test.dart": R,
    "test/rules/stylistic/named_parameters_ordering_test.dart": R,
    "test/rules/stylistic/new_instance_cascade_test.dart": R,
    "test/rules/testing/prefer_setup_teardown_test.dart": R,
    "test/rules/ui/navigation_fp_test.dart": R,
    "test/rules/ui/prefer_typed_route_params_fp_test.dart": R,
    "test/rules/widget/widget_layout_fp_test.dart": R,
    "test/rules/widget/widget_lifecycle_fp_test.dart": R,
    "test/rules/widget/widget_patterns_fp_test.dart": R,
}


def norm(g):
    return [(x, None) if isinstance(x, str) else x for x in g]


def skip_reason(text):
    if ANNOT.search(text):
        return "annotation"
    if IMPORT_TEST.search(text):
        return "imports test"
    if not SYNC_MAIN.search(text):
        return "main not plain sync void"
    return None


def main():
    import sys
    files = sorted(TEST.rglob("*_test.dart"))
    rel = lambda p: p.relative_to(ROOT).as_posix()
    left_out, counts = [], {}
    for f in files:
        r = f.relative_to(TEST)
        if r.parts[0] in EXCLUDED_DIRS:
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        if skip_reason(text) or rel(f) in SKIP_AGGREGATE:
            left_out.append(rel(f))
            continue
        counts[rel(f)] = len(TEST_CALL.findall(text))
    eligible = [f for f in files
                if f.relative_to(TEST).parts[0] not in EXCLUDED_DIRS
                and rel(f) in counts]

    def in_dir(f, d):
        r = f.relative_to(TEST).as_posix()
        if d == ".":
            return "/" not in r
        return r.startswith(d + "/")

    assigned, aggregates = set(), {}
    for name, spec in GROUPS.items():
        picked = []
        for d, half in norm(spec):
            fs = [f for f in eligible if in_dir(f, d)]
            if half is not None:
                mid = (len(fs) + 1) // 2
                fs = fs[:mid] if half == 0 else fs[mid:]
            picked += fs
        aggregates[name] = picked
        assigned.update(picked)
    # anything unmapped goes to misc
    for f in eligible:
        if f not in assigned:
            aggregates["misc"].append(f)
    # split slow aggregates into balanced bins (greedy, heaviest first)
    for name, n in SPLIT.items():
        fs = aggregates.pop(name, [])
        bins = [[] for _ in range(n)]
        load = [0] * n
        for f in sorted(fs, key=lambda f: -WEIGHTS.get(rel(f), 1)):
            i = load.index(min(load))
            bins[i].append(f)
            load[i] += WEIGHTS.get(rel(f), 1)
        for i, b in enumerate(bins, 1):
            aggregates[f"{name}_{i}"] = b

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    manifest = {"aggregates": {}, "left_out": sorted(left_out), "counts": counts}
    rows = []
    for name, fs in aggregates.items():
        if not fs:
            continue
        fs = sorted(fs)
        fname = f"{name}_aggregate.dart"
        lines = ["// GENERATED by scripts/gen_test_aggregates.py - DO NOT EDIT.",
                 "// ignore_for_file: directives_ordering",
                 "import 'package:test/test.dart';"]
        for i, f in enumerate(fs):
            lines.append(f"import '../{f.relative_to(TEST).as_posix()}' as t{i};")
        lines += ["", "void main() {"]
        for i, f in enumerate(fs):
            lines.append(f"  group('{rel(f)}', t{i}.main);")
        lines.append("}")
        (OUT / fname).write_text("\n".join(lines) + "\n", encoding="utf-8")
        manifest["aggregates"][fname] = [rel(f) for f in fs]
        rows.append((fname, len(fs), sum(counts[rel(f)] for f in fs)))
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{'aggregate':36}{'files':>6}{'tests':>7}")
    for r in rows:
        print(f"{r[0]:36}{r[1]:>6}{r[2]:>7}")
    print(f"left_out: {len(left_out)}")
    if "--print" in sys.argv:
        for fname, fl in manifest["aggregates"].items():
            w = sum(WEIGHTS.get(f, 1) for f in fl)
            print(f"\n{fname} (~{w}s weighted)")
            for f in fl:
                print(f"  {f}")


if __name__ == "__main__":
    main()
