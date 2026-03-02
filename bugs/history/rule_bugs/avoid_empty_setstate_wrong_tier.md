# Bug: `avoid_empty_setstate` belongs in comprehensive tier, not recommended

## Summary

`avoid_empty_setstate` is a stylistic preference that flags a common, valid Flutter pattern. It does not catch bugs or prevent common mistakes. It should be moved from the **recommended** tier ("common mistakes, performance basics") to the **comprehensive** tier ("code quality, style, and edge cases").

## Problem

The rule flags every `setState(() {})` with an empty callback as a style concern, suggesting the developer move state changes inside the callback. However, `setState(() {})` is an intentional and idiomatic Flutter pattern in several well-established scenarios where state mutation *cannot* be placed inside the callback:

### 1. Async state mutation with `mounted` guard

The `setState` callback must be synchronous. After an `await`, the mutation has already happened and the `mounted` check must precede the `setState` call. There is no way to restructure this code to satisfy the rule:

```dart
_activeTargetName = await loadFocusModeTargetName(
  mode: _currentMode,
  targetId: targetId,
);

// Rule flags this, but mutation above is async — cannot move inside callback
if (mounted) setState(() {});
```

### 2. Synchronous mutation in a helper called before setState

State is modified in a separate method for readability, then `setState` triggers the rebuild:

```dart
void _onSearchChanged() {
  _computeGroupedContacts(); // mutates _groupedContacts
  if (mounted) setState(() {});
}
```

### 3. Stream/listener callbacks requesting a rebuild

State was mutated elsewhere (e.g. by a `UserPreference` change); the listener just needs a rebuild:

```dart
_focusModeSubscription = <UserPreferenceType>[
  UserPreferenceType.ActiveContactFocusMode,
].notify()?.listen((_) {
  if (mounted) setState(() {});
});
```

### 4. `_setStateSafe()` utility pattern

The project codifies this as a reusable helper. The rule flags the helper itself:

```dart
void _setStateSafe() {
  if (mounted) setState(() {});
}
```

This pattern is documented in the project's coding standards and is a recognized Flutter idiom. The rule's own `problemMessage` acknowledges this: *"state was likely modified before this call"* — proving the rule knows the code is valid.

## Why this matters for tier placement

The tier hierarchy is:

| Tier | Purpose |
|---|---|
| **essential** | Must-fix bugs and crashes |
| **recommended** | Common mistakes, performance basics — the default tier |
| **professional** | Architecture, testing, maintainability |
| **comprehensive** | Code quality, style, edge cases — "quality-obsessed teams" |
| **pedantic** | Everything, noisy style preferences |

The **recommended** tier description is *"Essential + common mistakes, performance basics, accessibility basics. The default tier for most teams."* The section header where the rule sits is *"FLUTTER WIDGETS - Correct usage"*.

An empty `setState` callback is **not incorrect usage**. It is not a common mistake. It is not a performance problem. It is a style preference about *where* to place state mutations — and in the async case, the "preferred" placement is impossible.

A rule in the recommended tier should either:
- Catch a bug (this doesn't)
- Prevent a common mistake (this doesn't — the pattern is intentional)
- Improve performance (this doesn't — the rebuild cost is identical)

It is purely a code clarity opinion, which is exactly what the comprehensive tier is for.

## Previous fix history

The earlier bug report (`bugs/_history/avoid_empty_setstate severity.md`) correctly identified that the original WARNING severity and message ("Empty setState callback has no effect") were wrong. The severity was downgraded to INFO and the message reworded. However, the tier placement was not addressed at that time.

The severity fix was necessary but insufficient. An INFO-level stylistic rule in the recommended/default tier still generates noise for every team using the default configuration. The tier is the more impactful lever — it controls which teams see the rule at all.

## Affected code in `contacts` project

All 5 occurrences are intentional, using the `if (mounted) setState(() {})` idiom:

| File | Line | Pattern |
|---|---|---|
| `contact_focus_mode_dialog.dart` | 125 | Async state mutation after `await` |
| `contact_focus_mode_dialog.dart` | 173 | Sync mutation in helper, then rebuild |
| `app_search_bar.dart` | 178 | Stream listener requesting rebuild |
| `note_list_screen.dart` | 217 | Sync mutation in helper, then rebuild |
| `import_progress_dialog.dart` | 181 | `_setStateSafe()` utility method |

None of these can be restructured to place the mutation inside the callback without making the code worse (duplicating logic, losing the `mounted` guard, breaking the helper pattern).

## Suggested fix

Move the rule from `recommended.yaml` to `comprehensive.yaml`:

### In `lib/tiers/recommended.yaml`

Remove from the "FLUTTER WIDGETS - Correct usage" section:

```yaml
# Remove this line:
avoid_empty_setstate: true
```

### In `lib/tiers/comprehensive.yaml`

Add to the "FLUTTER WIDGETS - Complete" section:

```yaml
# FLUTTER WIDGETS - Complete
avoid_border_all: true
avoid_incorrect_image_opacity: true
avoid_empty_setstate: true            # stylistic: prefer mutations inside callback
# ... rest of section
```

## Alternative: suppress when preceded by `mounted` check

A complementary improvement (not a substitute for the tier move) would be to not flag `setState(() {})` when it appears inside an `if (mounted)` guard, since this pattern is always intentional:

```dart
// In AvoidEmptySetStateRule.runWithReporter:
if (body is BlockFunctionBody && body.block.statements.isEmpty) {
  // Don't flag if inside a mounted guard — this is intentional
  final AstNode? parent = node.parent;
  if (parent is ExpressionStatement) {
    final AstNode? grandparent = parent.parent;
    if (grandparent is Block) {
      final AstNode? ifStatement = grandparent.parent;
      if (ifStatement is IfStatement) {
        final Expression condition = ifStatement.expression;
        if (_isMountedCheck(condition)) return;
      }
    }
  }
  reporter.atNode(node, code);
}
```

This would eliminate the most common false-positive pattern while still flagging genuinely suspicious empty `setState` calls (e.g. `setState(() {})` with no nearby state mutation).

## File references

- Rule implementation: `lib/src/rules/widget_lifecycle_rules.dart` lines 172-232
- Tier config (current): `lib/tiers/recommended.yaml` line 61
- Tier config (target): `lib/tiers/comprehensive.yaml` (FLUTTER WIDGETS section)
- Previous severity fix: `bugs/_history/avoid_empty_setstate severity.md`
