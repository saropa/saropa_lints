# Bug: `prefer_wildcard_for_unused_param` false positive on named parameter overrides

**Status:** Fixed
**Rule:** `prefer_wildcard_for_unused_param` (v4)
**Severity:** False positive — flags valid code that cannot be fixed as suggested
**Plugin version:** saropa_lints

## Problem

The rule flags **named parameters in method overrides** (e.g. `toString({DiagnosticLevel minLevel = DiagnosticLevel.info})`) as needing a `_` wildcard replacement. However, Dart does not allow named parameters to start with an underscore — the compiler emits:

> Named parameters can't start with an underscore.

Additionally, the parameter **name must match the base class declaration** for the override to be valid. Renaming `minLevel` to anything else would produce:

> '_ClassName.toString' ('String Function({DiagnosticLevel _})') isn't a valid override of 'Diagnosticable.toString' ('String Function({DiagnosticLevel minLevel})').

## Reproduction

**File:** `lib/src/drift_viewer_floating_button.dart`, lines 279, 305, 472, 490, 511, 536, 567, 593, 609
**File:** `lib/src/drift_viewer_overlay.dart`, line 54

```dart
class _WebViewErrorScreen extends StatelessWidget {
  const _WebViewErrorScreen({required this.urlSample});

  final String urlSample;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_WebViewErrorScreen(urlSample: $urlSample)';
}
```

**Diagnostic output:**

```
[prefer_wildcard_for_unused_param] Unused parameter obscures intent and signals
incomplete API design. Replacing it with a _ wildcard (Dart 3.7+) makes the
function signature self-documenting, communicating that the parameter exists for
interface conformance but is intentionally ignored in this implementation. {v4}
Replace the parameter with _ to make the function signature self-documenting and
signal that the value is intentionally unused.
```

## Why this is wrong

1. **Dart forbids `_`-prefixed named parameters.** The Dart language spec does not allow named parameters whose name starts with `_`. This is a hard compiler error, not a style choice.

2. **Override signatures must match the base class.** The `toString` method is declared on `Diagnosticable` with the named parameter `minLevel`. Any override must use the same parameter name. There is no way to rename it.

3. **The suggestion is impossible to follow.** The lint tells the developer to do something the compiler forbids. This creates noise with no actionable fix.

## Expected behavior

The rule should NOT fire when:

- The parameter is a **named parameter** (named parameters cannot use `_` wildcards)
- The parameter is part of a **method override** where the name is dictated by the superclass

## Suggested fix

Add a check to skip named parameters:

```dart
// Skip named parameters — Dart does not allow _ prefix on named params
if (parameter.isNamed) {
  return;
}
```

Or more specifically, skip named parameters in override methods:

```dart
if (parameter.isNamed && _isOverrideMethod(node)) {
  return;
}
```

## Impact

Every `StatelessWidget` and `StatefulWidget` subclass that overrides `toString` triggers this false positive. In `drift_viewer_floating_button.dart` alone, 9 instances are flagged. Across a typical Flutter app with dozens of widget classes overriding `toString`, this generates significant noise for a fix that is literally impossible to apply.
