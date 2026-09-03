# BUG: unsupported plugin options `log_level` and `rule_packs`

**Status: Open**

<!-- Status values: Open -> Investigating -> Fix Ready -> Closed -->

Created: 2026-09-03
Area: Infrastructure
Severity: Wrong behavior (breaks downstream `--fatal-warnings`)

---

## Summary

<!-- What happens vs what should happen, in two sentences. -->

The Dart analyzer emits two `unsupported_option` warnings when a consumer's
`analysis_options.yaml` declares `log_level` and `rule_packs` under
`plugins: saropa_lints:`. These warnings are promoted to errors by
`flutter analyze --fatal-warnings`, which breaks CI and publish pipelines.

---

## Attribution Note

<!-- Why the standard rule-grep attribution is not applicable here. -->

This bug is **not about a lint rule**. It concerns plugin-level configuration
options (`log_level`, `rule_packs`) declared in the `plugins:` block of
`analysis_options.yaml`. The standard positive/negative grep for rule names
does not apply. The warnings are emitted by the Dart analyzer itself (not by
any `saropa_lints` rule) because the analyzer validates plugin option keys
against a fixed allowlist.

---

## Reproducer

<!-- Minimal analysis_options.yaml that triggers the two warnings. -->

Consumer `analysis_options.yaml`:

```yaml
plugins:
  saropa_lints:
    version: "14.3.8"
    log_level: info
    rule_packs:
      enabled:
        - collection_compat
        - dart_sdk_3_2
        - dart_sdk_3_4
        - testing
```

Run:

```bash
flutter analyze --fatal-warnings
```

**Frequency:** Always — deterministic on every analysis run.

---

## Actual Analyzer Output

<!-- The exact warnings the Dart analyzer produces. -->

```
warning - The option 'log_level' isn't supported by 'plugins/saropa_lints'. Try using one of the supported options: 'diagnostics', 'git', 'path', 'version', and 'hosted' - analysis_options.yaml:65:5 - unsupported_option
warning - The option 'rule_packs' isn't supported by 'plugins/saropa_lints'. Try using one of the supported options: 'diagnostics', 'git', 'path', 'version', and 'hosted' - analysis_options.yaml:66:5 - unsupported_option
```

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `log_level` and `rule_packs` are either accepted without warnings, or saropa_lints reads them from a location the analyzer does not validate |
| **Actual** | Two `unsupported_option` warnings, fatal under `--fatal-warnings`, blocking CI and publish |

---

## Root Cause

<!-- Why the Dart analyzer rejects these options. -->

The Dart analyzer's plugin option schema has a **closed allowlist** of keys
permitted under each `plugins: <name>:` entry. That allowlist is:

- `diagnostics`
- `git`
- `path`
- `version`
- `hosted`

Any key outside this set triggers an `unsupported_option` warning. The
`log_level` and `rule_packs` keys are custom configuration that `saropa_lints`
documents and may read through its own internal mechanism, but the analyzer
validates them **before** the plugin ever sees them. The analyzer's validation
pass does not have an extension point for plugins to register additional
option keys.

### Hypothesis A: move config out of the `plugins:` block

<!-- The most portable fix — read from a location the analyzer ignores. -->

`saropa_lints` reads its configuration from a separate file
(e.g. `saropa_lints.yaml` in the project root) or from a custom key under
`analyzer:` or `linter:` that the analyzer does not validate against the
plugin allowlist. This keeps the analyzer happy and gives saropa_lints full
control over its config schema.

### Hypothesis B: Dart SDK adds extensible plugin options

<!-- The ideal fix, but depends on upstream. -->

The Dart SDK expands the plugin option schema to allow arbitrary keys (or a
plugin-declared schema). This would let saropa_lints keep its config in the
`plugins:` block. However, this requires an upstream SDK change and is not
actionable by saropa_lints alone.

### Hypothesis C: document suppression as a workaround

<!-- Least-preferred — consumers must opt in to ignoring warnings. -->

saropa_lints documents that consumers should suppress these specific warnings
in their `analysis_options.yaml`:

```yaml
analyzer:
  errors:
    unsupported_option: ignore
```

This is a blunt instrument because it silences **all** `unsupported_option`
warnings, not just these two. It is a workaround, not a fix.

---

## Suggested Fix

<!-- Recommended approach, with trade-offs noted. -->

**Preferred: Hypothesis A.** Move `log_level` and `rule_packs` out of the
`plugins:` block and into a location the analyzer does not validate. Options:

1. **Separate config file** (`saropa_lints.yaml` in the project root) — clean
   separation, no collision risk, but adds a second file consumers must
   maintain.

2. **Custom key under `linter:` or `analyzer:`** — keeps everything in one
   file, but risks future collision if the Dart SDK adds a key with the same
   name.

3. **Embed under `diagnostics:`** — the `diagnostics` key IS in the allowlist,
   so `plugins: saropa_lints: diagnostics: { log_level: info, rule_packs: ... }`
   might pass validation. Needs verification: the analyzer may validate
   `diagnostics` sub-keys too.

**Short-term workaround (Hypothesis C):** Document the `unsupported_option:
ignore` suppression in the saropa_lints README and migration guide so
consumers can unblock their pipelines immediately. Note the caveat that this
silences all `unsupported_option` warnings.

---

## Fixture Gap

<!-- Not applicable — this is not a rule bug, so there is no rule fixture. -->

N/A — infrastructure bug, not a rule detection issue. No rule fixture applies.

---

## Changes Made

<!-- Fill in when a fix is written. -->

(none yet)

---

## Tests Added

<!-- Fill in when a fix is written. -->

(none yet)

---

## Commits

<!-- Add commit hashes as fixes land. -->

(none yet)

---

## Environment

<!-- Versions relevant to reproducing the issue. -->

- saropa_lints version: 14.3.8 (version in the reproducer config)
- Dart SDK version: (any version that validates `plugins:` option keys)
- Triggering context: any consumer project with `log_level` or `rule_packs`
  under `plugins: saropa_lints:` in `analysis_options.yaml`
- Failure mode: `flutter analyze --fatal-warnings` exits non-zero
