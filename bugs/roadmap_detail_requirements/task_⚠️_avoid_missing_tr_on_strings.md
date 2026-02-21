# Task: `avoid_missing_tr_on_strings`

## Summary
- **Rule Name**: `avoid_missing_tr_on_strings`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.62 Intl/Localization Rules

## Problem Statement

Similar to `avoid_missing_tr`, this rule focuses on detecting user-visible strings that aren't wrapped in translation calls. The distinction is that this rule looks at STRING LITERALS in any user-visible context (not just `Text` widget arguments), while `avoid_missing_tr` is more widget-specific.

## Description (from ROADMAP)

> User-visible strings should use translation methods.

## Relationship to `avoid_missing_tr`

**These two rules are essentially duplicates.** Both detect untranslated strings. The difference is scope:
- `avoid_missing_tr`: Focuses on `Text(...)` widget construction
- `avoid_missing_tr_on_strings`: More broadly targets any string in a user-visible context

**Recommendation: Implement as ONE rule** with configurable scope (widget-only vs. broad string detection). The ROADMAP has both — when implementing, create one file and note the consolidation. Both ROADMAP entries should be deleted when the single rule is implemented.

## Trigger Conditions

Broader than `avoid_missing_tr` — detect untranslated strings in:
1. `Text(...)` widget arguments (same as `avoid_missing_tr`)
2. `showDialog`, `showSnackBar`, `showModalBottomSheet` content
3. `AlertDialog(title: Text(...), content: Text(...))`
4. `DropdownMenuItem(value: ..., child: Text(...))`
5. `Tooltip(message: '...')` — accessibility tooltip text
6. `Button(child: Text('Submit'))` — button labels
7. `TextField(decoration: InputDecoration(labelText: '...', hintText: '...'))`

## Implementation Approach

### Extend `avoid_missing_tr` Detection
The implementation should be an extension/configuration of `avoid_missing_tr`. The broader rule also checks:
- Named arguments `labelText`, `hintText`, `helperText`, `errorText` in `InputDecoration`
- `title` and `content` named args in dialogs
- `message` in `Tooltip`

### Additional Widget Patterns

```dart
context.registry.addNamedExpression((node) {
  final name = node.name.label.name;
  if (!_isTranslatableNamedArg(name)) return;  // labelText, hintText, etc.
  final value = node.expression;
  if (value is! StringLiteral) return;
  if (_isTranslated(value)) return;
  if (_isNonTranslatableString(value)) return;
  reporter.atNode(value, code);
});
```

`_isTranslatableNamedArg`: check if the named argument is one of `labelText`, `hintText`, `helperText`, `errorText`, `message` (Tooltip), `title` (in dialog context).

## Code Examples

### Bad (Should trigger)
```dart
// InputDecoration without translation
TextField(
  decoration: InputDecoration(
    labelText: 'Email Address',  // ← trigger
    hintText: 'Enter your email',  // ← trigger
    errorText: 'Invalid email format',  // ← trigger
  ),
)

// Dialog without translation
showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Confirm Action'),  // ← trigger
    content: Text('Are you sure?'),  // ← trigger
    actions: [
      TextButton(
        onPressed: () {},
        child: Text('Cancel'),  // ← trigger
      ),
    ],
  ),
)
```

### Good (Should NOT trigger)
```dart
// Translated versions
TextField(
  decoration: InputDecoration(
    labelText: 'email_label'.tr(),  // ✓
    hintText: AppLocalizations.of(context)!.emailHint,  // ✓
  ),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `errorText` set to `null` (no error) | **Suppress** — null is not a user-visible string | Only check non-null string literals |
| `labelText: ''` empty string | **Suppress** | |
| `hintText: 'e.g., 2024-01-15'` (format hint) | **Trigger** — format hints should also be localized | |
| `Tooltip(message: 'Delete')` | **Trigger** — accessibility text needs translation | |
| Dialog with only button labels from localization | **No trigger** — all properly translated | |
| Test file | **Suppress** | |

## Unit Tests

### Violations
1. `InputDecoration(labelText: 'Email')` → 1 lint per untranslated string
2. `AlertDialog(title: Text('Confirm'))` → 1 lint
3. `Tooltip(message: 'Help')` → 1 lint

### Non-Violations
1. `InputDecoration(labelText: 'email'.tr())` → no lint
2. Test file → no lint
3. Project without localization → no lint

## Quick Fix

Same as `avoid_missing_tr` — add `.tr()` call.

## Notes & Issues

1. **CONSOLIDATION REQUIRED**: These two rules (`avoid_missing_tr` and `avoid_missing_tr_on_strings`) should be merged into one implementation. The wider rule (`avoid_missing_tr_on_strings`) subsumes the narrower one (`avoid_missing_tr`). Create ONE implementation covering all user-visible string contexts.
2. **Both ROADMAP entries should be deleted** when the consolidated rule is implemented.
3. **`InputDecoration` strings** are particularly commonly missed by developers — `labelText` and `hintText` are classic sources of untranslated strings in Flutter apps.
4. **`errorText`** in `InputDecoration` is often set dynamically from validation logic, not hardcoded — be careful about flagging dynamic `errorText` values.
