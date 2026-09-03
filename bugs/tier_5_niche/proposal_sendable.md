# PROPOSAL: Flag `@sendable`-Annotated Classes With Isolate-Unsafe Fields

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `sendable` to flag a class annotated with df_safer_dart_lints' `@sendable` marker that declares a field of a type not safe to pass across Dart isolate boundaries — most concretely a closure/`Function`-typed field, or a field of a known isolate-unsafe type (`BuildContext`, `Timer`, `StreamController`). The `@sendable` annotation is the author's explicit assertion that the class can be safely handed to `Isolate.spawn`, `compute()`, or `SendPort.send()`; a field that violates isolate-safety silently breaks that guarantee, and the failure only surfaces at runtime (a `SendPort.send` throwing "Invalid argument", or worse, an isolate that hangs or corrupts state) rather than at the point where the unsafe field was added.

**Closes gap:** df_safer_dart_lints `sendable` (github.com/robmllze/df_safer_dart_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

**Package dependency note:** this rule fires only on classes carrying `df_safer_dart_lints`' own `@sendable` annotation marker (alongside its sibling annotations `@mustAwaitAllFutures`, `@unsafe`). It has no meaning for classes not using this package's annotation-gated safety-checking system.

Dart's isolate model requires any object crossing an isolate boundary to be transferable — either a primitive, a type in Dart's built-in isolate-safe allowlist, or an object composed entirely of such types. Nothing in Dart's own type system enforces this: a class can freely declare a `Function` field, a `BuildContext` field, or a `Timer` field, and the compiler raises no objection — the violation only manifests when `SendPort.send()` (or `Isolate.spawn`/`compute()`'s implicit message-passing) actually attempts to serialize the object at runtime, typically failing with an unhelpful `Invalid argument(s): Illegal argument in isolate message` or, worse, silently misbehaving depending on how the object is used. By gating this check behind the package's own `@sendable` annotation, the rule only fires where a developer has explicitly asserted isolate-safety — turning a latent runtime footgun into an author-time static check exactly where the author has staked the claim.

---

## Detection / Behavior

Flag a class declaration annotated `@sendable` (from `package:df_safer_dart_lints` or the project's local re-export of it) that declares an instance field whose type is:

1. A `Function`/closure type (any function-typed field, including named function-type aliases), OR
2. A known isolate-unsafe type: `BuildContext`, `Timer`, `StreamController` (and subtypes), or any type from `dart:ui`/`package:flutter` known not to be transferable, OR
3. A non-primitive type that is neither itself `@sendable`-annotated nor a member of Dart's isolate-safe allowlist (`int`, `double`, `String`, `bool`, `null`, `List`/`Map`/`Set` of sendable elements, `SendPort`, `Capability`, typed data).

### Should flag (bad code)

```dart
import 'package:df_safer_dart_lints/df_safer_dart_lints.dart';

@sendable // LINT — declares a closure field and a Timer field, neither isolate-safe
class WorkerConfig {
  WorkerConfig({required this.onProgress, required this.timeout});

  final void Function(double progress) onProgress; // closure — cannot cross isolates
  final Timer timeout; // Timer is bound to the isolate that created it
}
```

### Should pass (good code)

```dart
import 'package:df_safer_dart_lints/df_safer_dart_lints.dart';

@sendable // OK — every field is a primitive or an isolate-safe collection
class WorkerConfig {
  WorkerConfig({required this.taskId, required this.retryCount, required this.tags});

  final String taskId;
  final int retryCount;
  final List<String> tags;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Entirely annotation-gated — the rule is inert in any codebase not using `df_safer_dart_lints`' `@sendable` marker, so it can never fire by accident in a project without the package dependency. Comprehensive/Pedantic matches saropa's placement for other single-package annotation-gated safety rules; not Essential/Recommended since the vast majority of projects don't use this package.

---

## Edge Cases

1. **A field typed as another `@sendable`-annotated class** — should pass; the annotation on the field's type is itself the safety assertion, and this rule should recognize nested `@sendable` types as safe, recursively.
2. **A field typed as a built-in isolate-safe collection of unsafe elements** (`List<Timer>`) — should flag; the collection type itself (`List`) is safe, but its element type isn't, so the field as a whole is unsafe. Requires inspecting generic type arguments, not just the bare collection type.
3. **Static fields / class-level (not instance) fields** — should pass; only instance fields matter for what gets serialized when an instance crosses an isolate boundary; static state is never part of a `SendPort.send()` payload.
4. **A field typed `dynamic` or `Object`** — should flag (or at minimum warn) since the actual runtime type cannot be statically verified as sendable; treat as unsafe-by-default since the annotation's promise cannot be verified for an unconstrained type.
5. **`@sendable` on an abstract class / mixin with no concrete fields** (fields only declared in subclasses) — should pass at the abstract declaration; each concrete subclass carrying its own fields (and its own `@sendable` if it re-asserts the marker) is where the check applies.

---

## Alternatives Considered

- **Apply the isolate-safety check universally, without requiring `@sendable`** — rejected; this would require the rule to infer "the developer intends to send this across an isolate boundary" from usage context (a much harder, imprecise problem: tracking `Isolate.spawn`/`compute()`/`SendPort.send()` call-site arguments back to type declarations). Gating on the package's own explicit annotation matches the upstream rule's design and keeps detection precise and false-positive-free.
- **Maintain saropa's own isolate-safe allowlist independent of the package** — rejected; the rule should track `df_safer_dart_lints`' own definition of "sendable" (including any exceptions/extensions the package itself declares) rather than diverging with a separately-maintained list, to avoid the rule disagreeing with the package it's built to complement.

---

## Decision

---

## Implementation Notes

---

## Commits
