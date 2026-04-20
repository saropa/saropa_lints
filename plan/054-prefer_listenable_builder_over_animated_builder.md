# Plan #054 — `prefer_listenable_builder_over_animated_builder`

**Source:** Flutter SDK 3.13.0 (when `ListenableBuilder` was added)
**Status:** ✅ Implemented on 2026-04-20 — rule `prefer_listenable_builder` shipped in Recommended tier with quick fix.
**Category:** Replacement / Migration
**Relevance Score:** 6

---

## Release Note Entry

> [flutter_tools] modify Skeleton template to use ListenableBuilder instead of AnimatedBuilder by @fabiancrx in [128810](https://github.com/flutter/flutter/pull/128810)

**PR:** https://github.com/flutter/flutter/pull/128810

The change in the Flutter repo itself was template-only (internal). **However**, the underlying recommendation — prefer `ListenableBuilder` when the animation argument is a plain `Listenable` (not an `Animation`) — is a real user-facing pattern worth a lint.

---

## Why it is implementable (2026-04-19 review)

`AnimatedBuilder` is semantically "rebuild on any `Listenable` change". In Flutter 3.13+, `ListenableBuilder` exists as the more precise name for that case. `AnimatedBuilder` should still be used when the argument is an `Animation`/`AnimationController` (it is idiomatic there).

Detection rule:

- Trigger on `AnimatedBuilder(animation: <expr>, ...)` instance creation.
- Resolve the static type of `<expr>`.
- If the type is `Listenable` / `ValueNotifier` / `ChangeNotifier` and is **not** a subtype of `Animation<T>` — report.
- If the type resolves to `Animation` or any of its subclasses (`AnimationController`, `CurvedAnimation`, `Tween<T>.animate(...)` results, etc.) — **do not report**.

Quick fix:

- Replace `AnimatedBuilder(` with `ListenableBuilder(`. Argument names stay identical (`animation:`, `builder:`, `child:` — all three are compatible in both widgets).

---

## Existing overlap — not a duplicate

[animation_rules.dart](../lib/src/rules/ui/animation_rules.dart) already references both `AnimatedBuilder` and `ListenableBuilder` in several rules — but those rules target **scope** ([avoid_animation_rebuild_waste](../lib/src/rules/ui/animation_rules.dart#L1289)) and **builder size** (line 1720+), not the widget *choice*. A dedicated migration rule does not overlap.

---

## Target file

`lib/src/rules/ui/animation_rules.dart` — add as a new rule alongside the existing `AnimatedBuilder`-aware rules so the shared constant sets can be reused.

Minimum SDK gate: Flutter 3.13.0 (earlier SDKs lack `ListenableBuilder`). Use `ProjectContext` or a version check before reporting — do **not** fire on projects pinned below 3.13.

---

## Proposed Lint Rule

- **Name:** `prefer_listenable_builder`
- **Kind:** Code smell / replacement
- **Severity:** `INFO`
- **Tier:** Recommended (tentative — confirm during implementation)
- **Has quick fix:** Yes (straight rename of the widget identifier)

### Detection Strategy

1. `context.addInstanceCreationExpression`.
2. Filter to `typeName == 'AnimatedBuilder'`.
3. Find the `animation:` named argument.
4. Resolve its static type via `argument.staticType`.
5. If that type is assignable to `Animation` — return (keep `AnimatedBuilder`).
6. If it implements `Listenable` but not `Animation` — report.
7. Guard: if the static type is unresolved (`dynamic`/`null`), do not report (avoid false positives).

### Fix Strategy

Single replacement: rewrite the constructor name from `AnimatedBuilder` to `ListenableBuilder`. No argument reshuffling needed — the parameter surface is identical.

### Relevant AST nodes

- `InstanceCreationExpression`
- `ConstructorName`
- `NamedExpression` (for `animation:`)
- Static-type resolution via analyzer `DartType` → `isSubtypeOf(animationType)`.

---

## False-positive risks to handle

- **`Animation.drive(...)` / `CurvedAnimation`**: these are `Animation` subtypes — must not be flagged.
- **Custom `Listenable` that extends both `Animation` and `ValueNotifier`**: unlikely but possible — the `Animation` check must come first.
- **Unresolved types** (e.g. inside `dynamic` maps): skip, do not report.
- **Conditional expressions**: `AnimatedBuilder(animation: someBool ? controllerA : controllerB, ...)` — use the least-upper-bound type; if it resolves to `Animation`, skip.

Write fixtures for each of the above in `example/lib/` before asserting the rule is stable.

---

## Implementation Checklist

- [x] Verify the API change in Flutter SDK source (confirm `ListenableBuilder` constructor signature matches `AnimatedBuilder` for `animation`/`builder`/`child`).
- [x] Determine minimum SDK version requirement (Flutter 3.13.0 for `ListenableBuilder` — noted in the rule's `correctionMessage`; no runtime gate since `ProjectContext` has no SDK-version detection today).
- [x] Write detection logic (AST visitor) in [`lib/src/rules/ui/animation_rules.dart`](../lib/src/rules/ui/animation_rules.dart).
- [x] Write quick-fix replacement (rename constructor) — [`lib/src/fixes/animation/prefer_listenable_builder_fix.dart`](../lib/src/fixes/animation/prefer_listenable_builder_fix.dart).
- [x] Create test fixture in [`example/lib/animation/prefer_listenable_builder_fixture.dart`](../example/lib/animation/prefer_listenable_builder_fixture.dart) covering ValueNotifier / ChangeNotifier (BAD), AnimationController / CurvedAnimation / already-migrated `ListenableBuilder` (GOOD), and dynamic/unresolved (GOOD). Flutter mocks were extended with a `Listenable` interface so type resolution works downstream.
- [x] Add unit tests in [`test/prefer_listenable_builder_rule_test.dart`](../test/prefer_listenable_builder_rule_test.dart).
- [x] Register rule class in [`lib/saropa_lints.dart`](../lib/saropa_lints.dart) `_allRuleFactories`.
- [x] Add rule name to `recommendedOnlyRules` in [`lib/src/tiers.dart`](../lib/src/tiers.dart).
- [x] Update `CHANGELOG.md` under `[Unreleased]`. ROADMAP body lists categories (not individual rules); the auto-sync line tracks the rule count.
- [ ] `/analyze`, `/test`, `/format`.

---

**Generated:** From Flutter SDK v3.13.0 release notes
**Re-reviewed:** 2026-04-19 — promoted from `plan/deferred/` after confirming detection viability.
