# PROPOSAL: Avoid Private Typedef Functions

**Status: Open**

Created: 2026-09-02

## Summary

Flags a private (`_`-prefixed) function-type `typedef` that is referenced exactly once in its library, since it adds a layer of indirection without reuse value.

## Existing Coverage

No existing rule searches for `typedef` usage counts. `lib/src/rules/architecture/compile_time_syntax_rules.dart` and `lib/src/rules/data/type_rules.dart` matched a general `typedef` keyword grep but contain no rule about typedef reuse/necessity. `PreferTypedefsForCallbacksRule` (`lib/src/rules/stylistic/stylistic_widget_rules.dart`, matched via `typedef`) goes the opposite direction — it *encourages* typedefs for repeated callback signatures — so this proposal is complementary, not a duplicate: one flags too little reuse of a raw function type, the other flags a typedef that never got reused.

## Motivation

A `typedef` exists to name a signature so it can be reused across multiple declarations, or to make a complex signature self-documenting. A private typedef referenced only once achieves neither: the reader has to jump to its definition to learn a signature that could have been written inline, and it inflates the file with a declaration that provides no deduplication benefit. It's a common leftover from a refactor where all-but-one usage was removed.

## Detection / Behavior

Triggers on a `typedef` declaration whose name starts with `_` (library-private) that defines a function type, when a library-wide reference count for that typedef name is exactly 1 (the declaration itself — zero use sites) or 2 (one use site).

```dart
// BAD
typedef _Callback = void Function(int value);

void register(_Callback cb) => cb(1);

// GOOD
void register(void Function(int value) cb) => cb(1);
```

## Quick Fix

Inline the function-type signature at the single use site and remove the `typedef` declaration.

## Alternatives Considered

Applying the same check to public typedefs was considered and rejected — a public typedef is part of the package's exported API surface and may be used by external consumers the analyzer can't see, so usage-count analysis is unreliable there.
