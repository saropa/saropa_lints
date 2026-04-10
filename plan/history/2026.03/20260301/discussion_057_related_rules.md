# Discussion: Related Rules (Link related rules together, suggest complementary rules)

**Source:** [GitHub Discussion #57](https://github.com/saropa/saropa_lints/discussions/57)  
**Priority:** Low  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)

---

## 1. Goal

Link rules together for better discoverability and guidance:

- **Discoverability:** When a user enables or fixes one rule, suggest related rules (e.g. "you might also want `require_animation_controller_dispose`").
- **Documentation / IDE:** Show "Related rules" in rule docs or in the IDE (e.g. code actions or hover).
- **Consistency:** Group rules that address the same theme (dispose, security, accessibility) so teams can enable coherent sets.

---

## 2. Current state in saropa_lints

- **Tiers:** Rules are grouped by tier (essential, recommended, professional, comprehensive, pedantic) and by category (files like `disposal_rules.dart`, `security_rules.dart`). There is no per-rule "related rules" field.
- **Documentation:** Rule docs (DartDoc) and ROADMAP/CHANGELOG describe rules individually; no structured "see also" list per rule.
- **OWASP mapping:** `SaropaLintRule.owasp` maps security rules to OWASP categories; that’s a form of grouping but not "related rule" links.

---

## 3. Proposed design (from Discussion #57)

```dart
class RequireDisposeRule extends SaropaLintRule {
  @override
  List<String> get relatedRules => [
    'require_stream_controller_dispose',
    'require_animation_controller_dispose',
  ];
}
```

- **relatedRules:** Optional getter on `SaropaLintRule` returning a list of rule names (canonical names as in `code.name`).
- **Semantics:** "Rules that are thematically or behaviorally related" — e.g. same domain (dispose, async, security), or stricter/looser variants.
- **Consumption:** Used by docs generation, init script (e.g. "you enabled X, consider Y and Z"), or IDE plugins to show "Related rules" or quick-enable suggestions.

---

## 4. Use cases

| Use case | How related rules help |
|----------|-------------------------|
| Init / onboarding | After user enables a rule, suggest related rules so they get a coherent set. |
| Docs | On pub.dev or in IDE, show "Related: require_animation_controller_dispose, require_stream_controller_dispose." |
| Fix guidance | When fixing one violation, suggest enabling a related rule to prevent similar issues. |
| Tier design | When moving a rule to a different tier, consider moving related rules together. |

---

## 5. Research & prior art

- **ESLint:** No built-in "related rules" field; plugins sometimes document "see also" in rule docs. The `recommended` and `plugin:recommended` configs group rules but don’t define pairwise relations.
- **SonarQube:** Rules are tagged with categories and types; "related rules" are sometimes shown in the UI based on tags, not explicit links.
- **Stylelint:** Rules have metadata; some tools use tags to suggest "similar" rules.
- **Roslyn:** Analyzers are independent; no standard "related analyzer" API; docs and NuGet package descriptions serve as the main discovery.

Conclusion: An optional `List<String> relatedRules` (or `relatedRuleNames`) on the rule class is low cost and enables better docs and tooling without changing analysis behavior.

---

## 6. Implementation considerations

- **Maintenance:** Keeping related rules up to date when rules are renamed or removed (e.g. validate that names in `relatedRules` exist in the registry).
- **Direction:** Keep the list small (e.g. 2–5) and one-way is fine (A lists B; B doesn’t need to list A) unless we want bidirectional "related" in the UI.
- **Cycles:** Avoid A → B → A; no strict need to enforce if the list is short and curated.
- **Where to consume:** Init script, generated markdown/docs, and any future IDE or web dashboard.

---

## 7. Open questions

- Should related rules be validated at startup (warn if a name doesn’t exist)?
- Do we want a separate "replaces" or "supersedes" for deprecated/renamed rules?
- Should we add "conflicts with" (e.g. prefer_single_quotes vs prefer_double_quotes) in addition to "related"?
