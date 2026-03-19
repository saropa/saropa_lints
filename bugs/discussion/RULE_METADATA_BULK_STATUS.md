# Rule metadata bulk application — status and remaining work

**Date:** 2026-03-19 (updated: phase 2 started)  
**Script:** `scripts/bulk_rule_metadata.py`

---

## Current status

### Done in bulk (phase 1)

- **108 rule files** updated (all `*_rules.dart` under `lib/src/rules` except `all_rules.dart`).
- **Every rule class that overrides `LintImpact get impact =>`** now has:
  - **`RuleType? get ruleType =>`** — set by folder (see mapping below).
  - **`Set<String> get tags =>`** — set by folder.

### Phase 2 started (this session)

#### Security hotspots (`RuleType.securityHotspot` + `review-required` tag + `cweIds`)

| Rule (lint id) | Notes |
|----------------|--------|
| `avoid_logging_sensitive_data` | CWE-532 |
| `avoid_stack_trace_in_production` | CWE-209 |
| `prefer_data_masking` | CWE-359 |
| `avoid_screenshot_sensitive` | CWE-200 |
| `require_catch_logging` | CWE-703 |
| `avoid_clipboard_sensitive` | CWE-200 |
| `avoid_sensitive_data_in_clipboard` | CWE-200 (auth/storage file) |

#### CWE on high-value vulnerability rules (sample batch)

| Rule / area | CWE |
|-------------|-----|
| All **crypto_rules.dart** (5 rules) | 798, 330, 327, 329, 335 (per rule; 335 = predictable PRNG for key material) |
| `avoid_hardcoded_credentials` | 798 |
| `avoid_token_in_url` | 598 |
| `avoid_api_key_in_code` | 798 |
| `avoid_ignoring_ssl_errors` | 295 |
| `require_https_only` | 319 |

#### Rule lifecycle

- **`avoid_api_key_in_code`**: `RuleStatus.beta` (heuristic / false positives documented in rule doc).

### Folder → (ruleType, tags) mapping used (phase 1)

| Path / category        | ruleType           | tags |
|------------------------|--------------------|------|
| `security/`            | vulnerability (except hotspots above) | `security` |
| `platforms/ios_ui_security` | vulnerability | `security`, `flutter` |
| `architecture/disposal` | bug                | `disposal`, `reliability`, `flutter` |
| `ui/accessibility`     | codeSmell          | `accessibility`, `a11y`, `flutter` |
| `stylistic/`           | codeSmell          | `convention` |
| `code_quality/`        | codeSmell          | `maintainability` |
| `flow/`                | codeSmell          | `reliability` |
| `architecture/` (other) | codeSmell         | `architecture` |
| `core/`                | codeSmell          | `dart-core` |
| `data/`                | codeSmell          | `reliability`, `type-safety` |
| `widget/`, `ui/` (other) | codeSmell       | `flutter`, `ui` |
| `testing/`              | codeSmell          | `testing` |
| `platforms/` (other)    | codeSmell          | `flutter`, `platform` |
| `packages/`             | codeSmell          | `packages` |
| `network/`, `resources/`, `config/`, `media/`, `commerce/`, `hardware/`, `codegen/` | codeSmell | category-appropriate |

### Still default (unchanged globally)

- **`accuracyTarget`** — still `null` for all.
- **`certIds`** — still `const []` for all.
- Rules that **do not override `impact`** still use base defaults: `ruleType => null`, `tags => const {}` (minority).

---

## Remaining work

### 1. Security hotspots — further review

- **Done:** 7 rules reclassified to `securityHotspot` with `review-required` tag.
- **Remaining:** Scan remaining `security_network_input_rules.dart` / `security_auth_storage_rules.dart` / `permission_rules.dart` for “context-dependent” findings (e.g. WebView rules where JS might be intentional); promote or demote individually.

### 2. CWE mapping — expand

- **Done:** Crypto file (5), credentials/token/SSL/HTTPS batch, hotspot CWEs.
- **Remaining:** ~60+ security rules still on default empty `cweIds`. Options:
  - Extend `scripts/bulk_rule_metadata.py` or add `scripts/apply_security_cwe.py` with a `rule_name → [cwe]` table.
  - Add `docs/cwe_mapping.md` (CWE id → short name) for compliance reports (per plan).

### 3. Rule lifecycle (`ruleStatus`)

- **Done:** `avoid_api_key_in_code` → `beta`.
- **Remaining:** Other heuristic-heavy security rules; any rules slated for removal → `deprecated` (per CHANGELOG/roadmap).

### 4. Accuracy targets (`accuracyTarget`)

- **Remaining:** Optional; add on hotspot vs vulnerability rules when reporting/gates consume metadata.

### 5. Tags refinement

- **Remaining:** Optional; add domain tags (`suspicious`, `network`, etc.) beyond bulk folder tags.

### 6. Rules without `impact` override

- **Remaining:** Find `extends SaropaLintRule` classes without `get ruleType =>` and add metadata after constructor or first `@override` (or extend bulk script).

### 7. Tooling / reporting

- **Remaining:** Violation export, compliance reports, extension UI — key off `ruleType`, `cweIds`, `tags`, `ruleStatus` when product work is scheduled (see `PLAN_RULE_METADATA_AND_QUALITY.md` §6–7).

---

## Re-running the bulk script

- The script is **idempotent**: it skips any file that already contains `get ruleType =>`.
- To re-run after changing the mapping: temporarily remove the `ruleType`/`tags` overrides from the files you want to re-process, or adjust the script to allow overwrite.

---

## Summary

| Item                    | Status |
|-------------------------|--------|
| ruleType + tags (bulk)  | Done — 108 files |
| securityHotspot         | **Started** — 7 rules |
| cweIds                  | **Started** — crypto + credentials/URL/SSL/HTTPS + hotspots |
| ruleStatus (beta)       | **Started** — `avoid_api_key_in_code` |
| certIds                 | Pending |
| accuracyTarget          | Optional; pending |
| Tags beyond bulk        | Optional (`review-required` on hotspots) |
| Reporting / gates       | Not in scope for metadata-only work |
