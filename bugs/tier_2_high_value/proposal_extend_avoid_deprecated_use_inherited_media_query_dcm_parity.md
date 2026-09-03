# PROPOSAL: Extend `avoid_deprecated_use_inherited_media_query` to Prefer Granular `MediaQuery` Accessors

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_deprecated_use_inherited_media_query`

---

## Summary

Extend `avoid_deprecated_use_inherited_media_query` (or add a sibling check registered under the same rule) to also flag `MediaQuery.of(context)` calls where only a single property (`.size`, `.padding`, `.viewInsets`, `.viewPadding`, `.devicePixelRatio`, `.textScaler`, etc.) is read, recommending the dedicated static accessor (`MediaQuery.sizeOf(context)`, `MediaQuery.paddingOf(context)`, `MediaQuery.viewInsetsOf(context)`, ...) instead — matching DCM's `prefer-dedicated-media-query-methods`, which fires on the general (non-deprecated) `MediaQuery.of(context)` pattern whenever a narrower accessor exists, not only on the deprecated `useInheritedMediaQuery` parameter.

**Closes gap:** DCM `prefer-dedicated-media-query-methods` (dcm.dev) — currently PARTIAL via saropa's `avoid_deprecated_use_inherited_media_query`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/config/flutter_sdk_migration_rules.dart:225-291` implements `AvoidDeprecatedUseInheritedMediaQueryRule`. Its scope is narrow and unrelated to the granular-accessor concern: it only looks for the named argument `useInheritedMediaQuery:` passed to `MaterialApp`/`CupertinoApp`/`WidgetsApp`:

```dart
static const _targetWidgets = {'MaterialApp', 'CupertinoApp', 'WidgetsApp'};
...
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  final typeName = node.constructorName.type.name.lexeme;
  if (!_targetWidgets.contains(typeName)) return;

  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression &&
        arg.name.label.name == 'useInheritedMediaQuery') {
      reporter.atNode(arg);
      return;
    }
  }
});
```

This is an entirely different pattern from what DCM's `prefer-dedicated-media-query-methods` targets: calling `MediaQuery.of(context)` to read only `.size` (or `.padding`, `.viewInsets`, etc.) rebuilds the widget on *every* `MediaQuery` change (orientation, text scale, brightness, platform brightness, keyboard insets — anything in the full `MediaQueryData`), not just the one property actually used. Flutter added dedicated static accessors (`MediaQuery.sizeOf`, `.paddingOf`, `.viewInsetsOf`, `.viewPaddingOf`, `.devicePixelRatioOf`, `.textScalerOf`, `.orientationOf`, `.platformBrightnessOf`, `.navigationModeOf`, `.gestureSettingsOf`, `.displayFeaturesOf`, `.accessibleNavigationOf`, `.boldTextOf`, `.disableAnimationsOf`, `.highContrastOf`, `.invertColorsOf`, `.alwaysUse24HourFormatOf`) precisely so a widget only rebuilds when the specific property it depends on changes — an unnecessary-rebuild performance issue distinct from the deprecated-parameter dead-code issue the existing rule catches.

## Detection / Behavior

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  // Subscribes to the ENTIRE MediaQueryData — rebuilds on orientation,
  // text scale, brightness changes even though only .size is used.
  final size = MediaQuery.of(context).size; // LINT
  return SizedBox(width: size.width);
}
```

```dart
final padding = MediaQuery.of(context).padding; // LINT — use MediaQuery.paddingOf(context)
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  final size = MediaQuery.sizeOf(context); // OK — subscribes only to size
  return SizedBox(width: size.width);
}
```

```dart
// OK — multiple distinct MediaQueryData properties are read from the same
// `.of(context)` result, so no single dedicated accessor could replace it
// without issuing multiple .of()-equivalent calls; not flagged.
Widget build(BuildContext context) {
  final mq = MediaQuery.of(context);
  return Column(children: [Text('${mq.size}'), Text('${mq.padding}')]);
}
```

## Proposed Tier

Tier: Recommended

Justification: keep parity with the existing rule's tier — `avoid_deprecated_use_inherited_media_query` is in `recommendedOnlyRules` (`lib/src/tiers.dart` line 883). This is a performance/rebuild-scoping best practice reachable early in a project's adoption curve, consistent with other Recommended-tier Flutter migration rules in the same file.

## Edge Cases

1. **Single property access chained directly off `.of(context)`** (`MediaQuery.of(context).size`) — the primary case; flag and offer a quick fix rewriting to `MediaQuery.sizeOf(context)`.
2. **Result assigned to a local, then only one property read off that local** (`final mq = MediaQuery.of(context); return mq.size;`) — should still flag; requires tracking whether the local variable's usages within the enclosing scope all resolve to a single `MediaQueryData` property.
3. **Multiple distinct properties read from the same `.of(context)` result** — should NOT flag (no single dedicated accessor covers it); this is the primary difference from a naive "always flag `.of(context)`" implementation and must be handled to avoid false positives on genuinely multi-property reads.
4. **No dedicated accessor exists for the property used** (e.g. `.systemGestureInsets`, `.displayFeatures` before they had `Of` variants in older Flutter SDKs) — should NOT flag if the SDK version in `pubspec.yaml`'s Flutter constraint predates the accessor's introduction, to avoid recommending an API that does not exist for the project's minimum SDK.
5. **`MediaQuery.maybeOf(context)`** — same rebuild-scoping issue applies; the dedicated accessors have `maybeXOf` counterparts (`MediaQuery.maybeSizeOf`, etc.) and should be recommended symmetrically.

## Alternatives Considered

- **New standalone rule** (`prefer_dedicated_media_query_methods`) — a reasonable alternative given the detection logic (property-of-`.of(context)`-result analysis) is unrelated to the existing rule's `InstanceCreationExpression`/named-argument walk. Proposing it as an extension here keeps this batch's one-to-one mapping with `plans/GAP_ANALYSIS.md`'s PARTIAL table (`avoid_deprecated_use_inherited_media_query` is the row's "Saropa Equivalent"), but the two checks can ship as sibling rules registered from the same file if the implementer finds sharing a single `LintCode`/message awkward given how different the detection AST shape is.
- **Blanket-flag every `MediaQuery.of(context)`** regardless of how many properties are read — rejected; would force `// ignore:` on the common, correct multi-property case and violates the project's stance against suppression-driving rules.

---

## Decision

---

## Implementation Notes

Add a new visitor (as a sibling class in `lib/src/rules/config/flutter_sdk_migration_rules.dart`, near `AvoidDeprecatedUseInheritedMediaQueryRule`) that registers on `MethodInvocation` for `MediaQuery.of`/`MediaQuery.maybeOf`, resolves the property-access chain (`PropertyAccess`/`PrefixedIdentifier` parent, or tracks the assigned local's usages within its enclosing block), and maps the accessed property name to its `*Of` accessor via a lookup table (`size` → `sizeOf`, `padding` → `paddingOf`, etc.) for the correction message and quick fix.

---

## Commits
