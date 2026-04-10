# Discussion: Tier-Based Filtering (Enable/disable rules by tier at runtime)

**Source:** [GitHub Discussion #61](https://github.com/saropa/saropa_lints/discussions/61)  
**Priority:** Medium  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)

---

## 1. Goal

Enable or disable rules based on strictness tiers at runtime (e.g. "run only Essential and Recommended") so teams can adopt saropa_lints incrementally or match a policy (e.g. "CI runs professional tier only").

---

## 2. Current state in saropa_lints

- **Tiers:** `lib/src/tiers.dart` defines tier sets: `essentialRules`, `recommendedOnlyRules`, `professionalOnlyRules`, `comprehensiveOnlyRules`, `pedanticOnlyRules`, and `stylisticRules`. `getRulesForTier(String tier)` returns the set of rule names for a given tier (e.g. `'essential'`, `'recommended'`, `'professional'`, `'comprehensive'`, `'pedantic'`, `'stylistic'`).
- **Configuration:** Rules are enabled via `analysis_options.yaml` (and custom_lint/analyzer config). The init script (e.g. `dart run saropa_lints:init`) generates or updates `analysis_options.yaml` to include rules; which rules are included depends on the user’s tier choice during init, not on a runtime "tier" variable.
- **No runtime tier variable:** There is no current mechanism to set "SAROPA_TIER=recommended" and have the plugin run only rules in that tier without changing `analysis_options.yaml`. So "tier-based filtering at runtime" would be a new behavior: the plugin reads an environment variable (or config) and skips rules that are not in the selected tier(s).

---

## 3. Proposed design (from Discussion #61)

```dart
// Configure via environment or analysis_options.yaml
// SAROPA_TIER=recommended dart analyze

abstract class SaropaLintRule extends DartLintRule {
  SaropaTier get tier;
  bool shouldRunForTier(SaropaTier activeTier) =>
    tier.index <= activeTier.index;
}
```

- **SaropaTier:** Enum or string for essential, recommended, professional, comprehensive, pedantic (and optionally stylistic). Each rule declares its tier (or it’s derived from which set in tiers.dart it belongs to).
- **activeTier:** Read from environment (e.g. SAROPA_TIER=recommended) or from analysis_options custom config. "Cumulative" semantics: e.g. recommended = essential + recommended; so `tier.index <= activeTier.index` means "run this rule if its tier is at or below the active tier."
- **Filtering:** When registering or running rules, if tier-based filtering is enabled, only run rules for which `shouldRunForTier(activeTier)` is true.

---

## 4. Use cases

| Use case | How tier-based filtering helps |
|----------|--------------------------------|
| Incremental adoption | Start with SAROPA_TIER=essential, then recommended, then professional. |
| CI vs local | CI uses SAROPA_TIER=professional; developers use recommended for faster feedback. |
| Policy | "We only enforce essential and recommended in this repo." |
| Performance | Run only lower tiers for faster analysis when needed. |

---

## 5. Research and prior art

- **ESLint:** "recommended" and "plugin:recommended" are config presets; no env-based tier. Users edit config to enable/disable rule sets.
- **SonarQube:** Quality profiles (e.g. "Sonar way") act like tiers; selection is profile-based, not env.
- **Dart:** analysis_options is the standard; a plugin can still decide internally not to run certain rules based on env or custom config, while analysis_options lists which rules are "enabled" by the analyzer. So tier could be: (1) only in init (generate options for a tier), or (2) runtime (plugin reads SAROPA_TIER and skips rules not in that tier even if they appear in options). (2) requires the plugin to know each rule’s tier and to have a single "active tier" source.

Conclusion: Implementing runtime tier filtering (SAROPA_TIER + per-rule tier + shouldRunForTier) is feasible. Mapping existing rules in tiers.dart to a SaropaTier enum (or string) and then filtering at run time is the main implementation task.

---

## 6. Implementation considerations

- **Source of tier per rule:** Today tier is defined by set membership in tiers.dart (essentialRules, recommendedOnlyRules, etc.). To get "rule R’s tier" you need a function: which set contains R? Then map set to SaropaTier (essential, recommended, professional, comprehensive, pedantic). Stylistic is separate (opt-in).
- **Where to filter:** In the plugin entry point or rule registration: when SAROPA_TIER is set, only register or run rules whose tier is <= active tier. Alternatively, each rule’s run checks a global "activeTier" and returns early if it shouldn’t run; the former is cleaner (fewer rules run at all).
- **Config vs env:** Support both: e.g. `analysis_options_custom.yaml` with `saropa_tier: recommended` and env SAROPA_TIER. Env could override file for CI.
- **Backward compatibility:** If SAROPA_TIER is not set, current behavior (all enabled rules from analysis_options run). So tier filtering is opt-in.

---

## 7. Open questions

- Should SaropaTier be an enum in the package (matching tiers.dart sets) or derived entirely from getRulesForTier?
- Allow multiple tiers (e.g. "essential,recommended") or only one active tier (cumulative)?
- Document SAROPA_TIER and optional analysis_options custom key in README and init flow.
