# PROPOSAL: Accepted-findings list (rule + file + reason, no line numbers) with stale-entry reporting

**Status: Implemented (UI unverified)**

<!-- Status values: Open → Accepted → In Progress → Closed -->
<!-- Use "Declined" if rejected, with rationale in the Decision section -->

Created: 2026-11-26
Type: Tooling / Infrastructure
Related rules: all (reporting layer, no single rule)

---

## Summary

Let a project commit a list of reviewed findings (accepted, or false positive), each as rule + file + reason with no line number. Listed findings are hidden from the Problems panel and exports, and entries that no longer match anything are reported. No `// ignore:` comment is needed in source.

---

## Motivation

A project that keeps source free of ignore comments has no durable place to record "this finding was reviewed, and why". The existing baseline is built for freezing legacy debt, not for recording decisions.

### What the baseline does today (17.9.1, from reading the code; not run)

| Question | Behavior | Evidence |
|---|---|---|
| Match key | file + rule + exact line number. No content hash, no rule+file form | `lib/src/baseline/baseline_file.dart:10-19`, `:142-170` |
| Reason per entry | None. Schema is `file -> rule -> [int]`; any other value shape is dropped on load | `lib/src/baseline/baseline_file.dart:88-103` |
| Line drift | A moved line stops matching, so the finding returns. The old number stays and can hide a different finding of the same rule that lands on it | `lib/src/baseline/baseline_file.dart:154`, `:163` |
| Problems panel | A matched finding is never reported by the plugin; it is recorded as `SuppressionKind.baseline` | `lib/src/saropa_lint_rule.dart:3399-3404`, `:3416-3424`, `:3463-3466`, `:3499-3503` |
| Exports | Excluded from violations; counted in the suppression summary | `lib/src/report/violation_export.dart:354-358`, `:473-474` |
| Stale entries | Not reported. `--update` rewrites the whole file from the current run | `bin/baseline.dart:181-200`, `:245` |
| Coarser option | `baseline.paths` hides every rule in the matched files | `lib/src/baseline/baseline_manager.dart:267-274` |
| Create command | `saropaLints.createBaseline` runs `dart run saropa_lints:baseline` | `extension/src/extension.ts:2536-2542`, `extension/src/setup.ts:771-776` |

`--dry-run`, `--update` and `only_impacts` do not add a reason, a line-free key or a stale report.

### Defects found while reading (these would also block the new list if it shares the loader)

None of these was reproduced by running; each needs a test first.

1. **Activation location mismatch.** The CLI inserts `baseline:` indented under `saropa_lints:` in `analysis_options.yaml` (`bin/baseline.dart:290-304`). The loader reads only a top-level `^baseline:` key from `analysis_options_custom.yaml` (`lib/src/native/config_loader.dart:155-166`, `:893-897`). A baseline created by the extension command therefore appears never to be activated.
2. **Project root.** The loader reads config from the resolved project root but initializes the manager with `Directory.current.path` (`lib/src/native/config_loader.dart:902`). The same file notes that the plugin's working directory is not the project (`:90-97`). A relative baseline path then fails to resolve (`lib/src/baseline/baseline_manager.dart:307-323`) and loads as null with no message (`lib/src/baseline/baseline_file.dart:40-43`).
3. **`--update` with an active baseline.** It rebuilds from `dart analyze` output (`bin/baseline.dart:88-104`, `:181`), which already omits baselined findings, so still-present entries would be dropped.

---

## Detection / Behavior

### File (committed in the consuming project)

Name and format are the maintainer's choice. Example, `saropa_accepted.yaml` at the project root:

```yaml
version: 1
accepted:
  - rule: avoid_print
    file: lib/tool/report.dart
    kind: false_positive   # or: accepted
    reason: Command-line output is the purpose of this file.
```

- `rule`, `file` (project-relative, forward slashes) and a non-empty `reason` are required. `kind` is optional.
- No line numbers. An entry covers every finding of that rule in that file.
- An entry missing a reason, or naming an unknown rule, is reported and hides nothing.
- A file that exists but cannot be parsed is reported, never silently treated as empty.

### Hiding

- Listed findings do not appear in the Problems panel, from every producer (analyzer plugin, scan-on-save / scan daemon, language server).
- They are left out of scan, audit and violations exports, and counted as their own suppression kind.
- `audit --include-suppressed` returns them with `kind` and `reason`.
- Edits to the list take effect without a manual analysis-server restart, or the extension says one is needed.

### Stale entries

- An entry whose file no longer exists, or whose rule produced no finding in that file, is reported as stale (CLI text and JSON, plus a Problems diagnostic on the list file).
- Staleness is judged only for files and rules that were actually run. A scoped scan, a disabled rule or a lower tier never marks an entry stale.
- A CI flag makes stale or invalid entries fail the run.
- Nothing rewrites or removes entries automatically.

### Optional editor support

A quick action on a finding, "Accept in this file…", prompts for the reason and appends the entry.

---

## Proposed Tier

Not applicable (infrastructure).

---

## Edge Cases

1. **A new occurrence of an accepted rule in the same file** is also hidden under rule + file. The hidden count per entry should be visible in the report. An optional `max:` count per entry could surface growth without line numbers (needs discussion).
2. **Renamed or moved file** makes the entry stale and the finding visible again (intended).
3. **Renamed rules**: `saropaLints.migrateRuleNames` should rewrite this list too.
4. **Windows paths** match the forward-slash form. Matching is exact on the project-relative path, not by suffix.
5. **Part files** are matched on the file that contains the finding.
6. **Dart SDK and other plugins' diagnostics** are out of scope.

---

## Alternatives Considered

- **Existing baseline file**: line-keyed, no reason, no stale report.
- **`baseline.paths`**: hides all rules in a file.
- **`// ignore:` / `// ignore_for_file:`**: puts the record in source. `--find-stale-ignores` covers only these comments (`bin/scan.dart:603-640`).
- **Disabling the rule**: project-wide.

Extending the baseline file with a version 2 entry shape is an option. A separate hand-maintained file is preferred because `--update` regenerates the baseline and would need to preserve reasons.

---

## Decision

---

## Implementation Notes

---

## Commits

---

## Finish Report (2026-11-26)

### Implemented

- List: `saropa_accepted.yaml` at the project root (`version: 1`; `rule`, `file`, `reason`, optional `kind`). Parsing, matching, stale verdicts and the plugin hook are in `lib/src/accepted/`.
- Hiding: analyzer plugin (reporter, re-reads the list on change), `scan`, `audit`, `scan_daemon`, LSP server. Violations export counts `accepted` as its own suppression kind. `audit --include-suppressed` returns `acceptedKind` and `acceptedReason`.
- `scan --check-accepted`: always resolved; exits 1 on stale or invalid entries; text and JSON output.
- Extension: "Accept {rule} in this file" lightbulb, "Check Accepted Findings" command (palette, catalog, list-file toolbar button), Problems markers on the list file, "N accepted" in the Summary tree.

### Review fix

`relativeToProject` did not match absolute finding paths against a relative project root (`scan_daemon .`); both sides are now made absolute. Test added.

### Verification

- `dart test test/accepted test/scan/scan_cli_args_test.dart`: 123 passed.
- `dart compile kernel` of `bin/{scan,audit,scan_daemon,lsp_server}.dart`: no errors.
- Extension: `npm run compile`, `tsc --noEmit -p .`, `tsc -p tsconfig.test.json`: passed. Mocha `acceptedFindings` and `commandCatalogRegistry`: 27 passed.
- Unverified: extension UI, daemon and LSP filtering, end-to-end `scan --check-accepted` on a sample project, translations.

Open items: `bugs/accepted_findings_list_open_items.md`.
