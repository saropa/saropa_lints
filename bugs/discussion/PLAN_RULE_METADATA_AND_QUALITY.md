# Plan: Rule Metadata, Standards Mapping, and Quality System

**Status:** Draft (partially implemented — see [RULE_METADATA_BULK_STATUS.md](RULE_METADATA_BULK_STATUS.md))  
**Priority:** Medium (incremental adoption)  
**Scope:** Rule base class, reporting, tooling, documentation  

**Review note:** Plan only; no runtime code in this file. Check alignment with CONTRIBUTING, CODEBASE_INDEX, and ROADMAP.

**Implementation note (2026-03-19):** Base types and `SaropaLintRule` getters are in place; bulk `ruleType`/`tags`; security CWE + hotspot pass expanded (WebView/redirect hotspots + `cweIds` population). **Not done:** quality gates CLI, new-code metrics reporting, `requiresReview` on diagnostics, full CWE coverage (permission rules/helpers left empty), `accuracyTarget` population.

---

## Overview

This plan defines eight enhancements to align rule semantics with industry expectations: explicit rule types, accuracy targets, a “review required” security workflow, standards mapping beyond OWASP, rule tags, quality gates, new-code metrics, and rule lifecycle status. Each section includes current state, proposed design with examples, use cases, and implementation notes.

---

## 1. Rule type taxonomy (Bug / Vulnerability / Code smell / Security hotspot)

### 1.1 Goal

Classify each rule into one of four semantic types so that tooling, docs, and quality policies can treat them differently (e.g. “must fix” vs “review required,” or different accuracy expectations).

### 1.2 Current state

- **LintImpact** (critical, high, medium, low, opinionated) describes business impact and is used for reporting.
- **Tiers** (essential → pedantic, stylistic) control which rules are enabled by default.
- There is no first-class “rule type” that distinguishes:
  - Definite correctness/reliability issues (bug)
  - Clear security flaws requiring a fix (vulnerability)
  - Maintainability/style issues (code smell)
  - Security-sensitive code that needs human review before deciding fix (security hotspot).

### 1.3 Proposed design

Add an optional `RuleType` enum and a getter on `SaropaLintRule`:

```dart
/// Semantic type of the rule for policies and reporting.
///
/// - [bug]: Reliability; fix required; target zero false positives.
/// - [vulnerability]: Security flaw; fix required; target high true positive rate.
/// - [codeSmell]: Maintainability; fix recommended; target zero false positives.
/// - [securityHotspot]: Security-sensitive; review required (may be safe); target high "resolved after review" rate.
enum RuleType {
  bug,
  vulnerability,
  codeSmell,
  securityHotspot,
}

abstract class SaropaLintRule extends DartLintRule {
  /// Semantic type of this rule. Default [null] = unspecified (legacy).
  /// When set, used for quality gates, accuracy targets, and reporting.
  RuleType? get ruleType => null;
}
```

**Examples by rule:**

| Rule name                         | Suggested ruleType     | Rationale |
|-----------------------------------|------------------------|-----------|
| `avoid_undisposed_controller`      | `RuleType.bug`         | Reliability; leak is a bug. |
| `avoid_hardcoded_credentials`      | `RuleType.vulnerability`| Clear security flaw; fix required. |
| `prefer_const_constructors`       | `RuleType.codeSmell`   | Maintainability/performance. |
| `avoid_stack_trace_in_production` | `RuleType.securityHotspot` | May be intentional logging; review first. |
| `require_ssl_for_sensitive_data`  | `RuleType.vulnerability` | Clear requirement. |
| `avoid_debug_print`               | `RuleType.codeSmell`   | Style/cleanliness. |

**Backward compatibility:** Default `ruleType => null`. Existing rules remain valid; we populate `ruleType` incrementally and use it only when non-null (e.g. in reports and gates).

### 1.4 Use cases

- **Quality gates:** Fail only on new bugs/vulnerabilities; allow new code smells under a threshold.
- **Reports:** “Critical: 2 bugs, 1 vulnerability, 15 code smells, 3 security hotspots.”
- **Documentation:** Filter rules by type in ROADMAP/CHANGELOG and on the website.
- **Accuracy targets:** Apply different targets per type (see §2).

### 1.5 Implementation notes

- Add `RuleType` to `lib/src/saropa_lint_rule.dart` (or a small `lib/src/rule_type.dart`).
- Add `RuleType? get ruleType => null` to `SaropaLintRule`.
- Populate per rule in batches (security rules first, then disposal/bugs, then code quality).
- Report layer and gate logic (see §6) key off `ruleType` when present; when null, fall back to severity/impact only.

---

## 2. Explicit accuracy targets per type

### 2.1 Goal

Document and, where feasible, enforce accuracy expectations per rule type so maintainers and users know what to expect (e.g. “bugs should have zero false positives”).

### 2.2 Current state

- CONTRIBUTING and the lint-rules skill describe avoiding false positives in general.
- There is no per-rule or per-type statement of accuracy targets (e.g. “this rule aims for zero false positives”).

### 2.3 Proposed design

**2.3.1 Documented targets (no code change required initially)**

Add a short “Rule quality and accuracy” section to CONTRIBUTING (or a new doc `docs/RULE_QUALITY.md`) with a table like:

| Rule type         | False positive target | True positive / resolution target | Notes |
|-------------------|------------------------|-----------------------------------|--------|
| Bug               | Zero                   | N/A                               | Developers should not doubt that a fix is required. |
| Vulnerability     | Minimize               | >80% true positives               | Some FPs acceptable if TP rate is high. |
| Code smell        | Zero                   | N/A                               | Same as bug for developer trust. |
| Security hotspot  | Minimize               | >80% quickly resolved as “reviewed” (safe or fixed) | Hotspots are “review required,” not auto-fix. |

**2.3.2 Optional: accuracy target metadata on rules**

For future tooling (e.g. audits, dashboards), add an optional getter:

```dart
/// Optional accuracy target for this rule (for documentation and tooling).
/// Does not enforce; used by reports and rule-audit scripts.
AccuracyTarget? get accuracyTarget => null;

class AccuracyTarget {
  const AccuracyTarget({
    this.expectZeroFalsePositives = false,
    this.minTruePositiveRate,   // e.g. 0.8 for 80%
    this.description,
  });
  final bool expectZeroFalsePositives;
  final double? minTruePositiveRate;
  final String? description;
}
```

Example for a vulnerability rule:

```dart
@override
AccuracyTarget? get accuracyTarget => const AccuracyTarget(
  expectZeroFalsePositives: false,
  minTruePositiveRate: 0.8,
  description: 'Vulnerability rule; aim for >80% true positives.',
);
```

Example for a bug rule:

```dart
@override
AccuracyTarget? get accuracyTarget => const AccuracyTarget(
  expectZeroFalsePositives: true,
  description: 'Bug rule; zero false positives target.',
);
```

### 2.4 Use cases

- **Rule authors:** Know what bar to meet when adding or relaxing heuristics.
- **Audits:** Scripts or docs can list “rules with zero-FP target” vs “rules with TP-rate target.”
- **Triage:** When users report false positives, we can check whether the rule’s target is zero FP and prioritize accordingly.

### 2.5 Implementation notes

- Start with documentation only; add `AccuracyTarget` and the getter in a later phase if we build audit/reporting that consumes it.
- Keep wording in docs clear: “target” not “guarantee”; we can’t prove zero FPs, we aim for it.

---

## 3. Security hotspot workflow (“review required”)

### 3.1 Goal

Distinguish security findings that require an immediate fix from those that require human review to decide whether the code is acceptable or needs changing. The latter are “security hotspots”: same visibility, different expected action.

### 3.2 Current state

- All security rules emit normal diagnostics (error/warning/info).
- There is no way to mark a finding as “review required” vs “fix required”; quick fixes and messaging are the same.

### 3.3 Proposed design

**3.3.1 Option A: Rule type + severity convention**

- Use `ruleType: RuleType.securityHotspot` for rules that are “review required.”
- In docs and extension UI, explain: “Security hotspot: review this code; it may be intentional. Resolve as ‘safe’ or apply a fix.”
- No new API; reporting and gates treat `securityHotspot` differently (e.g. gate fails on new vulnerabilities, warns or does not fail on new hotspots until “reviewed”).

**3.3.2 Option B: Explicit “review required” severity or flag**

Add a way to mark a diagnostic as “review required” so the IDE/extension can show a different treatment (e.g. different icon or action label):

```dart
// In LintCode or reporter API (conceptual)
class LintCode {
  // ...
  /// If true, this finding is a security hotspot: developer should review
  /// and resolve as "safe" or "fixed" rather than auto-applying a fix.
  bool get requiresReview => false;
}
```

Or at report time:

```dart
reporter.atNode(node, code, requiresReview: true);
```

Then:

- **Vulnerability:** `requiresReview: false` (default) — “Fix this.”
- **Security hotspot:** `requiresReview: true` — “Review this; confirm safe or fix.”

**3.3.3 Example rule classification**

| Rule                                      | Type / flag              | Reason |
|-------------------------------------------|--------------------------|--------|
| `avoid_hardcoded_credentials`             | vulnerability             | Always fix. |
| `require_ssl_for_sensitive_data`          | vulnerability             | Always fix. |
| `avoid_stack_trace_in_production`          | securityHotspot / review | May be deliberate in error reporting. |
| `avoid_logging_sensitive_data`            | securityHotspot / review | Context-dependent (dev vs prod, PII). |
| `prefer_encrypted_prefs`                   | vulnerability             | Clear requirement. |

### 3.4 Use cases

- **Security audits:** Report “X vulnerabilities (fix), Y hotspots (review).”
- **Quality gates:** “Block on new vulnerabilities; require review of new hotspots” or “Warn on unreviewed hotspots.”
- **IDE:** “Fix” vs “Mark as reviewed” or “Open review workflow” for hotspots.

### 3.5 Implementation notes

- Phase 1: Use `RuleType.securityHotspot` only (Option A); document and use in reporting/gates.
- Phase 2: If the extension or IDE supports a “review” workflow, add `requiresReview` (or equivalent) in the diagnostic/reporter layer (Option B).
- Reclassify existing security rules in batches; start with 3–5 clear hotspot candidates.

---

## 4. Standards mapping beyond OWASP (CWE, CERT)

### 4.1 Goal

Link security (and optionally other) rules to CWE and optionally CERT so that compliance reports and filtering can align with these standards in addition to OWASP.

### 4.2 Current state

- **OWASP:** `OwaspMapping` with Mobile Top 10 and Web Top 10; optional `owasp` getter on rules; compliance reports in `lib/src/owasp/`.
- **CWE / CERT:** Not represented.

### 4.3 Proposed design

**4.3.1 CWE identifiers**

Add optional CWE IDs (list to support one rule mapping to multiple weaknesses):

```dart
/// CWE identifiers this rule helps prevent or detect.
/// https://cwe.mitre.org/
/// Example: [798] for CWE-798 (Hardcoded Credentials).
List<int> get cweIds => const [];
```

Example:

```dart
// avoid_hardcoded_credentials
@override
List<int> get cweIds => const [798];  // CWE-798: Use of Hard-coded Credentials

// require_ssl_for_sensitive_data
@override
List<int> get cweIds => const [319];  // CWE-319: Cleartext Transmission of Sensitive Information
```

**4.3.2 CERT (optional)**

If we want CERT mapping, add similarly:

```dart
/// CERT coding standard identifiers (e.g. CERT rule IDs or chapter references).
/// Example: ['STR02-C'] for C standard; for Dart we may use conceptual mappings.
List<String> get certIds => const [];
```

Populate only where we have a clear mapping; leave empty for most rules initially.

**4.3.3 Reporting**

- Extend compliance report (e.g. `generateComplianceReport`) to include a “CWE coverage” section: for each CWE ID, list rules that map to it.
- Optional: export a small JSON (e.g. `rule -> [CWE-798, CWE-319]`) for external tools.

### 4.4 Use cases

- **Compliance:** “We need to show coverage of CWE Top 25” — report which rules map to which CWEs.
- **Filtering:** “Show me all rules that address CWE-798.”
- **Docs:** Rule detail page shows “OWASP: M1; CWE: 798.”

### 4.5 Implementation notes

- Add `cweIds` (and optionally `certIds`) to `SaropaLintRule`; default `const []`.
- Create a small reference list (e.g. `docs/cwe_mapping.md` or a Dart map) of CWE ID → short name for reports.
- Populate CWE for security rules in batches; CERT can be added later and sparingly.

---

## 5. Rule tags for filtering and discovery

### 5.1 Goal

Attach a set of tags to each rule so users and tooling can filter and discover rules by concept (e.g. “performance,” “accessibility,” “suspicious”) without relying only on tier and category folders.

### 5.2 Current state

- **Tiers:** Essential → Pedantic, Stylistic.
- **Categories:** Folder/file-based (e.g. `security/`, `ui/`, `widget/`).
- **Impact:** LintImpact (critical → opinionated).
- There is no first-class set of string tags per rule.

### 5.3 Proposed design

```dart
/// Tags for filtering and discovery (e.g. in docs, IDE, or CI).
/// Examples: 'performance', 'accessibility', 'suspicious', 'convention'.
Set<String> get tags => const {};
```

**Tag vocabulary (controlled set recommended):**

- **Domain:** `security`, `accessibility`, `performance`, `testing`, `i18n`, `a11y`, `network`, `storage`, `ui`, `state-management`.
- **Nature:** `suspicious`, `convention`, `bad-practice`, `pitfall`, `design`, `maintainability`, `reliability`.
- **Context:** `flutter`, `dart-core`, `async`, `disposal`, `crypto`.

**Examples:**

```dart
// avoid_undisposed_controller
@override
Set<String> get tags => const {'disposal', 'reliability', 'flutter'};

// avoid_hardcoded_credentials
@override
Set<String> get tags => const {'security', 'suspicious'};

// prefer_semantics_label
@override
Set<String> get tags => const {'accessibility', 'a11y', 'flutter'};

// require_item_extent_for_large_lists
@override
Set<String> get tags => const {'performance', 'flutter', 'ui'};
```

**Backward compatibility:** Default `tags => const {}`. Populate incrementally; tools that consume tags treat “no tags” as “uncategorized” or infer from folder/impact.

### 5.4 Use cases

- **Docs/ROADMAP:** “Show all rules with tag `accessibility`.”
- **Init wizard:** “Enable all rules tagged `security` and `performance`.”
- **Extension:** Filter rule list by tag.
- **CI/reports:** “List violations grouped by tag” or “Only run rules with tag `security`.”

### 5.5 Implementation notes

- Add `Set<String> get tags => const {}` to `SaropaLintRule`.
- Prefer a controlled vocabulary (e.g. in `lib/src/rule_tags.dart` as `const Set<String> allowedTags`) to avoid typo proliferation; lint or tests can warn on unknown tags.
- Populate tags in batches (e.g. by folder first: all `security/*` get `security` plus more specific tags).

---

## 6. Quality gates (pass/fail on metrics)

### 6.1 Goal

Allow the build or CI to fail (or warn) based on configurable conditions over diagnostic counts or impact (e.g. “fail if there are any new critical issues” or “warn if new security issues > 0”).

### 6.2 Current state

- **Baseline:** File-based, path-based, and date-based baselines suppress existing violations; they do not define “pass” or “fail.”
- **Analysis:** `dart analyze` exits with a non-zero code when the analyzer reports errors (and optionally infos); saropa_lints does not add a separate “gate” over its own metrics.

### 6.3 Proposed design

**6.3.1 Gate conditions (conceptual)**

A “quality gate” is a set of conditions; if any condition fails, the gate fails (and optionally the process exits non-zero). Conditions are defined over:

- **Scope:** “new code” vs “overall” (see §7 for “new code”).
- **Metric:** e.g. count of issues by severity, by impact, or by rule type.
- **Threshold:** e.g. “new critical > 0” → fail; “new code smells < 50” → pass.

**6.3.2 Example configuration (YAML, consumed by script or extension)**

```yaml
# Example: saropa_quality_gate.yaml (or under analysis_options / plugin config)
quality_gate:
  conditions:
    - metric: new_critical_issues
      op: eq
      value: 0
      on_fail: fail
    - metric: new_vulnerabilities
      op: eq
      value: 0
      on_fail: fail
    - metric: new_security_hotspots
      op: le
      value: 5
      on_fail: warn
    - metric: new_high_issues
      op: le
      value: 10
      on_fail: warn
```

**6.3.3 Where gates run**

- **Option A — Script:** A CLI (e.g. `dart run saropa_lints:gate`) runs after analysis, reads diagnostic output (or a report file), computes “new” vs “overall” from baseline/new-code logic, and exits 1 if any condition fails.
- **Option B — Extension:** VS Code extension runs analysis, evaluates gate conditions, and shows “Quality gate failed” and a summary.
- **Option C — Publish/CI script:** Integrate gate check into existing `scripts/publish.py` or CI so that “publish” or “main build” can fail when gate conditions are not met.

**6.3.4 Example script usage**

```bash
dart analyze --format=machine > analysis.out
dart run saropa_lints:gate --report analysis.out --config saropa_quality_gate.yaml
# Exit 1 if new_critical_issues != 0 or new_vulnerabilities != 0
```

### 6.4 Use cases

- **CI:** “Block merge if there are new critical or vulnerability findings.”
- **Release:** “Do not publish if gate fails.”
- **Gradual adoption:** “Warn on new high-impact issues but only fail on critical.”

### 6.5 Implementation notes

- “New” depends on a definition of new code (see §7); gate script or extension must consume baseline + new-code range.
- Start with a standalone script (Option A) that reads analyzer output or a JSON report; add config file and then optional integration into extension/CI.
- Reuse existing reporting (e.g. impact report, violation export) so the gate does not duplicate analysis logic.

---

## 7. New-code metrics and reporting

### 7.1 Goal

Define “new code” (e.g. lines or files changed since a baseline date or branch) and report diagnostics or metrics only for new code, so teams can track “quality of new code” separately from legacy.

### 7.2 Current state

- **Date-based baseline:** `baseline.date` suppresses violations in code unchanged since a given date (git-blame–based). This effectively “ignores” old code for reporting of violations.
- We do not have a first-class “new code” concept used to compute and report metrics (e.g. “12 issues in new code, 340 in overall”).

### 7.3 Proposed design

**7.3.1 Definition of “new code”**

- **Option A — Date-based:** Same as baseline: “new” = lines (or files) with last change (git blame) after a configured date (e.g. `new_code_date: 2025-01-01` or `new_code_since: 30d`).
- **Option B — Branch-based:** “New” = lines changed in the current branch vs a target ref (e.g. `main`). Requires diff/blame and a ref.
- **Option C — Baseline file:** “New” = violations not listed in the baseline file; “existing” = listed in baseline. So “new” = any violation not in the baseline.

We already have date-based logic in `BaselineManager` and path-based baselines; reuse for “new code” range.

**7.3.2 New-code report output**

After analysis, produce a summary that separates counts by “new” vs “overall” (or “existing”):

```
New code (since 2025-01-01):
  Critical: 0, High: 2, Medium: 8, Low: 14
  By type: bugs 0, vulnerabilities 0, code smells 10, security hotspots 2

Overall:
  Critical: 1, High: 12, Medium: 156, Low: 892
```

And/or a machine-readable report (JSON):

```json
{
  "new_code": { "since": "2025-01-01", "critical": 0, "high": 2, "medium": 8, "low": 14 },
  "overall": { "critical": 1, "high": 12, "medium": 156, "low": 892 }
}
```

**7.3.3 Integration with quality gates**

Gate conditions (§6) reference “new” metrics (e.g. `new_critical_issues`, `new_vulnerabilities`). The gate script or extension computes “new” using the same new-code definition and then evaluates conditions.

### 7.4 Use cases

- **CI:** “Fail if new code has any critical/vulnerability” while allowing legacy to have many issues.
- **Trends:** “New code issues this sprint: 5 → 3 → 2.”
- **Compliance:** “We only require zero critical in new code; legacy is on a roadmap.”

### 7.5 Implementation notes

- Reuse `BaselineDate` / git-blame logic for date-based “new code”; add a dedicated “new code report” path that does not suppress diagnostics but only classifies them for reporting.
- If we use “violations not in baseline” as “new,” we need a way to run analysis and produce both “all violations” and “violations in baseline” so that “new” = all − baseline.
- Document the chosen definition (date vs branch vs baseline) in the user guide and gate docs.

---

## 8. Rule lifecycle status (Beta, Ready, Deprecated)

### 8.1 Goal

Mark each rule with a lifecycle status (e.g. beta, ready, deprecated) so users and docs know what to expect (stability, false-positive risk, sunset).

### 8.2 Current state

- Rules are either present or not; there is no “beta” or “deprecated” flag.
- Deprecation or removal is done by removing the rule or documenting in CHANGELOG; no in-rule status.

### 8.3 Proposed design

```dart
/// Lifecycle status of this rule.
enum RuleStatus {
  /// Stable; recommended for production use.
  ready,
  /// Under evaluation; may have more false positives or behavior changes.
  beta,
  /// No longer recommended; will be removed in a future version.
  deprecated,
}

abstract class SaropaLintRule extends DartLintRule {
  /// Default [ready]. Use [beta] for new or heuristic-heavy rules.
  RuleStatus get ruleStatus => RuleStatus.ready;
}
```

**Examples:**

```dart
// New rule with heuristic detection
@override
RuleStatus get ruleStatus => RuleStatus.beta;

// Old rule we plan to remove in favor of analyzer built-in
@override
RuleStatus get ruleStatus => RuleStatus.deprecated;
```

**Documentation and UI:**

- **ROADMAP / rule list:** Show a badge or column “Status: Ready | Beta | Deprecated.”
- **Rule DartDoc:** “**Status:** Beta. May produce false positives; feedback welcome.”
- **Extension:** Optional filter “Hide deprecated” or “Show only ready.”
- **Deprecation:** When status is deprecated, include in message or docs: “This rule is deprecated and will be removed in vX.Y. Prefer ….”

### 8.4 Use cases

- **New rules:** Ship as beta; promote to ready after feedback and tuning.
- **Heuristic rules:** Keep as beta so users expect possible FPs.
- **Sunset:** Mark deprecated, document replacement, remove in next major.

### 8.5 Implementation notes

- Default `ruleStatus => RuleStatus.ready` for backward compatibility.
- Add `ruleStatus` to any JSON/CSV export and to docs generation so the website and init wizard can show or filter by status.
- For deprecated rules, consider emitting a single “deprecation” info diagnostic per file or per run (to avoid noise) and document removal version in CHANGELOG.

---

## 9. Implementation order and dependencies

Suggested order to minimize rework and allow incremental delivery:

| Phase | Items | Rationale |
|-------|--------|-----------|
| 1 | Rule type (§1), Rule status (§8) | Pure metadata on rules; no new infra. Enables reporting and docs. |
| 2 | Accuracy targets doc (§2), Security hotspot workflow (§3) | Doc + convention and optional `requiresReview`; builds on rule type. |
| 3 | CWE mapping (§4), Tags (§5) | More metadata; reporting and filtering. |
| 4 | New-code metrics (§7) | Reuse baseline/date logic; needed for gates. |
| 5 | Quality gates (§6) | Depends on new-code and rule type; script first, then optional extension/CI. |

---

## 10. Open questions

- **Rule type default:** When `ruleType` is null, should reporting treat the rule as “unspecified” or infer from folder (e.g. `security/` → vulnerability)?
- **Security hotspot in analyzer:** Can the Dart analyzer / IDE represent “review required” in a way that doesn’t look like a normal fix? If not, we may rely on rule type + docs and extension-only “review” UX.
- **Gate config location:** Should gate conditions live in `analysis_options.yaml` under the plugin, in a separate `saropa_quality_gate.yaml`, or in the extension’s workspace settings?
- **New-code default:** Prefer date-based, branch-based, or “violations not in baseline” as the default “new code” definition for the first release of new-code reporting?
- **Tags vocabulary:** Strict enum/const set vs free-form strings with recommended list in docs?

---

## 11. Summary table

| # | Enhancement | Main artifact | Default / backward compat |
|---|-------------|---------------|----------------------------|
| 1 | Rule type | `RuleType? get ruleType => null` | null = unspecified |
| 2 | Accuracy targets | Doc + optional `AccuracyTarget? get accuracyTarget => null` | Doc only first |
| 3 | Security hotspot | `RuleType.securityHotspot` + optional `requiresReview` | No change to existing rules until reclassified |
| 4 | CWE/CERT | `List<int> get cweIds`, `List<String> get certIds` | `const []` |
| 5 | Tags | `Set<String> get tags => const {}` | empty set |
| 6 | Quality gates | Script + config (YAML) | Opt-in; no change to analyze exit code by default |
| 7 | New-code metrics | Report format + script/extension | Opt-in; reuse baseline date logic |
| 8 | Rule status | `RuleStatus get ruleStatus => RuleStatus.ready` | ready |

All of the above are additive and optional so that existing rules and users continue to work unchanged while we roll out metadata and features incrementally.
