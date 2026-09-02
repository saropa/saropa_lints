# PROPOSAL: Require Known-Unsafe APIs to Be Called Through a Designated Wrapper

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `must_use_unsafe_wrapper` to flag direct calls to a project-designated list of memory/isolate-unsafe APIs (raw `dart:ffi` pointer access, unchecked `SendPort`/`ReceivePort` payloads, unsynchronized static mutable state accessed from spawned isolates) unless the call site is inside a function explicitly marked as the sanctioned wrapper (e.g. annotated `@unsafe` or named per a configured pattern such as `unsafe*`).

**Closes gap:** `df_safer_dart_lints` `must_use_unsafe_wrapper` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Dart has no `unsafe` keyword like Rust, so isolate- and FFI-unsafe operations are invisible in a diff — a raw pointer dereference or an isolate-shared mutable read looks like any other line of code. Forcing every unsafe call through a single, greppable wrapper function centralizes the audit surface: reviewers can search for the wrapper name instead of re-deriving which calls are dangerous from scratch.

---

## Detection / Behavior

### Should flag (bad code)

```dart
import 'dart:ffi';

void readValue(Pointer<Int32> ptr) {
  final value = ptr.value; // LINT — raw FFI pointer dereference outside an unsafe wrapper
}
```

### Should pass (good code)

```dart
import 'dart:ffi';

@unsafe
int readValueUnsafe(Pointer<Int32> ptr) {
  return ptr.value; // OK — inside the designated unsafe wrapper
}

void readValue(Pointer<Int32> ptr) {
  final value = readValueUnsafe(ptr); // OK — routed through the wrapper
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific to `dart:ffi`/isolate-heavy codebases; most Flutter/Dart apps never touch these APIs, so it belongs in an opt-in tier rather than Essential/Recommended.

---

## Edge Cases

1. **Call inside a method whose class is annotated `@unsafe`** — should pass; class-level annotation covers all members.
2. **Transitive call through a non-wrapper helper that itself calls the unsafe API** — should flag; the immediate caller of the unsafe API must be the wrapper, not an indirect ancestor.
3. **Configured API list is empty (no project config)** — should not flag anything; rule requires explicit `dart:ffi`/isolate-unsafe API configuration to activate.
4. **Generated FFI bindings (`.g.dart` from `ffigen`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **A custom `@unsafe` lint that requires the annotation on every call site** (Rust-style `unsafe {}` block) — rejected as too invasive for Dart's syntax; wrapping the call is closer to idiomatic Dart than annotating every call site.

---

## Decision

---

## Implementation Notes

---

## Commits
