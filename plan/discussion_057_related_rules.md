# Discussion: Related Rules (Link related rules together, suggest complementary rules)

**Source:** [GitHub Discussion #57](https://github.com/saropa/saropa_lints/discussions/57)  
**Priority:** Low  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)  
**Last reviewed:** 2026-04-14

---

## 1. Goal

Link rules together for better discoverability and guidance:

- **Discoverability:** When a user enables or fixes one rule, suggest related rules (e.g. "you might also want `require_animation_controller_dispose`").
- **Documentation / IDE:** Show "Related rules" in rule docs, the VS Code extension sidebar, or hover tooltips.
- **Consistency:** Group rules that address the same theme (dispose, security, accessibility) so teams can enable coherent sets.

---

## 2. Current state in saropa_lints

### What exists

- **Tiers:** Rules are grouped by tier (essential, recommended, professional, comprehensive, pedantic) and by category (files like `disposal_rules.dart`, `security_rules.dart`). No per-rule "related rules" field.
- **`tags` getter:** `SaropaLintRule.tags` (line 2016 of `saropa_lint_rule.dart`) returns `Set<String>` for filtering/discovery. ~2083 tag assignments across 115 rule files. Examples: `'performance'`, `'accessibility'`, `'suspicious'`, `'convention'`. Tags provide implicit grouping — rules sharing a tag are thematically related — but there is no explicit pairwise "related" link.
- **OWASP mapping:** `SaropaLintRule.owasp` maps security rules to OWASP categories; another form of implicit grouping.
- **CWE / CERT IDs:** `cweIds` and `certIds` getters provide cross-references to external standards.
- **Rule Packs (extension):** The VS Code extension has a "Rule Packs" sidebar (`rulePacksWebviewProvider.ts`) that groups rules into toggleable packs by package/domain. This is the closest existing "enable a coherent set" mechanism.

### What does NOT exist

- No per-rule `relatedRules` getter or equivalent.
- No "see also" in rule DartDocs.
- No structured "related rules" display in the extension's Rule Explain panel, hover tooltips, or tree items.

### Implicit vs. explicit related rules

The `tags` getter already enables tag-based discovery ("find all rules tagged `dispose`"). Adding an explicit `relatedRules` getter adds value only where:

1. Two rules are related but don't share a tag (e.g. `require_dispose` and `avoid_build_context_in_async` — both prevent subtle bugs but in different domains).
2. There's a directional recommendation ("if you enable A, you should strongly consider B") that a tag alone doesn't convey.
3. There's a stricter/looser variant relationship (e.g. `prefer_const_constructors` vs `prefer_const_declarations`).

---

## 3. Proposed design (from Discussion #57)

```dart
class RequireDisposeRule extends SaropaLintRule {
  @override
  List<String> get relatedRules => const [
    'require_stream_controller_dispose',
    'require_animation_controller_dispose',
  ];
}
```

- **relatedRules:** Optional getter on `SaropaLintRule` returning a list of rule names (canonical names as in `code.lowerCaseName`).
- **Default:** Empty list (same pattern as `configAliases`, `cweIds`, `certIds`).
- **Semantics:** "Rules that are thematically or behaviorally related" — e.g. same domain (dispose, async, security), stricter/looser variants, or commonly co-enabled rules.
- **Consumption points:** See Section 6.

---

## 4. Use cases

| Use case | How related rules help |
|----------|----------------------|
| Init / onboarding | After user enables a rule, suggest related rules so they get a coherent set. |
| Extension: Rule Explain panel | Show "Related: require_animation_controller_dispose, require_stream_controller_dispose" with clickable links. |
| Extension: Hover tooltips | Show related rules in the hover card when a violation is highlighted. |
| Extension: Suggestions tree | When fixing one violation, suggest enabling a related rule to prevent similar issues. |
| Docs generation | On pub.dev or generated markdown, show "See also" per rule. |
| Tier design | When moving a rule to a different tier, consider moving related rules together. |
| Rule Packs | Auto-suggest expanding a rule pack when a related rule outside the pack is enabled. |

---

## 5. Research & prior art

- **ESLint:** No built-in "related rules" field; plugins sometimes document "see also" in rule docs. The `recommended` and `plugin:recommended` configs group rules but don't define pairwise relations.
- **SonarQube:** Rules are tagged with categories and types; "related rules" are sometimes shown in the UI based on tags, not explicit links.
- **Stylelint:** Rules have metadata; some tools use tags to suggest "similar" rules.
- **Roslyn:** Analyzers are independent; no standard "related analyzer" API; docs and NuGet package descriptions serve as the main discovery.

Conclusion: An optional `List<String> relatedRules` on the rule class is low cost and enables better docs and tooling without changing analysis behavior. The `tags` getter already handles tag-based grouping; `relatedRules` adds explicit pairwise links that tags can't express.

---

## 6. Implementation plan

### Phase 1: Dart-side metadata (low complexity)

1. **Add `relatedRules` getter to `SaropaLintRule`** — default empty `const <String>[]`, same pattern as `cweIds`.
2. **Add startup validation** — during plugin init, warn if any name in `relatedRules` doesn't exist in the rule registry. Log warning, don't crash.
3. **Populate selectively** — start with a few obvious clusters (disposal rules, security credential rules, async rules). Do NOT attempt to populate all 2100+ rules at once.

### Phase 2: Extension surfaces (low-medium complexity)

4. **Rule Explain panel** — add a "Related rules" section to the HTML, with clickable links that open the explain panel for each related rule.
5. **Hover provider** — if a violation's rule has `relatedRules`, append a brief "See also: ..." line to the hover card.
6. **Suggestions tree** — when a related rule is disabled, surface it as a suggestion ("Consider enabling X").

### Phase 3: Documentation (low complexity)

7. **Docs generation** — include "Related rules" in any generated markdown/JSON rule catalog.
8. **Init CLI** — during `dart run saropa_lints:init`, after enabling a rule, mention related rules the user hasn't enabled.

---

## 7. Implementation considerations

- **Maintenance:** Startup validation (Phase 1, step 2) catches stale references when rules are renamed or removed.
- **Direction:** One-way is fine (A lists B; B doesn't need to list A). The extension can compute the reverse mapping at runtime if bidirectional display is wanted.
- **Size:** Keep lists small (2-5 per rule). This isn't a recommendation engine — it's curated "see also."
- **Tags overlap:** If two rules already share a tag, `relatedRules` is redundant unless there's a specific recommendation relationship. Don't duplicate what tags already provide.
- **Cycles:** A -> B -> A is fine for short curated lists. No enforcement needed.

---

## 8. Open questions

1. **Relationship types:** Should we distinguish "related" from "conflicts with" (e.g. `prefer_single_quotes` vs `prefer_double_quotes`) and "supersedes" (for deprecated/renamed rules)? Or keep a single flat `relatedRules` list and handle conflicts via a separate `conflictsWith` getter later?
2. **Tag-based auto-discovery:** Should the extension also show "rules with the same tag" alongside explicit `relatedRules`? This could be noisy for broad tags like `'performance'` (49 rules in `performance_rules.dart` alone).
3. **Rule Packs integration:** Should rule packs auto-suggest related rules that aren't in the pack? Or is that scope creep for this discussion?

---

## 9. Decision log

| Date | Decision |
|------|----------|
| 2026-03-01 | Initial plan drafted from Discussion #57. |
| 2026-03-19 | No changes; plan still speculative. |
| 2026-04-14 | Updated: documented existing `tags` getter (2083 usages), extension surfaces (Rule Explain, hover, suggestions, rule packs), added phased implementation plan, clarified when `relatedRules` adds value beyond tags. |
