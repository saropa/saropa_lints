# `prefer_foundation_platform_check` — false positive in mobile-only Flutter project (no `web/` dir)

**Status:** Fixed (2026-04-26) — `PreferFoundationPlatformCheckRule` now calls `ProjectContext.hasWebSupport(context.filePath)` inside the `PrefixedIdentifier` visitor (same timing as `avoid_platform_specific_imports`: `context.filePath` is often empty at registration time).

Filed: 2026-04-26
Rule: `prefer_foundation_platform_check`
File: `lib/src/rules/config/platform_rules.dart` (`PreferFoundationPlatformCheckRule`)
Severity: False positive (sibling of `avoid_platform_specific_imports_false_positive_mobile_only_no_web_dir`)
Rule version: v2 | Severity in code: INFO

---

## Summary

Rule fires on `Platform.isAndroid` inside a `build()` method of a Flutter app that does not target web (no `web/` directory exists, `flutter create .` never added it). The rule's only stated justification is *"Platform requires `dart:io` which doesn't exist on web"* — for a mobile-only project, that failure mode is structurally impossible. The diagnostic is pure noise.

This is the same web-gating gap as the already-filed
`avoid_platform_specific_imports_false_positive_mobile_only_no_web_dir.md`.
Both rules detect the same hazard ("breaks on web") and need the same project-context gate.

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_foundation_platform_check'" lib/src/rules/
lib/src/rules/config/platform_rules.dart:277:    'prefer_foundation_platform_check',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/config/platform_rules.dart:252` (`PreferFoundationPlatformCheckRule`)
**Rule class:** `PreferFoundationPlatformCheckRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts` (Flutter app, Saropa Contacts, mobile-only).

- `contacts/web/` does **not** exist.
- `contacts/android/`, `contacts/ios/` exist.
- `pubspec.yaml` declares `saropa_lints` at `recommended` tier.
- `analysis_options_custom.yaml` declares `Disabled platforms: macos, web, windows, linux`.
- File `lib/components/contact/detail_panels/nav_icons/nav_icon_list.dart`, line 423:

```dart
import 'dart:io'; // for Platform.isAndroid

class _NavIconListState extends State<NavIconList> {
  @override
  Widget build(BuildContext context) {
    // ...
    if (Platform.isAndroid) { // LINT — but should NOT lint (mobile-only project)
      icons.add(NavIcon(...));
    }
    // ...
  }
}
```

VS Code Problems panel reports:

```
[prefer_foundation_platform_check] Use defaultTargetPlatform in widget code.
In widget code, defaultTargetPlatform from foundation is safer and allows for
testing overrides. Platform requires dart:io which doesn't exist on web. {v2}
```

**Frequency:** Always, on every `Platform.is*` reference inside any `build()` method.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. Project has no `web/` dir → web is not a target → `dart:io` cannot be loaded into a non-existent web build → the stated risk does not apply. |
| **Actual** | `[prefer_foundation_platform_check]` fires on every `Platform.is*` in widget code. |

---

## AST Context

```
ImportDirective ('dart:io')
ClassDeclaration (_NavIconListState)
  └─ MethodDeclaration (build)
      └─ Block
          └─ IfStatement
              └─ PrefixedIdentifier (Platform.isAndroid)  ← node reported here
```

The rule's `runWithReporter` registers `addPrefixedIdentifier`. It checks `node.prefix.name == 'Platform'`, that the property starts with `is`, and that the node is inside a `build()` method (`_isInsideBuildMethod`). It then called `reporter.atNode(node)` without a project-context check.

---

## Root Cause

### Hypothesis A: rule has no `hasWebSupport` short-circuit

There was no `ProjectContext.hasWebSupport(context.filePath)` gate. Without it, the rule emits in pure-mobile projects where `dart:io` can never reach a web target.

### Hypothesis B: `ProjectContext.hasWebSupport` itself is broken on Windows / no-web-dir layouts

Same root cause as the sibling bug. If `getProjectInfo` returns null, `hasWebSupport` defaults to `true` (strict). The gate must run when `context.filePath` is set — inside an AST callback, not only at `runWithReporter` entry.

---

## Landed fix

- `PreferFoundationPlatformCheckRule`: first statement in the `PrefixedIdentifier` visitor — `if (!ProjectContext.hasWebSupport(context.filePath)) return;`
- Related sibling rules in the same file (`RequirePlatformCheckRule`, `PreferPlatformIoConditionalRule`) were aligned to evaluate path-dependent gates inside their visitors for the same `filePath` timing reason as `AvoidPlatformSpecificImportsRule` in `config_rules.dart`.
- `CHANGELOG.md` [Unreleased]: user-facing note for `prefer_foundation_platform_check`.
- Tests: `test/avoid_platform_specific_imports_web_gate_test.dart` documents regression linkage.

---

## Fixture Gap (optional follow-up)

1. **Mobile-only project (no `web/` dir), `Platform.isAndroid` in `build()`** — expect NO lint (covered by `ProjectContext.hasWebSupport` synthetic-project tests; `example/` is non-Flutter so existing fixture still expects BAD lint there.)
2. **Web-enabled project (has `web/` dir), `Platform.isAndroid` in `build()`** — expect LINT
3. **Pure Dart library (no Flutter, no platform dirs), `Platform.isAndroid` in `build()`** — expect LINT (consumers may target browsers)
4. **Mobile-only project, `Platform.isAndroid` outside `build()`** — expect NO lint (already handled by `_isInsideBuildMethod`)

---

## Downstream

Tracked in `contacts/bugs/` alongside the existing `// ignore:` workaround that
will be added once this report exists. Two consumer files are flagged:

- `lib/components/contact/detail_panels/nav_icons/nav_icon_list.dart:423`

---

## Environment

- saropa_lints version: 12.4.0 (consumer-declared in contacts `analysis_options.yaml`)
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts` (Flutter mobile-only)
- Platform: Windows 11
