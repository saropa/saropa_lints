# BUG: `require_keyboard_dismiss_on_scroll` — fires on every scroll view, ignoring its own "containing text fields" precondition

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `require_keyboard_dismiss_on_scroll`
File: `lib/src/rules/widget/forms_rules.dart` (class ~line 1327, code ~line 1344)
Severity: False positive
Rule version: v2 | Since: v1.8.2 | Updated: v4.13.0

---

## Summary

The rule's doc and message both scope it to scroll views **containing text fields** ("ScrollViews containing text fields should specify how the keyboard dismisses…"). The implementation never checks for a text-field descendant — it flags **every** `ListView` / `GridView` / `CustomScrollView` / `SingleChildScrollView` that lacks `keyboardDismissBehavior`. A pure content list (a list of contacts, a grid of avatars, a continent list) has no editable field and therefore no keyboard to dismiss, yet it is flagged identically to a real form. The diagnostic should require a text-field descendant (or at least an editable field somewhere in the subtree) before firing.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rln "require_keyboard_dismiss_on_scroll" lib/src/rules/
lib/src/rules/widget/forms_rules.dart

$ grep -n "'require_keyboard_dismiss_on_scroll'" lib/src/rules/widget/forms_rules.dart
1344:    'require_keyboard_dismiss_on_scroll',
```

**Emitter registration:** `lib/src/rules/widget/forms_rules.dart:1327` (`RequireKeyboardDismissOnScrollRule`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#2`

---

## Reproducer

```dart
import 'package:flutter/material.dart';

class NoTextFieldList extends StatelessWidget {
  const NoTextFieldList({super.key});

  @override
  Widget build(BuildContext context) {
    // LINT (require_keyboard_dismiss_on_scroll) — but there is no text field
    // anywhere in this subtree, so there is never a keyboard to dismiss.
    // The dismiss behavior is meaningless here; this should be OK.
    return ListView(
      children: const <Widget>[
        ListTile(title: Text('Africa')),
        ListTile(title: Text('Asia')),
      ],
    );
  }
}

class RealForm extends StatelessWidget {
  const RealForm({super.key});

  @override
  Widget build(BuildContext context) {
    // LINT — correct here: the list contains an editable field, so a keyboard
    // can be open while the user scrolls.
    return ListView(
      children: const <Widget>[
        TextField(),
        ListTile(title: Text('row')),
      ],
    );
  }
}
```

**Frequency:** Always, for any of the four scroll-view types without `keyboardDismissBehavior`, regardless of content.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Diagnostic only when the scroll view has a text-field / editable descendant (per the rule's own doc) |
| **Actual** | `[require_keyboard_dismiss_on_scroll] Scroll view must have keyboardDismissBehavior for form UX` reported on every `ListView`/`GridView`/`CustomScrollView`/`SingleChildScrollView` |

---

## AST Context

```
InstanceCreationExpression (ListView(...))   ← reported on constructorName
  └─ ArgumentList
      └─ (named args; no keyboardDismissBehavior)
         children: [ ... ]   ← subtree never inspected for a TextField
```

---

## Root Cause

`runWithReporter` registers `addInstanceCreationExpression`, checks the constructor type name against `_scrollViewTypes`, scans the argument list only for a `keyboardDismissBehavior` named argument, and reports if absent (`forms_rules.dart:1363-1380`). There is no traversal of the `children` / `slivers` / `body` subtree to confirm a text-field (`TextField`, `TextFormField`, `CupertinoTextField`, `EditableText`, or a custom field) is present. The "containing text fields" precondition stated in the doc/message is unimplemented, so the rule is structurally over-broad.

---

## Suggested Fix

Gate the report on the presence of an editable descendant. Two viable levels:

1. **Syntactic (cheap, keeps scan CLI working):** walk the constructor's child argument expressions for an `InstanceCreationExpression` whose type name is in a known editable set (`TextField`, `TextFormField`, `CupertinoTextField`, `EditableText`, `TextFormField`-likes). Only report when one is found, or when content is opaque (a builder/variable) — choose whether opaque content reports or is exempt and document it.
2. **Resolved (precise):** when resolution is available, check subtree element types against `EditableText` / `TextField` supertypes.

If implementing detection is out of scope, an interim option is to drop the "containing text fields" claim from the doc/message and re-scope the rule as "all scroll views should declare dismiss behavior" — but that makes it noisy on non-form lists and should probably move to a lower tier / opt-in.

---

## Fixture Gap

`example*/lib/widget/require_keyboard_dismiss_on_scroll_fixture.dart` should include:

1. `ListView` with a `TextField` child, no `keyboardDismissBehavior` — expect LINT
2. `ListView` with only non-editable children — expect NO lint
3. `GridView` / `CustomScrollView` / `SingleChildScrollView` variants of both cases
4. A scroll view whose children come from a builder/variable (opaque) — document expected behavior

---

## Environment

- saropa_lints version: 14.0.4
- Dart SDK version: (Flutter stable, analyzer ^12)
- Triggering project: Saropa Contacts — 41 hits across 39 files; the majority are non-form content lists (e.g. `lib/components/country/continent/contact_continent_list_widget.dart:201`, a continent `ListView` with no text field). Downstream resolution: `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` was added to all 41 (harmless), but the non-form sites are false positives.
