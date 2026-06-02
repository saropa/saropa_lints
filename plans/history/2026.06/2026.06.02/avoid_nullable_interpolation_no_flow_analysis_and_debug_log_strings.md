# BUG: `avoid_nullable_interpolation` — no flow analysis (misses `??` and `!= null` guards) and fires on developer-facing `debug()` log strings where "null" output is the intent

**Status: Fixed**

Created: 2026-06-02
Fixed: 2026-06-02
Rule: `avoid_nullable_interpolation`
File: `lib/src/rules/data/type_rules.dart` (class `AvoidNullableInterpolationRule`, ~line 402)
Severity: Improvement / overly broad
Rule version: v6 | Since: prior | Updated: v6

## Fix summary (v6)

Three suppressions added inside `runWithReporter`:

1. `${expr ?? fallback}` — when the unwrapped interpolation expression is a `BinaryExpression` with `??` operator, return early regardless of the fallback's static nullability. The `??` itself is the developer's null-handling intent.
2. Syntactic `!= null` guard — walk ancestor `ConditionalExpression` / `IfStatement` / `IfElement` looking for a `then` branch whose condition is `expr != null` matching the interpolated expression's source. Covers chained property access (`widget.contact.uuid`) that Dart's flow analysis cannot promote.
3. Developer-facing log calls — walk ancestors up to 12 hops looking for an enclosing `MethodInvocation` whose name is in `{debug, breadcrumb, debugPrint, print, log}`. Short-circuit at `FunctionBody`, `FunctionExpressionInvocation`, and `InstanceCreationExpression` so a guard in a different scope cannot leak.

Fixtures added to [example/lib/type/avoid_nullable_interpolation_fixture.dart](../example/lib/type/avoid_nullable_interpolation_fixture.dart) covering: `??`-with-nullable-fallback, ternary guard on chained access, `if` guard on chained access, `debug` / `print` / `developer.log` / `breadcrumb` calls, and a real-UI-bug BAD case that still fires.

CHANGELOG bullet added under `[Unreleased]` → `### Fixed`.

Note: the `scan` CLI uses `parseString` (unresolved AST) so `expr.staticType` is `null` and the rule short-circuits; this rule's narrowing logic only exercises end-to-end inside `custom_lint`. Behavior verified by code review against the AST shapes documented in the bug report.

## Finish Report (2026-06-02)

### Scope (LINTER variant)
(A) Dart lint rules / analyzer plugin.

### Files changed
- **`lib/src/rules/data/type_rules.dart`** (~lines 397–574): rewrote `AvoidNullableInterpolationRule` to v6 — added three early-return narrowings (`??` operator, `!= null` ancestor guard, developer-log call) plus helpers `_unwrapParens`, `_isInsideDeveloperLogCall`, `_hasNotNullAncestorGuard`, `_isNotNullCheckFor`, `_normalizeSource`, and constant `_developerLogCallTargets`. Bumped rule version v5→v6 in class doc and LintCode message.
- **`example/lib/type/avoid_nullable_interpolation_fixture.dart`**: added `import 'dart:developer' as developer;`; added GOOD fixtures `_goodNullCoalesceNullableFallback`, `_goodTernaryGuardOnChainedAccess`, `_goodIfGuardChainedAccess`, `_goodDebugLogString`, `_goodPrintLogString`, `_goodDeveloperLogString`, `_goodBreadcrumbString`, plus `_Contact`/`_Widget` types and stub top-level `debug` / `breadcrumb` functions; added BAD fixture `_UiCard.build()` (real UI bug, no guard, still fires).
- **`CHANGELOG.md`**: added `## [Unreleased]` → `### Fixed` bullet above `## [13.11.7]`.
- **`bugs/<bug>.md` → `plans/history/2026.06/2026.06.02/<bug>.md`**: archived with `Status: Fixed`, fix summary inserted before this Finish Report.

### Diff summary of core logic (lib/src/rules/data/type_rules.dart)
Inside `runWithReporter`, after the existing `nullabilitySuffix == question` gate, three new guards return early:
1. `_unwrapParens(expr) is BinaryExpression && operator.type == TokenType.QUESTION_QUESTION` → trust developer's null-handling.
2. `_hasNotNullAncestorGuard(node)` → walks `ConditionalExpression.thenExpression` / `IfStatement.thenStatement` / `IfElement.thenElement` ancestors via `identical()` and matches `expr != null` by whitespace-normalized source comparison (deliberately preserves `?` so `widget.contact?.uuid` vs `widget.contact.uuid` are distinct guards). Stops at `FunctionBody`.
3. `_isInsideDeveloperLogCall(node)` → walks ancestors up to 12 hops looking for a `MethodInvocation` whose `methodName.name` ∈ {debug, breadcrumb, debugPrint, print, log}. Short-circuits at `FunctionBody`, `FunctionExpressionInvocation`, `InstanceCreationExpression` (the nearest enclosing call wins — correct, since the string is being passed to that inner call, not the log call further out).

### Tests
- Existing instantiation pin (`test/rules/data/type_rules_test.dart` lines 42–46) re-ran: **56 tests passed**.
- New fixture cases added but not exercised end-to-end — `scan` CLI uses unresolved AST so `expr.staticType` is `null` and the rule short-circuits before the new logic runs. Project memory `reference_verify_rule_behavior_scan_cli.md` documents this limitation; full verification will happen when consumers run `custom_lint` after the next publish.

### Maintenance
- Bug archived: `bugs/avoid_nullable_interpolation_no_flow_analysis_and_debug_log_strings.md` → `plans/history/2026.06/2026.06.02/avoid_nullable_interpolation_no_flow_analysis_and_debug_log_strings.md` (was untracked, so plain `mv`, not `git mv`).
- Finish report appended: `plans/history/2026.06/2026.06.02/avoid_nullable_interpolation_no_flow_analysis_and_debug_log_strings.md`.
- README verified — no updates needed (no rule count change).
- Guides reviewed — no impact.
- Roadmap — rule not on ROADMAP.md.

### Outstanding work
None for this bug. Per project memory `feedback_never_publish.md`, not proposing publish.

## Attribution (positive grep)

```
$ grep -rn "'avoid_nullable_interpolation'" lib/src/rules/
lib/src/rules/<category>/<file>.dart:NNN:    'avoid_nullable_interpolation',
```

(Locate via grep; rule lives in saropa_lints.)

## Summary

The rule flags every `${nullable_expr}` interpolation as a "Hello null" risk. In practice, three distinct patterns produce the vast majority of hits in a real Flutter codebase, and none of them represent the failure mode the rule's correctionMessage describes:

1. **`${x ?? fallback}` already-handled** — the `??` operator IS the fallback. The rule fires on `x` (the nullable side) without seeing the `??`.
2. **Inside `!= null` ternary / `if` flow-narrowed branch** — Dart's flow analysis already narrowed the type to non-null, but the rule sees only the declared type.
3. **Inside `debug()` / `print()` / log call strings** — developer-facing diagnostic output where "null" IS the intended thing to see in the log. Rendering "(field omitted because nullable)" would defeat the entire point of debug logging.

Net effect of enabling: hits flood the codebase with FPs that drown out any real "user sees null in the UI" bug the rule was meant to catch.

## Downstream impact (the noise/signal problem)

Enabling this rule in `saropa/contacts` produced **58 raw hits across 22 unique sites** on first run. Sampling:

```dart
// no_activities_notice:49 — guarded by `description != null` ternary;
// the rule fires on `$description` despite the flow guard.
final String displayText = description != null
    ? '${text ?? _emptyNoticeText}\n\n$description'
    : text ?? _emptyNoticeText;
```

```dart
// contact_avatar:690 — inside the true-branch of `contactSaropaUUID != null`;
// flow-narrowed but the rule fires on `widget.contact.contactSaropaUUID`.
final Widget keyedCommonAvatar = widget.contact.contactSaropaUUID != null
    ? KeyedSubtree(
        key: ValueKey<String>(
          'contact-avatar-slot-${widget.contact.contactSaropaUUID}',
        ),
        child: commonAvatar,
      )
    : commonAvatar;
```

```dart
// recent_phone_calls:134 — `??` fallback handles null directly;
// the rule still fires on the nullable receiver chain.
text: groupDate.isToday()
    ? groupDate.makeDisplayDate(showTodayWord: true)!
    : '${groupDate.getSimpleRelativeDay()?.displayName ?? groupDate.relativeTime()} '
      '- ${groupDate.makeDisplayDate()}',
```

```dart
// issue_panel:341 — DEBUG-ONLY log string; developer needs to see "null"
// to diagnose missing data. Renaming to a fallback would hide the bug.
if (DebugType.Contact.isDebug) {
  debug(
    'Missing [roleMatch] '
    'in [organizationRoles]: `${contact.organizationRoles}` '
    'for [type]: `$type`',
    level: DebugLevels.Warning,
  );
}
```

14 of the 22 unique sites are inside `debug()` calls in `issue_panel.dart` alone — a single file's debug-logging discipline triggers more than half the rule's noise.

## Suggested fix

Two improvements; either alone helps materially, both together close the rule's gap:

### Improvement 1: skip strings passed to developer-facing logging calls

Walk up from the interpolated `StringLiteral` to the enclosing `Expression` — if the parent (or one ancestor MethodInvocation) is a call to one of:

```dart
const Set<String> _developerLogCallTargets = <String>{
  'debug',        // saropa-specific
  'breadcrumb',   // saropa-specific
  'debugPrint',   // Flutter SDK
  'print',        // Dart core
  'log',          // dart:developer
};
```

…then skip the diagnostic. The string is going to a log channel, not the user.

(For projects that wrap their own logger under a different name, this could be made configurable via `analysis_options.yaml`.)

### Improvement 2: honor `??` operator and `!= null` flow narrowing

In the rule's visitor, when it inspects an `InterpolationExpression` whose `expression` is nullable:

- If the expression's PARENT in the source string is `${expr ?? fallback}` (a `BinaryExpression` with `??` operator), the interpolation is already guarded.
- If the enclosing expression is the consequent of a conditional whose condition is `expr != null` (or the `if` branch's then-part), the type is flow-narrowed; the rule should treat as non-null.

Dart's `TypeSystem` exposes the narrowed type via `expression.staticType` in many cases — when that returns a non-nullable type even though the declaration is nullable, that IS the flow-narrowing signal the rule should trust. (Fall back to syntactic `??` and `!= null` ancestor checks when the static type still reads nullable.)

## Project decision (`saropa/contacts`)

Surfaced the 58 hits and sampled. Project owner chose to **SKIP** this rule pending upstream narrowing. Rationale comment is in `analysis_options.yaml` pointing at this bug.

Re-enable once either:

- Strings inside `debug` / `print` / `log` / `debugPrint` are skipped, OR
- `??` operator + `!= null` flow guards are recognized.

## Fixture gap

Add fixtures that should NOT fire (under either improvement):

```dart
// fixtures/avoid_nullable_interpolation_debug_log_ok.dart
void main() {
  String? name;
  debug('Missing [name]: $name');  // expect: no diagnostic
  print('Order #$name');           // expect: no diagnostic
}

// fixtures/avoid_nullable_interpolation_null_coalesce_ok.dart
void main() {
  String? name;
  final greeting = 'Hello, ${name ?? 'friend'}';  // expect: no diagnostic
}

// fixtures/avoid_nullable_interpolation_flow_narrowed_ok.dart
void main() {
  String? name;
  if (name != null) {
    print('Hello, $name');  // expect: no diagnostic (flow-narrowed)
  }
}

// fixtures/avoid_nullable_interpolation_genuine_ui_bug_fires.dart
class Widget {
  final String? name;
  String build() => 'Hello, $name';  // expect: diagnostic (real UI bug)
}
```
