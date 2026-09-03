# PROPOSAL: Flag Direct Imports Between Sibling Library/Shared Modules

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: prevent_feature_module_dependencies (sibling rule, same source package, feature-module layer instead of library-module layer)

---

## Summary

Add `prevent_library_module_dependencies` to flag an import statement inside one project-defined "library module" (an internal shared/reusable package or directory, e.g. `lib/libraries/<name>/` or a monorepo `packages/<name>` layout representing shared UI kits, utilities, networking, etc.) that reaches directly into another library module. Library modules are meant to be independently reusable and publishable — one shared library depending on another shared library tangles the dependency graph and defeats that independence.

**Closes gap:** ripplearc_linter `prevent_library_module_dependencies` (github.com/ripplearc/ripplearc-flutter-lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Ripplearc_linter targets mono-repo Flutter projects that split shared/reusable code into distinct "library modules" (e.g. a `ui_kit` package, a `networking` package, a `common_utils` package) alongside the feature-module split covered by the sibling rule `prevent_feature_module_dependencies`. The intent of splitting shared code this way is that each library module can be extracted, versioned, or published independently — but nothing stops one library from importing another's internals, and once that happens the "independent" libraries are secretly a single tangled unit that cannot be extracted or tested in isolation. This is a distinct failure mode from feature-module coupling: feature modules represent vertical product slices, library modules represent horizontal shared infrastructure, and each needs its own boundary check because the acceptable dependency direction differs (features may depend on libraries; libraries must not depend on each other).

---

## Detection / Behavior

Given a configured list of library-module root directories (e.g. `analysis_options_custom.yaml` → `library_module_roots: ['lib/libraries']` or `['packages']`), flag any `ImportDirective` (and `export` directive) in a file under `<root>/<library_A>/**` whose resolved target path lies under `<root>/<library_B>/**` where `library_A != library_B`.

### Should flag (bad code)

```dart
// File: lib/libraries/ui_kit/widgets/app_button.dart
import 'package:app/libraries/networking/api_client.dart'; // LINT — library module "ui_kit" imports directly from sibling library module "networking"

class AppButton extends StatelessWidget {
  final ApiClient client; // a UI kit should not depend on a networking library
}
```

### Should pass (good code)

```dart
// File: lib/libraries/ui_kit/widgets/app_button.dart
import 'package:flutter/material.dart'; // OK — external framework dependency, not a sibling library module

class AppButton extends StatelessWidget {
  final VoidCallback onPressed; // OK — depends only on a primitive callback, no cross-library coupling
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Same rationale as `prevent_feature_module_dependencies` — package/config-driven, only meaningful once a project declares its library-module roots, and applicable only to mono-repo/multi-package Flutter projects. Not suited to Essential/Recommended.

---

## Edge Cases

1. **No `library_module_roots` configured** — rule is a no-op.
2. **Import within the same library module** — should pass; only cross-library imports are flagged.
3. **A library module importing a feature module** — out of scope for this rule (that direction is typically forbidden by convention too, but is a distinct check — flag as a possible follow-up rule, not folded into this one, to keep each rule's blast radius predictable).
4. **A designated "common"/"core" library module that other libraries are explicitly allowed to depend on** — should pass when the project configuration marks a module as a shared foundation (e.g. `library_module_allow_common: ['core']`); without this exemption, every library ends up needing its own copy of truly universal primitives.
5. **`pubspec.yaml` `path:` dependency between two library packages in a multi-package monorepo (not a same-package import)** — out of scope for this AST-level rule; a `pubspec.yaml`-level dependency-graph check would need separate tooling (see `pubspec_ordering` proposal for the general challenge of YAML-level checks in this codebase).

---

## Alternatives Considered

- **Merge with `prevent_feature_module_dependencies` into a single generic "module boundary" rule with a `kind: feature|library` config** — rejected; the two concepts have different allowed dependency directions and different false-positive shapes (test-fixture sharing is common across features, "common" library exemptions are common across libraries), so a single merged rule would need branching configuration that is harder to reason about than two named rules matching the source package's own split.
- **Detect library modules automatically via `pubspec.yaml` package boundaries only** — considered for true multi-package monorepos, but rejected as the sole detection path because many projects implement "library modules" as plain directories within one package (`lib/libraries/<name>/`), which have no `pubspec.yaml` boundary to inspect.

---

## Decision

---

## Implementation Notes

Shares its config-parsing and import-resolution implementation path with `prevent_feature_module_dependencies` — both need a directory-root list and cross-directory import detection. Consider implementing both rules on top of one shared internal helper (e.g. a generic "flag cross-sibling-directory import under configured roots" utility parameterized by rule name and config key) rather than duplicating the AST-walk logic twice.

---

## Commits
