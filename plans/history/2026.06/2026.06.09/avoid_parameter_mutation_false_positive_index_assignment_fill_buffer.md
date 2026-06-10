# BUG: `avoid_parameter_mutation` — fires on index-assignment fill-buffer / out-parameter pattern

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_parameter_mutation`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~483, visitor at ~597)
Severity: False positive
Rule version: v2 | Since: (unknown) | Updated: v13.12.2

---

## Summary

The rule flags `param[index] = value` on a `List`-typed parameter even when the
parameter is a freshly-allocated **out-parameter / fill-buffer** the caller
created expressly for the callee to populate. The rule already exempts the
equivalent collection-method output pattern (`list.add(x)`, `list.addAll(...)`)
with the comment "standard accumulator/output pattern in Dart" — but index
assignment into a list is the same output pattern expressed differently, and it
is **not** exempted. The two should be treated symmetrically.

Real-world trigger: a generated timezone-polygon table in Saropa Contacts
(`_polygon_data.dart`) produces **1001** hits from this single pattern.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_parameter_mutation'" lib/src/rules/
lib/src/rules/code_quality/code_quality_variables_rules.dart:500:    'avoid_parameter_mutation',

# Negative — rule is NOT in the drift-advisor sibling repos
$ grep -rn "'avoid_parameter_mutation'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# (0 matches)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:499-506`
**Rule class:** `AvoidParameterMutationRule` — registered in `lib/saropa_lints.dart:643` (`AvoidParameterMutationRule.new`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
// Caller allocates a buffer and hands it to the callee solely to be filled,
// then uses the populated result. `p` is an out-parameter, not shared caller
// state — there is no caller data to corrupt.
List<String> buildItems() {
  final List<String> p = List<String>.filled(3, '');
  _Filler.fill(p); // p exists only to be populated here
  return p;
}

class _Filler {
  static void fill(List<String> p) {
    p[0] = 'a'; // LINT (false positive) — but this is the fill-buffer pattern
    p[1] = 'b'; // LINT (false positive)
    p[2] = 'c'; // LINT (false positive)
  }
}

// Contrast — already EXEMPTED by the rule today (same output intent):
class _Accumulator {
  static void fill(List<String> out) {
    out.add('a');     // OK — exempted as "accumulator/output pattern"
    out.addAll(<String>['b', 'c']); // OK — exempted
  }
}
```

**Frequency:** Always — any `list[i] = x` where `list` is a parameter not in the
mutation-by-design type set.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — index assignment into a `List` parameter is the same output/fill pattern already exempted for `.add` / `.addAll` |
| **Actual** | `[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}` reported on every `p[i] = …` |

---

## AST Context

```
MethodDeclaration (fill)
  └─ BlockFunctionBody
      └─ Block
          └─ ExpressionStatement
              └─ AssignmentExpression            ← node reported here
                  ├─ IndexExpression (left)
                  │   ├─ target: SimpleIdentifier (p)   ← parameter
                  │   └─ index: IntegerLiteral (0)
                  └─ (rhs) StringLiteral ('a')
```

The visitor's `visitAssignmentExpression` matches `left is IndexExpression` with
`target is SimpleIdentifier` resolving to a parameter
(`code_quality_variables_rules.dart:597-604`).

---

## Root Cause

The detection deliberately skips collection **method** mutations on parameters —
`_ParameterMutationVisitor.visitMethodInvocation` calls only `super` with the
comment (lines 567, 579-582):

> Collection method calls (add, addAll, etc.) are intentionally skipped — they
> represent the standard accumulator/output pattern in Dart.

But `visitAssignmentExpression` (lines 586-607) flags `param[index] = value`
unconditionally (subject only to the `_isMutableParameter` type exemption). The
`_mutationByDesignTypeNames` exemption set (lines 651-660) covers notifiers and
sinks only — it has **no entry for plain mutable collections** and no concept of
the fill-buffer/out-parameter case.

So the rule is internally inconsistent: `out.add(x)` (method) is exempt as
"output pattern" but `out[i] = x` (index assignment) — the identical intent — is
flagged. Index assignment is only valid on indexable mutable types (`List`,
typed-data lists, `Map`); for `List`/typed-data it is the canonical way to fill a
pre-sized buffer, which is precisely the accumulator/output pattern the rule
claims to exempt.

### Hypothesis A (confirmed by source): index-assignment exemption is missing

The method-call branch exempts the output pattern; the index-assignment branch
does not. Adding a symmetric exemption for index assignment on collection-typed
parameters fixes the FP class.

---

## Suggested Fix

In `_ParameterMutationVisitor.visitAssignmentExpression`
(`code_quality_variables_rules.dart:597-604`), skip the `IndexExpression` case
when the parameter's declared/static type is a mutable indexable collection —
symmetric with the existing `.add`/`.addAll` method-call exemption.

Cheapest, most-targeted option: treat `List` (and typed-data lists / `Map`) as
output-collection types for the **index-assignment** path only. A list whose
elements are reassigned by index is the fill-buffer pattern; field assignment
(`param.field = x`) and cascade field assignment stay flagged (those are the real
DTO-corruption cases the rule targets).

```dart
// param[index] = value — exempt when the parameter is a mutable collection
// (List / typed-data / Map). Index assignment into a passed-in collection is
// the fill-buffer/output pattern, symmetric with the .add/.addAll exemption
// in visitMethodInvocation. Field/cascade assignment (DTO corruption) is
// still flagged.
if (left is IndexExpression) {
  final Expression? target = left.target;
  if (target is SimpleIdentifier &&
      _isMutableParameter(target.name, target.staticType) &&
      !_isOutputCollectionParameter(target.name, target.staticType)) {
    reporter.atNode(node);
  }
}
```

where `_isOutputCollectionParameter` recognizes a declared type name in a new
`_outputCollectionTypeNames = {'List', 'Uint8List', 'Int32List', …, 'Map'}` set
(syntax-only path) and, when resolved, `staticType` that is/implements
`List`/`Map`/typed-data (supertype walk, mirroring `_isMutationByDesignType`).

Note: the syntax-only scan already captures declared type names via
`paramTypeNames` (lines 536-542), so the name-based exemption works under the CLI
the same way the existing `_mutationByDesignTypeNames` check does.

---

## Fixture Gap

The fixture at `example*/lib/.../avoid_parameter_mutation_fixture.dart` should
include:

1. **`p[i] = x` on a `List` parameter** — expect NO lint (fill-buffer / output
   pattern), mirroring the existing `out.add(x)` exempt case.
2. **`p[i] = x` on a `Uint8List` / typed-data parameter** — expect NO lint.
3. **`p.field = x` on a DTO parameter** — expect LINT (still the real target).
4. **`p..field = x` cascade on a DTO parameter** — expect LINT.
5. **`m[key] = v` on a `Map` parameter** — expect NO lint (decide explicitly;
   recommend exempt for consistency with `List`).

---

## Environment

- saropa_lints version: 13.12.2
- Triggering project/file: `saropa` (Saropa Contacts) —
  `lib/utils/event/astronomical/lat_lng_to_timezone/_polygon_data.dart`
  (generated timezone polygon table; 1001 hits from `p[N] = _TzPolygon(...)`
  inside 31 `_InitializerN._init(List<_TzPolygon> p)` methods, all filling a
  buffer allocated by `_buildPolygons()`).
- Downstream disposition: file-level `// ignore_for_file: avoid_parameter_mutation`
  added with rationale (generated file; symptom only). Links back to this report.
