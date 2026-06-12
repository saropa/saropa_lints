# app_links 6.0 pre-upgrade migration pack (app_links_6)

app_links 6.0.0 removed the `getInitialAppLink()` / `getLatestAppLink()` methods
and the `allUriLinkStream` / `allStringLinkStream` broadcast getters. Code on 5.x
that uses them compiles today but will not compile after the v6 bump. The
package already shipped three always-on best-practice rules, but the three
pre-upgrade migration rules were split out and left unbuilt because they require
the `<`-version pack gate archetype — which has since been ratified and is in use
by `local_auth_3`, `connectivity_plus_6`, `webview_flutter`, and `file_picker_*`.

## Finish Report (2026-06-12)

### Scope
**(A)** Dart lint rules / analyzer plugin. No extension or Flutter app code —
Extension l10n SKIPPED [A-NOT-IN-SCOPE].

### What was built
Three rules in [app_links_rules.dart](../../../../lib/src/rules/packages/app_links_rules.dart),
each gated to the `app_links_6` pack (`app_links < 6.0.0`, pre-upgrade
readiness), each WARNING with a rename quick fix:

| rule | detects (removed in v6) | fix → v6 |
|---|---|---|
| `app_links_use_get_initial_link` | `getInitialAppLink()` call | `getInitialLink()` |
| `app_links_use_get_latest_link` | `getLatestAppLink()` call | `getLatestLink()` |
| `app_links_use_uri_link_stream` | `allUriLinkStream` / `allStringLinkStream` getter | `uriLinkStream` / `stringLinkStream` |

The method rules register on `addMethodInvocation` and match the removed method
name; the stream rule registers on both `addPrefixedIdentifier`
(`appLinks.allUriLinkStream`) and `addPropertyAccess`
(`AppLinks().allUriLinkStream`). All three gate on
`fileImportsPackage(node, PackageImports.appLinks)`, mirroring the three shipped
always-on app_links rules in the same file, so the distinctive getter/method
names cannot collide with unrelated code. A single shared quick fix
(`_AppLinksV6RenameFix`) renames the reported identifier via one old→new map,
serving all three rules.

### Severity rationale
WARNING, not ERROR: on the gated version (`< 6.0.0`) the symbols still exist and
compile, so these are pre-upgrade-readiness nudges, not current compile errors.
This matches the shipped `local_auth_3` / `connectivity_plus_6` / `webview_flutter`
migration renames (all WARNING with a mechanical fix) and the project's severity
calibration (ERROR is reserved for code that is broken on the current version).

### Wiring
- Registered in [saropa_lints.dart](../../../../lib/saropa_lints.dart) `_allRuleFactories`.
- Added to `appLinksPackageRules` and `comprehensiveOnlyRules` in
  [tiers.dart](../../../../lib/src/tiers.dart).
- Pack gate `app_links_6` (`<6.0.0`) in [rule_packs.dart](../../../../lib/src/config/rule_packs.dart).
- Relocation `app_links → app_links_6` for all three codes in
  [tool/rule_pack_audit.dart](../../../../tool/rule_pack_audit.dart).
- Pack marker + title (`app_links 6.x (pre-upgrade)`) in
  [tool/generate_rule_pack_registry.dart](../../../../tool/generate_rule_pack_registry.dart);
  `rule_pack_codes_generated.dart` + `rulePackDefinitions.ts` regenerated (65 packs).

### Deep review
- **Logic & safety:** name-based detection + import gate is the proven pattern of
  the sibling always-on rules; no resolution dependency, no recursion, allocation-
  free `requiredPatterns` pre-filter per rule.
- **Linter-specific integrity:** rules in the correct package file; `impact`
  (warning), `ruleType` (bug), `cost` (low), `tags` ({'packages'}) set; tier and
  pack relocation consistent (audit `PACK app_links_6: OK (3)`, `PACK app_links:
  OK (3)`); useful rename quick fix on every rule.
- **Single source of truth:** one `_v5ToV6Rename` map drives the shared fix; the
  stream rule reuses `_removedV5StreamToV6` for both detection branches.

### Testing
- **Audited** existing tests: only `app_links_rules_test.dart` references the
  package; the fixture-verification group lists the always-on fixtures only and is
  unaffected.
- **New:** three instantiation pins (name, `[code]` prefix, message length > 200,
  correction message present) — matching the `local_auth_3` exemplar, which ships
  no migration fixtures (a migration fixture references symbols removed in v6,
  which do not resolve on a v6 project and would not fire under the pack gate).
- **Run:** `dart analyze lib bin tool --fatal-infos` clean; `dart run
  tool/rule_pack_audit.dart` exit 0; `dart test test/integrity/` 351 passing
  (incl. plugin-registration consistency); full `dart test` = **6027 passing**.

### Not verified
Runtime firing was not scan-verified: the rules are gated to `app_links < 6.0.0`,
and `example_packages` carries no `app_links` dependency (a scan there fires no
app_links rule, including the existing always-on ones), so confirming a live
diagnostic requires a project pinned to `app_links` 5.x. The detection code is
structurally identical to the three shipped always-on app_links rules.

### Files
- Modified: `lib/src/rules/packages/app_links_rules.dart`, `lib/saropa_lints.dart`,
  `lib/src/tiers.dart`, `lib/src/config/rule_packs.dart`,
  `lib/src/config/rule_pack_codes_generated.dart`, `tool/rule_pack_audit.dart`,
  `tool/generate_rule_pack_registry.dart`,
  `extension/src/rulePacks/rulePackDefinitions.ts` (regenerated),
  `test/rules/packages/app_links_rules_test.dart`, `CHANGELOG.md`,
  `plans/OUTSTANDING_ITEMS_AUDIT.md`
