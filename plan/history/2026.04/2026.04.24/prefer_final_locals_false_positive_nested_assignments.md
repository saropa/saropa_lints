# BUG: `prefer_final_locals` — False positive on reassignments inside nested blocks and closures

**Status: Fixed (2026-04-24)**

Created: 2026-04-24
Rule: `prefer_final_locals`
File: `lib/src/rules/data/type_rules.dart` (line ~2699)
Severity: False positive
Rule version: v? (no `{vN}` tag on the message) | saropa_lints: 12.4.1

---

## Summary

`prefer_final_locals` fires on variables that ARE reassigned, because the rule's `_assignsToName` detector only walks **sibling** `ExpressionStatement`s at the same block level as the declaration. Any reassignment inside an `IfStatement` body, a nested `Block`, a closure passed as an argument, or a `try`/`catch`/`while`/`switch` body is invisible to the detector — so the rule treats the variable as never reassigned and flags it.

Hit 148 times in the `saropa` contacts project (Dart 3.11.4, Flutter 3.41.6).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_final_locals'" lib/src/rules/
# lib/src/rules/data/type_rules.dart:2715:    'prefer_final_locals',

# Negative — rule is NOT in saropa_drift_advisor
grep -rn "'prefer_final_locals'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# (zero matches)
```

**Emitter registration:** `lib/src/rules/data/type_rules.dart:2699` (`PreferFinalLocalsRule`), registered in `lib/saropa_lints.dart:2922` (`PreferFinalLocalsRule.new`).
**Rule class:** `PreferFinalLocalsRule` — inherits from `SaropaLintRule`.
**Fix generator:** `lib/src/fixes/type/prefer_final_locals_fix.dart:10` (`PreferFinalLocalsFix`).
**Diagnostic message (exact match):** `[prefer_final_locals] Local variable that is never reassigned should be declared final.`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#2` (VS Code labels saropa_lints diagnostics under the Dart analyzer source).

---

## Reproducer

### Minimal case A — reassignment inside `if` body

```dart
void methodA() {
  String? text = computeInitial(); // LINT — but text IS reassigned below
  if (text == '@saropacontacts') {
    text = '@saropa contacts'; // <-- rule does not see this assignment
  }
  print(text);
}
```

### Minimal case B — reassignment inside a closure argument

```dart
void methodB() {
  ReshareOption selectedOption = ReshareOption.canceled; // LINT — reassigned inside closures

  showDialogCommon(
    onButton1: () {
      selectedOption = ReshareOption.fullWorkflow; // <-- not seen
    },
    onButton2: () {
      selectedOption = ReshareOption.quickReshare; // <-- not seen
    },
  );

  return selectedOption;
}
```

### Minimal case C — reassignment after null check

```dart
Future<void> methodC(Activity activity) async {
  ContactModel? effectiveContact = activity.contact; // LINT — reassigned in if body

  if (effectiveContact == null && activity.uuid.isNotEmpty) {
    effectiveContact = await loadByUuid(activity.uuid); // <-- not seen
  }

  use(effectiveContact);
}
```

### Minimal case D — self-referential string reassignment

```dart
String? methodD(DateTime? dt) {
  String? displayTime = dt?.makeDisplayTime(); // LINT — reassigned in if body
  if (displayTime != null) {
    displayTime = 'at $displayTime'; // <-- not seen
  }
  return displayTime;
}
```

### Real-codebase examples (saropa contacts project)

| File | Line | Variable | Reassignment pattern |
|---|---|---|---|
| `lib/components/activity/recent_phone/activity_view_phone_dialer.dart` | 152 | `effectiveContact` | if-body |
| `lib/components/connection/reshare_options_dialog.dart` | 44 | `selectedOption` | closure (×4 callbacks) |
| `lib/components/contact/action_icons/action_icon_google_meet.dart` | 117 | `hasPermission` | if-body |
| `lib/components/contact/action_icons/action_icon_social_media.dart` | 70 | `text` | if-body |
| `lib/components/activity/activity_subtitle.dart` | 284 | `displayTime` | if-body |

`dart fix --dry-run` offers **zero** auto-fixes for these — the `PreferFinalLocalsFix` quick-fix does not trigger, which suggests the rule itself recognizes something is off but still emits the diagnostic.

**Frequency:** Always, on every file matching this pattern. 148 occurrences in one mid-size project.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — variable IS reassigned, so `final` is not valid |
| **Actual** | `[prefer_final_locals] Local variable that is never reassigned should be declared final.` reported at declaration token |

Applying the suggested `final` modifier in any of the above cases produces a compile error: `'x' can't be used as a setter because it's final` or `The final variable 'x' must be assigned before it can be used.`

---

## AST Context

For case A (`String? text = ...; if (...) { text = ...; }`):

```
MethodDeclaration
  └─ Block                                ← `block` in rule logic
      ├─ VariableDeclarationStatement     ← `stmt` in rule logic
      │   └─ VariableDeclarationList (node reported on)
      │       └─ VariableDeclaration (text)
      └─ IfStatement                      ← rule's _assignsToName returns false here,
          └─ Block                          because IfStatement is not an
              └─ ExpressionStatement        ExpressionStatement or ForStatement
                  └─ AssignmentExpression (text = '@saropa contacts')  ← invisible
```

For case B (closure reassignment):

```
MethodDeclaration
  └─ Block
      ├─ VariableDeclarationStatement (selectedOption)  ← flagged
      └─ ExpressionStatement
          └─ MethodInvocation (showDialogCommon)
              └─ ArgumentList
                  └─ NamedExpression (onButton1)
                      └─ FunctionExpression
                          └─ Block
                              └─ ExpressionStatement
                                  └─ AssignmentExpression (selectedOption = ...)  ← invisible
```

---

## Root Cause

The detector at `lib/src/rules/data/type_rules.dart:2763` (`_assignsToName`) only recognizes assignments in two shapes:

1. A sibling `ExpressionStatement` whose expression is an `AssignmentExpression` / `PrefixExpression` / `PostfixExpression` targeting the named variable.
2. A sibling `ForStatement`'s updater clause.

```dart
bool _assignsToName(Statement stmt, String name) {
  if (stmt is ExpressionStatement) {
    return _exprAssignsToName(stmt.expression, name);
  }
  if (stmt is ForStatement) {
    final parts = stmt.forLoopParts;
    if (parts is ForParts) {
      if (parts.updaters.isNotEmpty) {
        for (final u in parts.updaters) {
          if (u is AssignmentExpression && _lhsName(u) == name) return true;
          if (u is PrefixExpression || u is PostfixExpression) {
            if (_incDecTargetName(u) == name) return true;
          }
        }
      }
    }
  }
  return false; // <-- everything else (IfStatement, Block, WhileStatement,
                //     TryStatement, SwitchStatement, nested callbacks inside
                //     ExpressionStatement-wrapped MethodInvocations) returns
                //     false, so the outer loop concludes "never reassigned"
}
```

The outer loop at line 2744 walks only **sibling** statements in the same `Block`:

```dart
for (int i = idx + 1; i < statements.length; i++) {
  if (_assignsToName(statements[i], name)) {
    reassigned = true;
    break;
  }
}
```

So reassignments buried at any level of nesting — inside an `if` body, inside a closure passed to a method invocation, inside a `try` body — are structurally invisible to this detector.

### Why the narrow walk exists

The docstring at line 2693 says "Conservative: only checks statements after the declaration in the same block; assignments in nested blocks or for-loop updaters are considered." The for-loop-updater case IS handled, but **"nested blocks are considered"** is not actually implemented — the current code only reads sibling statements, never descends.

The intent was correct; the implementation is incomplete.

---

## Suggested Fix

Replace the shallow sibling-only scan with a descendant walk over the enclosing block (from the declaration onward). The simplest correct implementation is an `AstVisitor` that visits every `AssignmentExpression`, `PrefixExpression`, and `PostfixExpression` in the subtree — but bounded to nodes whose offset is **after** the declaration's end offset.

```dart
bool _isReassigned(Block block, VariableDeclarationStatement stmt, String name) {
  final int afterOffset = stmt.end;
  final _ReassignmentVisitor visitor = _ReassignmentVisitor(name, afterOffset);
  block.accept(visitor);
  return visitor.found;
}

class _ReassignmentVisitor extends RecursiveAstVisitor<void> {
  _ReassignmentVisitor(this.name, this.afterOffset);

  final String name;
  final int afterOffset;
  bool found = false;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (!found && node.offset >= afterOffset) {
      final Expression lhs = node.leftHandSide;
      if (lhs is SimpleIdentifier && lhs.name == name) {
        found = true;
        return;
      }
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (!found && node.offset >= afterOffset && _incDecOf(node) == name) {
      found = true;
      return;
    }
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (!found && node.offset >= afterOffset && _incDecOf(node) == name) {
      found = true;
      return;
    }
    super.visitPostfixExpression(node);
  }
}
```

### Scope caveat — shadowing

Because the visitor resolves by lexical name (`SimpleIdentifier.name`), it will incorrectly match a same-named variable declared in an inner scope. Two safer options:

- Resolve the declaring element (`node.staticElement` / `node.readElement`) and compare element identity, not name; OR
- Before recording a match, check there is no inner `VariableDeclaration` with the same name that shadows the outer declaration on the path from flagged node up to `block`.

Element-based comparison is preferred — it also handles cases where the variable escapes via closures.

### Also worth fixing while in the area

- `_lhsName` only handles `SimpleIdentifier`; compound targets like `x ??= foo` on a property (`this.x ??= ...`) would need `PropertyAccess` / `PrefixedIdentifier` handling if the rule is extended to fields.
- The rule skips variables whose name starts with `_` (line 2741). That filter makes sense for private-member intent but is an unusual constraint for *local* variables — private-naming locals are legal. Worth documenting or removing.

---

## Fixture Gap

The fixture at `example*/lib/data/prefer_final_locals_fixture.dart` (or wherever the rule's fixture lives) should cover:

1. **Reassignment inside `if` body** — expect NO lint
   ```dart
   String? x = a();
   if (cond) { x = b(); }
   ```
2. **Reassignment inside `else` body** — expect NO lint
3. **Reassignment inside a closure passed as an argument** — expect NO lint
   ```dart
   String result = '';
   runCallback(() { result = computed(); });
   ```
4. **Reassignment inside a `for` body (not the updater)** — expect NO lint
   ```dart
   int total = 0;
   for (final item in items) { total = total + item; }
   ```
5. **Reassignment inside `while`/`do-while`** — expect NO lint
6. **Reassignment inside `try` / `catch` / `finally`** — expect NO lint
7. **Reassignment inside `switch` case** — expect NO lint
8. **Nested block `{ ... }`** — expect NO lint
9. **Shadowed variable with same name in inner scope** — expect LINT on outer (outer IS never reassigned) and separately not crash
10. **Compound assignment operators** (`+=`, `??=`, `*=`) inside nested block — expect NO lint
11. **Truly never-reassigned local in a function with if/for/closures not touching it** — expect LINT (regression baseline)

The current fixture likely only covers the "truly never reassigned" happy path and the sibling-statement negative case.

---

## Changes Made

- **[lib/src/rules/data/type_rules.dart](../lib/src/rules/data/type_rules.dart)** — replaced the sibling-only `_assignsToName` / `_exprAssignsToName` / `_lhsName` / `_incDecTargetName` scan with a bounded descendant walk:
  - Added `_ReassignmentVisitor extends RecursiveAstVisitor<void>` that visits every `AssignmentExpression`, `PrefixExpression`, and `PostfixExpression` inside the enclosing `Block` and records a hit when (a) the node's offset is `>= stmt.end` (after the declaration, so the initializer and earlier statements are excluded) and (b) the LHS / operand `SimpleIdentifier` resolves to the declared element.
  - Resolution is **element-based**: `variable.declaredFragment?.element` at the declaration, compared against `SimpleIdentifier.element` at the write site. This is shadow-safe — an inner-scope `var name = ...` resolves to a different `LocalVariableElement`, so its writes do not count as reassignments of the outer variable.
  - For `++` / `--`: only `TokenType.PLUS_PLUS` and `TokenType.MINUS_MINUS` count as writes; `!`, `-`, `~` are reads and are ignored.
  - Compound assignments (`+=`, `??=`, `*=`, etc.) flow through `visitAssignmentExpression` because analyzer models them as `AssignmentExpression` with an operator other than `=`, and the LHS is still a `SimpleIdentifier` resolving to the declared element.
  - The docstring on `PreferFinalLocalsRule` now accurately describes the detection scope ("INCLUDING reassignments buried inside nested `if`/`else`, `for`/`while`/`do-while`, `try`/`catch`/`finally`, `switch` cases, nested `Block`s, and closures passed as arguments").
- **[CHANGELOG.md](../CHANGELOG.md)** — added a `### Fixed` entry under `[Unreleased]` and updated the overview sentence to mention the 148-false-positive sweep.

### Caveats preserved

- `variable.name.lexeme.startsWith('_')` skip is unchanged — the bug report flagged it as unusual for locals but it was out of scope for this fix.
- LHS is only matched when `leftHandSide is SimpleIdentifier`. Compound targets such as `this.x = ...` or `obj.x = ...` are out of scope (the rule is about *local* variables, which are always bare identifiers on the LHS).

---

## Tests Added

- **[example/lib/type/prefer_final_locals_fixture.dart](../example/lib/type/prefer_final_locals_fixture.dart)** — expanded from a 2-case stub to a full regression fixture covering every shape from the bug report plus shadowing and the baseline:
  1. `reassignInIfBody` — `if` body reassignment — expect NO lint
  2. `reassignInElseBody` — `else` body reassignment — expect NO lint
  3. `reassignInClosureArg` — closure passed as argument — expect NO lint
  4. `reassignInForBody` — for-body (not the updater) — expect NO lint
  5. `reassignInWhileBody` — while body — expect NO lint
  6. `reassignInDoWhileBody` — do/while body — expect NO lint
  7. `reassignInTry` — `try` / `catch` / `finally` — expect NO lint
  8. `reassignInSwitchCase` — switch case bodies — expect NO lint
  9. `reassignInNestedBlock` — bare `{ ... }` — expect NO lint
  10. `reassignCompoundInNested` — `+=` / `??=` inside `if` body — expect NO lint
  11. `reassignSelfRef` — `displayTime = 'at $displayTime'` pattern from the bug — expect NO lint
  12. `shadowedInnerReassignment` — inner shadow of same name; outer IS unchanged — expect LINT on outer
  13. `trulyNeverReassigned` — baseline: some other variable is reassigned but this one is not — expect LINT
  14. Original 2 cases (`placeholderPreferFinalLocals`) retained: baseline BAD / GOOD.
- **[test/type_rules_test.dart](../test/type_rules_test.dart)** — existing `prefer_final_locals` smoke test (`rule offers quick fix (add final to local)`) continues to pass unchanged. The project's per-rule behavioral coverage lives in the `example/` fixture, validated by `custom_lint` at publish time.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 12.4.1
- Dart SDK version: 3.11.4
- Flutter version: 3.41.6
- Triggering project/file: `d:/src/contacts` (148 diagnostics across `lib/components/**`)
- Disabled in triggering project: `analysis_options.yaml` line 937 set to `false` on 2026-04-24 pending this fix
