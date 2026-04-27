# Discussion: Batch Deduplication (Prevent duplicate reports at same offset)

**Source:** [GitHub Discussion #58](https://github.com/saropa/saropa_lints/discussions/58)  
**Priority:** Low  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)

---

## 1. Goal

Prevent the same issue from being reported multiple times when AST visitors traverse nodes from multiple angles (e.g. same offset reported by more than one callback or for parent and child nodes).

---

## 2. Current state in saropa_lints

- Rules call `reporter.atNode(node, code)` or `atOffset`/`atToken`. ProgressTracker uses per-file dedup keys `ruleName:line` to avoid double-counting when the same file is re-analyzed. There is no offset-level dedup within a single pass (same rule, same offset).
- If a rule reports twice at the same node/offset in one run, both diagnostics may appear unless the analyzer merges them.

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

## 7. Open questions

- Dedup by (offset, ruleName) only, or allow same rule to report different messages at same offset (e.g. include length/code)?
- Opt-in or always-on?
- Any rules that intentionally report multiple times at same offset?

---

## 8. Review update (2026-04-27)

- This is the best immediate closeout candidate: self-contained, low-risk, and directly testable.
- Expected outcome is cleaner diagnostics and more accurate counts without broad architectural changes.

**Execution recommendation:**

1. Implement reporter-level dedup keyed by `(rule, file, offset)`.
2. Keep behavior always-on to avoid configuration complexity.
3. Add targeted tests for duplicate suppression and legitimate distinct reports.
4. Close this discussion once tests pass.

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
