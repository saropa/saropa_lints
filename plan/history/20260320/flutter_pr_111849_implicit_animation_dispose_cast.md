# Completed: Flutter PR #111849 (implicit animation dispose / cast)

**Date:** 2026-03-20  
**Plans:** `065`, `066` (same PR; consolidated into one rule)

## Summary

- **Flutter change:** [PR #111849](https://github.com/flutter/flutter/pull/111849) — internal `ImplicitlyAnimatedWidgetState` uses `CurvedAnimation` directly so the framework no longer casts when disposing. No public API signature change for app code.
- **Lint delivered:** `avoid_implicit_animation_dispose_cast` — warns on `(animation as CurvedAnimation).dispose()` in `ImplicitlyAnimatedWidgetState` subclasses (redundant with `super.dispose()`; lifecycle risk).
- **Not flagged:** Casts to `CurvedAnimation` for members other than `dispose` (e.g. `.curve`).
- **Quick fix:** Removes the redundant expression statement.
- **Tier:** Professional. **LintImpact:** high. **Performance:** `requiredPatterns: {'as CurvedAnimation'}`, `applicableFileTypes: {FileType.widget}`.
- **Tests:** `test/avoid_implicit_animation_dispose_cast_rule_test.dart`; fixture `example_widgets/lib/animation/avoid_implicit_animation_dispose_cast_fixture.dart`.
- **Shared AST:** `lib/src/implicit_animation_dispose_cast_ast.dart` (rule + fix).

## Plan files

Original specs were removed from `plan/implementable_only_in_plugin_extension/` after implementation; this file is the archive record.
