# PROPOSAL: Flag Direct Imports Between Sibling Feature Modules

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: prevent_library_module_dependencies (sibling rule, same source package, different architectural layer)

---

## Summary

Add `prevent_feature_module_dependencies` to flag an import statement inside one project-defined "feature module" directory (e.g. `lib/features/auth/**`) that reaches directly into another feature module (e.g. `lib/features/checkout/**`). Feature modules in a modular/mono-repo Flutter layout are meant to be siloed — they should only communicate through a shared/core layer, never import each other's internals directly.

**Closes gap:** ripplearc_linter `prevent_feature_module_dependencies` (github.com/ripplearc/ripplearc-flutter-lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Ripplearc_linter is a mono-repo-focused Flutter linter built around the "feature module" architectural convention: each top-level directory under a configured root (commonly `lib/features/<feature_name>/`) is an independently-owned vertical slice, and features are expected to depend only downward into shared/core code, never sideways into a sibling feature. A direct `import 'package:app/features/checkout/checkout_service.dart';` from inside `lib/features/auth/` silently reintroduces coupling that the module boundary was meant to prevent — the compiler does not enforce this, so violations accumulate invisibly until a refactor of one feature breaks an unrelated one.

This rule is **project-configuration-driven**: saropa_lints has no built-in notion of "feature module" — the project must declare which directories are feature-module roots. It is deliberately narrower than a generic import-glob DSL (a separate `import_lint`-style infra proposal covers arbitrary glob-based import bans); this rule is scoped specifically to the "feature module" architectural concept so teams adopting that pattern get a purpose-built check without hand-writing glob rules themselves.

---

## Detection / Behavior

Given a configured list of feature-module root directories (e.g. `analysis_options_custom.yaml` → `feature_module_roots: ['lib/features']`), flag any `ImportDirective` in a file under `<root>/<feature_A>/**` whose resolved target path lies under `<root>/<feature_B>/**` where `feature_A != feature_B`. Imports into a shared/core layer outside the configured feature roots are unaffected.

### Should flag (bad code)

```dart
// File: lib/features/auth/auth_service.dart
import 'package:app/features/checkout/checkout_service.dart'; // LINT — feature module "auth" imports directly from sibling feature module "checkout"

class AuthService {
  final CheckoutService checkout; // reaches across feature boundary
}
```

### Should pass (good code)

```dart
// File: lib/features/auth/auth_service.dart
import 'package:app/core/services/payment_gateway.dart'; // OK — shared/core layer, not a sibling feature module

class AuthService {
  final PaymentGateway gateway; // both features depend on the shared abstraction instead of each other
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package/config-driven — the rule only activates meaningfully once a project declares its feature-module roots, and mono-repo vertical-slice architecture is a minority pattern among saropa_lints' user base. Not appropriate for Essential/Recommended, which target universally-applicable defaults.

---

## Edge Cases

1. **No `feature_module_roots` configured** — rule is a no-op; never flags anything without explicit project configuration.
2. **Import within the same feature module** (`lib/features/auth/a.dart` importing `lib/features/auth/b.dart`) — should pass; only cross-feature imports are flagged.
3. **Export directives, not just imports** — `export` statements that re-expose a sibling feature's API should also flag; they create the same coupling via a different directive.
4. **`part`/`part of` within one feature module** — should pass; these are not cross-module boundaries.
5. **Test files under `test/features/<feature>/...` importing another feature's test helpers** — should pass by default (tests commonly need cross-feature fixtures); document as excluded from the check or gated by a separate config flag.
6. **Barrel file inside a feature module re-exporting only its own public API** — should pass when consumed by other features, since the import target still resolves inside the same feature's directory tree; only importing another feature's *internal* files triggers the rule.

---

## Alternatives Considered

- **Generic `import_lint`-style glob DSL covering this case too** — rejected as the primary implementation; a separate infra proposal covers arbitrary glob-based import bans, but a dedicated `prevent_feature_module_dependencies` rule gives a named, discoverable check that matches the source package's framing and needs no glob authoring from the adopting team.
- **Infer feature-module roots automatically from directory structure** (e.g. any second-level directory under `lib/features/`) — considered as a zero-config default, but rejected because "feature module root" is a naming convention that varies by project (`lib/features/`, `lib/modules/`, `lib/domains/`); explicit configuration avoids false positives on projects that happen to have a `lib/features/` directory without intending module isolation.

---

## Decision

---

## Implementation Notes

Needs a config surface: a new `feature_module_roots: [String]` (or similar) list in `analysis_options_custom.yaml`, parsed once per project analysis and cached — mirrors how other saropa_lints project-configured rules read `analysis_options_custom.yaml` today. Path resolution should use the same import-target-to-file-path logic saropa_lints already uses elsewhere for cross-file import checks (check `lib/src/` for existing import-resolution utilities before writing new resolution code).

---

## Commits
