# BUG: `prefer_reusing_assigned_local` — false positive on re-invoked side-effecting instance method (recursive-descent parser)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `prefer_reusing_assigned_local`
File: `lib/src/rules/code_quality/unnecessary_code_rules.dart` (line ~1163)
Severity: False positive
Rule version: v2 | Since: — | Updated: —

---

## Summary

The rule flags the second (and later) call to a no-argument instance method
that mutates object state and returns a different value each time — e.g. a
recursive-descent parser's `_and()` / `_equality()` / `_not()` that consume
tokens by advancing a cursor field. It reports these as "redundant recomputes"
of the local that holds the first call's result. Reusing the local, as the rule
and its quick fix suggest, would skip the second parse and break the parser.
Expected: no diagnostic, because each call returns a distinct value.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_reusing_assigned_local'" lib/src/rules/
# lib/src/rules/code_quality/unnecessary_code_rules.dart:1163:    'prefer_reusing_assigned_local',
```

**Emitter registration:** `lib/src/rules/code_quality/unnecessary_code_rules.dart:1163`
**Rule class:** `PreferReusingAssignedLocalRule` — registered in `lib/saropa_lints.dart:237`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (custom_lint plugin `saropa_lints`)

---

## Reproducer

Minimal recursive-descent parser. Each `_term()` call consumes one token and
returns the next value; the two calls are NOT the same expression evaluated
twice.

```dart
class MiniParser {
  MiniParser(this._tokens);
  final List<int> _tokens;
  int _pos = 0;

  int _term() => _tokens[_pos++]; // side effect: advances the cursor

  int sum() {
    int left = _term();           // decl: holds the FIRST term
    while (_pos < _tokens.length) {
      // LINT (false positive): rule says reuse `left` instead of `_term()`,
      // but `_term()` here MUST run again to consume the next token.
      final int right = _term();
      left = left + right;
    }
    return left;
  }
}
```

**Frequency:** Always, for any no-arg instance method whose name is camelCase or
`_`-prefixed and not in the rule's `_nonDeterministicNames` allowlist, called
once into a local and again later in the same block.

Real-world hits (downstream `saropa_dart_utils`, on plugin 13.12.3):
- `lib/parsing/expression_evaluator_utils.dart` — `_and()` (in `_or()`), `_equality()` (in `_and()`)
- `lib/parsing/sql_filter_utils.dart` — `_and()` (in `_or()`), `_not()` (in `_and()`)

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `_term()` mutates `_pos` and returns a different value each call |
| **Actual** | `[prefer_reusing_assigned_local]` reported on the second `_term()` invocation |

---

## AST Context

```
MethodDeclaration (sum)
  └─ Block
      ├─ VariableDeclarationStatement
      │   └─ VariableDeclaration (left)
      │       └─ MethodInvocation (_term)          ← recorded as the "assigned local"
      └─ WhileStatement
          └─ Block
              └─ VariableDeclarationStatement
                  └─ VariableDeclaration (right)
                      └─ MethodInvocation (_term)  ← node reported here (false positive)
```

---

## Root Cause

The reuse candidate is gated by `_isReusableInitializer` →
`_InitializerPurityVisitor`. The visitor rejects non-deterministic expressions,
but its `visitMethodInvocation` (line ~1409) only marks an invocation impure
when the **method name is PascalCase** (treated as a constructor):

```dart
@override
void visitMethodInvocation(MethodInvocation node) {
  final String name = node.methodName.name;
  if (name.isNotEmpty) {
    final int first = name.codeUnitAt(0);
    // ASCII A-Z: types/constructors are PascalCase, methods are camelCase.
    if (first >= 0x41 && first <= 0x5A) isPure = false;
  }
  super.visitMethodInvocation(node);
}
```

A camelCase or `_`-prefixed user method (`_term`, `_and`, `_equality`, `_not`)
has a first code unit outside `A`–`Z`, so it is **not** marked impure. The only
other guard is the fixed `_nonDeterministicNames` allowlist (`now`, `random`,
`next`, `read`, `elapsed`, …), which a user parser method never matches.

The mutation-barrier pass (`mutationBarrierFor`) cannot save it either: it scans
for writes to identifiers **textually referenced in the initializer**. `_term()`
references no identifiers, and the field it mutates (`_pos`) never appears in the
call text, so no barrier is found and the recompute is reported.

Net: any no-arg instance method of unknown purity is assumed pure. Instance
methods routinely mutate fields and return per-call-varying values, so this
assumption is unsound.

### Hypothesis A: name-shape heuristic is too narrow

Treating only PascalCase calls as impure assumes camelCase calls are pure. A
sound purity check cannot be derived from the call's name casing.

### Hypothesis B: missing element resolution

The visitor never inspects `node.methodName.staticElement`. A user-defined
instance method (declared in the enclosing class/library, body not provably
pure) should disqualify reuse.

---

## Suggested Fix

In `_InitializerPurityVisitor.visitMethodInvocation`, mark impure for any
invocation that resolves to a user-defined instance/local method rather than a
known-pure SDK accessor. Conservative, element-based:

```dart
@override
void visitMethodInvocation(MethodInvocation node) {
  // A bare call (implicit `this`) to a user method can mutate object state and
  // return a different value each evaluation (e.g. a parser cursor advance).
  // Reusing the first result would skip the side effect — never safe.
  if (node.realTarget == null) {
    isPure = false;
    return;
  }
  // ...existing PascalCase / allowlist checks for targeted calls...
}
```

If implicit-`this` is too broad, gate on `node.methodName.staticElement` being a
`MethodElement` whose library is the analyzed source (not `dart:*` /
allowlisted), and only then mark impure. Either change resolves the parser case
without affecting genuinely-pure property/index reads.

---

## Fixture Gap

The fixture at `example*/lib/.../prefer_reusing_assigned_local_fixture.dart`
should include:

1. **Side-effecting no-arg instance method called twice into locals** — expect NO lint
   (recursive-descent parser `_term()` / `_and()` pattern)
2. **Method named with a non-deterministic allowlist word** (`now()`) — expect NO lint (already covered)
3. **Genuinely pure property read reused** (`obj.field`) — expect LINT (regression guard)

---

## Changes Made

`_InitializerPurityVisitor.visitMethodInvocation`
(`lib/src/rules/code_quality/unnecessary_code_rules.dart`) now marks a call
impure — disqualifying its result from reuse — when the call has no receiver
(`node.realTarget == null`, implicit `this`) or an explicit `this` receiver
(`target is ThisExpression`). This is the Hypothesis-A/B remedy from the Root
Cause: a receiver-less instance call is of unknown purity and routinely mutates
a field (parser cursor advance), so the first result must not be reused.

The original PascalCase name-shape guard and the `_nonDeterministicNames`
allowlist are preserved for receiver-qualified calls, so the intended positives
(`Theme.surface.from(ctx)`, `JsonUtils.toStringJson(...)`) still lint. The
discriminator is deliberately the receiver, not element resolution: an
element-based "user-defined method → impure" rule would also suppress
`Theme.surface.from(ctx)` (a user instance method in the fixture), breaking an
intended positive.

Verified with the scan CLI against the fixture: the new `MiniParser.sum()`
`_term()` calls do not lint, while all five pre-existing expected positives
still fire.

---

## Tests Added

- `example/lib/unnecessary_code/prefer_reusing_assigned_local_fixture.dart` —
  added `MiniParser` (recursive-descent `_term()` cursor advance reused into a
  later local) as a GOOD case that must NOT lint.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.3 (triggering project) / reproduced in 13.12.4 source (rule unchanged, {v2})
- Dart SDK version: bundled with Flutter (project `saropa_dart_utils`)
- custom_lint version: per `saropa_dart_utils` lockfile
- Triggering project/file: `saropa_dart_utils` — `lib/parsing/expression_evaluator_utils.dart`, `lib/parsing/sql_filter_utils.dart`

---

## Finish Report (2026-06-11)

**Scope:** (A) Dart lint rule — `lib/`, `example/`.

**Deep review:**
- *Logic & safety:* The new guard sits at the top of `visitMethodInvocation` and
  early-returns after setting `isPure = false`; skipping `super` is safe because
  impurity is terminal (the visitor only ever flips `isPure` to false). No
  recursion or state-ordering risk.
- *Linter integrity:* The discriminator is the receiver (`node.realTarget ==
  null || target is ThisExpression`), deliberately NOT element resolution. An
  element-based "user-defined method → impure" rule would also suppress the
  intended positive `Theme.surface.from(ctx)` (a user instance method in the
  fixture). The receiver test suppresses the parser pattern while leaving
  receiver-qualified resolver/static-helper calls flagged. No tier / `LintImpact`
  / `cost` change — this fixes an existing rule, not a new one.
- *Refactoring:* none beyond scope.

**Testing:**
- Audited `test/rules/code_quality/unnecessary_code_rules_test.dart` (the only
  references). Its `prefer_reusing_assigned_local` cases pin rule instantiation,
  fixture existence, and quick-fix presence — none assert diagnostics, so the
  change cannot break an assertion. Ran the file: **33/33 pass**
  (`dart test test/rules/code_quality/unnecessary_code_rules_test.dart`).
- Verified behavior with the scan CLI against the fixture copied to a scratch
  dir: the new `MiniParser.sum()` `_term()` calls do NOT lint; all five
  pre-existing expected positives still fire (fixture lines 23, 31, 38, 104,
  135). `dart analyze` on the rule file: no issues.

**Maintenance:**
- CHANGELOG: Fixed bullet added under `[13.12.5]`.
- ROADMAP / README: no references to this rule; counts unchanged — verified, no
  updates needed.

**Outstanding:** none. The line-124 firing seen only in the standalone scan
(`goodShadowedNestedClosure`'s `wrapper.label`, a `PropertyAccess`) is a
scan-CLI element-resolution limitation, untouched by this edit and out of scope.

Finish report appended: plans/history/2026.06/2026.06.11/prefer_reusing_assigned_local_false_positive_side_effecting_instance_method.md
