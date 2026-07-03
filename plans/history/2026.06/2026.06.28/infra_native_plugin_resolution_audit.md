# Resolution-call audit — native plugin (APPENDIX, demoted)

Companion to the memory-growth bug, fixed in 14.3.0 and archived to
`../plans/history/2026.06/2026.06.28/infra_native_plugin_analysis_server_memory_growth_10gb.md`
— read that consolidated report first; it is the source of truth.
Created: 2026-06-28.

> **DEMOTED 2026-06-28.** Direct measurement this session showed resolution
> reduction is **not** the memory lever: the full rule set run out-of-process
> (syntactic `parseString`, no resolution) peaks at ~46 MB, and rules run
> *after* the analyzer has already resolved the unit, so `.element`/`.staticType`
> reads on local nodes are free. The multi-GB cost is the in-process analyzer
> retaining resolved element state, not our resolution calls. Treat the work-list
> below as a CPU/code-hygiene backlog ONLY — it will not move the ~10 GB. The
> memory investigation and plan live in the main report.

## Why this exists

To find element/type-resolution calls (`.element`, `.staticType`,
`.declaredElement`, `.declaredFragment.element`, `.enclosingElement`) in rules
that could be removed or deferred, as a candidate lever against the analysis
server's ~10 GB memory growth.

## CRITICAL CAVEAT — read before implementing any of this

Rules run on units the analyzer has **already fully resolved** for its own
diagnostics. Therefore:

1. Reading `.element` / `.staticType` / `.name` on a **local** node (the unit
   being analyzed) is a field read on an already-resolved AST. It does **not**
   trigger new resolution. Converting these to `.name.lexeme` is a CPU /
   cleanliness win, **not a confirmed memory reduction**.
2. The reaches that genuinely materialize and pin **other** libraries' element
   models are `allSupertypes` walks and `.element.library.uri` identity checks.
   These are the audit's **KEEP** items — they cannot be dropped without
   reintroducing false positives.
3. `applicableFileTypes` / `requiredPatterns` gates are evaluated **inside the
   callback, after** the analyzer has already resolved the unit. Adding them
   reduces the plugin's own per-node CPU but does **not** reduce what the
   analyzer resolves or retains.

**Consequence:** no per-rule change verified here can be shown (from code
reading alone) to reduce the analyzer's retained memory. A heap snapshot of the
analysis-server isolate is required to confirm the dominant retained type before
investing in this work-list. See the parent bug's "Confirmation still needed".

This file is therefore a **CPU-optimization + code-hygiene** work-list with
*possible* memory benefit, not a confirmed memory fix.

---

## Classification key

- **DROP** — detection is equivalent from AST shape / token text / identifier
  names at acceptable false-positive risk. Each conversion needs a fixture
  proving detection is preserved (lexeme matching admits a user-defined
  same-named class the resolved check excluded).
- **NARROW** — resolution is genuinely needed, but the rule resolves on a hot,
  ungated node before any cheap filter; reorder so a token/AST precheck
  short-circuits first, or add a file-level `requiredPatterns` gate.
- **KEEP** — subtype / cross-library identity / const-eval / element-identity
  data-flow. No safe AST proxy. These are the memory-relevant reaches.

---

## Tier 1 — NARROW on ungated, hot nodes (highest plausible value, low count)

These rules resolve on extremely common node types with no precheck. Reordering
a cheap check ahead of resolution is the change most likely to matter, and the
lowest risk.

| rule | file:line | issue | change |
|---|---|---|---|
| `prefer_dot_shorthand` | code_quality/code_quality_prefer_rules.dart:1934 | resolves `prefix.staticType` on EVERY `PrefixedIdentifier` (`a.b`) before any filter | move the parent-shape check (typed var / named arg / typed assignment) ahead of `staticType` |
| `avoid_missing_interpolation` | code_quality/code_quality_avoid_rules.dart:3883 | resolves both operands' `staticType` on EVERY `+` | require a `StringLiteral` operand (already computed) before resolving the other |
| `avoid_async_call_in_sync_function` | code_quality/code_quality_avoid_rules.dart:2171 | resolves `staticType` on EVERY MethodInvocation | run the sync-enclosing-function ancestor check (already present) before resolving |
| `avoid_collection_equality_checks` | data/collection_rules.dart:92,93 | resolves BOTH operands of EVERY `==`/`!=` | skip literals; resolve left, short-circuit before right |
| `avoid_datetime_comparison_without_precision` | data/equality_rules.dart:550,551 | resolves BOTH operands of EVERY `==`/`!=` | skip literals/null; precheck operand source for DateTime hint |
| `prefer_extracting_repeated_map_lookup` | config/sdk_migration_batch2_rules.dart:1289+ | ungated; resolves `.element` for every index expr + `.staticType` in EVERY BlockFunctionBody | pre-count IndexExpressions (pure AST); bail before resolving when < 3 |
| `avoid_future_tostring` / `avoid_unawaited_future` / `prefer_stream_transformer` | core/async_rules.dart:130,3350,5312 | ungated, no name filter; resolve `staticType` on every interpolation / expr-statement / `.map`/`.where` | add file-level `requiredPatterns` for `Future`/`Stream` so resolution is skipped in files that never reference them |
| `type_check_with_null` | data/type_rules.dart:2119,2120 | resolves element+library on EVERY `IsExpression` | gate on `node.type` token name `== 'Null'` first |
| `avoid_parameter_mutation` | code_quality/code_quality_variables_rules.dart:655,671,685,755 | resolves `staticType` + `allSupertypes` on every param assignment despite an AST declared-type-name map | make the AST name map authoritative; resolve only for unannotated params |

---

## Tier 2 — DROP: constructor / superclass name reads (mechanical, high count)

`node.constructorName.type.element?.name` and `superclass.element?.name`
compared against a literal name set, where `.type.name.lexeme` /
`.superclass.name.lexeme` is equivalent. The codebase already uses lexeme
matching for the same purpose elsewhere. Per-site memory benefit is likely ~nil
(local node already resolved); value is CPU + consistency. Each needs a fixture.

### UI (largest cluster; many ungated-broad)

- `ui/accessibility_rules.dart` — ~13 rules, all DROP: lines 74, 181, 262, 322,
  433, 584, 642, 669, 742, 751, 845, 951, 979, 1047, 1076, 1168, 1192, 1277,
  1297, 1315, 1484, 1620, 1658. (Tail after line 1663 unaudited — re-scan.)
- `ui/internationalization_rules.dart` — 78, 185, 622, 782, 789; plus 882
  (parent-name read in `prefer_date_format`).
- `ui/navigation_rules.dart` — 85, 339, 354, 436, 518, 628, 908.
- `ui/animation_rules.dart` — 84, 531, 610, 938, 1046, 1857.

### Widget

- `widget/forms_rules.dart` — 169, 292, 313, 395, 534. Also add
  `applicableFileTypes: {FileType.widget}` (most forms rules are ungated).
- `widget/build_method_rules.dart` — 132 (drop `.element?.name ??` lexeme
  fallback), 1240, 1249.
- `widget/widget_layout_flex_scroll_rules.dart` — 165, 175, 250, 265.
- `widget/widget_layout_constraints_rules.dart` — 285, 449, 3667.
- `widget/widget_lifecycle_rules.dart` — 33, 833, 1063, 2536 (superclass
  `State`/Widget name; file already trusts lexeme in its fallback).

### Core / data

- `core/performance_rules.dart` — 90, 925, 1027, 2061, 2071, 2087.
- `core/state_management_rules.dart` — 406, 997, 1206.
- `core/class_constructor_rules.dart` — 1222 (`proper_super_calls` superclass).
- `core/compound_performance_patterns.dart:98` — `widgetConstructionName`
  evaluates `.element` first then falls back to lexeme; swap order.
- `data/collection_rules.dart` — 3341, 3454, 3462.
- `data/type_safety_rules.dart:878`.

### Stylistic (all gated to widget files, but widget files dominate a Flutter app)

- `stylistic/stylistic_widget_rules.dart` — all 12: 83, 172, 253, 325, 401, 507,
  584, 597, 672, 756, 1027, 1116.
- `stylistic/stylistic_rules.dart` — 240, 1346, 1353, 1482 (superclass names).

### Packages / security / architecture / platforms / media

- `architecture/dependency_injection_rules.dart:305`.
- `flow/error_handling_rules.dart` — 297, 714, 1377.
- `code_quality/code_quality_avoid_rules.dart:3794` (`avoid_empty_build_when`).
- `packages/provider_rules.dart` — 388, 1387 (1387 already has lexeme fallback).
- `packages/firebase_rules.dart` — 251, 349.
- `packages/getx_rules.dart:1580`.
- `packages/riverpod_rules.dart:1624` (`avoid_global_riverpod_providers`).
- `security/security_network_input_rules.dart` — 385, 1008, 1519, 4681.
- `platforms/ios_capabilities_permissions_rules.dart` — 156, 748.
- `media/image_rules.dart` — 170, 185, 266.

---

## Tier 3 — NARROW: declared-type / source-text reorder

- bool-type display-string checks resolving `declaredFragment.element.type` on
  every variable/field: `stylistic/stylistic_rules.dart:2987,3016,3175`,
  `packages/getx_rules.dart:2426`. Read the `TypeAnnotation` token when the
  declaration is explicitly typed; resolve only inferred declarations.
- nullable-field checks: `code_quality/code_quality_variables_rules.dart:1544,
  1887` — read the `?` token (`isOuterTypeNullable`, already used at line 3297)
  instead of resolving the element type.
- `network/api_network_rules.dart:3160,3286,3392` — each already OR's a
  `target.toSource()` match with `target.staticType?.toString()`; reorder so the
  source-text regex runs first and resolution is the fallback.
- `compile_time_syntax_rules.dart:40` — precheck annotation name token
  (`literal`/`nonVirtual`) before resolving to the package:meta symbol.

---

## KEEP (do not touch — these are the memory-relevant reaches)

Genuine subtype/cross-library/const/data-flow. A string proxy reintroduces
false positives. Several were *deliberately* converted from name heuristics to
resolution to fix documented FPs (riverpod notifier disambiguation, security
receiver checks, `avoid_manual_date_formatting` custom-calendar types) —
reverting them re-breaks those.

Representative essential sites: `allSupertypes` subtype walks across
animation/widget/Tween/Enum/FFI types; `.element.library.uri` identity (dart:io,
dart:html Window, dart:convert, package:meta, js_interop); `isSealed`
(control-flow exhaustiveness); const-evaluation (non-constant map/set elements);
`avoid_deprecated_usage` (annotation + cross-package library identity on every
call site — the single most resolution-heavy rule, ungated, 3 node types — a
candidate for a config/tier gate rather than a code change); element-identity
data-flow (`avoid_pop_without_result`, `prefer_reusing_assigned_local`,
api_network local-variable tracking); `avoid_recursive_widget` self-instantiation
by element identity.

---

## Recommendation

1. Capture the heap snapshot (parent bug). It decides whether resolution-reduction
   touches the dominant retained type at all.
2. If it does: implement **Tier 1** first (low count, highest plausible value,
   lowest risk), each behind a preserved-detection fixture.
3. **Tier 2** is a large mechanical sweep with likely-negligible memory benefit;
   do it for CPU/consistency only if the snapshot does not point elsewhere.
4. Consider a **config/tier gate** for `avoid_deprecated_usage` — it is the
   heaviest single resolver and ungated.
