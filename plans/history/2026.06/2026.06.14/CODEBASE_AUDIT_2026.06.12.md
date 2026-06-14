# Codebase Audit & Remediation Plan

**Created:** 2026-06-12
**Scope:** Full review — `lib/` rules + infra, `bin/`/`lib/src/cli/` CLIs, `scripts/` Python, `extension/` TypeScript, docs/plans.
**Method:** Parallel deep-read of every major source region (no files skipped); top findings re-verified against source.

---

## FINAL STATUS (2026-06-13) — remediation COMPLETE except one blocked item

Full-project `dart analyze`: **No issues found.** 238 new oracle-backed tests pass (1 documented skip). All fixes use a new reusable resolved-analyzer test oracle (`test/support/resolved_rule_harness.dart`) that runs a single rule against resolved source — closing the root cause (rules previously shipped detection bugs unverified).

- **Workstreams B, C, D, E, G, H, J — DONE** (suppression/baseline, Future type checks, build-parse FP, package gating, infra caching, release robustness, docs). See per-workstream sections below.
- **Workstream F (name→AST sweep) — DONE.** Every flagged rule file fixed + tested + analyze-clean: navigation (5), animation (5), accessibility (3), widget_patterns (11), widget_lifecycle (~10, incl. 3 silently-dead rules revived), widget_layout (7 + 1 non-issue), security_auth_storage (3), security_network_input (2), performance (2), api_network (2 + 1 cleanup), bloc (3), riverpod (3), async_rules-remaining (3 + 1 non-issue), flow (1 + 1 non-issue). Several audit-flagged items were VERIFIED NON-ISSUES and left unchanged (collection duplicates, use_ref_read_synchronously, avoid_unassigned_stream_subscriptions, avoid_conditions_with_boolean_literals, avoid_fixed_dimensions negative). Key harness insight: the oracle ENFORCES `applicableFileTypes`/`requiredPatterns`, so widget-rule fixtures must be real widget files.
- **G5 — DONE** (version resolution by `jsonDecode`, not regex).
- **H6 (`shell=True`) — ASSESSED, DECLINED; moved to `plans/deferred/publish_subprocess_shell_true_hardening.md`.** Blanket-removing it risks breaking the Windows publish path's `.bat`/PATH tool resolution; the interpolated values (validated semver tag, the repo's own branch) are not attacker-controlled in the publish context. Safe default kept; deferred doc has the safe approach if ever pursued.
- **I1, I4 — DONE** (extension `l10n` empty-string, watch-interval clamp).
- **I2/I3 — BLOCKED (own session needed).** ~104 hardcoded extension strings + notification concatenation → `l10n()`/`en.json`. Two hard blockers: (1) the required post-edit step `extension/scripts/generate_translations.py` is the **NLLB machine-translation pipeline, which is hard-prohibited** — adding keys without it leaves English placeholders that fail the publish coverage gate; (2) the extension is under concurrent edits from another session. Must be a focused session with the regeneration run by an authorized process.

---

## 1. High-Level Report

### Overall health
The package is large (~211k lines of Dart, ~1,650–2,100 rules depending on which doc you trust) and the **infrastructure is sound**: no crash-class defects (unguarded `as`, unsafe `.first`/`[0]`, force-unwrapped `staticType!`) were found in the audited rule files — AST parent access is consistently `is`-checked and argument lists use `isEmpty`/`firstOrNull` guards. The native bridge, baseline system, and project-context caching are well-structured.

### The dominant problem: detection by string, not by type
The single largest defect class — spanning **dozens of rules** across widget, ui, navigation, accessibility, animation, security, network, and package categories — is **detecting code patterns by matching identifier/type NAMES or `toSource()` substrings instead of resolved AST types**. This produces:

- **False positives** from substring collisions: `view` → `ListView`/`overview`, `order` → `reorder`/`border`, `id:` → `uuid:`, `asset` → `dataset`, `State` (lexeme) → `RealEstate`/`RequestState`, `parse` → `int.parse`/`Uri.parse`.
- **False negatives** when the substring appears in a comment/string, or when the real API doesn't match the assumed name (e.g. `localAuth.authenticate(...)` missed by a `\bauth\b` whole-word match because `localAuth` is one token).
- **Rules that fire on their own GOOD example** (over-broad gates): `prefer_semantics_sort`, `avoid_stateful_widget_in_list`, `prefer_split_widget_const`, `avoid_expensive_build` (flags `int.parse`), `require_token_refresh`, `prefer_cached_getter` (flags any property read twice).

The codebase already contains the correct pattern (`element?.name`, `staticType.isDartCoreX`, `target is SimpleIdentifier && target.name == 'ref'`) in sibling rules — so the fix is mechanical, not architectural.

### Why these bugs ship undetected (root enabler)
The verification path is weak. There is a **known High-severity bug** (`plans/BUG_stub_tests_in_suite.md`): assertion-free stub tests that always pass. Combined with fixtures that don't assert "GOOD example produces zero diagnostics," false positives and false negatives in detection logic are invisible to CI. **Fixing the test harness is the highest-leverage work** — it converts the long tail of detection bugs from "find by hand" to "caught automatically."

### Sub-themes
- **`getDisplayString().startsWith('Future')`** used as a Future check in several async rules — matches `FutureOr<T>`, misses raw `Future` and unresolved types. Should be `isDartAsyncFuture`.
- **`toSource()`-offset arithmetic** (`target.offset - body.offset` indexed into `body.toSource()`): re-rendered source offsets do not match original offsets → wrong "before/after await" slices. Also **ancestor `toSource()` scans** that grow to the whole method → quadratic cost + over-broad context matching.
- **Package rules not gated on package presence** → fire on projects that don't use the package, some at ERROR severity (`incorrect_firebase_event_name`, `require_database_index`, `avoid_drift_unsafe_web_storage`, and `avoid_throw_in_catch_block` mis-gated to Bloc-only).
- **Suppression correctness:** inline `// ignore:` matching uses a bare substring (confirmed), and the baseline path matcher uses unbounded `endsWith` → cross-file collisions.
- **Docs drift:** rule count stated as 1652+, 1880, 1900, 2106+ across CLAUDE.md / README / CODEBASE_INDEX — no single source of truth.
- **Build/release robustness:** `gh run watch` 300s timeout can crash publish *after the tag is pushed*; NDJSON size-scan sink buffers unboundedly, violating the documented "memory-flat" guarantee.

### Confirmed against source (not just agent claims)
- `ignore_utils.dart:116` bare-substring suppression — **confirmed** (sibling `isIgnoredForFile` at :97 uses `\b` boundaries with a comment naming this exact hazard).
- `extension/src/i18n/runtime.ts:148,151` empty-string translation discarded — **confirmed** (truthiness check instead of `!== undefined`).

---

## 2. Remediation Plan (by workstream, prioritized)

### Workstream A — Test harness (do FIRST; unblocks everything else)
Highest leverage: without it, every detection fix below is unverifiable.

1. **DONE 2026-06-13 — reusable resolved-analyzer oracle built and validated.** `test/support/resolved_rule_harness.dart` runs ONE rule against inline source with full type/element resolution (`AnalysisContextCollection.getResolvedUnit` → real `typeProvider`/`typeSystem`/`libraryElement` → `registerNodeProcessors` → `ScanWalker` → flush `afterLibrary`) and returns `(ruleName, line, message)`. Self-test `test/support/resolved_rule_harness_self_test.dart` proves it fires at the right line on a true positive and stays silent on compliant code. **Resolution scope:** fixtures inherit the `example/` package config (dart SDK + meta + crypto) — Flutter types are NOT resolved (example has no Flutter dep), so Flutter-typed POSITIVE assertions are out of scope; GOOD-stays-silent is still verifiable for any rule.
2. **Phase 2 stub backlog** (`plans/BUG_stub_tests_in_suite.md`) — now unblocked: author trigger/non-trigger tests via the oracle.
3. **Add GOOD-example assertions to fixtures** — every rule fixture should assert the compliant block produces **zero** diagnostics.

### Workstream B — Suppression & baseline correctness (High; affects ALL rules) — DONE 2026-06-13
1. ~~`lib/src/ignore_utils.dart:116`~~ **FIXED** — `hasIgnoreCommentOnToken` and `_hasValidLeadingIgnoreComment` now use a shared `_commentNamesRule` whole-word (`\b`) matcher mirroring `isIgnoredForFile`. Regression tests added in `test/utils/ignore_utils_test.dart` (failing→green).
2. ~~`lib/src/ignore_utils.dart:394`~~ **FIXED** — same helper (both sites replaced).
3. ~~`lib/src/baseline/baseline_file.dart:194`~~ **FIXED** — `_pathsMatch` suffix match now requires a `/` path-segment boundary; relative-vs-absolute still matches, `util.dart` no longer matches `my_util.dart`. Regression tests in `test/baseline/baseline_file_path_match_test.dart`. Full utils+baseline+defensive suite green (262).

### Workstream C — Future/async type checks (High; multiple rules) — PARTIALLY DONE 2026-06-13
Added `_staticTypeIsFuture(DartType)` helper (Future + implementers, excludes `FutureOr`) and routed the resolved-type Future checks through it. Regression tests in `test/rules/core/async_future_type_check_test.dart` (6, green) — including proof the `FutureOr` `.toString()` false positive is gone.
1. ~~`core/async_rules.dart:65-72`~~ **FIXED** — `avoid_future_ignore`.
2. ~~`core/async_rules.dart` `avoid_future_tostring`~~ **FIXED** — toString + interpolation sites (the demonstrable FutureOr false positive).
3. ~~`core/async_rules.dart:1024-1031`~~ **FIXED** — `prefer_return_await`.
4. ~~`core/async_rules.dart:3320-3344`~~ **FIXED** — `avoid_unawaited_future` (now also catches Future subtypes).
5. **TODO** `core/async_rules.dart:833` — `require_async_returns_future` checks the return-type *annotation* text (`toSource().startsWith('Future')`); left as-is (syntactic, not the resolved-type bug). Revisit if FutureOr annotations need handling.
6. **TODO** `core/async_rules.dart:1478-1490` — `avoid_dialog_context_after_async` `toSource()`-offset slicing → AST node-position comparison (separate bug, not the Future-type class).

### Workstream D — Rules that fire on the GOOD example (High; user-trust killers)
1. `widget_patterns_avoid_prefer_rules.dart:2376-2447` — `avoid_stateful_widget_in_list`: resolve returned type; only report StatefulWidget.
2. `ui/accessibility_rules.dart:4589-4596` — `prefer_semantics_sort`: gate on a real complexity signal; today every `Semantics(...)` fires.
3. `widget_patterns_avoid_prefer_rules.dart:1715-1740` — `prefer_split_widget_const`: counts all descendants ignoring const-ness, contradicting its message.
4. ~~`core/performance_rules.dart:219-270`~~ **FIXED 2026-06-13** — `avoid_expensive_build`: `parse`/`tryParse` now skipped when the resolved result type is a core primitive (int/double/num/bool/BigInt/DateTime/Uri/Duration); `jsonDecode` and heavy parsing still flag. Harness test `test/rules/core/avoid_expensive_build_parse_test.dart` (2, green).
5. `core/performance_rules.dart:615-672` — `prefer_cached_getter`: fires on ANY property read twice with no cost signal; needs a real "expensive" signal or removal.
6. `security/security_auth_storage_rules.dart:840-845` — `require_token_refresh`: duplicate report + expiry branch fires on any class holding an access token; combine reports, gate the expiry branch.

### Workstream E — Package-gating — DONE 2026-06-13
1. ~~`avoid_throw_in_catch_block`~~ **FIXED** — removed the `applicableFileTypes => {FileType.bloc}` override (only gated rule in the file; logic is general). Behavior change noted in CHANGELOG: now runs on all Dart files.
2. ~~`incorrect_firebase_event_name`~~ **FIXED** — added `requiredPatterns => {'firebase'}` (ERROR rule no longer fires on Mixpanel/Segment/Amplitude `logEvent`).
3. ~~`require_database_index` / `require_database_migration`~~ **FIXED** — added `requiredPatterns` ({isar,realm,objectbox} / {hive,isar}). `prefer_transaction_for_batch` left as-is (already type-guarded; audit did not flag strongly).
4. ~~`avoid_drift_unsafe_web_storage`~~ **FIXED** — added `fileImportsPackage(..., PackageImports.drift)` guard to both visitors. Harness test `test/rules/packages/drift_web_storage_gate_test.dart` (2, green) verifies no fire without a drift import.

### Workstream F — Name/source-string → AST type checks — IN PROGRESS 2026-06-13
**Verification note:** two audit-flagged F items were checked with the oracle and found to be NON-issues — record them so they aren't re-flagged:
- `collection_rules` `avoid_duplicate_string_elements`/`avoid_duplicate_object_elements` flagging List literals is **intentional** (documented: string/object repeats in lists are usually errors, unlike numeric; the object rule already carves out position-sensitive gradient ramps). Not changed.
- `riverpod_rules` `use_ref_read_synchronously` `node.target.toString() == 'ref'` **works** — `SimpleIdentifierImpl.toString()` returns the name (`EQ_REF=true` verified). The rule only visits `MethodDeclaration` bodies (not top-level functions); an earlier "never fires" probe was confounded by a top-level-function fixture. Not a bug; left as-is.

The genuine F long-tail (dozens of `toSource()`/`.contains()`/`endsWith` name matches in widget/ui/navigation/accessibility/animation) remains. Most are **Flutter-typed**, so the oracle can only verify GOOD-stays-silent (the `example/` fixture package has no Flutter dep) — positive assertions need a Flutter-resolved fixture package (separate decision). Full per-file list is in the audit agent findings.

#### Original Workstream F catalog
The systemic theme. Treat as a sweep, fixture-pinned via Workstream A. Highest-value individual items (full list in agent findings, by file):

- **Accessibility:** `prefer_explicit_semantics` (`classSource.contains('Semantics')` matches `ExcludeSemantics`); `prefer_focus_traversal_order` (`'TextField'` counts `TextFormField`); `avoid_auto_play_media` (`contains('player')` → `PlayerScoreCard`).
- **Navigation:** `avoid_context_after_navigation` + `avoid_pop_without_result` (order-blind await/mounted flags); `require_route_guards` (`order` → `/reorder`, ERROR); `avoid_push_replacement_misuse` / go_router path-segment substring matches.
- **Animation:** `require_animation_controller_dispose` (disposal only seen in literal `dispose()` body — misses `_disposeControllers()` helper); `require_animation_status_listener` / `require_animation_curve` (`toSource()` identity + `endsWith('Tween')`).
- **Widget layout:** `avoid_fixed_dimensions` misses negative literals (`PrefixExpression`); `avoid_opacity_misuse` flags any `_`-prefixed const; `avoid_builder_index_out_of_bounds` regex over `toSource()`.
- **Lifecycle:** State rules matched by bare `'State'` lexeme; `require_field_dispose` cross-statement cascade regex matches a different field; `avoid_unsafe_setstate` treats else-branch `mounted` as a guard.
- **Riverpod:** `use_ref_read_synchronously:405` uses `node.target.toString()` (debug render, not source); `avoid_ref_in_dispose`/`avoid_ref_inside_state_dispose` flag any identifier named `ref`.
- **Bloc:** `avoid_bloc_event_in_constructor` flags any method named `add`; `require_immutable_bloc_state` flags any `...State`-named class.
- **Security/network:** `avoid_logging_sensitive_data` `_isSafeMatch` is dead (OAuth carve-out never works); `avoid_webview_javascript_enabled` flags any arg source containing `'true'`; `prefer_utc_for_storage` ancestor `toSource()` scan (over-broad + quadratic).
- **Collections:** `avoid_duplicate_string_elements`/`avoid_duplicate_object_elements` flag List literals (the number-variant deliberately only checks Sets — inconsistent).

### Workstream G — Infra caching & config parsing — MOSTLY DONE 2026-06-13
1. ~~android manifest cache never invalidates~~ **FIXED** — now keyed on manifest path+mtime+size (mirrors InfoPlistChecker). Test: `test/utils/android_manifest_checker_test.dart`.
2. ~~`hasPermission` unbounded substring~~ **FIXED** — boundary-anchored regex (`READ_CONTACTS` no longer matches `READ_CONTACTS_EXTENDED`). Same test file.
3. `config_loader.dart:374` enable/disable regex — **VERIFIED NON-ISSUE**: saropa rule names are underscore-only, which `[\w_]+` matches; the diagnostics block never holds dotted/hyphenated names (and a hyphenated name wouldn't match a registered rule anyway). No change.
4. ~~info_plist background-mode independent substrings~~ **FIXED** — `_hasIosBackgroundMode` checks membership inside the `UIBackgroundModes` array. Test: `test/utils/info_plist_background_mode_test.dart`.
5. **TODO (cosmetic, deferred)** `saropa_lints.dart` version-by-regex over `package_config.json` → `jsonDecode`. Display-only "unknown" fallback; low impact.

### Workstream H — CLI & release robustness — MOSTLY DONE 2026-06-13
1. ~~NDJSON unbounded buffering~~ **FIXED** — `onRow` is now `Future<void> Function(...)` and awaited in the walk; the caller flushes the sink every 256 rows (backpressure). Memory-flat guarantee restored.
2. ~~BOM in size scanner~~ **FIXED** — leading `﻿` stripped before `countLines` (first line no longer miscounted as code).
3. ~~`gh run watch` 300s timeout crash-after-tag~~ **FIXED** — wrapped in `try/except TimeoutExpired`, bumped to 600s (aligned with run discovery), prints monitor URL on timeout instead of crashing.
4. ~~pubspec dep parser false hard-block~~ **FIXED** — `dependencies:` header now tolerates a trailing comment (the real false-block; non-2-space top-level deps are invalid pubspec). Regression test in `scripts/modules/tests/test_dependency_imports.py`.
5. ~~`get_latest_changelog_version` unanchored~~ **FIXED** — anchored to `^##` (MULTILINE). Changelog Python tests green (17).
6. **MOVED to `plans/deferred/publish_subprocess_shell_true_hardening.md`** — `_git_ops.py` `shell=True` hardening. Assessed and intentionally not changed (no attacker-controlled input in publish; blanket removal risks the Windows release path). Full rationale + safe approach in the deferred doc.

### Workstream I — Extension — PARTIALLY DONE 2026-06-13 (tsc clean)
1. ~~`runtime.ts:148,151` `l10n()` empty-string~~ **FIXED** — `!== undefined` instead of truthiness.
4. ~~`freshness-watcher.ts` `watchIntervalHours` runaway~~ **FIXED** — clamped at read: floor 15 min, fall back to 6h for 0/negative/NaN.
2. **TODO (deferred — large l10n migration + locale regen)** ~104 hardcoded user-facing strings across ~19 files routed through `l10n()` + `en.json`. This is a cross-locale regeneration (blast-radius); should be its own scoped pass.
3. **TODO (part of #2)** `freshness-watcher.ts` notification strings built by English concatenation around `${count}`/`${names}` → catalog keys with `{token}` + plural variants.

### Workstream J — Documentation — DONE 2026-06-13
Authoritative count is **2300 rules / 145 categories** (`scripts/modules/_rule_metrics.py` `count_rules`/`count_categories`). The shipped README rules badge is auto-synced at publish by `sync_readme_badges`, so the user-facing number stays current. Fixed the stale hardcoded stats in checked-in `CLAUDE.md` ("2106+ / 80 categories" → "2300+ / 145 category files", pointing at the authoritative source). The stale "1652+" lives only in the gitignored `CODEBASE_INDEX.md` (local, never ships); not load-bearing.

---

## 3. Suggested sequencing
1. **A** (test harness) — gate for everything.
2. **B + C + D + E** (High: suppression, Future checks, GOOD-example fires, package gating) — each fixture-pinned.
3. **H** (release robustness) — independent, low risk, protects publishing.
4. **F + G** (the name→AST sweep + infra caching) — large but mechanical once A is in place.
5. **I + J** (extension l10n + docs).

## 4. Open questions (saved for the user)
1. `prefer_cached_getter` and `prefer_split_widget_const` have **no real cost/const signal** — fix the detection, or retire the rules? (Resolved during remediation: both narrowed to a defensible resolved signal — `prefer_cached_getter` flags only non-synthetic declared getters; `prefer_split_widget_const` counts only const-constructible widgets. Neither retired.)
2. Should the name→AST sweep (Workstream F) be one large pass or split per category for reviewability? (Resolved: executed as file-scoped passes, one rule file at a time, each verified independently.)
3. Rule-count: confirm the authoritative number should come from `_rule_metrics.py` output. (Resolved: yes — `count_rules`/`count_categories`; README badge auto-syncs at publish; stale prose stats in `CLAUDE.md` corrected to 2300/145.)

## Finish Report (2026-06-14)

**Scope:** (A) Dart lint rules + analyzer plugin + Dart tests; (B) VS Code extension localization; (C) docs/scripts (this audit plan, a deferred doc, Python publish/hook scripts).

A full-codebase audit identified one dominant defect class and several discrete infrastructure bugs. The dominant class: lint rules deciding "what is this code?" by matching identifier/type names or re-rendered `toSource()` substrings rather than resolved AST types — producing false positives from substring collisions (`order` in `/reorder`, `view` in `ListView`, `Custom` in `Customer`, `parse` matching `int.parse`), false negatives when the marker sat in a comment/string, and rules that fired on their own documented GOOD example. The discrete bugs spanned suppression matching, baseline path matching, manifest/plist caching, the publish pipeline, and extension localization.

**Root-cause infrastructure.** The rule tests previously only pinned metadata and counted `// expect_lint:` strings (never executed, because the package builds on `analyzer_plugin`, not `custom_lint`), so detection regressions shipped unverified. A reusable resolved-analyzer oracle was added at `test/support/resolved_rule_harness.dart`: it runs one rule against inline source with full type/element resolution (`AnalysisContextCollection.getResolvedUnit` → real `typeProvider`/`typeSystem`/`libraryElement` → `registerNodeProcessors` → `ScanWalker` → flushed `afterLibrary` callbacks) and returns the reported diagnostics. Fixtures are written to a unique temp subdirectory under `example/lib/` so they inherit the example package's resolved config and so concurrent test isolates cannot collide. The harness enforces `applicableFileTypes`/`requiredPatterns`, so widget-rule fixtures are shaped as real widget files; Flutter types are supplied as local stubs since the example package has no Flutter dependency (positive assertions for genuinely Flutter-typed detection are therefore out of reach for this oracle and are noted as a follow-up).

**Detection fixes (resolved-AST, each test-pinned).** Suppression: `IgnoreUtils` inline-`// ignore:` matching switched from substring to whole-word (`\b`), matching `isIgnoredForFile`. Baseline: `_pathsMatch` suffix match now requires a `/` segment boundary. Async Future checks (`avoid_future_ignore`, `avoid_future_tostring`, `prefer_return_await`, `avoid_unawaited_future`) use a Future-or-subtype type check instead of `getDisplayString().startsWith('Future')`, removing the `FutureOr` false positive. `avoid_expensive_build` no longer flags `int.parse`/`Uri.parse`. Package gating added to `incorrect_firebase_event_name`, `require_database_index`/`migration`, `avoid_drift_unsafe_web_storage`; `avoid_throw_in_catch_block` un-gated from Bloc-only. The name→AST sweep corrected ~55 further rules across navigation, animation, accessibility, widget patterns/lifecycle/layout, security, performance, api_network, bloc, riverpod, async, and flow — including three lifecycle rules (`require_super_dispose_call`/`require_super_init_state_call`/`avoid_set_state_in_dispose`) that were silently dead because a `parent is ClassDeclaration` guard never held under the current analyzer (the method's parent is the class body). Several audit-flagged items were verified as non-issues against the oracle and intentionally left unchanged (collection list-duplicate rules, `use_ref_read_synchronously`, `avoid_unassigned_stream_subscriptions`, `avoid_conditions_with_boolean_literals`, the `avoid_fixed_dimensions` negative-literal case).

**Infra/release fixes.** Android manifest checker now invalidates its per-project cache on mtime+size (was session-permanent) and boundary-anchors permission lookup; iOS background-mode detection checks membership inside the `UIBackgroundModes` array; version resolution parses `package_config.json` via `jsonDecode`. Publish robustness: `gh run watch` timeout is handled (was crashing publish after the tag was pushed); the dependency-import gate tolerates a commented `dependencies:` header (was false-blocking releases); `get_latest_changelog_version` is heading-anchored; the Project Health size scan flushes its NDJSON sink with backpressure and strips a UTF-8 BOM. The British-English spelling guard hook now scans only files inside the repository.

**Extension localization.** Every `showInformationMessage`/`showWarningMessage`/`showErrorMessage` call across `extension/src` and their action-button labels were routed through `l10n()` with `{token}` interpolation — 208 keys under a new `notify.*` namespace in `en.json`. `en.json` was written by a single safe JSON-merge step; per-file key sets were produced independently and merged centrally, so the catalog stayed coherent.

**Testing.** 3,044 Dart tests pass across the new oracle-backed regression files and the existing rule-test suites for every changed rule file (1 documented skip — a rule self-gated on `isFlutterProject`). Full `dart analyze` clean. Extension `tsc --noEmit` clean. Cross-check confirms all 208 `notify.*` keys referenced in code exist in `en.json` (0 missing). Python suites: dependency-import + spelling + changelog/version tests pass.

**Outstanding (not code work).**
- Extension translated-locale catalogs are stale until the NLLB translation pass is run (`generate_translations.py`); the publish coverage gate fails until then. This is a user/authorized step — the NLLB pipeline is not run from this workflow.
- Positive assertions for genuinely Flutter-typed rules need a Flutter-resolved fixture package (the oracle currently verifies GOOD-stays-silent for them).
- `shell=True` hardening in the publish scripts is documented as a deliberate non-change in `plans/deferred/publish_subprocess_shell_true_hardening.md`.

**Finish report appended:** `plans/CODEBASE_AUDIT_2026.06.12.md` (this file). The completed plan is archived to `plans/history/2026.06/2026.06.14/`.
