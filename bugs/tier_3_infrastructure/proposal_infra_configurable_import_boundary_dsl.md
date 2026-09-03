# PROPOSAL: Generic Configurable Import-Boundary DSL (`target`/`from`/`except`)

**Status: Open**

Created: 2026-09-02
Type: New rule (infrastructure — generic, project-configurable engine)
Related rules: none in saropa today (see Motivation for related prior art this could subsume)

---

## Summary

Add a single generic, project-configurable import-boundary rule/engine that lets a project declare "files matching `target` must not import files matching `from`, except files matching `except`" purely via a new config section (e.g. in `analysis_options_custom.yaml`), mirroring `import_lint`'s own three-key DSL. This is NOT a fixed AST pattern for one specific architecture — it is a reusable engine any project configures for its own boundaries.

**Closes gap:** import_lint (github.com/kawa1214/import-lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Gap Theme 2".

---

## Motivation

Several alternative packages independently ship bespoke, narrower versions of the same underlying idea — "some files must not import some other files" — as one-off hardcoded rules: `clean_architecture_kit`'s domain-layer-purity rules, `ripplearc_linter`'s `prevent_feature_module_dependencies`/`prevent_library_module_dependencies` (module-dependency bans), `subpackage_lint`'s `avoid_src_import_from_other_subpackage`/`avoid_src_import_from_same_package` (monorepo `/src/` isolation), and `architecture_lints`-style layer-boundary checks. Each of these is really the same shape — a glob-matched source set, a glob-matched forbidden-import set, and an exceptions carve-out — reimplemented per package with its own fixed vocabulary (features vs. layers vs. subpackages). `import_lint` recognizes this and ships ONE generic DSL (`target`/`from`/`except`) instead of N bespoke rules. Building this ONE engine in saropa would let saropa close this whole cluster of related-but-currently-separate architecture-boundary gaps via project config rather than requiring a bespoke Dart rule class per pattern — this reusability, not any single boundary check, is the strategic value of this proposal.

---

## Detection / Behavior

This is an infrastructure proposal — the "detection" is driven entirely by project configuration, not a fixed pattern. Describe the config schema and give a worked example.

### Config schema (proposed, in `analysis_options_custom.yaml`)

```yaml
saropa_lints:
  import_boundaries:
    - name: "checkout-cannot-import-auth-internals"
      target: "lib/features/checkout/**"
      from: "lib/features/auth/**"
      except: "lib/features/auth/public_api.dart"
    - name: "domain-cannot-import-data"
      target: "lib/domain/**"
      from: "lib/data/**"
```

Each entry:
- `target` — glob(s) for files the boundary applies to (the "consumer" side).
- `from` — glob(s) for import paths that are FORBIDDEN when imported from a `target` file.
- `except` — optional glob(s) carving out allowed exceptions within the `from` set (e.g. a public barrel file that's the intended integration seam).
- `name` — human-readable label surfaced in the diagnostic message so a violation is traceable back to the specific boundary rule that fired.

### Should flag (bad code)

Given the config above, a file matching `target: lib/features/checkout/**`:

```dart
// lib/features/checkout/checkout_service.dart
import 'package:myapp/features/auth/internal/token_store.dart';
// LINT — import_boundary: "checkout-cannot-import-auth-internals" — this
// import matches the forbidden `from` glob (lib/features/auth/**) and does
// NOT match the `except` glob (lib/features/auth/public_api.dart).

class CheckoutService {}
```

### Should pass (good code)

```dart
// lib/features/checkout/checkout_service.dart
import 'package:myapp/features/auth/public_api.dart';
// OK — matches the `except` glob, an explicitly allowed integration seam.

class CheckoutService {}
```

A project with no `import_boundaries` config entries gets zero diagnostics from this engine — it is entirely opt-in via config presence.

---

## Proposed Tier

Tier: Comprehensive/Pedantic, opt-in via config presence.
Justification: This is an infrastructure rule with no default behavior — a project must actively author `import_boundaries` config entries before it produces any diagnostic. Tier gating and config-presence gating are complementary: even in an enabled tier, silence is the default until a project opts in.

---

## Edge Cases

1. **Glob matching semantics** — must support the common `**` (recursive) and `*` (single-segment) glob conventions consistent with how saropa's other path-glob-based config (if any) already matches, to avoid introducing a second, inconsistent glob dialect in the same config file.
2. **Relative vs. package: imports** — a `from` glob targeting `lib/features/auth/**` must match both a relative import (`../auth/internal/token_store.dart`) and a `package:myapp/features/auth/internal/token_store.dart` import resolving to the same file; resolve both to a canonical project-relative path before glob-matching.
3. **Multiple boundary entries matching the same file** — a `target` file can match more than one `import_boundaries` entry; each should be evaluated independently and can each produce its own diagnostic (with its own `name` in the message) rather than short-circuiting on the first match.
4. **`export` statements** — decide explicitly whether `export` directives are subject to the same `from`/`except` matching as `import` (an export re-surfaces the forbidden dependency transitively to any importer of the exporting file); recommend treating `export` the same as `import` for boundary purposes, since it has the same coupling effect.
5. **Generated files (`.g.dart`, `.freezed.dart`)** — should typically pass under standard generated-file suppression, since generated imports mirror the source file's own imports and flagging them would just duplicate the diagnostic on the hand-written file.
6. **Self-referential glob (`target` and `from` overlapping)** — a file that matches both its own `target` and `from` glob (e.g. two files in the same feature importing each other) should not be flagged for importing itself/its own directory; document the expected within-target behavior clearly so config authors don't accidentally lock a feature out of its own internal imports.

---

## Alternatives Considered

- **Bespoke per-pattern rules matching each of `clean_architecture_kit`/`ripplearc_linter`/`subpackage_lint`'s specific vocabulary** — rejected as the primary approach; this would mean shipping and maintaining 3+ separate Dart rule classes for what is structurally the same check, when one generic config-driven engine subsumes all of them and any future architecture-boundary pattern a project invents on its own.
- **Fixed-vocabulary "layers" config (domain/data/presentation) instead of free-form globs** — rejected; free-form `target`/`from`/`except` globs are strictly more general and don't force every project into a specific layering vocabulary that may not match their actual architecture (feature-based, module-based, etc.).

---

## Decision

---

## Implementation Notes

---

## Commits
