# Discussion: Custom Ignore Prefixes (Support custom `// saropa-ignore:`, `// tech-debt:` prefixes)

**Source:** [GitHub Discussion #59](https://github.com/saropa/saropa_lints/discussions/59)  
**Priority:** Low  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)

---

## 1. Goal

Support project-specific ignore comment styles so that:

- **Standard:** `// ignore: avoid_print` continues to work (Dart convention).
- **Branded:** `// saropa-ignore: avoid_print` is supported for teams that want to distinguish saropa_lints suppressions.
- **Tech debt:** `// tech-debt: avoid_print` (or similar) can be tracked separately for auditing and cleanup campaigns (see Discussion #56 Suppression Tracking).

---

## 2. Current state in saropa_lints

- **IgnoreUtils** (`lib/src/ignore_utils.dart`): Parses `// ignore: rule_name` and `// ignore_for_file: rule_name`; supports both underscore and hyphenated rule names. No other prefixes are recognized.
- **Dart analyzer:** Only `// ignore:` and `// ignore_for_file:` are built-in. Custom prefixes are not processed by the analyzer; they would need to be handled inside the custom_lint plugin (e.g. when deciding whether to report, check for these patterns in addition to `ignore:`).

---

## 3. Proposed design (from Discussion #59)

```dart
// All of these would suppress the lint:
// ignore: avoid_print
// saropa-ignore: avoid_print
// tech-debt: avoid_print (tracked separately for auditing)
```

- **Parsing:** Extend IgnoreUtils (or equivalent) to look for:
  - `ignore: rule_name` (current)
  - `saropa-ignore: rule_name`
  - `tech-debt: rule_name` (and optionally other configurable prefixes)
- **Semantics:** Same as `ignore:` — if the comment applies to the line/block/file and the rule name matches, do not report.
- **Suppression tracking:** When recording a suppression (Discussion #56), store the prefix used so reports can filter e.g. "all tech-debt suppressions."

---

## 4. Use cases

| Use case | How custom prefixes help |
|----------|---------------------------|
| Branding | Teams use `saropa-ignore:` so it’s clear which linter is being suppressed. |
| Tech debt | Use `tech-debt: rule_name` and report them separately; e.g. "fix all tech-debt suppressions this quarter." |
| Policy | Require that production code only use `ignore:` with a ticket, and use `tech-debt:` for temporary suppressions. |
| Grep/search | Search for `tech-debt:` or `saropa-ignore:` to find suppressions without mixing with other tools’ ignores. |

---

## 5. Research and prior art

- **ESLint:** Only `eslint-disable(-next-line|-line)?` and variants. Descriptions can be added after `--` (e.g. `// eslint-disable-next-line no-console -- tech-debt: remove in Q2`); the part after `--` is not a separate "prefix" but is used for documentation and some tools parse it for tech-debt.
- **Dart:** No native support for custom ignore prefixes; any custom prefix must be implemented in the plugin.
- **Conclusion:** Supporting additional prefixes in the plugin (e.g. `saropa-ignore:`, `tech-debt:`) is straightforward: same parsing logic as `ignore:`, with a list of allowed prefixes. Optionally make the list configurable (e.g. in analysis_options or env).

---

## 6. Implementation considerations

- **Parsing:** Reuse the same line/block/file logic as IgnoreUtils; add a regex or list of prefixes (e.g. `ignore:`, `saropa-ignore:`, `tech-debt:`). Require a colon and then the rule name (with hyphen/underscore).
- **Config:** Allow users to add custom prefixes via config (e.g. `custom_ignore_prefixes: [ "tech-debt", "saropa-ignore" ]`) so teams can define their own.
- **Backward compatibility:** Existing `// ignore:` must keep working; new prefixes are additive.
- **Suppression tracking:** When recording a suppression, store the prefix (e.g. `"ignore"`, `"tech-debt"`) so reports can group by prefix.

---

## 7. Open questions

- Default list: ship with `ignore`, `saropa-ignore`, `tech-debt` or only `ignore` and make the rest configurable?
- Should `ignore_for_file` have equivalent prefixes (e.g. `tech-debt_for_file: avoid_print`)?
- Document in README and in rule docs that these prefixes are supported and how they interact with Suppression Tracking.
