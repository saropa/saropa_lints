# BUG: `avoid_missing_enum_constant_in_map` — False positive on partial enum-keyed map when sibling argument constrains the active set

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_missing_enum_constant_in_map`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~169)
Severity: False positive
Rule version: v3 | Since: unknown | Updated: unknown

---

## Summary

The rule flags a `dismissThresholds` map that intentionally maps only `DismissDirection.up`
because the parent `Dismissible` widget is locked to `direction: DismissDirection.up` — every
other `DismissDirection` constant can never fire, so omitting them is correct. The rule sees only
the map literal's keys versus the full `DismissDirection` enum set and reports missing constants
without consulting whether a sibling argument constrains which directions are reachable. A
`// ignore:` was added at the Saropa Contacts call site on 2026-06-09.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_missing_enum_constant_in_map'" lib/src/rules/
# Expected:
# lib/src/rules/code_quality/code_quality_variables_rules.dart:173:
#   'avoid_missing_enum_constant_in_map',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:173`
**Rule class:** `AvoidMissingEnumConstantInMapRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#0`

---

## Reproducer

```dart
// direction: constrains which DismissDirection values can ever be triggered.
// Only DismissDirection.up is reachable; the rest can never fire, so omitting
// them from dismissThresholds is intentional — filling them in would be
// misleading dead configuration.
Dismissible(
  key: ValueKey(item.id),
  direction: DismissDirection.up,
  dismissThresholds: const {
    DismissDirection.up: 0.25, // LINT — but should NOT lint (false positive)
    // All other DismissDirection constants intentionally absent; they can
    // never be triggered because direction: is fixed to .up above.
  },
  onDismissed: (_) => _onDismiss(item),
  child: _ItemTile(item: item),
);
```

**Frequency:** Always — fires whenever a `dismissThresholds` map covers only the active
direction subset declared in the sibling `direction:` argument.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the partial map is correct because the sibling `direction: DismissDirection.up` constrains which directions are reachable at runtime |
| **Actual** | `[avoid_missing_enum_constant_in_map] Map literal keyed by enum values does not include all enum constants…` reported at the `dismissThresholds:` map literal |

---

## AST Context

```
InstanceCreationExpression  (Dismissible(...))
  └─ ArgumentList
      ├─ NamedExpression  direction: DismissDirection.up
      │     └─ PrefixedIdentifier  (DismissDirection.up)
      └─ NamedExpression  dismissThresholds: const { DismissDirection.up: 0.25 }
            └─ SetOrMapLiteral  ← rule registers addSetOrMapLiteral; node reported here
                  └─ MapLiteralEntry
                        └─ PrefixedIdentifier (key)  DismissDirection.up
```

---

## Root Cause

The detection logic in `AvoidMissingEnumConstantInMapRule.runWithReporter` (lines ~197–232)
registers an `addSetOrMapLiteral` visitor. For each map literal it:

1. Resolves the enum type from the first key's `staticType` via `_resolveEnumKeyType` (lines
   ~236–248).
2. Collects every declared `FieldElement` where `isEnumConstant` is true — the full
   `DismissDirection` set (`up`, `down`, `startToEnd`, `endToStart`, `horizontal`, `vertical`,
   `none`).
3. Collects only the constants that appear as keys in the literal.
4. Reports if the difference is non-empty.

The rule inspects the `SetOrMapLiteral` node in isolation. It does not walk to the enclosing
`ArgumentList` or `NamedExpression` to check whether a sibling `direction:` argument restricts
the reachable set. Because `DismissDirection.up` is the only key and `DismissDirection` has seven
constants, `missing` is non-empty and the rule fires unconditionally.

This is an instance of the broader "configuration override vs dispatch table" distinction the
rule's own doc comment acknowledges for sparse lookup tables (lines ~156–168), but the current
implementation has no mechanism to detect that the sparse map is a *threshold override* where
Flutter's framework provides defaults for absent keys — not a dispatch table where a missing key
causes a silent `null`.

---

## Suggested Fix

**Option A (targeted — preferred):** When the `SetOrMapLiteral` is the value of a `NamedExpression`
inside an `ArgumentList`, walk the sibling `NamedExpression` nodes to find a parameter whose name
semantically constrains the active enum subset (e.g. `direction:` paired with
`dismissThresholds:` on `Dismissible`). If the constraining sibling's value is a single enum
constant that is present in the map, suppress the diagnostic. This requires knowing the pairing,
which could be encoded in a rule configuration allow-list of `(builderType, constrainingParam,
constrainedParam)` triples.

**Option B (general — broader impact):** Treat a partial enum-keyed map as intentional when it
is passed to a named parameter whose documentation (or a hard-coded exemption list) indicates
that absent keys fall back to a defined default rather than producing `null`. At minimum add
`dismissThresholds` on `Dismissible` to an exemption list at the lint configuration level.

**Option C (minimal — lowest risk):** Emit a lower-severity `INFO` (the rule already uses
`DiagnosticSeverity.INFO` at line ~177) and document that `// ignore:` is the correct
suppression for intentional partial maps, as the rule's existing doc comment already recommends
(lines ~163–168). This does not fix the FP but reduces its friction.

In all options, add an `// ignore: avoid_missing_enum_constant_in_map` exemption path so the
suppression is honored when the sparseness is explicitly documented — the existing `IgnoreUtils`
support (referenced at line ~167) already provides this.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/avoid_missing_enum_constant_in_map_fixture.dart`
should include:

1. **`Dismissible` with `direction: DismissDirection.up` and a single-key `dismissThresholds`** —
   expect NO lint (currently emits a FP).
2. **`Dismissible` with `direction: DismissDirection.horizontal` and a two-key
   `dismissThresholds: {startToEnd: 0.4, endToStart: 0.4}`** — expect NO lint (covers the
   active horizontal subset).
3. **Partial map NOT inside a constraining context (e.g. a standalone `<MyEnum, String>{}`
   missing constants)** — expect LINT (true positive must still fire).
4. **Full enum-keyed map** — expect NO lint (baseline passing case).

---

## Changes Made

Implemented Option A (constraining-sibling exemption), generalized so it does
not hardcode `Dismissible`. In `AvoidMissingEnumConstantInMapRule.runWithReporter`
(`code_quality_variables_rules.dart`), before reporting a map with missing
constants, call the new `_hasConstrainingEnumSibling(node, enumElement)`:

- It confirms the map is the value of a `NamedExpression` inside an
  `ArgumentList`, then scans the sibling arguments. If any sibling
  `NamedExpression` has a value whose static type is the SAME enum
  (`InterfaceType.element` identical to the map-key `enumElement`), the map is
  treated as an intentional scoped override and the diagnostic is suppressed.

This covers both `direction: DismissDirection.up` (single direction) and
`direction: DismissDirection.horizontal` (composite subset) without needing the
constraining constant to appear as a map key — the mere presence of a
same-enum sibling is the signal. A standalone partial enum-keyed map (no
constraining sibling) still flags.

---

## Tests Added

- `example/lib/code_quality/avoid_missing_enum_constant_in_map_fixture.dart`:
  added a `_Constrained` widget-like class and two cases — `_withConstraint`
  (partial map with a `direction:` sibling → NO lint) and `_withoutConstraint`
  (partial map, no constraining sibling → LINT). Existing complete/incomplete
  and ignore-based cases retained.

**Verification limitation:** the project scan CLI uses parse-only (unresolved)
AST, so `_resolveEnumKeyType` cannot resolve the enum-key static type and the
rule does not fire there at all — not even on the pre-existing BAD cases. The
fix is therefore verified by inspection and a clean analyze: the new helper
only ADDS a suppression path gated on resolved enum-type identity, so it can
never introduce a new false positive. In a consumer's analysis server (where
enum types resolve), the constrained map is exempt and the standalone partial
map still flags.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** `_hasConstrainingEnumSibling` is a bounded single pass over the
argument list, O(args). It is purely additive (suppression only). It uses
`identical(...)` on element instances rather than name matching, so it cannot
be fooled by a same-named enum in another library. Rule file, tier, severity
(INFO), `LintImpact` unchanged.

**Tests:** `dart test test/rules/code_quality/code_quality_rules_test.dart` →
all pass. Scan-CLI cannot exercise this resolution-dependent rule (noted above);
verified by inspection + clean analyze.

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/avoid_missing_enum_constant_in_map_false_positive_partial_map_intentional_default.md
→ plans/history/2026.06/2026.06.09/avoid_missing_enum_constant_in_map_false_positive_partial_map_intentional_default.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (saropa_lints repo default)
- custom_lint version: N/A (native analyzer plugin)
- Triggering project/file: Saropa Contacts — 2026-06-09 (suppressed with `// ignore: avoid_missing_enum_constant_in_map -- DismissDirection.up only; other directions cannot fire`)
