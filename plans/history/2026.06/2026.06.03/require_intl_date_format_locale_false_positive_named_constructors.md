# require_intl_date_format_locale — False Positive on named constructors that DO pass a locale

- **Status:** Fixed
- **Created:** 2026-06-03
- **Rule:** `require_intl_date_format_locale`
- **Rule class:** `RequireIntlDateFormatLocaleRule` (`lib/src/rules/ui/internationalization_rules.dart:1309`)
- **Registration:** `lib/saropa_lints.dart:862` (`RequireIntlDateFormatLocaleRule.new`)
- **Severity:** WARNING
- **Rule version:** v2
- **Reported from:** `D:\src\contacts\lib\utils\primitive\date_time\date_formatting.dart` (16 occurrences: lines 216, 217, 250, 252, 256, 258, 300, 370, 373, 376, 379, 407, 443)

## Summary

The rule flags every `DateFormat.<namedConstructor>(locale)` call (e.g. `DateFormat.yMMMMd(_locale)`) as "created without an explicit locale parameter" — even though the locale **is** passed. Named constructors take the locale as their first (and only relevant) positional argument, but the rule evaluates them under the unnamed-constructor branch, which requires `args.length >= 2`. A correct one-argument named-constructor call therefore looks like "1 arg < 2 → missing locale".

What should happen: `DateFormat.yMd(locale)` (locale present) must NOT fire; `DateFormat.yMd()` (no locale) should fire.

## Attribution Evidence

Positive grep (rule lives in saropa_lints):

```
$ grep -rn "'require_intl_date_format_locale'" D:/src/saropa_lints/lib/src/rules/
lib/src/rules/ui/internationalization_rules.dart:1325:    'require_intl_date_format_locale',
```

Negative grep (not emitted by the sibling drift-advisor plugin):

```
$ grep -rn "require_intl_date_format_locale" D:/src/saropa_drift_advisor/lib/ D:/src/saropa_drift_advisor/extension/ 2>/dev/null
(only D:\src\saropa_drift_advisor\analysis_options.yaml — config, not a rule definition)
```

## Reproducer

```dart
import 'package:intl/intl.dart';

String fmt(DateTime d, String locale) {
  // OK — locale IS provided as the named constructor's only argument.
  // Currently FIRES (false positive).
  final a = DateFormat.yMMMMd(locale).format(d); // LINT (should be OK)
  final b = DateFormat.jm(locale).format(d);     // LINT (should be OK)

  // OK — unnamed two-arg constructor with locale. Correctly NOT flagged today.
  final c = DateFormat('yMMMMd', locale).format(d); // OK

  // BAD — named constructor with NO locale. Should fire (and does, via args.isEmpty).
  final e = DateFormat.yMMMMd().format(d); // LINT (correct)

  // BAD — unnamed constructor with no locale. Correctly flagged today.
  final f = DateFormat('yMMMMd').format(d); // LINT (correct)

  return '$a $b $c $e $f';
}
```

## Expected vs Actual

| Call | Expected | Actual |
|---|---|---|
| `DateFormat.yMMMMd(locale)` | OK | **LINT (FP)** |
| `DateFormat.jm(locale)` | OK | **LINT (FP)** |
| `DateFormat('yMMMMd', locale)` | OK | OK |
| `DateFormat.yMMMMd()` | LINT | LINT |
| `DateFormat('yMMMMd')` | LINT | LINT |

## AST Context

`DateFormat.yMMMMd(_locale)` parses as an **`InstanceCreationExpression`** (named constructor), not a `MethodInvocation`:

```
InstanceCreationExpression
  constructorName: ConstructorName
    type: NamedType (name.lexeme == 'DateFormat')
    name: SimpleIdentifier ('yMMMMd')   <-- named constructor segment
  argumentList: ArgumentList
    arguments: [ SimpleIdentifier('_locale') ]   // length == 1
```

## Root Cause

`runWithReporter` has two handlers:

1. `addInstanceCreationExpression` (lines 1338–1348): checks `node.constructorName.type.name.lexeme == 'DateFormat'`, then `if (args.length < 2) reporter.atNode(node)`. This branch does **not** inspect `node.constructorName.name`, so it treats `DateFormat.yMMMMd(locale)` (a named constructor, 1 arg) identically to `DateFormat('pattern')` (unnamed, 1 arg) and reports it.

2. `addMethodInvocation` (lines 1351–1390): the branch intended to handle named factory constructors (`yMd`, `jm`, …) checking `argumentList.arguments.isEmpty`. This is **dead code** for these calls: named constructors are `InstanceCreationExpression`s, not `MethodInvocation`s, so this handler never fires for `DateFormat.yMMMMd(...)`.

Net: named constructors are mis-handled by branch 1 (demands 2 args) and never reach the correct logic in branch 2.

## Suggested Fix

In the `addInstanceCreationExpression` handler, branch on `node.constructorName.name`:

- **Unnamed constructor** (`node.constructorName.name == null`): keep `args.length < 2` (pattern + locale required) — current behavior is correct.
- **Named constructor** (`node.constructorName.name != null`): the locale is the first positional arg, so fire only when `args.isEmpty` (mirroring the intended branch-2 logic). Optionally restrict to the known `factoryMethods` set already defined at lines 1362–1382.

The `addMethodInvocation` handler can then be removed (it is dead for named constructors) or retained only for genuine static-method forms if any exist.

## Fixture Gap

`example/lib/internationalization/require_intl_date_format_locale_fixture.dart` is an empty stub (`// TODO: Add bad/good examples`). It has **zero** cases. Add:

- GOOD: `DateFormat.yMMMMd(locale)`, `DateFormat.jm(locale)`, `DateFormat('yMMMMd', locale)` — must NOT lint.
- BAD: `DateFormat.yMMMMd()`, `DateFormat('yMMMMd')` — must lint.

## Environment

- saropa_lints: 13.11.9 (consumed in contacts as `^13.11.9`)
- Dart SDK: `>=3.10.7 <4.0.0`; Flutter `>=3.44.0`
- Plugin mode: native `analysis_server_plugin` (IDE analysis server only; `flutter analyze` CLI does not surface these)
- Triggering file: `D:\src\contacts\lib\utils\primitive\date_time\date_formatting.dart`

## Finish Report (2026-06-03)

**Fixed in** `lib/src/rules/ui/internationalization_rules.dart`.

The `addInstanceCreationExpression` handler now branches on `node.constructorName.name`:

- **Unnamed** (`name == null`) — `DateFormat(pattern, locale)`: unchanged, fires when `args.length < 2` (locale is the second arg).
- **Named** (`name != null`) — `DateFormat.yMd(locale)`: fires only when the constructor is in the known `_factoryConstructors` set AND `args.isEmpty`, because the locale is the sole positional argument. This removes the false positive.

**The bug report's "remove the `addMethodInvocation` handler" advice was not followed — and that was deliberate.** The suggested-fix and root-cause sections assume `DateFormat.yMd(...)` is always an `InstanceCreationExpression`. That is true only when `intl` *resolves*: the Dart parser produces a `MethodInvocation` first and the resolver rewrites it to an `InstanceCreationExpression` once the constructor binds. In partially-analyzed or unresolved contexts the node stays a `MethodInvocation`, so that handler is the live detection path there — not dead code. It was kept and rewritten to share the `_factoryConstructors` set and mirror the named-constructor logic (`args.isEmpty`). The two node types are mutually exclusive for any single call site, so no double-reporting occurs.

**Verification.** The saropa_lints scan CLI is parse-only (it never resolves `intl`, even with a real `intl` dependency present in the scanned project — confirmed by adding one). It therefore exercises the `MethodInvocation` path. Against the new fixture:

- GOOD `DateFormat.yMMMMd(locale)`, `DateFormat.jm(locale)`, `DateFormat.yMd(locale)`, `DateFormat('yyyy-MM-dd', locale)` — no fire.
- BAD `DateFormat.yMMMMd()`, `DateFormat.jm()` — fire.

The resolved `InstanceCreationExpression` path (the one the IDE plugin uses on the contacts project) is covered by code reasoning, not the CLI, because the CLI cannot resolve. Note: the unnamed BAD case `DateFormat('yyyy-MM-dd')` does not fire under the parse-only CLI (the parser sees a target-less invocation, not an `InstanceCreationExpression`); it does fire in the resolved IDE. This is a pre-existing CLI limitation, unchanged by this fix.

**Fixture.** `example/lib/internationalization/require_intl_date_format_locale_fixture.dart` populated with the GOOD/BAD cases above (was an empty stub).

**Changelog.** Entry added under `[Unreleased] → Fixed`.
