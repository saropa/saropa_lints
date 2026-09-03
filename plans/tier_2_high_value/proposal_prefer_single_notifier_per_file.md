# PROPOSAL: Flag More Than One Notifier Class Per File

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_correct_notifier_file_name`, `prefer_riverpod_notifier_suffix`

---

## Summary

Flag a file that declares more than one Riverpod `Notifier`/`AsyncNotifier` subclass.

**Closes gap:** DCM `prefer-single-notifier-per-file` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Riverpod's file-per-notifier convention exists for the same reason as Bloc's one-event-class-per-file guidance: it keeps `prefer_correct_notifier_file_name`'s name-to-file correspondence meaningful (a file can only match one class name), keeps diffs scoped to one notifier's change history, and keeps "find the notifier for X" a single-file lookup instead of a scroll-and-search. Two or more notifiers crammed into one file is a common outcome of quick prototyping that never gets split out, and it silently defeats the file-naming convention the sibling `prefer_correct_notifier_file_name` rule enforces (a file can match at most one of the notifiers it contains). saropa_lints has no rule for this today (confirmed by grep — zero matches for `prefer_single_notifier_per_file` in `lib/src/rules/`).

---

## Detection / Behavior

### Should flag (bad code)

```dart
// File: lib/features/cart/notifiers.dart
class CartNotifier extends Notifier<Cart> { // LINT — 2 notifiers in one file
  @override
  Cart build() => Cart.empty();
}

class WishlistNotifier extends Notifier<Wishlist> { // LINT
  @override
  Wishlist build() => Wishlist.empty();
}
```

### Should pass (good code)

```dart
// File: lib/features/cart/cart_notifier.dart
class CartNotifier extends Notifier<Cart> { // OK — only notifier in the file
  @override
  Cart build() => Cart.empty();
}
```

```dart
// File: lib/features/cart/wishlist_notifier.dart
class WishlistNotifier extends Notifier<Wishlist> { // OK — split into its own file
  @override
  Wishlist build() => Wishlist.empty();
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: File-organization convention, no runtime effect — same tier as the rest of the Riverpod naming/structure batch. It's a useful guardrail for larger teams but not something every project needs enforced by default.

---

## Edge Cases

1. **A private "helper" notifier class used only internally by the file's public notifier (rare but possible with composition patterns)** — should still flag; DCM's rule counts declared `Notifier`/`AsyncNotifier` subclasses regardless of visibility, and a private helper notifier is itself evidence the file should be split (the helper likely deserves its own file too, or should not be a `Notifier` at all).
2. **A file with one `Notifier` and one unrelated non-notifier class (e.g. a plain data model)** — should pass; the rule counts only `Notifier`/`AsyncNotifier` subclasses, not total class count in the file.
3. **A file with zero notifiers** — should pass trivially (no violation possible).
4. **Generated files (`.g.dart`)** — should pass (skip); code generation output is not subject to hand-authored file-organization conventions.
5. **Abstract base notifier class plus one concrete subclass in the same file (e.g. `abstract class _BaseNotifier` + `class FeatureNotifier extends _BaseNotifier`)** — needs discussion: if the base class itself extends `Notifier`, this technically counts as two notifier declarations. Recommend excluding `abstract` classes from the count, since an abstract base is not an independently usable provider and pairing it with its one concrete subclass in the same file is a reasonable, common pattern that shouldn't be penalized.

---

## Alternatives Considered

- **Count at the file level via a simple `ClassDeclaration` counter with no abstract exclusion** — simpler to implement, but rejected as the initial default because it would flag the common and reasonable abstract-base-plus-one-subclass pattern (edge case 5); the abstract exclusion is a small addition to the same visitor.
- **Merge into `prefer_correct_notifier_file_name`** (treat "more than one notifier" as an automatic failure of the naming rule) — rejected; the two failure modes are diagnostically distinct (wrong name vs. too many classes) and a developer fixing one shouldn't have to guess whether the other also needs addressing from a single combined message.
