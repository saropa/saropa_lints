# Discussion: Batch Deduplication (Prevent duplicate reports at same offset)

**Source:** [GitHub Discussion #58](https://github.com/saropa/saropa_lints/discussions/58)  
**Priority:** Low  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)  
**Status: Closed** (implemented 2026-04-27 on `main`; reporter-scoped `(ruleName, filePath, offset)` dedup — see §9. Close [Discussion #58](https://github.com/saropa/saropa_lints/discussions/58) on GitHub when convenient.)

---

## 1. Goal

Prevent the same issue from being reported multiple times when AST visitors traverse nodes from multiple angles (e.g. same offset reported by more than one callback or for parent and child nodes).

---

## 2. Current state in saropa_lints

**Update (2026-04-27):** Reporter-level dedup for duplicate emission attempts is **implemented** (§9). The bullets below describe the pre-change baseline for context.

- Rules call `reporter.atNode(node, code)` or `atOffset`/`atToken`. ProgressTracker uses per-file dedup keys `ruleName:line` to avoid double-counting when the same file is re-analyzed. Offset-level dedup within a single pass is now handled in `SaropaDiagnosticReporter` before suppression checks.
- Previously, if a rule reported twice at the same node/offset in one run, both diagnostics could appear unless the analyzer merged them; dedup now drops the second attempt for the same rule at the same file offset.

---

## 3. Proposed design (from Discussion #58)

```dart
class SaropaDiagnosticReporter {
  final Set<int> _reportedOffsets = {};
  void atNode(AstNode node, LintCode code) {
    if (_reportedOffsets.contains(node.offset)) return;
    _reportedOffsets.add(node.offset);
    // ... existing report logic
  }
}
```

- Scope: per rule, per file (clear set when switching files). Key: (offset, ruleName) so different rules can still report at the same offset.
- Lifecycle: clear set when starting a new file.

---

## 4. Use cases

- Cleaner Problems tab: one diagnostic per (rule, location).
- Accurate counts: no double-counting when AST is traversed in multiple ways.
- Rules with multiple callbacks hitting the same node: dedup avoids duplicate report.

---

## 5. Research and prior art

- custom_lint does not guarantee merging of duplicate reportAtOffset for same (file, offset, rule). Many linters dedupe by (file, offset, rule) before emitting.
- ESLint: one report per (rule, location); duplicates typically collapsed.

Conclusion: Explicit "already reported at this offset for this rule" check in the reporter is safe and improves UX. Key choice: (offset, ruleName) vs (offset, ruleName, length); scope per file.

---

## 6. Implementation considerations

- Key: (offset, ruleName) or (offset, ruleName, length). Prefer (offset, ruleName) so different rules can report at same offset.
- Scope: per file; clear set when switching files.
- Threading: if parallel, set must be per-worker or merged after.
- Memory: set of offsets per file is small.

---

## 7. Open questions → **Resolved (2026-04-27)**

| Question | Decision |
|----------|----------|
| Key shape: offset only vs include length/code? | **`(ruleName, filePath, offset)`** — same as §9; length/code not part of v1 key. If a rule truly needs two distinct messages at the identical offset, that is treated as out of scope for this dedup (rare); revisit only with a concrete rule example. |
| Opt-in vs always-on? | **Always-on**, reporter-scoped — no new config flags (§9). |
| Rules that intentionally report twice at the same offset? | **None identified** during implementation; if one appears, document it and widen the key or add a rule-level opt-out. |

---

## 8. Review update (2026-04-27)

- This is the best immediate closeout candidate: self-contained, low-risk, and directly testable.
- Expected outcome is cleaner diagnostics and more accurate counts without broad architectural changes.

**Execution recommendation:**

1. Implement reporter-level dedup keyed by `(rule, file, offset)`.
2. Keep behavior always-on to avoid configuration complexity.
3. Add targeted tests for duplicate suppression and legitimate distinct reports.
4. ~~Close this discussion once tests pass.~~ **Done** — plan status set to Closed; close GitHub Discussion #58 in the UI when ready.

---

## 9. Implementation update (2026-04-27)

Implemented in this workspace:

- Added reporter-level dedup in `SaropaDiagnosticReporter` via `DiagnosticDedupTracker`.
- Dedup key is `(rule, file, offset)` and applies to `atNode`, `atToken`, and `atOffset`.
- Behavior is always-on and reporter-scoped (no new config flags).
- Added unit coverage in `test/diagnostic_dedup_tracker_test.dart` for:
  - duplicate key suppression,
  - distinct offsets,
  - same offset across files,
  - same file/offset across different rules.

Validation:

- `dart analyze lib/src/saropa_lint_rule.dart test/diagnostic_dedup_tracker_test.dart` passes.
- `dart test test/diagnostic_dedup_tracker_test.dart test/progress_tracker_dedup_test.dart` passes.
