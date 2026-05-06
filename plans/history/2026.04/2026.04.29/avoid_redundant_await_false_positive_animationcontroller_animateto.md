# BUG FIXED: `avoid_redundant_await` — `AnimationController` `animateTo` and other `TickerFuture` methods

**Status: Resolved**

Created: 2026-04-29  
Resolved: 2026-04-29  
Rule: `avoid_redundant_await`  
Primary file: `lib/src/rules/core/async_rules.dart`  
Severity: False positive  
Rule version: v3 (diagnostic suffix; allowlist completion)

---

## Summary

`avoid_redundant_await` only exempted `AnimationController.forward()` and `.reverse()` in `_isAnimationControllerTickerAwait`. `animateTo`, `animateBack`, `animateWith`, `repeat`, and `fling` also return `TickerFuture` and are legitimately awaited for sequencing, but were still reported as redundant when `TickerFuture` did not satisfy the generic awaitable-type check in some analyzer contexts.

---

## Root cause

The method-name allowlist in `_isAnimationControllerTickerAwait` was incomplete relative to every `TickerFuture`-returning API on `AnimationController`.

---

## Implementation

- Extended `_isAnimationControllerTickerAwait` to allow the same receiver check for:
  `forward`, `reverse`, `animateTo`, `animateBack`, `animateWith`, `repeat`, `fling`.
- Bumped rule text to `{v3}` in `LintCode` and class docstring.
- Updated `example/lib/async/avoid_redundant_await_fixture.dart` and `test/async_rules_test.dart`.
- Synced `analysis_options.yaml` and `example/analysis_options_template.yaml` comments.

---

## Regression coverage

Fixture includes `await` on all listed methods and `await someInt` under the BAD `expect_lint` block so non-Future awaits stay reported.

---

## Validation

- `dart test test/async_rules_test.dart` (including AvoidRedundantAwait group) passes.
- `dart format` on touched Dart files.

**Former location:** `bugs/avoid_redundant_await_false_positive_animationcontroller_animateto.md` (moved here on resolve).

**CHANGELOG:** add the Unreleased `### Fixed` bullet for `avoid_redundant_await` when you merge (see `CHANGELOG.md` worktree or copy from the commit message in a follow-up).
