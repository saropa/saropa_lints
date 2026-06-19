# BUG: `scan` CLI silently misses every `InstanceCreationExpression` rule for implicit (no-`new`) constructor calls

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Component: `scan` CLI engine (`bin/scan.dart` → `lib/src/scan/scan_runner.dart`)
Severity: Correctness — High (silent under-reporting, not a crash)

---

## Summary

The `dart run saropa_lints scan` command parses each file with `parseString` (a purely **syntactic** parse — no element/type resolution). In an unresolved AST, an implicit constructor call written without `new` — e.g. `File('x')`, the modern idiom — is represented as a **`MethodInvocation`**, not an `InstanceCreationExpression`. The analyzer only rewrites such nodes into `InstanceCreationExpression` during **resolution**, which scan mode never performs (`ScanRuleContext.typeProvider`/`typeSystem` deliberately throw).

Consequently, every rule that registers on `addInstanceCreationExpression` never fires under the scan CLI for the no-`new` form. The rule's visitor is captured and wired correctly, the tier/gating all pass — there simply is no `InstanceCreationExpression` node in the tree to visit. Explicit `new File(...)` and `const Foo()` still parse as `InstanceCreationExpression` and are unaffected; only the (overwhelmingly common) implicit form is dropped.

This was discovered while verifying the `require_platform_check` conditional-import fix: that rule fired zero times under scan even on the pre-existing known-bad fixture.

---

## Reproducer

```bash
# A fixture whose only violation is an implicit-constructor dart:io call:
#   void f() { final file = File('data.txt'); }   // require_platform_check expects a lint
dart run saropa_lints scan example/lib/platform --tier comprehensive --format json
# require_platform_check appears 0 times in byRule, on EVERY file — including
# example/lib/platform/require_platform_check_fixture.dart, whose BAD case is a
# textbook violation.
```

`avoid_synchronous_file_io` (registered on `addMethodInvocation`, matching `writeAsStringSync`) DOES fire on the same `File` objects — confirming the file is scanned and visitors run; only the `InstanceCreationExpression` channel is empty.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `scan` reports the same `InstanceCreationExpression`-based violations the IDE/`custom_lint` plugin reports (subject to scan's documented no-type-resolution limits). |
| **Actual** | Every `InstanceCreationExpression` rule is a silent no-op under scan for implicit constructor calls (`File('x')`), the dominant Dart idiom. Only `new`/`const` forms are seen. No error, no warning — the rule just never matches. |

---

## Root Cause (verified)

`lib/src/scan/scan_runner.dart` parses with `parseString` (unresolved). Verified directly with the analyzer:

```dart
parseString(content: "void f(){ var a = File('x'); var b = new File('y'); var c = const Foo(); }")
// Visiting the unparsed unit:
//   MI:  File('x')        <- implicit constructor call → MethodInvocation
//   ICE: new File('y')    <- explicit new   → InstanceCreationExpression
//   ICE: const Foo()      <- explicit const → InstanceCreationExpression
```

Without `new`/`const`, the parser cannot know whether `File(...)` is a constructor or a function call — that decision needs name resolution. The resolver rewrites the node into `InstanceCreationExpression`; `parseString` never resolves, so the node stays a `MethodInvocation`. `lib/src/scan/scan_rule_context.dart` makes the lack of resolution explicit: `typeProvider`/`typeSystem` throw `UnsupportedError('Type resolution unavailable in scan mode')`.

This is not specific to `require_platform_check`. It is structural to scan mode and affects every rule on the `InstanceCreationExpression` channel.

---

## Blast Radius

- **85 rule files**, **514 `addInstanceCreationExpression` call sites** (`grep -rn "addInstanceCreationExpression" lib/src/rules/`). All silently under-report implicit constructor calls under the scan CLI.
- The IDE / `custom_lint` analysis-server path is unaffected — it runs on resolved units, so these rules fire correctly there. The gap is scan-CLI-only.
- Impact is silent under-reporting (false negatives), never a false positive or crash. A user running `scan` as their gate would believe the code is clean when these rules were never actually evaluated.

---

## Suggested Fix

In order of correctness:

### (a) Resolve units in scan mode instead of (or in addition to) `parseString`

Build an `AnalysisContextCollection` and use `getResolvedUnit` so the analyzer rewrites implicit constructor calls into `InstanceCreationExpression` (and unlocks type-based rules too). This is the accurate fix but heavyweight: resolution needs package resolution and is materially slower than the current syntactic pass — it changes scan's performance profile and the "fast syntactic scan" design intent. Could be opt-in via a `--resolve` flag so the fast path stays default.

### (b) Adapter: also fire `InstanceCreationExpression` visitors on constructor-shaped `MethodInvocation` nodes

In `lib/src/scan/capturing_registry.dart`, when a rule registers `addInstanceCreationExpression`, additionally run it against `MethodInvocation` nodes whose target reads as a constructor by convention (capitalized type name, no realizable receiver). Cheaper, keeps the syntactic pass, but heuristic — without resolution it cannot distinguish a top-level function from a constructor, so it would rely on the capitalized-identifier convention and risk both misses and the occasional false hit. Would also require shimming each rule's node access (an `InstanceCreationExpression` rule reads `node.constructorName`, absent on `MethodInvocation`).

### (c) Document the limitation and route verification away from scan

Regardless of (a)/(b): the scan CLI is a syntactic-only fast pass. `InstanceCreationExpression`-based rules — and any rule needing type resolution — cannot be verified through it. Document this in the scan CLI help and the contributor/verification notes so rule authors verify such rules via the IDE/`custom_lint` plugin, not `scan`. (This corrects the project assumption, recorded in session memory, that `dart run saropa_lints scan` is the way to verify any rule's behavior — it is not, for this whole class.)

**Recommendation:** ship (c) immediately (cheap, prevents further mis-verification), and pursue (a) behind an opt-in `--resolve` flag as the real fix. Avoid (b) — the heuristic's false hits/misses undercut the value of a lint gate.

---

## Environment

- saropa_lints version: 14.0.3 (current `main`)
- Dart SDK: 3.12.1
- Discovered via: `require_platform_check` conditional-import fix verification (see `plans/history/2026.06/2026.06.19/require_platform_check_false_positive_conditional_import_io_file.md`)

---

## Finish Report (2026-06-19)

Shipped recommendation (a) — a real resolved scan behind an opt-in `--resolve` flag — plus recommendation (c) — documented the limitation. Did **not** ship (b) (the heuristic adapter), per the bug's own guidance.

### What changed

- **`scan --resolve` flag** — new opt-in path. `bin/scan.dart` now has an async `main` and dispatches `runResolved()` when `--resolve` is present; the default path stays the fast syntactic `run()`.
  - `lib/src/scan/scan_cli_args.dart` — parse `--resolve` into `ScanCliArgs.resolve`.
  - `lib/src/scan/scan_runner.dart` — new `Future<List<ScanDiagnostic>?> runResolved()`. Builds an `AnalysisContextCollection`, calls `getResolvedUnit` per file, and walks the resolved unit. Resolution rewrites implicit constructor calls (`File('x')`) into `InstanceCreationExpression` and supplies a real `typeProvider`/`typeSystem`, so the whole class of rules fires. The syntactic-vs-resolved prelude (rule-set + file-list resolution) was extracted into a shared `_prepare()`; the diagnostic-to-`ScanDiagnostic` conversion into `_collectDiagnostics()`.
  - `lib/src/scan/scan_rule_context.dart` — added `MutableRuleContext` base (holds the per-file `currentUnit` + lib/test classification) and `ResolvedScanRuleContext` (mutable `typeProvider`/`typeSystem`/`libraryElement`, set per file via `setResolved`). `ScanRuleContext` now extends the base.
- **Scan resilience** — `lib/src/scan/scan_walker.dart` gained an optional `onError` sink. A rule that throws mid-walk is reported by name and disabled for the rest of that file instead of aborting the entire scan. Wired into both scan paths via a visitor→rule map in `scan_runner.dart`. This was forced by verification: once instance-creation rules actually run under `--resolve`, `require_platform_check` surfaced a latent crash in `conditional_import_utils.dart` (see below) that previously could never fire under scan.
- **Docs** — `bin/scan.dart` help text documents `--resolve` and the syntactic-scan limitation; `lib/scan.dart` library doc points at `runResolved`. CHANGELOG updated (Added + Fixed).

### Verification

- Programmatic check on the motivating fixture (`example/lib/platform/require_platform_check_fixture.dart`, comprehensive tier): `runResolved()` reports a rule (`avoid_ignoring_return_values`) that the syntactic `run()` does not — confirming resolution-only rules now fire.
- `dart analyze --fatal-infos` clean on all touched lib/bin/test files.
- `dart test test/scan/scan_runner_test.dart test/scan/scan_cli_args_test.dart` — all pass, including a new test asserting `runResolved()`'s diagnostics are a strict superset of `run()`'s on the fixture, and new `--resolve` arg-parsing tests.

### Adjacent bug found, NOT fixed here (out of scope — separate file/feature)

`lib/src/conditional_import_utils.dart:138` calls `parseString(content:, path:)` with `throwIfDiagnostics` defaulting to `true`, then checks `parseResult.errors.isNotEmpty` on the next line — which is unreachable, because the parse throws first on any importing file that has parse diagnostics (e.g. a fixture with `await_in_wrong_context`). This crashes `require_platform_check` whenever it inspects such a file. Under the IDE/`custom_lint` resolved path it would crash there too; under the new resolved scan it is now caught by the resilience layer (rule disabled for that file, reported to stderr). The one-line fix is `throwIfDiagnostics: false`. Left for a separate change since it is a different file/feature from this scan-engine bug.
