# TODO — Rule metadata completeness residuals

**Created:** 2026-06-12
**Split from:** `OUTSTANDING_ITEMS_AUDIT.md` §4 (audit archived to `history/2026.06/2026.06.12/`)
**Subsystem:** rule metadata schema + lifecycle
**Source plan:** `history/2026.04/2026.04.28/PLAN_RULE_METADATA_AND_QUALITY.md`

The metadata schema, CWE/OWASP mapping, per-rule CI threshold gate
([bin/quality_gate.dart](../bin/quality_gate.dart)), and baseline comparison
([bin/baseline.dart](../bin/baseline.dart), [bin/diagnostic_baseline.dart](../bin/diagnostic_baseline.dart))
all shipped. These are the gaps.

## Status legend
- **[OPEN — verified]** getter exists, populated nowhere — confirmed in the 2026-06-11 audit.
- **[OPEN — needs per-item confirm]** triage against code before treating as done.

---

## 4.1 Accuracy measurement gate that reads `accuracyTarget` **[IN PROGRESS — paused since 2026-06-24, reviewed 2026-07-16]**

> **Status as of 2026-07-16:** No further fixture-adequacy work had landed since 2026-06-24 (last
> relevant commits: `a5c2dc2c` liveness tool + `avoid_hardcoded_api_urls` fix, `b9eddd7e` api_network
> 20→0, `d724edff` code_quality 36→32). The instrument ships and works; the corpus cleanup is stalled.
> **Next action → see "Next action" block at the end of §4.1.**

### Tool confounder removed 2026-07-16 — stylistic rules were 133 false silents

The full-corpus run was scoped `--tier pedantic`, but **no tier — not even pedantic — contains the
stylistic rules** (`getRulesForTier('pedantic')` unions essential→pedantic, never `stylisticRules`; and
`stylistic` was not even a valid `tierOrder` entry). So the scan never enabled any stylistic rule, and the
report marked every stylistic rule that has an `expect_lint` fixture as silent. That was **133 of the 744**
reported silents (18%) — pure measurement error, not fixture bugs.

Fix (this session): `ScanRunner` gained an optional `enabledRuleNames` set that bypasses tier/config, and
`accuracy_report` now defaults to `getAllDefinedRules()` (pedantic ∪ stylistic) so every marker-bearing rule
is actually exercised; `--tier <name>` still narrows when wanted. Verified on `example/lib/collection`: the
three stylistic rules there (`prefer_list_first`, `prefer_list_last`, `map_keys_ordering`) plus
`prefer_fold_over_reduce` flipped silent→fired with no fixture change. 9 `accuracy_report` unit tests still
pass.

**True silent count with all rules enabled (2026-07-16 full-corpus re-run): 664** (was 744 under
`--tier pedantic`). Enabling stylistic exercised 80 rules that had been false silents. **53 stylistic rules
are still genuinely silent** even with all rules on — those are real fixture/rule gaps, not the confounder.
So the corrected worklist is 664, of which 611 are non-stylistic and 53 are stylistic.

### Collection cluster: silents here are genuine RULE bugs, not fixture inadequacy

Unlike api_network (mostly inadequate fixtures), the remaining collection silents are rules that fail to
detect their own correct canonical bad example. Verified by the silent report (the fixtures show the right
bad code; the rules do not fire on it under resolved analysis):

- **`prefer_list_contains`** — checks `right is IntegerLiteral && value == -1`, but `!= -1` parses as a
  `PrefixExpression` (unary minus over `1`), never an `IntegerLiteral`, so the canonical
  `list.indexOf(x) != -1` is missed. Needs to handle negated-literal right operands.
- **`avoid_map_keys_contains`** — only handles a `PropertyAccess` target, but `map.keys` on a
  simple-identifier receiver is a `PrefixedIdentifier`, so the canonical `map.keys.contains(k)` is missed.
- **`avoid_unnecessary_collections`** — registers on `MethodInvocation`, but `List.of([...])` /
  `Set.of(...)` / `Map.of(...)` resolve to `InstanceCreationExpression` under resolution, so the rule
  never sees them in a resolved scan (and, by the same token, in the real analyzer).

These are production under-firing bugs (each affects every consumer project), so fixing them is a
blast-radius change gated on approval — distinct from the mechanical fixture wraps the api_network loop
assumed. `prefer_asmap_over_indexed_iteration` and `require_key_for_collection` in this dir are not yet
categorized.

#### Done 2026-07-16 (user-approved) — collection rule bugs fixed: 5 → 2 silent

All three genuine under-firing bugs above were fixed in the rule (not the fixture), version-bumped, with
changelog Fixed entries; `accuracy_report --fixtures example/lib/collection` confirms each flipped
silent→fired and 69 collection unit tests still pass:

- `prefer_list_contains` v2→v3 — added a helper that unwraps a unary-minus `PrefixExpression`, so
  `indexOf(x) != -1` now matches.
- `avoid_map_keys_contains` v5→v6 — now accepts a `PrefixedIdentifier` `.keys` target (plain
  `map.keys.contains`), not only `PropertyAccess`. Its quick fix already handled exactly this shape (the
  rule and fix were previously mismatched), so the fix now applies where it never could before.
- `avoid_unnecessary_collections` v4→v5 — added an `InstanceCreationExpression` handler (shared literal
  check) so the resolved `List.of([...])`/`Set.of`/`Map.of` constructor forms are caught, not just the
  syntactic method-invocation shape.

Remaining silent in `example/lib/collection`: `prefer_asmap_over_indexed_iteration` and
`require_key_for_collection` (a widget rule) — still uncategorized, next if this cluster is resumed.

#### Done 2026-07-16 (continued) — collection cluster now 0 silent (all 27 fire)

The last two were the same two bug classes already seen in this cluster:

- `prefer_asmap_over_indexed_iteration` — required the `for` bound to be a `PropertyAccess`, but
  `list.length` on a plain variable is a `PrefixedIdentifier`, so the canonical
  `for (i = 0; i < list.length; i++)` never fired. Now accepts both shapes. (Message carries no `{vN}`
  marker, so no in-message bump.)
- `require_key_for_collection` v4→v5 — `ListView.builder` / `GridView.builder` are named constructors, so
  under resolution they are `InstanceCreationExpression`, not the `MethodInvocation` the primary handler
  matched; the instance-creation handler covered only Reorderable/Animated. Extended it to the `.builder`
  constructors (reading the type name syntactically so it does not depend on the widget type resolving),
  and factored the shared `itemBuilder:` scan into one helper.

`accuracy_report --fixtures example/lib/collection` = 27/27 fire; 69 collection unit tests pass. The
collection cluster (`example/lib/collection`) is fully green. Five genuine under-firing rule bugs were fixed
in this cluster total (three approved + these two of the same classes).

#### Done 2026-07-16 (continued) — async cluster: 13 → 4 silent (user-approved)

Nine of the 13 async silents fixed; 92 async unit tests pass. This cluster was a mix, not one class:

- **Rule bug (same InstanceCreation-vs-MethodInvocation class as collection):** `prefer_commenting_future_delayed`
  (v4→v5). `Future.delayed` is a named constructor → `InstanceCreationExpression` under resolution, so the
  MethodInvocation-only handler never fired for anyone. Also fixed a second real bug: it checked the leading
  comment on the `Future` token, but in `await Future.delayed(...)` the `await` token owns the comment, so it
  could not tell a commented delay from an uncommented one (would FP on commented code). Now checks the
  enclosing statement's token and added an InstanceCreation handler. This is the only user-facing async fix.
- **Typed-fixture (dynamic/undefined → real type):** `require_stream_on_done`, `avoid_stream_tostring`
  (use `StreamController<int>().stream` for a real `Stream` static type), `prefer_return_await` (declare a
  real `Future`-returning helper).
- **Wrong-context (nested/top-level fn → class method):** `require_completer_error_handling`,
  `avoid_stream_in_build` (needs a method literally named `build`), `require_pending_changes_indicator`
  (also its identifier had to match `\b_dirty\b` and avoid `.add(`, which the rule's own patterns treat as a
  notification).
- **Name/heuristic-gated fixtures:** `require_future_timeout` (rule matches only exact long-running method
  names like `download`; `expensiveOperation` never matched), `require_websocket_reconnection` (rule matches
  a bounded `\bWebSocketChannel\b`/`\bWebSocket\b` in the class source; the fixture's mock `WebSocketDemo` has
  no boundary, so it was renamed to `WebSocketChannel`).

**Async cluster: now 0 silent (all 4 remaining resolved 2026-07-16).**

1. `avoid_sequential_awaits` and `avoid_sync_on_every_change` — **both diagnosed and fixed** (my earlier
   "could not isolate" was wrong; the diagnosis method was flawed, not the rules). The reliable repro is a
   full-dir resolved JSON scan (`dart run saropa_lints scan <dir> --resolve --format json`) filtered by file
   path — NOT the `--files`/single-file path, which fails to resolve isolated files and returns zero even for
   a known-firing control. Using it, a minimal clean fixture showed both rules silent while sibling rules
   examining the same nodes fired, proving the rules (not fixtures) were at fault. Root causes:
   - **`avoid_sync_on_every_change`**: `applicableFileTypes => {FileType.widget}`, so it only runs on files
     containing `extends StatelessWidget`/`StatefulWidget`. The fixture used a bare `TextField` in a
     top-level function → not a widget file → gated out. Fixed the fixture (TextField now lives in a
     `StatelessWidget.build`).
   - **`avoid_sequential_awaits`** (v2→v3): registered via `context.addFunctionBody`, which is a **no-op stub**
     in the native engine (`saropa_context.dart:1002` — FunctionBody is not a visitable node), so the rule
     never fired for anyone. Switched to `addBlockFunctionBody` (the real registration; the rule already
     narrowed to BlockFunctionBody). **Engine finding (RESOLVED 2026-07-16, user-approved): `addFunctionBody`
     is a silent no-op used by 4 more call sites in 3 other rule files, so those rules were also dead —
     `require_getit_registration_order` (get_it), `require_hive_adapter_registration_order` (hive),
     `prefer_single_exit_point` and `prefer_guard_clauses` (stylistic_control_flow). All four switched to
     `addBlockFunctionBody` and version-bumped. Verified with throwaway marker fixtures (accuracy_report: all
     4 fire); the scratch fixtures were removed after verifying — these 4 rules still have NO permanent
     fixtures, a pre-existing gap worth a later dedicated fixture pass.**
2. `prefer_isolate_for_heavy_compute` and `require_cache_ttl` — **phantom markers** (RESOLVED 2026-07-16,
   user-approved): `expect_lint` comments in `async_rules_fixture.dart` named rules that exist **nowhere** in
   `lib/`, so they could never fire. The two marker lines were removed (replaced with a `NOTE:` explaining no
   such rule exists); the BAD/GOOD example code was left in place. If those rules are ever wanted, they are
   new-feature work, tracked separately. After removal the async cluster has **2 silent** (the undiagnosed
   pair above), down from 13.


Premise correction: `accuracyTarget` is **not** unpopulated. It is a derived getter
([saropa_lint_rule.dart:2288](../lib/src/saropa_lint_rule.dart#L2288)) computed from `ruleType`, and
it is already serialized into [extension/media/rules_catalog.json](../extension/media/rules_catalog.json)
and read by the extension. So every rule with a `ruleType` already carries a target. The actual gap is
that **nothing measures a rule's real accuracy against that target** — the `*_expect_lint_contract_test.dart`
integrity tests only assert that a fixture *declares* an `expect_lint` marker; they never run the rule to
confirm it fires (or that it does not over-fire).

The consumer to build is an accuracy report/gate, not a metadata backfill.

### Built — `bin/accuracy_report.dart` (+ `lib/src/report/accuracy_report.dart` core)

Mirrors the `quality_gate` split: a testable pure core plus a thin CLI that exits non-zero so CI can
gate on it. `dart run saropa_lints:accuracy_report [--fixtures <dir>] [--tier <name>] [--fail-on silent|none] [--format json]`.

**What it measures: rule liveness, not FP/TP rate.** For every rule declared by an `// expect_lint:`
marker, it runs a resolved scan (`ScanRunner.runResolved` via [scan.dart](../lib/scan.dart)) and checks
the rule produced at least one diagnostic in that fixture file. A declared-but-silent rule is reported and
(default) fails the gate. 9 unit tests cover marker parsing + the liveness tally.

**Why liveness and not accuracy-vs-target — discovered during the build, two corpus blockers:**

1. **Markers are not line-precise.** Many `expect_lint` markers sit above a *function* while the rule
   fires on a statement several lines inside it (e.g. `require_request_timeout`'s marker is on the line
   before the function; the violation is the `http.get` two lines down). Exact-line matching therefore
   reports false negatives for correctly-firing rules — measured TP≈0 across the corpus. Measuring real
   false-positive / true-positive *rate* against `accuracyTarget` requires re-authoring markers
   immediately above each violation with good examples isolated in separate files. That is a corpus
   project, deferred.
2. **Package/platform-gated rules legitimately skip.** Rules that gate on `ProjectContext.usesPackage(...)`
   or a platform do not fire in the example project when its pubspec lacks the package, so they appear
   "silent" without being broken. The raw silent list therefore over-reports and must be triaged before it
   can be a clean hard CI gate. (api_network: 20 of 34 rules silent on first run — a triage worklist, not
   20 confirmed bugs.)

### Decision / status

- The tool is the durable deliverable: it produces the per-rule silent-list worklist the contract tests
  cannot — they only check a marker's *text* exists, never that the rule still fires.
- **Full-corpus result (2026-06-24, `--tier pedantic`, resolved scan of 1,738 fixtures):** 767 of 1,551
  marker-bearing rules (~49%) fire in *none* of their fixtures. This rate is too high to be real
  under-firing — it is dominated by the confounders below, so the raw silent list is **not an actionable
  bug list** as-is. The tool runs correctly; the corpus + scan environment do not yet support a trustworthy
  liveness verdict.
- **Confounders to remove before the silent list means anything:** (1) environment gating —
  package/platform/Flutter-gated rules cannot fire in the example project's environment; (2) scan coverage —
  even `runResolved` does not exercise every rule shape (documented in `scan.dart`). Both must be handled
  (run fixtures in an environment that satisfies the gates, and/or add `requiredPackages`/platform metadata
  to exclude un-fireable rules from the silent verdict) before the gate is meaningful.
- **Default `--fail-on silent` exits 1 on any silent rule.** Do NOT wire it into CI as a hard gate until
  the confounders above are removed. Until then run with `--fail-on none` as a report.
- **Follow-up (line-precise accuracy-vs-target):** still open, blocked on fixture line-precision. This is
  where `accuracyTarget`'s `expectZeroFalsePositives` / `minTruePositiveRate` would finally be enforced.

### Root cause of the silent rules (2026-06-24 triage)

Per-rule investigation of the silent list found the dominant cause is **inadequate fixtures, not broken
rules**. A silent rule's fixture typically fails to satisfy the rule's real trigger:

1. **Wrong code context** — the bad example is a top-level function (`void _bad44()`) while the rule only
   visits class methods (`addMethodDeclaration`), so the rule never sees it.
2. **Missing required import** — import-gated rules (e.g. `require_http_status_check` needs
   `package:http`/`package:dio` via `fileImportsPackage`, which reads the import URI *text*, so the package
   need not resolve) sit in fixtures that only stub `dynamic http;` with no import directive.
3. **Unrealistic identifiers** — name-gated rules (e.g. `require_connectivity_check` only flags methods
   named like `fetch*`/`upload*`) have fixtures whose bad example is named `_bad48`.

The fix is to make each fixture realistic: put the bad code in a class method, add the import line the gate
reads, and name it to match the rule's heuristic. A genuine rule bug (too-narrow detection) is fixed in the
rule instead — done once so far for `avoid_hardcoded_api_urls`.

### Done — api_network cluster: 20 → 0 silent (all 34 rules fire on their fixtures)

- `avoid_hardcoded_api_urls` — real rule bug (regex demanded `/api` path, missed `api.` hosts). Rule
  widened, version bumped to v6, changelog Fixed entry. silent→fired.
- The other 19 silent rules were **inadequate fixtures**, fixed without touching rule behavior:
  - **Wrong context** (bad code in a top-level/nested function, rule visits class methods) → wrapped the
    bad example in a realistic class method: `require_http_status_check`, `require_retry_logic`,
    `require_response_caching`, `require_connectivity_check`, `prefer_api_pagination`,
    `prefer_http_connection_reuse`, `require_content_type_check`, `avoid_cached_image_in_build` (method
    named `build`), `avoid_websocket_without_heartbeat`, `require_notification_permission_android13`,
    `require_permission_denied_handling`, `require_permission_rationale`.
  - **Body did not match the rule's pattern** → fixed the call (`api.fetchData()`→`http.get`):
    `avoid_redundant_requests`, `require_cancel_token`, `require_api_error_mapping`.
  - **Missing the package import the rule gates on** → added the import line (text-gate, no resolution
    needed): `require_connectivity_subscription_cancel`, `require_geolocator_timeout`,
    `require_notification_handler_top_level` (+ the two permission rules above).
  - **Wrong AST node** (`response.bodyBytes` parses as a PrefixedIdentifier; rule registers on
    PropertyAccess) → made the bad example a real property access on the call result:
    `prefer_streaming_response`.

### Remaining: the same triage across the rest of the package (~745 silent)

The api_network cluster proves the loop. The remaining silent rules package-wide are the same three shapes
(wrong context / unmatched body / missing import), to be worked in clusters with `accuracy_report` verifying
each batch flips silent→fired. Run the full-corpus report to pick the next cluster:
`dart run saropa_lints:accuracy_report --tier pedantic --fail-on none --format json`.

### Optional rule-widening (separate, blast-radius)

The `addMethodDeclaration` network rules only catch class methods; a top-level/nested function doing
`http.get` without a status check is real and currently unprotected. Widening these rules to also visit
`addFunctionDeclaration` would close that gap (low FP risk — identical body analysis) but changes what fires
in every consumer project, so it is gated on explicit approval and tracked separately from the fixture work.

### code_quality cluster (started): 36 → 32 silent

Four context-fixable rules were corrected the same way as api_network and now fire:
`avoid_positional_boolean_parameters` and `prefer_named_bool_params` (the rule skips `FunctionExpression`
parents, so the bad example must be a class method), `avoid_unnecessary_overrides` (needs a method carrying
`@override` that only calls super), and `avoid_duplicate_constant_values` (the rule scans top-level
declarations, so the duplicate consts were moved out of a function body).

The remaining 32 code_quality silent rules are heavier than the api_network shapes: most depend on type
resolution and need the fixture to **define real enum/class types** rather than reference undefined
identifiers (e.g. `avoid_enum_values_by_index` references an undeclared `Status`). Defining the enum alone
did not flip `avoid_enum_values_by_index`, so that group needs per-rule resolution debugging, not a
mechanical wrap. This group is deferred.

## Finish Report (2026-06-24)

A rule-liveness instrument was added and two fixture clusters were repaired. The instrument
(`bin/accuracy_report.dart` + the pure core `lib/src/report/accuracy_report.dart`, 9 unit tests) pairs the
`expect_lint` fixture markers with a resolved scan and reports any rule that is declared in a fixture but
never fires there — a gap the `*_expect_lint_contract_test.dart` tests cannot detect because they only assert
the marker string exists.

The full-corpus run found 767 of 1,551 marker-bearing rules silent. Triage established the dominant cause is
inadequate stub fixtures, not broken rules: a silent rule's bad example typically fails the rule's real
trigger (wrong code context, missing required import, unrealistic identifier, or an undefined type the rule
must resolve). One genuine rule defect surfaced and was fixed: `avoid_hardcoded_api_urls` required `/api` in
the URL path and so missed the common `api.`-host shape — its regex was widened (rule version v5 → v6).

Two clusters were brought to a measurable state. api_network reached 0 silent (all 34 rules fire): one rule
fix plus 19 fixtures made realistic (class methods, required import lines, corrected call patterns, and one
property-access shape). code_quality reached 32 silent from 36: four context-fixable rules corrected; the
remaining resolution-dependent group deferred as noted above.

Status of §4.1: the consumer that reads accuracy targets is partially realized as a liveness instrument.
True false-positive / true-positive-rate measurement against `accuracyTarget` remains blocked on
line-precise fixtures. The remaining ~745 package-wide silent rules and the code_quality resolution group are
the open work; this TODO stays active and is not moved to history.

## Next action (§4.1) — what to do next, in order

1. **Regenerate the silent-list worklist** (the count below is from 2026-06-24; confirm it is still ~745):
   `dart run saropa_lints:accuracy_report --tier pedantic --fail-on none --format json`.
2. **Pick the next cluster and repeat the api_network loop.** For each silent rule, the fix is almost always
   the fixture, not the rule — apply the three-shape triage: (a) move the bad example into a class method if
   the rule visits `addMethodDeclaration`; (b) add the `package:` import line if the rule gates on an import
   URI; (c) rename the bad example to match the rule's name heuristic. Re-run `accuracy_report` on that
   cluster to confirm silent→fired. Fix a rule only when its detection is genuinely too narrow (as with
   `avoid_hardcoded_api_urls`), and bump its version + add a changelog Fixed entry when you do.
3. **Defer the code_quality resolution group** (~32 rules) — these need the fixture to define real
   enum/class types and then per-rule resolution debugging; not a mechanical wrap. Do the easy clusters first.
4. **Do NOT wire `--fail-on silent` into CI yet.** The raw silent list over-reports because
   package/platform/Flutter-gated rules cannot fire in the example project. Removing those confounders
   (run fixtures in a gate-satisfying environment, and/or add `requiredPackages`/platform metadata to
   exclude un-fireable rules) is prerequisite to a hard gate.
5. **Blocked follow-up:** line-precise accuracy-vs-target (enforcing `expectZeroFalsePositives` /
   `minTruePositiveRate`) stays blocked on re-authoring markers immediately above each violation. A separate
   corpus project; do not start it before the liveness silent-list is clean.

## Overall §4 status (2026-07-16)

- **§4.1 accuracy gate** — IN PROGRESS, paused. Instrument done; ~745 silent-rule fixtures remain. See above.
- **§4.2 `certIds`** — OPEN by design. Opportunistic only; no bulk pass.
- **§4.3 rule-lifecycle enforcement** — DONE 2026-06-12.

This TODO stays active until §4.1's silent list is cleared (or explicitly closed as consumer-gated).

## 4.2 `certIds` sparse/empty **[OPEN — verified — by design]**

By design. Populate per-rule where a clear CERT/CWE mapping exists.

Action: opportunistic — when touching a security rule with an obvious CERT/CWE id, add it. No bulk
backfill pass warranted on its own.

## 4.3 Rule-lifecycle enforcement **[DONE 2026-06-12]**

`RuleStatus` (ready / beta / deprecated) exists. Confirmation found the enforcement was wired in the
interactive `init` path (`init_runner.dart`) but **missing in the headless `runWriteConfig` path** —
the one the VS Code extension and CI use — so a beta/deprecated rule sitting in a selected tier was
enabled in extension/CI-written configs while `init` excluded it.

Closed by extracting the filter into a shared `lifecycleFilteredRules(enabled)` helper
(`lib/src/init/rule_metadata.dart`) and applying it in both `init_runner` and `runWriteConfig`, so
the two paths can no longer drift. Beta/deprecated rules are excluded by default; an explicit
`analysis_options_custom.yaml` RULE OVERRIDES entry re-enables one. The runtime gate (the plugin
registers all rules and gates per-rule on the config's enabled set) needs no change — excluding the
rule from the generated config is sufficient. See the Finish Report below.

---

## Finish Report (2026-06-12)

### Lifecycle filter shared between the interactive and headless config paths

Rules carry a `RuleStatus` of `ready`, `beta`, or `deprecated`. Beta rules may carry more false
positives or change behavior, and deprecated rules are slated for removal, so neither should land in
a config the user did not hand-pick. The interactive `init` path applied this exclusion, but the
headless `runWriteConfig` path — the one the VS Code extension and CI use to generate
`analysis_options.yaml` — applied only the tier, stylistic, platform, and package filters. A beta or
deprecated rule that sat in a selected tier was therefore enabled in every extension- or CI-written
config, while `init` excluded the same rule: a silent divergence between the two generators.

#### What changed

- **`lifecycleFilteredRules(Set<String> enabled)`** (lib/src/init/rule_metadata.dart) — a shared
  helper returning the beta/deprecated subset of an enabled set. Both config generators call it, so
  the filter is defined once and cannot drift.
- **`runWriteConfig`** (lib/src/init/write_config_runner.dart) — applies the filter after the
  platform/package filters and before the plugins section is generated. Rules a user explicitly
  enabled via RULE OVERRIDES survive, because those overrides were already captured into
  `permanentOverrides` and are re-applied through `userCustomizations` at generation time.
- **`init_runner`** (lib/src/init/init_runner.dart) — its inline beta/deprecated loop was replaced
  with the shared helper; the per-status counts it logs are unchanged.
- An unused `analyzer_compat` import in `rule_metadata.dart` (pre-existing, surfaced by
  `dart analyze --fatal-infos` on the edited file) was removed so the touched file passes the CI
  gate. No symbol from it was referenced.

#### Verification

- `dart test test/init/write_config_test.dart`: 7 passing, including 2 new cases — a beta tier rule
  (`avoid_api_key_in_code`, the one beta rule, in `essentialRules`) is absent from `essential`
  output, and an explicit RULE OVERRIDES opt-in re-enables it.
- `dart analyze --fatal-infos`: "No issues found!" across the package (the CI gate the publish
  script mirrors).

#### Scope note

The runtime plugin registers every rule and gates per-rule on the config's enabled set, so excluding
a rule from the generated config is the complete fix — no analyzer-runtime change is required. This
closes §4.3; §4.1 (`accuracyTarget`) and §4.2 (`certIds`) remain consumer-gated and untouched.
