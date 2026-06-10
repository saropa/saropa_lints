# BUG: `prefer_reusing_assigned_local` — False positive when collection is mutated between the two reads

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `prefer_reusing_assigned_local`
File: `lib/src/rules/code_quality/unnecessary_code_rules.dart` (line ~1163)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: unknown

---

## Summary

`prefer_reusing_assigned_local` flags a second `list.length` read as redundant when a local
already holds the first read, but does not detect that the collection was mutated (via
`removeWhere`, `add`, etc.) between the two reads. The two `length` values are therefore
DIFFERENT — replacing the second read with the cached local would produce a real bug. The rule's
mutation-barrier mechanism exists precisely to prevent this, but it fails to fire in at least two
structural patterns: (1) the mutating call is not a direct method invocation on the root identifier
(it is a closure argument), and (2) constructor calls such as `ValueNotifier<bool>(false)` pass
the purity filter and then get flagged for "reuse" even though each constructor call allocates a
distinct object. A `// ignore:` was added at the Saropa Contacts call sites on 2026-06-09.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'prefer_reusing_assigned_local'" lib/src/rules/
# lib/src/rules/code_quality/unnecessary_code_rules.dart:1163:
#   'prefer_reusing_assigned_local',
```

The rule is registered in `lib/src/rules/code_quality/unnecessary_code_rules.dart` (line ~1163)
as `PreferReusingAssignedLocalRule`. Attribution is confirmed; the diagnostic owner in the IDE
Problems panel is `_generated_diagnostic_collection_name_#N` (the analysis-server plugin host),
not a sibling repo, so negative attribution is not required.

**Emitter registration:** `lib/src/rules/code_quality/unnecessary_code_rules.dart:1163`
**Rule class:** `PreferReusingAssignedLocalRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

### Pattern 1 — mutating method call in a closure argument

```dart
// list.length is read twice, but the list is mutated between reads.
// Replacing the second read with `before` would snapshot the PRE-mutation
// length, which is wrong — `after` must reflect the post-mutation length.
void _pruneAndReport(List<String> list) {
  final int before = list.length;          // first read — pre-mutation
  list.removeWhere((String e) => e.isEmpty); // mutates list
  final int after = list.length;           // LINT — "reuse `before`" — WRONG, length changed
  debugPrint('removed ${before - after} items');
}
```

### Pattern 2 — post-increment index used in two successive reads

```dart
// pts[i++] evaluates i, reads, then increments i — each call reads a
// DIFFERENT element. Reusing the first read would read the same element twice
// instead of advancing through the list.
final Point a = pts[i++]; // first read at old index
final Point b = pts[i++]; // LINT — "reuse result of pts[i++]" — WRONG, i changed
```

### Pattern 3 — two `ValueNotifier` constructor calls flagged as reusable

```dart
// Each ValueNotifier<bool>(false) allocates a distinct object.
// They are NOT the same value — reusing one notifier for two listeners
// would wire them to the same mutable state, breaking isolation.
final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false); // first alloc
final ValueNotifier<bool> isVisible = ValueNotifier<bool>(false); // LINT — "reuse `isLoading`"
```

**Frequency:** Always for Pattern 1 when the mutating call is inside a closure body
(e.g. passed as a callback). Always for Pattern 3 when two same-type, same-argument
constructor calls appear in the same block. Pattern 2 frequency depends on use of
post-increment index expressions in indexed reads.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the second `list.length` read follows a mutation and holds a different value; reusing the pre-mutation local would be a real bug |
| **Actual** | `[prefer_reusing_assigned_local] A local variable already holds the result of this expression, but the identical expression is recomputed here instead of reusing that local…` reported at the second `list.length` (and at the second `ValueNotifier<bool>(false)`) |

---

## AST Context

#### Pattern 1

```
FunctionDeclaration  (_pruneAndReport)
  └─ FunctionBody  (Block)
      ├─ VariableDeclarationStatement  (before = list.length)   ← declaration
      │     └─ PropertyAccess  (list.length)
      ├─ ExpressionStatement
      │     └─ MethodInvocation  list.removeWhere(...)          ← mutation; barrier should fire here
      │           └─ FunctionExpression  (closure arg)          ← barrier NOT registered because
      │                                                              removeWhere call IS in _mutatingMethods,
      │                                                              but the closure body is the arg, not target
      └─ VariableDeclarationStatement  (after = list.length)    ← reported here
            └─ PropertyAccess  (list.length)  ← node reported
```

#### Pattern 3

```
Block
  ├─ VariableDeclarationStatement  (isLoading = ValueNotifier<bool>(false))
  │     └─ InstanceCreationExpression  ValueNotifier<bool>(false)   ← _isReusableInitializer returns false?
  └─ VariableDeclarationStatement  (isVisible = ValueNotifier<bool>(false))
        └─ InstanceCreationExpression  ValueNotifier<bool>(false)   ← reported here
```

---

## Root Cause

### Pattern 1 — mutation barrier not triggered for closure-argument mutations

The mutation-barrier mechanism is in `_BlockReuseScanner` (unnecessary_code_rules.dart lines
~1444–1591). It records a mutation event when `visitMethodInvocation` sees a call whose
`methodName.name` is in `_mutatingMethods` (lines ~1462–1487, which includes `removeWhere`) AND
whose `target` root identifier can be resolved via `_rootIdentifierName` (lines ~1594–1612).

The problem: `list.removeWhere((String e) => e.isEmpty)` DOES match `removeWhere` on target
`list` (line ~1551–1555), so a mutation event IS recorded. However, the barrier comparison in
`runWithReporter` (lines ~1222–1237) uses offset arithmetic:

```dart
// unnecessary_code_rules.dart ~1229–1237
final int barrier = mutationBarrier < awaitBarrier ? mutationBarrier : awaitBarrier;
for (final Expression reuse in scanner.occurrencesOf(entry.key)) {
  if (reuse.offset <= local.initializer.offset) continue;
  if (reuse.offset >= barrier) continue;   // skip recomputes AFTER the barrier
  ...
  reporter.atNode(reuse);
}
```

The barrier is the offset of the `removeWhere` call node (line ~1554: `offset: node.offset`).
`list.removeWhere(...)` has an `offset` that points to the start of the `list` identifier in the
call expression. The second `list.length` variable declaration begins at an offset AFTER the
`removeWhere` call — so `reuse.offset >= barrier` should be true and the diagnostic should be
suppressed.

In practice the FP fires, which means the barrier offset recorded for the `removeWhere` call is
GREATER than the second `list.length` offset, or the mutation event is not recorded at all.
Likely cause: `_BlockReuseScanner.visitMethodInvocation` is called in AST traversal order; for
a closure argument, the `FunctionExpression` body is visited recursively inside the
`super.visitMethodInvocation(node)` call (line ~1557). If the scanner's `_mutations` list is
populated during the recursive `super` call AFTER the outer method invocation itself is processed,
the recorded offset may differ from what the barrier check expects. This ordering issue can cause
the mutation to be registered at the closure body's offset rather than the outer call's offset,
placing the barrier AFTER the second `list.length` in source and disabling the guard.

A secondary path: if `_rootIdentifierName` cannot resolve the target (e.g. because `removeWhere`
is called on the result of a getter rather than a bare `SimpleIdentifier`), the mutation event is
never recorded and the second read is always flagged.

### Pattern 2 — post-increment inside `IndexExpression` not propagated as a mutation

`visitPostfixExpression` (lines ~1570–1578) records a mutation for the root identifier of the
operand when `++` or `--` is seen. However, when `i++` appears inside an `IndexExpression` as
the index sub-expression (i.e. `pts[i++]`), the post-increment is a child of the
`IndexExpression` node. `_BlockReuseScanner.visitIndexExpression` (lines ~1543–1546) calls
`_recordOccurrence(node)` on the whole `pts[i++]` and then `super.visitIndexExpression(node)`,
which recursively visits the `PostfixExpression`. The mutation for `i` is therefore recorded, but
its offset is the offset of the `i` operand inside the sub-expression — which is LESS than the
offset of the outer `pts[i++]` expression. Because the first `pts[i++]` declaration uses the same
source text, the barrier for `i` is set at the offset of `i` inside the FIRST declaration, not
between the two declarations. The second `pts[i++]` passes the barrier check and is flagged.

### Pattern 3 — `InstanceCreationExpression` not excluded from declaration scanning

`_isReusableInitializer` (lines ~1269–1278) returns `false` for `InstanceCreationExpression`
(line ~1379: `visitInstanceCreationExpression` sets `isPure = false`). This should prevent
constructor calls from ever entering `firstDecls`. However, the FP is observed in practice for
`ValueNotifier<bool>(false)`, which suggests either:

(a) The `InstanceCreationExpression` is wrapped in another node type (e.g. a
`TypedLiteralExpression` or a named constructor access via `PrefixedIdentifier`) that is NOT
caught by `_InitializerPurityVisitor`, bypassing the `isPure = false` path; or

(b) The source text `ValueNotifier<bool>(false)` resolves to a `MethodInvocation` node in the
AST (when the constructor is a generic factory), which IS accepted by `_isReusableInitializer`'s
`MethodInvocation` branch (line ~1272) and then passes `_InitializerPurityVisitor` because
`ValueNotifier` and `false` are not in `_nonDeterministicNames`.

Path (b) is the most likely root cause: a generic constructor `ClassName<T>(args)` parses as a
`MethodInvocation` in unresolved AST, and `_isReusableInitializer` accepts `MethodInvocation`
without checking whether the resolved element is a constructor. Each such call is a new allocation
with a distinct identity, so treating two calls as "the same value" is always wrong.

---

## Suggested Fix

### Fix for Pattern 1 (closure-argument mutation offset)

In `_BlockReuseScanner.visitMethodInvocation`, record the mutation at `node.offset` BEFORE
calling `super.visitMethodInvocation(node)`, not after. This ensures the barrier is placed at the
outer call's start offset in source order, before any child closure body offsets:

```dart
// unnecessary_code_rules.dart ~1549–1558  — proposed change
@override
void visitMethodInvocation(MethodInvocation node) {
  // Record mutation BEFORE recursing into arguments so the barrier offset
  // is anchored to the call site, not to a closure body inside the arguments.
  if (_mutatingMethods.contains(node.methodName.name)) {
    final String? root = _rootIdentifierName(node.target);
    if (root != null) {
      _mutations.add((offset: node.offset, name: root));
    }
  }
  _recordOccurrence(node);
  super.visitMethodInvocation(node);  // recurse into args after recording
}
```

### Fix for Pattern 2 (post-increment inside index expression)

When `_recordOccurrence` is called for an `IndexExpression` whose index sub-expression contains
a `PostfixExpression` (or `PrefixExpression`) with `++`/`--`, treat the entire index expression
as non-reusable and skip adding it to `_occurrences`. The simplest check: if any direct child of
the `IndexExpression.index` is a `PostfixExpression` or `PrefixExpression`, do not record.

### Fix for Pattern 3 (constructor call treated as pure method invocation)

In `_isReusableInitializer`, after accepting a `MethodInvocation`, resolve its `staticElement`.
If the element is a `ConstructorElement` (or `ExecutableElement` where the enclosing element is a
`ClassElement`), return `false` — constructor calls are identity-sensitive by definition.
Alternatively, call `node.staticType?.isDartCoreObject` and reject any `MethodInvocation` whose
resolved type is an instantiable class type with value-semantics unknown to the rule:

```dart
// unnecessary_code_rules.dart ~1269–1278  — proposed addition
static bool _isReusableInitializer(Expression expr) {
  if (expr is MethodInvocation) {
    // A MethodInvocation that resolves to a constructor is an allocation —
    // each call produces a distinct object, so reusing the first would wire
    // two consumers to the same mutable instance. Reject constructor calls.
    final Element? element = expr.methodName.staticElement;
    if (element is ConstructorElement) return false;
  }
  ...
}
```

---

## Fixture Gap

The fixture at `example*/lib/code_quality/prefer_reusing_assigned_local_fixture.dart` should
include:

1. **`list.length` before and after `list.removeWhere(...)`** — expect NO lint (mutation between
   reads; currently emits a FP).
2. **`list.length` read twice with NO intervening mutation** — expect LINT (true positive; the
   second read is genuinely redundant).
3. **`pts[i++]` used twice in succession** — expect NO lint (post-increment advances `i` between
   reads; currently emits a FP).
4. **`pts[i]` (no increment) used twice** — expect LINT (true positive; `i` unchanged between
   reads).
5. **`ValueNotifier<bool>(false)` declared twice in the same block** — expect NO lint (each call
   allocates a distinct object; currently emits a FP).
6. **A pure property access `contact.name` assigned and then reused** — expect LINT (true
   positive; the canonical case the rule was designed for).

---

## Changes Made

Empirical testing against the scan CLI showed only Patterns 2 and 3 actually
reproduce; **Pattern 1** (`list.length` before/after `list.removeWhere(...)`)
does NOT fire on the current code — the mutation barrier is already recorded at
the call-site offset (`node.offset`), so the report's Pattern-1 root-cause
analysis was incorrect and no change was needed there.

Both real FPs originate in `_InitializerPurityVisitor`, which decides whether a
local's initializer is safe to reuse. Added three overrides:

- `visitPostfixExpression` / `visitPrefixExpression`: a `++`/`--` in the
  initializer marks it impure. `pts[i++]` advances `i` and reads a different
  element each evaluation, so it can never be reused (Pattern 2).
- `visitMethodInvocation`: a call whose name starts with an ASCII uppercase
  letter (PascalCase) is a constructor/class instantiation — in unresolved AST
  `ValueNotifier<bool>(false)` parses as a `MethodInvocation` named
  `ValueNotifier`, slipping past `visitInstanceCreationExpression`. Each call
  allocates a distinct identity-sensitive object, so two same-source
  allocations must never be merged (Pattern 3).

Making the initializer impure removes it from the tracked set entirely, so no
occurrence is recorded and the FP cannot fire. Existing reusable cases use
lowercase method names (`Theme.surface.from(context)`,
`JsonUtils.toStringJson(...)`) and are unaffected.

---

## Tests Added

- `example/lib/unnecessary_code/prefer_reusing_assigned_local_fixture.dart`:
  added `goodPostIncrementIndex` (`pts[i++]` twice — NO lint) and
  `goodSeparateAllocations` (`ValueNotifier<bool>(false)` twice — NO lint) with
  a local `ValueNotifier<T>` mock.
- Scan CLI verified: the two new GOOD cases are silent; every existing
  true-positive recompute case still fires.

**Note:** a pre-existing shadowed-closure regression guard
(`goodShadowedNestedClosure`) fires in the parse-only scan CLI because its
`_sameBindings` shadow detection needs element resolution the CLI does not
provide. This is unrelated to and unaffected by this fix (the change touches
only `++`/`--` and PascalCase-call purity), and the case is correctly silent in
a resolving analysis server.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** All three additions are suppression-only — they can only make
an initializer impure (drop it from tracking), never create a new diagnostic.
The PascalCase heuristic relies on the universal Dart convention (types are
PascalCase, members camelCase) so it needs no resolution and works in both the
scan and the analysis server. Rule file, tier, severity, `LintImpact`, and the
quick fix are unchanged.

**Tests:** `dart test test/rules/code_quality/unnecessary_code_rules_test.dart`
→ all pass. Scan-CLI behavior verified as above.

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/prefer_reusing_assigned_local_false_positive_value_changed_by_intervening_mutation.md
→ plans/history/2026.06/2026.06.09/prefer_reusing_assigned_local_false_positive_value_changed_by_intervening_mutation.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (saropa_lints repo default)
- custom_lint version: N/A (native analyzer plugin)
- Triggering project/file: Saropa Contacts — 2026-06-09 (suppressed with `// ignore: prefer_reusing_assigned_local -- list mutated by removeWhere between reads; after != before`)
