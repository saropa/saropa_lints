# Bug: All rules enabled by default forces 1000+ explicit `false` entries

**Status:** FIXED in v8.0.10+
**Component:** Plugin registration / config loader
**Severity:** Design issue — usability and maintainability
**Discovered in:** saropa_drift_viewer project (v8.0.9)

---

## Resolution

Flipped rule registration from opt-out to opt-in. Rules are now disabled by
default — only rules explicitly set to `true` in `diagnostics:` (or with a
severity override) are registered.

### Changes

- **`config_loader.dart`**: `_loadDiagnosticsConfig()` now collects `true`
  values into `SaropaLintRule.enabledRules`. Severity overrides
  (ERROR/WARNING/INFO) implicitly enable rules. `false` values remove from
  enabled set and add to disabled set.
- **`main.dart`**: `register()` uses `getRulesFromRegistry(enabledRules)`
  instead of `allSaropaRules`, instantiating only enabled rules (~500MB vs
  ~4GB memory for essential tier).
- **`saropa_lint_rule.dart`**: Added `static Set<String>? enabledRules`
  field. `disabledRules` kept as safety net for `severities: false`.
- **`bin/init.dart`**: Removed Section 4 (disabled rules by tier with `false`
  entries) and disabled stylistic subsection from generated YAML. Essential
  tier YAML shrinks from ~2050 entries to ~300.

### Fallback

No config = no rules fire. Safe default matching `dart analyze` behavior.

### Backwards compatibility

Existing YAML with `true`/`false` entries works correctly — `true` enables,
`false` is redundant but harmless (cleaned up on next `init` run).
