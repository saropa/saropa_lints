<!-- AUTO-SYNC: The heading and Goal line below are updated by the publish
     script via sync_roadmap_header() in scripts/modules/_rule_metrics.py.
     Heading regex: "# Roadmap: Aiming for N,NNN"
     Goal regex:    "Goal: NNN rules (NNN implemented, NNN remaining)"
     Goal is rounded up to the nearest 100. -->
# Roadmap: Aiming for 2,200 Lint Rules
<!-- cspell:disable -->

See [CHANGELOG.md](CHANGELOG.md) for implemented rules. Goal: 2200 rules (2107 implemented, 93 remaining).

> **When implementing**: Remove from ROADMAP, add to CHANGELOG, register in `all_rules.dart` + `tiers.dart`. See [CONTRIBUTING.md](CONTRIBUTING.md).

> **Deferred rules**: Rules we cannot implement today are documented with full justification in [plan/deferred/](plan/deferred/). Do not re-propose rules listed there without addressing the stated barrier.

---

## Part 1: Technical Debt & Improvements

### SaropaLintRule Base Class Enhancements

The `SaropaLintRule` base class provides enhanced features for all lint rules.

#### Planned Enhancements

Details and design notes for each enhancement are in [bugs/discussion/](bugs/discussion/) (one file per discussion: `discussion_055_diagnostic_statistics.md` through `discussion_061_tier_based_filtering.md`).

---

## Part 2: Implementable Rules

Rules below can be implemented with existing infrastructure or moderate new work. Grouped by the type of work needed.

### Platform Config Cross-Reference Rules

These rules follow the **existing Info.plist pattern**: a Dart rule fires when it detects API usage, then cross-checks a platform config file. `info_plist_utils.dart` already does this for iOS permission checks. The same approach works for other config files — each just needs a parser.

| Rule | Tier | Severity | Config file needed | Parser status |
|------|------|----------|--------------------|---------------|
| `require_ios_info_plist_entries` | Essential | ERROR | `Info.plist` | **Parser exists** (`info_plist_utils.dart`) |
| `require_desktop_window_setup` | Professional | INFO | Platform-specific files | Needs platform parsers |
| `avoid_audio_in_background_without_config` | Essential | ERROR | `Info.plist` + `AndroidManifest.xml` | Needs XML parser |
| `avoid_geolocator_background_without_config` | Essential | ERROR | `Info.plist` + `AndroidManifest.xml` | Needs XML parser |
| `require_notification_icon_kept` | Essential | ERROR | `proguard-rules.pro` | Needs text parser |
| `require_firestore_security_rules` | Essential | ERROR | `firestore.rules` | Needs text parser |
| `require_env_file_gitignore` | Essential | ERROR | `.gitignore` | Needs text parser |

**GitHub issues**: [#35](https://github.com/saropa/saropa_lints/issues/35), [#36](https://github.com/saropa/saropa_lints/issues/36), [#37](https://github.com/saropa/saropa_lints/issues/37), [#41](https://github.com/saropa/saropa_lints/issues/41)

### Cross-File CLI Improvements

The CLI tool (`dart run saropa_lints:cross_file`) is functional but can be improved. See [plan/cross_file_cli_design.md](plan/cross_file_cli_design.md) for the full design.

| Improvement | Status |
|-------------|--------|
| Unused files detection | Done |
| Circular dependency detection | Done |
| Import statistics | Done |
| HTML reports | Done |
| Baseline integration | Done |
| CI exit codes | Done |
| Watch mode | Planned |
| Unused symbols detection | Planned |
| Cross-feature dependency analysis | Planned |
| Dead import detection | Planned |
| Extension UI integration (sidebar views) | Planned |

---

## Stylistic Rule Pairs and Overlaps

Some rules intentionally conflict or overlap; the **init wizard** (`dart run saropa_lints:init --stylistic`) lets users choose which stylistic rules to enable. This is by design, not a bug.

| Relationship | Rules | Notes |
|--------------|--------|--------|
| **Intentional pair** | `avoid_cubit_usage` vs `prefer_cubit_for_simple_state` | Opposite preferences: prefer Bloc (event traceability) vs prefer Cubit for simple state. Enable one via the wizard. |
| **Narrow variant** | `prefer_expression_body_getters` vs `prefer_arrow_functions` | Getter-only vs all single-expression bodies. Can enable both or just one. |
| **Narrow variant** | `prefer_super_parameters` vs `prefer_super_key` | Both can flag `super(key: key)` on widgets; `prefer_super_key` is Flutter-widget + `Key` only. |
| **Intentional pair** | `prefer_caret_version_syntax` vs `prefer_pinned_version_syntax` | Extension-side pubspec diagnostics. Caret (default) vs exact pin. Controlled via `preferPinnedVersions` flag. |
| **Other pairs** | e.g. `prefer_type_over_var` / `prefer_var_over_explicit_type` | Documented in rule DartDoc and CHANGELOG; wizard shows both so users pick one. |

When adding or reviewing rules, check CODE_INDEX and tiers for existing stylistic opposites; document pairs in the rule's DartDoc and, if needed, in this table.

---

## Deferred Rules

Rules that cannot be implemented today are split into focused documents by barrier type:

| Document | Barrier | Rule count |
|----------|---------|------------|
| [cross_file_analysis.md](plan/deferred/cross_file_analysis.md) | Single-file AST — needs multi-Dart-file analysis | 26 |
| [unreliable_detection.md](plan/deferred/unreliable_detection.md) | Heuristic / subjective / no AST pattern | 54 |
| [external_dependencies.md](plan/deferred/external_dependencies.md) | Needs pub.dev API or maintained databases | 5 |
| [framework_limitations.md](plan/deferred/framework_limitations.md) | Blocked by analyzer/IDE API limitations | 15 |
| [compiler_diagnostics.md](plan/deferred/compiler_diagnostics.md) | Duplicates Dart compiler checks — high effort, low value | 28 |
| [not_viable.md](plan/deferred/not_viable.md) | Reviewed and permanently rejected | 14 |

**Total deferred: ~142 rules/items.** These will not be implemented until the stated barrier is addressed.

---

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines.

---

> **Package-specific rule sources** have been moved to [LINKS.md](LINKS.md#package-specific-rule-sources).
