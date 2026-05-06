# Gap Analysis: saropa_lints vs External Dart Rules

**Goal:** Compare saropa_lints rules with another Dart rule set to find overlap, gaps (rules they have we don’t), and opportunities (rules we have they don’t).

**Status:** Draft — sources and procedure.

**Review note:** Procedure and script reference only; no runtime code in this file. Export script: `scripts/export_saropa_rules_for_gap.py`.

---

## 1. Getting the external Dart rules list

Many static analysis platforms support Dart and expose rules via a Web API. Rules are often not published as a static webpage list; you typically need one of the following.

### 1.1 Rules API (recommended)

Use the platform’s Web API to export all Dart rules (requires an instance with Dart analysis enabled).

**Typical endpoint:** `GET /api/rules/search`

**Parameters:**

| Parameter   | Value   | Notes                          |
|------------|---------|---------------------------------|
| `languages`| `dart`  | Filter by Dart only.            |
| `p`        | 1, 2, … | Page number (pagination).       |
| `ps`       | 100–500 | Page size (max often 500).      |

**Example (first page):**

```http
GET https://YOUR_ANALYZER_HOST/api/rules/search?languages=dart&ps=500&p=1
```

**Response shape (relevant fields):**

```json
{
  "total": 120,
  "p": 1,
  "ps": 500,
  "rules": [
    {
      "key": "dart:S1234",
      "name": "Rule display name",
      "htmlDesc": "Description...",
      "severity": "MAJOR",
      "type": "BUG",
      "tags": ["convention"],
      "lang": "dart"
    }
  ]
}
```

**To export all pages:**

1. Call with `p=1`, `ps=500`; read `total`.
2. Loop `p = 1` to `ceil(total / ps)`.
3. Concatenate all `rules` arrays into one list.
4. Save as JSON (e.g. `external_dart_rules.json`) for the gap script.

**Authentication:** If the instance is protected, use a user token: `Authorization: Bearer YOUR_TOKEN` or the platform’s recommended auth (prefer token).

**Without an instance:** You need access to a server/cloud instance with Dart analysis, or ask someone with access to run the API and share the JSON. There is often no official, downloadable “all Dart rules” CSV/JSON without using the API.

### 1.2 Web UI (manual)

- In the platform: **Quality Profiles** (or equivalent) → select a Dart profile → **Rules**.
- You can see rule keys and names; export options depend on the product (e.g. backup/export may give XML).
- Useful for spot-checks; for a full gap analysis, the API is more reliable.

### 1.3 Rules portal (reference only)

- Many vendors host a rules catalog (e.g. by language and tag).
- There is rarely a single “download all” link; use the API for a complete list.

---

## 2. Exporting saropa_lints rules

We need a list of rule **names** (and optionally tier, category, problem message) for comparison.

### 2.1 Option A: Dart script (authoritative)

Run from the repo root (with `dart run` from a package that depends on `saropa_lints`, or from within the saropa_lints package and use the same list we use at runtime):

```dart
// scripts/export_rule_names.dart (or run via dart run saropa_lints:export_rules if we add a bin)
import 'package:saropa_lints/saropa_lints.dart';

void main() {
  final rules = allSaropaRules;
  for (final r in rules) {
    print(r.code.lowerCaseName);
  }
}
```

To get more than names (e.g. tier, message), extend the loop:

```dart
for (final r in rules) {
  final name = r.code.lowerCaseName;
  final message = r.code.problemMessage;
  // tier: resolve from getRulesForTier / tiers.dart
  print('$name\t$message');
}
```

Save output to a file, e.g. `saropa_rule_names.txt` or CSV.

### 2.2 Option B: Python (no Dart runtime)

Use the same regex as `_rule_metrics.py` to extract rule names from source:

```python
# In scripts/modules or a one-off script
import re
from pathlib import Path

RULES_DIR = Path("lib/src/rules")
LINT_NAME_RE = re.compile(
    r"LintCode\s*\(\s*[\s\n]*'([A-Za-z][A-Za-z0-9_]*)'",
    re.MULTILINE,
)

def get_saropa_rule_names():
    names = []
    for f in RULES_DIR.glob("**/*_rules.dart"):
        if f.name == "all_rules.dart":
            continue
        content = f.read_text(encoding="utf-8")
        names.extend(LINT_NAME_RE.findall(content))
    return sorted(set(names))
```

Output: one name per line or CSV. Normalize to lowercase for comparison if needed (external keys are often like `dart:S1234`; names may be mixed case).

### 2.3 Suggested export format (for gap script)

Produce a JSON file, e.g. `saropa_rules.json`:

```json
[
  { "name": "avoid_hardcoded_credentials", "tier": "essential", "category": "security" },
  { "name": "avoid_undisposed_controller", "tier": "essential", "category": "architecture" }
]
```

Category can be derived from the path under `lib/src/rules/` (e.g. `security/crypto_rules.dart` → `security`). Tier can be resolved by checking membership in `essentialRules`, `recommendedOnlyRules`, etc. (e.g. via a small Dart script that uses `tiers.dart` and `allSaropaRules`).

---

## 3. Gap analysis procedure

### 3.1 Inputs

| Input | Description |
|------|-------------|
| `external_dart_rules.json` | Array of external rules (from §1.1). Each item: `key`, `name`, `type`, `tags`, etc. |
| `saropa_rules.json` or `saropa_rule_names.txt` | saropa_lints rule names (and optionally tier/category) from §2. |

### 3.2 Normalization

- **External:** Rule identity = `key` (e.g. `dart:S101`). For comparison by topic, use `name` and/or `htmlDesc`.
- **saropa_lints:** Rule identity = `code.name` (e.g. `avoid_hardcoded_credentials`).
- There is no shared ID; overlap is by **semantic similarity** (same or similar check), not by name string equality. So:
  - **Exact or near-exact name match:** e.g. “Parameter names should match base declaration” vs a rule we name similarly — flag as potential overlap.
  - **By topic/description:** Map external rules to categories (naming, security, disposal, etc.) and compare with our categories and rule names/messages.

### 3.3 Outputs (what the gap analysis should produce)

| Output | Description |
|--------|-------------|
| **Overlap (likely same)** | External rule X and saropa_lints rule Y cover the same (or very similar) issue. List (external key, external name, saropa name, confidence: high/medium/low). |
| **Only in external** | External rules with no saropa_lints counterpart. Prioritize by type (BUG, VULNERABILITY, SECURITY_HOTSPOT) and severity for ROADMAP candidates. |
| **Only in saropa_lints** | Our rules with no external counterpart. Useful for marketing and “what we add on top.” |
| **By category** | For each category (naming, security, disposal, …), counts and lists: overlap, only-external, only-saropa. |

### 3.4 Matching strategy

1. **By key/name string:** Build a set of normalized saropa names (lowercase, maybe strip underscores). For each external rule, normalize its `name` (lowercase, collapse spaces to underscores) and check for containment or equality (e.g. “parameter names should match” might map to our `prefer_correct_setter_parameter_name` or similar).
2. **By tag/type:** External `type` (BUG, VULNERABILITY, CODE_SMELL, SECURITY_HOTSPOT) and `tags` can be compared to our categories and impact (e.g. security → our `security/` + OWASP rules).
3. **Manual pass:** Automate the above to produce candidate pairs and “only in X” lists; then a human reviews and confirms overlap vs gap.

### 3.5 Example report (target format)

```markdown
## Gap analysis summary (YYYY-MM-DD)

- External Dart rules: N
- saropa_lints rules: M

### Overlap (high confidence)
| External key | External name | saropa_lints rule |
|--------------|---------------|-------------------|
| dart:S101    | Class names should comply... | prefer_camel_case_class_names |

### Only in external (candidates for ROADMAP)
| Key | Name | Type | Notes |
|----|------|------|-------|
| dart:S123 | ... | BUG | Consider adding. |

### Only in saropa_lints (by category)
- Security: avoid_hardcoded_credentials, require_ssl_for_sensitive_data, ...
- Disposal: avoid_undisposed_controller, ...
```

---

## 4. Scripts to add (optional)

- **`scripts/export_saropa_rules_for_gap.py`**: Reads `lib/src/rules`, outputs `saropa_rules.json` (name, category). See repo root run instructions in the script.
- **`scripts/gap_analysis_external.py`**: Reads `external_dart_rules.json` and `saropa_rules.json`; implements normalization and matching (§3.2–3.4); prints or writes the report (§3.5). Can take `--external-json` and `--saropa-json` paths.

These can live under `scripts/` or `bugs/discussion/` as one-off tools; if we run the gap regularly, move to `scripts/` and document in CONTRIBUTING or README.

---

## 5. Checklist

- [ ] Obtain external Dart rules JSON (API or from someone with access).
- [ ] Export saropa_lints rules to JSON or CSV (name + optional tier/category).
- [ ] Implement or run matching (normalized names + categories/types).
- [ ] Produce overlap table and “only in external” / “only in saropa_lints” lists.
- [ ] Manual review of overlap (high/medium/low) and “only external” for ROADMAP.
- [ ] Document findings in this file or a separate `GAP_ANALYSIS_RESULTS.md` and link from ROADMAP/CHANGELOG if we add rules from the gap.

---

## 6. References

- Typical rules API: `GET /api/rules/search` with `languages=dart`, pagination `p`, `ps`.
- saropa_lints rule list: `allSaropaRules` in `lib/saropa_lints.dart`; tier sets in `lib/src/tiers.dart`; categories from `lib/src/rules/**/*_rules.dart`.
