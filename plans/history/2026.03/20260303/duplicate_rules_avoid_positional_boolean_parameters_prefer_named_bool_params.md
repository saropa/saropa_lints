# Bug Report: Duplicate / Overlapping Rules — `avoid_positional_boolean_parameters` and `prefer_named_bool_params`

**Date:** 2026-03-03  
**Status:** Open  
**Severity:** Low (noise, double diagnostics; no crash or wrong result)  
**Rules:** `avoid_positional_boolean_parameters`, `prefer_named_bool_params`

---

## 1. Executive summary

Two saropa_lints rules report the **same issue** (positional boolean parameters) and recommend the **same fix** (use a named parameter). When both are enabled—as they are in the same tier—every affected call site receives **two diagnostics** for the same parameter. They are semantically duplicate for the common case; one should be deprecated, removed from the default tier, or merged so that only a single rule reports.

---

## 2. Evidence that they are duplicate

### 2.1 Same trigger and location

Both rules fire on the **same source location** (same line/column) for the same parameter. Example from a consumer project:

**File:** `lib/widgets/card_options.dart` (e.g. radiant_vector game), line 153:

```dart
static T? _clearable<T>(bool clear, T? param, T? current) =>
    clear ? null : (param ?? current);
```

**Diagnostic 1:**
- `code`: `avoid_positional_boolean_parameters`
- `message`: "[avoid_positional_boolean_parameters] Positional bool parameter makes call sites unreadable. Use named parameters for clarity. Convert to a named parameter so call sites are self-documenting."
- `startLineNumber`: 153, `startColumn`: 27, `endColumn`: 37

**Diagnostic 2:**
- `code`: `prefer_named_bool_params`
- `message`: "[prefer_named_bool_params] Prefer named parameter for boolean parameters. Convert to a named parameter (e.g. {required bool visible})."
- `startLineNumber`: 153, `startColumn`: 27, `endColumn`: 37

Same span, same parameter (`bool clear`), same intent.

### 2.2 Same intent in codebase

- **AvoidPositionalBooleanParametersRule** (DartDoc in `code_quality_avoid_rules.dart`): "Positional bool parameter makes call sites unreadable. Use named parameters for clarity."
- **PreferNamedBoolParamsRule** (DartDoc in `code_quality_prefer_rules.dart`): "Prefer named parameter for boolean parameters." Correction: "Convert to a named parameter (e.g. {required bool visible})."

The in-repo DartDoc for a *neighboring* rule (`BannedUsageRule`) explicitly states: *"Complements avoid_positional_boolean_parameters; **use one or the other**."* So the design intent was that consumers use **one or the other**, not both. Currently both are enabled in the same tier, so "use one or the other" is violated by default.

### 2.3 Consumer documentation treats them as one

In the radiant_vector project, `docs/lint-issues-todo.md` documents them as a single item:  
`avoid_positional_boolean_parameters / prefer_named_bool_params | Use named bool parameter (e.g. visible → isVisible).`

---

## 3. Behavioral difference (narrow)

The two rules are **not** byte-identical:

| Aspect              | `avoid_positional_boolean_parameters`          | `prefer_named_bool_params`                      |
| ------------------- | ---------------------------------------------- | ----------------------------------------------- |
| **Parameter count** | No limit; reports any positional `bool`        | Only reports when `node.parameters.length <= 3` |
| **Bool type**       | `bool` only (via `type.name.lexeme == 'bool'`) | `bool` or `bool?` (`'bool'` or `'bool?'`)       |
| **Impact**          | `LintImpact.medium`                            | `LintImpact.low`                                |

So:

- For functions with **1–3 parameters** and a positional `bool` (or `bool?` for prefer_*): **both** rules fire → **duplicate diagnostics**.
- For functions with **4+ parameters** and a positional `bool`: only `avoid_positional_boolean_parameters` fires.
- For nullable `bool?` with 4+ parameters: only `avoid_positional_boolean_parameters` might fire (and only if that rule is extended to `bool?`); `prefer_named_bool_params` would not fire due to param count.

In practice, the vast majority of "positional bool" cases are small functions (1–3 params), so users see double reports.

---

## 4. Where the rules are defined and enabled

### 4.1 Rule implementations

| Rule                                | Class                                  | File                                           | Approx. line |
| ----------------------------------- | -------------------------------------- | ---------------------------------------------- | ------------ |
| avoid_positional_boolean_parameters | `AvoidPositionalBooleanParametersRule` | `lib/src/rules/code_quality_avoid_rules.dart`  | 3401         |
| prefer_named_bool_params            | `PreferNamedBoolParamsRule`            | `lib/src/rules/code_quality_prefer_rules.dart` | 1940         |

Both are registered in `lib/saropa_lints.dart` (e.g. `AvoidPositionalBooleanParametersRule.new`, `PreferNamedBoolParamsRule.new`).

### 4.2 Tier / default enablement

Both appear in the same tier in `lib/src/tiers.dart` (e.g. around 1555 and 1559):

- `'avoid_positional_boolean_parameters'`
- `'prefer_named_bool_params'`

So any analysis_options that include this tier enable **both** rules by default.

### 4.3 Fixtures and tests

- Fixtures: `example_core/lib/code_quality/avoid_positional_boolean_parameters_fixture.dart`, `example_core/lib/code_quality/prefer_named_bool_params_fixture.dart`.
- Tests reference both in `test/code_quality_rules_test.dart` and elsewhere (e.g. `test/roadmap_15_rules_test.dart`, `test/roadmap_detail_rules_test.dart`).

---

## 5. Impact

- **User experience:** Two info-level diagnostics per positional bool parameter in the typical case (1–3 parameters), with redundant messages and the same fix. Noisy and confusing.
- **No functional bug:** No crash, no wrong result; only redundancy.
- **Scope:** Any project that enables the tier containing both rules (e.g. generated or recommended analysis_options from saropa_lints).

---

## 6. Recommended fix (options)

### Option A — Remove one rule from the default tier (minimal change)

- Keep both rule implementations (for backward compatibility if someone explicitly enables only one).
- In `lib/src/tiers.dart`, **remove** `'prefer_named_bool_params'` from the tier that also contains `avoid_positional_boolean_parameters`.
- Result: default config produces a single diagnostic per positional bool; consumers can still opt in to `prefer_named_bool_params` if desired.

**Recommendation:** Prefer removing `prefer_named_bool_params` from the tier, since `avoid_positional_boolean_parameters` has the more descriptive name and matches the official Dart lint naming style (`avoid_*`).

### Option B — Deprecate and eventually remove one rule

- Mark `PreferNamedBoolParamsRule` as deprecated in DartDoc and in the rule’s message (e.g. "Deprecated: use avoid_positional_boolean_parameters instead").
- Remove it from the default tier (as in Option A).
- In a later major version, remove the rule class and its registration, and migrate any fixture/tests that reference it to `avoid_positional_boolean_parameters`.

### Option C — Merge behavior into a single rule

- Extend `AvoidPositionalBooleanParametersRule` to optionally support `bool?` (if desired) and document parameter-count policy in one place.
- Remove `PreferNamedBoolParamsRule` from registration and tiers; delete the class and its fixture; update tests.
- Single rule, single diagnostic, no duplication.

### Option D — Document only (no code change)

- In the rule DartDocs and in user-facing docs, state clearly: "Do not enable both avoid_positional_boolean_parameters and prefer_named_bool_params; they report the same issue. Enable only one."
- Leave the tier as-is. This reduces confusion for readers but does not fix the default double diagnostic.

---

## 7. Reproduction

### 7.1 Steps

1. Create or use a Dart project with `dev_dependencies: saropa_lints` and the saropa_lints plugin enabled in `analysis_options.yaml` (using a tier that includes both rules).
2. Add a file with at least one function that has a positional `bool` (and total parameters ≤ 3), e.g.:

   ```dart
   static T? _clearable<T>(bool clear, T? param, T? current) =>
       clear ? null : (param ?? current);
   ```

3. Run the analyzer (e.g. `dart analyze` or IDE analysis).
4. Observe two diagnostics on the same parameter: `avoid_positional_boolean_parameters` and `prefer_named_bool_params`.

### 7.2 Expected after fix

- Only one diagnostic per positional bool parameter when using the default (tier) configuration.
- Message and fix remain: use a named parameter.

---

## 8. References

- Rule implementations: `lib/src/rules/code_quality_avoid_rules.dart` (AvoidPositionalBooleanParametersRule), `lib/src/rules/code_quality_prefer_rules.dart` (PreferNamedBoolParamsRule).
- Tier list: `lib/src/tiers.dart` (both rule names in same tier).
- In-repo note: "use one or the other" in DartDoc near `BannedUsageRule`, `code_quality_avoid_rules.dart` ~3462.
- Consumer example: radiant_vector `game/lib/widgets/card_options.dart` line 153; `game/docs/lint-issues-todo.md`.

---

## 9. Checklist for maintainers

- [ ] Decide which option (A–D) to apply.
- [ ] If A or B: remove `prefer_named_bool_params` from the tier in `lib/src/tiers.dart` (and document deprecation if B).
- [ ] If C: merge behavior, remove PreferNamedBoolParamsRule, update fixtures and tests.
- [ ] If D: update DartDocs and user docs only.
- [ ] Run full test suite and `dart analyze` in saropa_lints and in a consumer with the plugin.
- [ ] CHANGELOG: note duplicate-rule fix or deprecation.

---

**End of report.**
