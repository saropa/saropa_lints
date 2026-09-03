# PROPOSAL: Require Notifier File Name to Match Class Name

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_riverpod_notifier_suffix`, `prefer_single_notifier_per_file`

---

## Summary

Flag a file containing a Riverpod `Notifier`/`AsyncNotifier` class whose `snake_case` filename doesn't match the class's own name (e.g. a `MyNotifier` class should live in `my_notifier.dart`).

**Closes gap:** DCM `prefer-correct-notifier-file-name` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Riverpod projects lean heavily on file-based navigation — "find the notifier for X" almost always means "open `x_notifier.dart`." When the class name and filename drift apart (renamed class, copy-pasted file, generated scaffolding left with a placeholder name), IDE "go to file" and code review both get harder, and new team members can't predict where a notifier lives from its name alone. saropa_lints already has file-name-to-class-name conventions elsewhere in the codebase pattern (rule packs enforce Provider/Bloc naming), but grep confirms zero matches for `prefer_correct_notifier_file_name` in `lib/src/rules/` — there is no rule enforcing this specifically for Riverpod notifiers today.

---

## Detection / Behavior

### Should flag (bad code)

```dart
// File: lib/features/cart/cart_state.dart
class CartNotifier extends Notifier<Cart> { // LINT — file should be cart_notifier.dart
  @override
  Cart build() => Cart.empty();
}
```

```dart
// File: lib/features/auth/session_manager.dart
class SessionNotifier extends AsyncNotifier<Session?> { // LINT — expected session_notifier.dart
  @override
  Future<Session?> build() async => null;
}
```

### Should pass (good code)

```dart
// File: lib/features/cart/cart_notifier.dart
class CartNotifier extends Notifier<Cart> { // OK — file name matches class name
  @override
  Cart build() => Cart.empty();
}
```

```dart
// File: lib/features/auth/session_notifier.dart
class SessionNotifier extends AsyncNotifier<Session?> { // OK
  @override
  Future<Session?> build() async => null;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Pure file-organization convention with no runtime correctness impact — appropriate for teams that want consistent project navigation but not something that should block builds by default. Consistent with the tiering of the other Riverpod naming/structure proposals in this batch.

---

## Edge Cases

1. **Multiple notifiers in one file** — this rule only checks name-to-file matching for each notifier found; `prefer_single_notifier_per_file` (separately proposed) is the rule that flags the "more than one notifier per file" case. When both apply, both should fire independently — they check different things.
2. **Generated files (`.g.dart`, `.freezed.dart`)** — should pass (skip entirely); these are never hand-named and file-name conventions don't apply to codegen output, matching the existing convention of skipping generated files noted in `bugs/ISSUE_REPORT_GUIDE.md`'s "Common Pitfalls" table.
3. **Test files (`_test.dart`)** — should pass; a notifier class briefly declared inline in a test file for mocking purposes shouldn't force a matching filename.
4. **Barrel/export-only files** — not applicable; the rule only fires when it finds an actual `Notifier`/`AsyncNotifier` class declaration in the file, so a barrel file with only `export` statements never triggers it.
5. **`snake_case` conversion ambiguity for acronyms (e.g. `HTTPCacheNotifier`)** — should use the same camelCase-to-snake_case conversion convention already used elsewhere in saropa_lints for file-name rules, to keep behavior consistent across the codebase (e.g. `http_cache_notifier.dart`, matching Dart's own `lowerCamelCase` → `snake_case` convention for acronyms).

---

## Alternatives Considered

- **Generalize to "class name must match file name" for all classes** — rejected as out of scope; DCM's gap is specifically about `Notifier` classes, and a fully general file-naming rule would need to handle multi-class files, private classes, and mixins with very different tolerance rules than this narrow, well-scoped check.
- **Fold into `prefer_riverpod_notifier_suffix`** — rejected; suffix checking (class name shape) and file-name checking (file/class correspondence) are independent failure modes that should surface as independent diagnostics so a fix to one doesn't silently mask the other.
