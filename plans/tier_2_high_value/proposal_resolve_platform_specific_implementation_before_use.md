# PROPOSAL: Flag Platform-Interface Method Calls That Precede Platform Registration

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `resolve_platform_specific_implementation_before_use` to flag call sites that invoke a method on a federated-plugin platform-interface singleton (e.g. `XxxPlatform.instance.someMethod()`) before the platform-specific implementation has been registered (`XxxPlatform.instance = ...` / `registerWith(...)`) in the same scope. Federated plugins rely on `instance` being reassigned from the default `MethodChannelXxx` to a platform-specific override during app/plugin initialization; calling through the interface before that reassignment silently falls back to the (often non-functional) default implementation instead of failing loudly.

**Closes gap:** flutter_skill_lints `resolve_platform_specific_implementation_before_use` (github.com/sgaabdu4/flutter_skill_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

**Package dependency note:** this rule targets the federated-plugin / platform-interface pattern (an abstract `XxxPlatform` class with a static `instance` field, a default `MethodChannelXxx` implementation, and per-platform packages that call `XxxPlatform.instance = XxxWindows()` / `registerWith()` during initialization). It applies specifically to plugin-authoring code, not general app code.

Flutter's federated-plugin architecture depends on registration happening before first use: the `app-facing` package's platform interface starts with `instance` pointing at a `MethodChannelXxx` default, and each platform package's `registerWith()` (invoked by the Flutter engine/plugin registrant at startup) swaps in the real implementation. If any code path — a constructor, a static initializer, or code that runs eagerly at module load — calls a method on the platform interface before that swap happens, the call either silently uses the unconfigured default (which may throw `UnimplementedError`, no-op, or hit a method channel with no native-side receiver) or produces platform-dependent, hard-to-reproduce failures. This is a well-known plugin-authoring footgun that's easy to introduce in a plugin's own example app or in eager top-level initialization code, and hard to catch in review since the bug only manifests at specific startup-ordering timing.

---

## Detection / Behavior

**Uncertain — needs discussion; verify exact upstream trigger before implementing.** The precise heuristic used by flutter_skill_lints was not independently confirmed against its source at proposal time. This proposal is written at the conceptual level; implementation should study the upstream rule's actual AST pattern (via its GitHub source or published test fixtures) before build, since "before registration" requires some notion of ordering that is only tractable with a narrowed, practical heuristic — not full cross-file/cross-timing static analysis (which is undecidable in general).

Proposed practical scope (subject to revision after studying upstream):

Flag a call to a method on `XxxPlatform.instance` (or a similarly-named platform-interface singleton — a class extending/implementing a `PlatformInterface` from `package:plugin_platform_interface`, exposing a static `instance` getter/setter) when that call occurs:

- Inside a **top-level function, static initializer, or `main()`** in the SAME plugin package that also defines the platform interface, AND
- No `registerWith()` call or `instance = ...` assignment for that same platform-interface type precedes it in an executable path within that same file/library.

### Should flag (bad code)

```dart
// lib/my_plugin.dart — defines the platform interface AND calls it eagerly
class MyPluginPlatform extends PlatformInterface {
  MyPluginPlatform() : super(token: _token);

  static final Object _token = Object();
  static MyPluginPlatform _instance = MethodChannelMyPlugin();
  static MyPluginPlatform get instance => _instance;
  static set instance(MyPluginPlatform value) {
    PlatformInterface.verify(value, _token);
    _instance = value;
  }

  Future<String?> getPlatformVersion() =>
      throw UnimplementedError('getPlatformVersion() has not been implemented.');
}

// LINT — calls MyPluginPlatform.instance before any platform-specific
// registerWith()/instance= assignment has run; silently uses the
// unconfigured MethodChannelMyPlugin default.
final String? eagerVersion = MyPluginPlatform.instance.getPlatformVersion() as String?;
```

### Should pass (good code)

```dart
class MyPlugin {
  // OK — deferred: the call happens inside a method invoked by app code
  // AFTER Flutter's plugin registrant has run registerWith() for the
  // active platform, not at module load / static-initializer time.
  Future<String?> getPlatformVersion() {
    return MyPluginPlatform.instance.getPlatformVersion();
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Applies only to plugin-authoring code (defining a platform interface), a narrow audience compared to general app development. Not Essential/Recommended, since most projects consuming plugins (rather than authoring federated plugins) would never trigger it.

---

## Edge Cases

1. **Exact upstream trigger condition** — flagged above as uncertain; do not implement against the AST pattern described here without first confirming against flutter_skill_lints' actual rule source/tests, since the practical heuristic materially affects false-positive rate.
2. **App code (not a plugin) calling a third-party plugin's `XxxPlatform.instance`** — should pass; the rule is scoped to a plugin's own package defining its own platform interface, not to consumers of an already-registered third-party plugin.
3. **Lazy `late` singleton wrapping the platform-interface access** — should pass; the deferred evaluation means the call only executes when accessed, typically after the app is running and registration has occurred.
4. **`registerWith()` and the platform-interface call in the same function, correctly ordered** (registration statement precedes the call statement) — should pass.

---

## Alternatives Considered

- **Full cross-file/cross-timing static analysis of "has registerWith run yet"** — rejected; undecidable in the general case since registration timing depends on the Flutter engine's plugin registrant, which runs outside the analyzed source. A narrowed same-file/same-scope heuristic is the only tractable approach, matching how similar footgun-detection rules elsewhere in saropa work (heuristic pattern match, not full data-flow proof).
- **Implement now on this proposal's own best-guess heuristic without confirming upstream** — rejected; the proposal explicitly requires implementation to first verify the upstream AST pattern to avoid shipping a rule that either misses the real bug class or generates excessive false positives on legitimate patterns (e.g. `late` accessors, deferred method wrapping).

---

## Decision

---

## Implementation Notes

---

## Commits
