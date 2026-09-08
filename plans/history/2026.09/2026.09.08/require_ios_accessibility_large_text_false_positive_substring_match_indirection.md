# BUG: `require_ios_accessibility_large_text` — substring match can't see through helper indirection

**Status: Fixed**

Created: 2026-09-08
Rule: `require_ios_accessibility_large_text`
File: `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart` (line ~2662)
Severity: False positive
Rule version: v2

---

## Summary

The rule flags a `TextStyle(fontSize: ...)` construction as not respecting
iOS Dynamic Type unless the `fontSize` expression's **source text**
literally contains one of three substrings (`textScaleFactor`,
`textScaler`, `MediaQuery`), or an ancestor node's source text matches
`textTheme`/`ThemeData`. Any expression that resolves Dynamic-Type-aware
scaling through a named helper/getter — e.g. a project's own
`ThemeCommonFontSize.size` getter, which internally reads
`MediaQuery`/`textScaler` inside its own implementation — has none of
those literal substrings at the call site and is flagged even though the
scaling is already handled, one indirection layer down.

---

## Attribution Evidence

```bash
grep -rn "'require_ios_accessibility_large_text'" lib/src/rules/
# lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:2688:    'require_ios_accessibility_large_text',
```

**Emitter registration:** `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:2688`
**Rule class:** `RequireIosAccessibilityLargeTextRule` — defined at
`lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:2662`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
import 'package:flutter/widgets.dart';

/// Project's own font-size token — internally applies Dynamic Type scaling
/// (imagine `theme_common_font.dart`'s `_updateSizes` reading
/// `MediaQuery.textScalerOf(context)` once per size-change and caching the
/// scaled value on this getter).
enum ThemeCommonFontSize {
  medium;

  // In the real project this reads MediaQuery/textScaler internally — but
  // that happens INSIDE this getter's implementation, not in the call-site
  // source text the rule inspects.
  double get size => 14.0;
}

Widget example() {
  return const Text(
    'Hello',
    // `.size` already bakes in Dynamic Type scaling one layer down — but
    // the call-site source is just `ThemeCommonFontSize.medium.size`, which
    // contains none of the three substrings
    // ('textScaleFactor'/'textScaler'/'MediaQuery') the rule pattern-matches
    // against, and no ancestor node's source contains 'textTheme'/'ThemeData'
    // either.
    style: TextStyle(fontSize: ThemeCommonFontSize.medium.size), // LINT — but should NOT lint
  );
}
```

**Frequency:** Always, for any `fontSize:` expression that resolves
Dynamic-Type-aware scaling through a helper method/getter/extension whose
own name doesn't happen to contain one of the three matched substrings.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `ThemeCommonFontSize.medium.size` already applies Dynamic Type scaling internally |
| **Actual** | `[require_ios_accessibility_large_text] Hardcoded font size may not respect iOS Dynamic Type...` reported on the `TextStyle(...)` node |

---

## AST Context

```
InstanceCreationExpression (TextStyle(...))
  └─ ArgumentList
      └─ NamedExpression (fontSize:)
          └─ PropertyAccess (ThemeCommonFontSize.medium.size)  ← node.getNamedParameterValue('fontSize')
              — toSource() == "ThemeCommonFontSize.medium.size"
              — contains none of 'textScaleFactor' / 'textScaler' / 'MediaQuery'
```

---

## Root Cause

`lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:2712-2734`:

```dart
final Expression? fontSize = node.getNamedParameterValue('fontSize');
if (fontSize != null) {
  final String fontSizeSource = fontSize.toSource();
  if (fontSizeSource.contains('textScaleFactor') ||
      fontSizeSource.contains('textScaler') ||
      fontSizeSource.contains('MediaQuery')) {
    return;
  }

  AstNode? current = node.parent;
  while (current != null) {
    final String currentSource = current.toSource();
    if (_themeSourceRegex.any((re) => re.hasMatch(currentSource))) {
      return; // Part of theme definition
    }
    current = current.parent;
  }

  reporter.atNode(node);
}
```

### Hypothesis A (confirmed): the check is textual, not semantic

The exemption is pure string matching on `Expression.toSource()` — the
literal characters typed at the call site — rather than resolving what the
expression actually evaluates to. `usesTypeResolution` is already `true`
for this rule (declared at line 2685), so the infrastructure to inspect
static types/elements is available but unused for this specific check. Any
one-hop indirection (a getter, a static method, a top-level function, an
extension property) that itself performs Dynamic-Type-aware scaling is
invisible to a source-text substring scan.

---

## Suggested Fix

Two complementary options, in order of robustness:

1. **Resolve to the declaration and check its own body.** When `fontSize`
   is a `PropertyAccess`/`PrefixedIdentifier`/`MethodInvocation` whose
   `staticElement` resolves to a getter/method declared in the same
   package, recurse one level: inspect that declaration's body source (or
   AST) for the same three substrings before giving up. This handles the
   common "project design-system token" case without a full data-flow
   analysis.
2. **Escape hatch: a project-configurable allowlist.** Let a project
   register known Dynamic-Type-safe getters/methods (by qualified name) in
   `saropa_lints` config (similar to how other rules expose
   project-specific overrides), so a project like `d:/src/contacts` can
   declare `ThemeCommonFontSize.size` as pre-approved without a per-call-site
   `// ignore:`.

Option 2 is lower-effort and directly unblocks the downstream false
positives; option 1 is the more general fix and should be tracked
separately if not done together.

---

## Fixture Gap

The fixture (find via `grep -rn 'RequireIosAccessibilityLargeTextRule' example_packages/`) should include:

1. **`TextStyle(fontSize: SomeDesignSystemToken.medium.size)`** where the
   referenced getter's own body reads `MediaQuery`/`textScaler` — expect NO
   lint once the fix lands (currently LINTs, this report's reproducer).
2. Keep existing **`TextStyle(fontSize: 14.0)`** (bare literal) — expect
   LINT (already covered, must still fire).
3. Keep existing **`TextStyle(fontSize: MediaQuery.textScalerOf(context).scale(14))`** — expect NO lint (already covered).

---

## Changes Made

- `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart`:
  - Replaced substring-based exemption with `_isHardcodedNumeric()` +
    `_isConstIdentifier()` guards. The rule now flags `fontSize` expressions
    that are bare numeric literals, const-qualified identifiers/fields, negated
    literals (recursively), parenthesized literals, or arithmetic on those.
  - Non-const getters, method calls, and property accesses are excluded — they
    may apply Dynamic Type scaling internally (the original FP).
  - Removed the now-dead `textScaleFactor`/`textScaler`/`MediaQuery` substring
    block — `_isHardcodedNumeric` can never return `true` for expressions
    containing those identifiers.
  - Added `import 'package:analyzer/dart/ast/token.dart'` for `TokenType.MINUS`
    and `import 'package:analyzer/dart/element/element.dart'` for
    `VariableElement`/`PropertyAccessorElement`.
- `example/lib/ios/require_ios_accessibility_large_text_fixture.dart`:
  - Added `ThemeCommonFontSize` enum + `_goodGetterIndirection()` GOOD case.
  - Fixed header source comment (was `ios_rules.dart`, now
    `ios_capabilities_permissions_rules.dart`).
- `CHANGELOG.md`: Added entry under `### Fixed`.

---

## Tests Added

- Fixture case: `_goodGetterIndirection()` — `TextStyle(fontSize: ThemeCommonFontSize.medium.size)` must NOT lint.
- Instantiation pin (`ios_rules_test.dart`) and quick fix presence test pass.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: v2 (rule version)
- Triggering project/file: `d:/src/contacts` —
  `lib/components/contact/contact_display_name.dart:149,394,409` (all three
  route through `ThemeCommonFontSize.*.size`/`.down.size`, which apply
  native/user text-scale internally per `theme_common_font.dart
  _updateSizes` — see that file for the actual scaling implementation).

---

## Finish Report (2026-09-08)

`require_ios_accessibility_large_text` flagged any `TextStyle(fontSize:)` whose
call-site source text did not contain `textScaleFactor`, `textScaler`, or
`MediaQuery` as a substring. Expressions routed through a project design-system
getter (e.g. `ThemeCommonFontSize.medium.size`) were flagged as false positives
because the scaling logic lived inside the getter's body, invisible to source-text
pattern matching.

**Root cause:** The exemption was purely textual (`Expression.toSource().contains(…)`)
rather than semantic. `usesTypeResolution` was already `true` but unused for this
check.

**Fix:** Replaced the substring-match heuristic with a structural AST check
(`_isHardcodedNumeric` + `_isConstIdentifier`). The rule now only flags `fontSize`
expressions that are:
- Bare numeric literals (`14`, `14.0`)
- Const-qualified identifiers (`kFontSize`, `AppFonts.small`)
- Negated, parenthesized, or arithmetic combinations of the above

Non-const getters, method calls, and property accesses are excluded — they may
apply Dynamic Type scaling internally, so flagging them is unsound without
cross-file body inspection (which is infeasible in the lint rule context).

**Review-driven improvements:** Code review identified three issues in the
initial implementation: (1) the substring exemption block became dead code after
the `_isHardcodedNumeric` gate — removed; (2) negation check did not recurse, so
`-(14)` was missed — made recursive; (3) named const identifiers (`kFontSize`)
were silently skipped, a genuine false negative — added `_isConstIdentifier` to
catch compile-time-constant font sizes while still exempting non-const getters.

**Hardening (post-review):** Added depth guard (`_maxNumericDepth = 8`) to
`_isHardcodedNumeric` to prevent stack overflow on pathologically nested
arithmetic. Added fixture cases for non-const method calls and non-const
parameters (both GOOD/no-lint). Fixed the DartDoc comment on the rule class,
which was a copy-paste error describing push notifications.

**Config feature:** Added `scaling_aware:` allowlist in
`analysis_options_custom.yaml` under `require_ios_accessibility_large_text:`.
Projects can declare getter/method names that apply Dynamic Type scaling
internally — the rule checks the expression's terminal name against this set
before the `_isHardcodedNumeric` gate, so allowlisted non-const getters are
exempted without requiring per-call-site `// ignore:`.

**New files:**
- `lib/src/config/require_ios_accessibility_large_text_config.dart` — config
  loader for the `scaling_aware:` section.
- `test/config/require_ios_accessibility_large_text_config_test.dart` — 11
  tests covering null/empty/missing/single/multiple/quoted/stop/blank/reload.

**Verification:** Instantiation pin and quick fix presence tests pass. Config
tests pass (11/11). Scan CLI cannot exercise this rule against mock fixtures
(known limitation: fixtures are skipped by `SaropaContext._shouldSkipCurrentFile`,
and the example project's mock `TextStyle` lacks full Flutter resolution).
Behavioral coverage relies on the fixture's `// expect_lint:` annotations
processed by the fixture test harness.
