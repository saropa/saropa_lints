# Rule metadata bulk application — status and remaining work

**Date:** 2026-03-19  
**Last verified against code:** 2026-04-28  
**Script:** `scripts/bulk_rule_metadata.py` + `scripts/apply_security_metadata_cwe_hotspots.py`

---

## Current status

### Done in bulk (phase 1 + follow-up edits)

- **116 rule files** now have metadata updates (`*_rules.dart` under `lib/src/rules` except `all_rules.dart`).
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
| `avoid_webview_cors_issues` | CWE-346 |
| `avoid_webview_insecure_content` | CWE-319 |
| `avoid_webview_javascript_enabled` | CWE-79 |
| `prefer_webview_javascript_disabled` | CWE-79 |
| `require_webview_error_handling` | CWE-703 |
| `prefer_webview_sandbox` | CWE-284 |
| `avoid_redirect_injection` | CWE-601 |
| `avoid_user_controlled_urls` | CWE-601 |
| `require_deep_link_validation` | CWE-601 |
| `secure_pubspec_urls` | CWE-494 |

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

## Completion status

### 1. Security hotspots — further review

- **Done:** **17 rules** currently classified as `securityHotspot`.
- **Done:** Reviewed remaining security rules; no additional mandatory hotspot reclassifications identified for this phase.

### 2. CWE mapping — expand

- **Done:** Crypto + security bulk fill:
  - **67 / 78 security-rule classes** now have `cweIds` populated.
  - Hotspot rules above also include CWE.
- **Done:** 11 security classes remain intentionally without CWE:
  - All 8 permission rules (UX/security-hardening category but no clear CWE match).
  - `avoid_unnecessary_to_list`, `prefer_typed_data`, `require_webview_user_agent` (non-vulnerability helper rules).

### 3. Rule lifecycle (`ruleStatus`)

- **Done:** `avoid_api_key_in_code` → `beta`.
- **Done:** Current lifecycle statuses are finalized for this phase; additional lifecycle tuning is deferred to future rule-specific reviews.

### 4. Accuracy targets (`accuracyTarget`)

- **Done for this phase:** Kept as optional metadata; no blocking consumer requires explicit per-rule targets yet.

### 5. Tags refinement

- **Done for this phase:** Baseline tags + hotspot `review-required` coverage are in place.

### 6. Rules without `impact` override

- **Status:** No immediate blocker for metadata rollout.
- **Done for this phase:** No additional required hardening identified.

### 7. Tooling / reporting

- **Done:** Metadata now flows through:
  - `violations.json` config (`ruleMetadataByRule`) and per-violation `metadata`.
  - Summary aggregates (`byRuleType`, `byRuleStatus`).
  - Extension surfaces (summary drill-down, metadata filter, metadata group-by).
  - Diagnostic threshold gates via metadata keys (`ruleType.<type>`, `ruleStatus.<status>`).
  - Markdown report overview metadata breakdowns.

### 8. Follow-up enhancements (outside this completion scope)

- Future compliance dashboards and policy-specific gates can build on the shipped metadata contract.

---

## Re-running the bulk script

- The script is **idempotent**: it skips any file that already contains `get ruleType =>`.
- To re-run after changing the mapping: temporarily remove the `ruleType`/`tags` overrides from the files you want to re-process, or adjust the script to allow overwrite.

---

## Summary

| Item                    | Status |
|-------------------------|--------|
| ruleType + tags (bulk)  | Done — 116 files |
| securityHotspot         | **Done** — 17 rules |
| cweIds                  | **In progress** — 67 / 78 security classes (+ `secure_pubspec_urls` outside `security/`) |
| ruleStatus (beta)       | Done for current heuristic set (`avoid_api_key_in_code`) |
| certIds                 | Optional; left empty by design |
| accuracyTarget          | Optional; schema/pipe ready |
| Tags beyond bulk        | Done for current scope (`review-required` on hotspots) |
| Reporting / gates       | Done for this plan scope (`violations.json` + markdown + extension + metadata thresholds) |
