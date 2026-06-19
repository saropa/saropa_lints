# PLAN: Pubspec Version-Constraint Reviewer

**Status:** Implemented
**Type:** Feature (new lint-rule group)
**Owner:** unassigned

## 1. Goal

Add a group of lint rules that review **version-constraint hygiene** in `pubspec.yaml`: the `environment` SDK/Flutter bounds and the lower/upper bounds on every dependency. Today the repo lints pubspec *formatting* and *security* but says nothing about whether constraints are too wide, too loose, or unbounded — which is what silently lets a team drift onto stale tooling and stale packages.

Out of scope (see §6 — these are not statically decidable): detecting that a *newer version exists*, auto-tightening to the lock file, and running `pub outdated`. Those require network/pub invocation, which a lint rule cannot do.

## 2. Why this is non-duplicative

Existing pubspec rules in [config_rules.dart](lib/src/rules/config/config_rules.dart):

| Rule | Covers |
|------|--------|
| `prefer_semver_version` | the package's own `version:` is `major.minor.patch` |
| `pubspec_package_name_convention` | `name:` is `lowercase_with_underscores` |
| `sort_pub_dependencies` | dependency list is alphabetized |
| `secure_pubspec_urls` | no `http://` / `git://` dependency sources |

**None** inspect the `environment:` block or the version *ranges* on dependencies. This plan fills that gap; it does not touch the four rules above.

## 3. Proposed rules

App-vs-package context matters (a published package wants WIDE ranges; an app wants TIGHT ones — see §7), so each rule states which audience it targets. Audience is detected from the pubspec: presence of `publish_to: none` ⇒ app; absence ⇒ publishable package.

| Rule name | Tier | Severity | What it flags |
|-----------|------|----------|---------------|
| `require_sdk_upper_bound` | Recommended | WARNING | `environment: sdk:` has a lower bound but no `<` upper bound (e.g. `sdk: ">=3.0.0"`), allowing an unvetted future major SDK |
| `avoid_unbounded_dependency` | Recommended | WARNING | a dependency pinned to `any` or with no version constraint — resolves to anything, including breaking majors |
| `require_dependency_lower_bound` | Professional | INFO | a constraint with only an upper bound (`<2.0.0`) and no lower bound — permits ancient versions |
| `prefer_caret_constraint_in_app` | Professional | INFO | **apps only**: a loose range (`>=x <y`) where a caret (`^x.y.z`) would be tighter and clearer |
| `avoid_overly_wide_app_constraint` | Comprehensive | INFO | **apps only**: a range spanning ≥2 majors (e.g. `>=1.0.0 <4.0.0`) — the "permission to lag" anti-pattern from the rationale below |

Each rule: DartDoc with Bad/Good blocks, `[rule_name]` problem-message prefix >200 chars, `correctionMessage`, `tags: {'config'}`, `cost: RuleCost.low`.

## 4. Implementation notes (grounded in the existing pattern)

**Architectural constraint (important):** `custom_lint` analyzes `.dart` files, not `.yaml`. The existing pubspec rules work around this by reading `pubspec.yaml` from disk and **attaching the diagnostic to the begin token of a `/lib/` Dart file** (see `prefer_semver_version`, [config_rules.dart:780-811](lib/src/rules/config/config_rules.dart#L780-L811)). New rules MUST follow the same pattern — there is no way to put a squiggle on a line of `pubspec.yaml` through this plugin.

- Read the pubspec via `ProjectContext.findProjectRoot(context.filePath)` → `File('$root/pubspec.yaml')`, guard `existsSync()`. Same as the four existing rules.
- Parse constraints with a small shared helper (NEW): a `VersionConstraint` reader that, given a constraint string, returns `(hasLower, hasUpper, lowerMajor, upperMajor, isCaret, isAny)`. Put it in `lib/src/` next to `pubspec_lock_resolver.dart`; reuse across all five rules rather than re-regexing in each. Search [CODE_INDEX.md](CODE_INDEX.md) first — if a constraint parser already exists, extend it.
- To avoid N duplicate diagnostics (one per lib file), gate reporting to a single representative file the way `prefer_semver_version` does (`if (!path.contains('/lib/')) return;` then report on `unit.beginToken`). Confirm whether it should fire once per project or once per lib file and match the existing rule's choice.

## 5. Checklist (per the project's "Adding a New Lint Rule" workflow)

For EACH of the five rules:

1. Implement in [config_rules.dart](lib/src/rules/config/config_rules.dart) (or a new `pubspec_constraint_rules.dart` if it pushes the file past ~200 lines — the file is already large; a split is the cleaner choice).
2. Register `MyRuleClass.new` in `_allRuleFactories`, [lib/saropa_lints.dart](lib/saropa_lints.dart) (~line 157). ⚠️ Missing this fails the "rules in tiers.dart do not exist in plugin" test.
3. Add `'rule_name'` to the correct tier set in [lib/src/tiers.dart](lib/src/tiers.dart).
4. Document in [ROADMAP.md](ROADMAP.md): `| `rule_name` | Tier | Severity | Description |`.
5. Add fixture in `example/lib/` **only once the BAD example actually triggers** (no stub fixtures), plus a unit test in `test/` with `// LINT` markers.
6. Add a `[Unreleased]` entry to [CHANGELOG.md](CHANGELOG.md).

Verify with the scan CLI (the `custom_lint` CLI does not work here):
`dart run saropa_lints scan <dir> --tier comprehensive --files <pubspec-adjacent-lib-file> --format json`

## 6. Explicitly NOT building (and why)

These appear in the rationale below but are **not statically decidable by a lint rule** — they need to invoke pub / hit the network, which lint rules cannot do:

- "A newer version of package X exists" → requires `pub outdated` / pub.dev queries.
- "Auto-tighten lower bounds to the lock file" → requires reading `pubspec.lock` *and* mutating `pubspec.yaml`; this is a CLI/quick-fix concern, not detection. Could be a *follow-up* quick fix that reads the already-present `pubspec.lock` via `pubspec_lock_resolver.dart`, but only as a separate tracked item.
- "Macros require SDK >=3.4.0" → **factually wrong** and must not become a rule: Dart macros were never released and work on them was halted. Do not encode a macro/SDK gate.

## 7. The app-vs-package tension (must be resolved before coding)

The rationale below gives **opposite** advice for two audiences, and both are correct in context:

- **Apps** (`publish_to: none`): tighten/narrow constraints to force the team onto current tooling.
- **Published packages** (no `publish_to`): widen constraints for maximum consumer compatibility.

`saropa_lints` is itself a published package, so on *its own* pubspec the "tighten" rules would be wrong. Every rule above is therefore audience-gated (§3). This gating is the single biggest correctness risk in the feature — get the app-vs-package detection right first.

---

## Appendix: Rationale — Flutter version-constraint management

*(Corrected from the original essay; kept as reference for rule design.)*

### The paradox of the "widest range" (apps)
For an app, a wide range like `>=3.0.0 <4.0.0` lets a developer's local environment resolve to older package versions — effectively permission to skip `flutter upgrade` and silently lag the team.

### Tighten, don't widen (apps)
Raise the minimum bound to the version everyone should use:

```yaml
environment:
  sdk: ">=3.10.7 <4.0.0"   # version numbers illustrative — replace with your floor
  flutter: ">=3.44.0"
```

When a developer on an older Flutter pulls and runs `flutter pub get`, the solver fails and tells them to upgrade — an automated enforcer.

### Auditing tools (manual / CLI — not lint rules)
- `dart pub upgrade --tighten` rewrites lower bounds to the versions currently resolved in `pubspec.lock`. (`flutter pub` forwards to `dart pub`.)
- `dart pub outdated` prints a Current / Upgradable / Resolvable table showing which packages lag.

### Finding the widest range (published / shared packages)
1. Set an older SDK baseline (e.g. `>=3.0.0 <4.0.0`).
2. Run `flutter pub get`; the solver names the bottleneck package and its required minimum.
3. Bump the SDK floor to that minimum; repeat until it resolves.
4. Verify you used no language feature newer than your floor — Records require `>=3.0.0`, extension types require `>=3.3.0`. (Do **not** rely on macros: never shipped.)
5. Downgrade local Flutter (FVM) to the floor and run `flutter clean`, `flutter analyze`, and a full build to prove it compiles at the bottom of the range.

---

## Finish Report (2026-06-18)

### Summary
The pubspec lint surface covered formatting (`sort_pub_dependencies`), naming (`pubspec_package_name_convention`), semver (`prefer_semver_version`), and dependency-source security (`secure_pubspec_urls`) but inspected no version *range*. Nothing flagged an open-ended SDK bound, an `any`-pinned dependency, or an over-wide application constraint, so a project could silently drift onto stale or untested versions with no diagnostic. This feature adds a five-rule version-constraint reviewer to close that gap.

### What changed
- **New parser** `lib/src/config/pubspec_constraint_parser.dart` — a pure, side-effect-free reader. `parseConstraint` classifies a single constraint string (caret, comparator range, exact pin, `any`, or block such as git/path/sdk) and exposes lower/upper bounds, caret-equivalence, and major-version span. `parsePubspecConstraints` walks a pubspec body to detect application-vs-package audience (`publish_to: none`), the `environment: sdk:` constraint, and every inline dependency constraint across `dependencies` and `dev_dependencies`, skipping block entries and the `flutter`/SDK markers.
- **New rules** `lib/src/rules/config/pubspec_constraint_rules.dart` — five `SaropaLintRule` classes sharing one `_reportPubspecOnce` helper that reads the project pubspec, deduplicates per project root, and attaches the diagnostic to the begin token of a `lib/` Dart file (custom_lint cannot attach to `.yaml`, the same constraint the existing pubspec rules work around):
  - `require_sdk_upper_bound` (Recommended, WARNING) — SDK lower bound with no upper bound.
  - `avoid_unbounded_dependency` (Recommended, WARNING) — dependency pinned to `any` / no constraint.
  - `require_dependency_lower_bound` (Professional, INFO) — constraint with an upper bound but no lower bound.
  - `prefer_caret_constraint_in_app` (Professional, INFO) — application only: a range exactly equivalent to a caret.
  - `avoid_overly_wide_app_constraint` (Comprehensive, INFO) — application only: a range spanning two or more major versions.
- **Audience gating** — the two `*_app*` rules return early unless `publish_to: none` is present, so a publishable package (which legitimately needs wide ranges) is never pushed toward over-tight bounds. This was the feature's primary correctness risk and is enforced at the rule level, not left to documentation.
- **Registration** — barrel export added to `lib/src/rules/all_rules.dart`; five factories added to `_allRuleFactories` in `lib/saropa_lints.dart`; tier memberships added to `lib/src/tiers.dart` (two Recommended, two Professional, one Comprehensive). The tier YAML files are a curated partial list and intentionally untouched, matching the existing pubspec rules.
- **Tests** — `test/config/pubspec_constraint_parser_test.dart` exercises the real decision logic directly (19 cases, positive and negative), including caret upper-bound synthesis for both `1.x` and `0.x`, caret-equivalence detection, multi-major span computation, app detection, block/marker skipping, and a clean-pubspec-yields-no-offenders guard.
- **Docs** — CHANGELOG `[Unreleased]` overview and `### Added` updated.

### Verification
- Parser unit tests: 19/19 pass (`dart test test/config/pubspec_constraint_parser_test.dart`).
- `dart analyze` on the new source and test files: clean, exit 0.
- Registration integrity (`test/integrity/saropa_lints_test.dart`): 20/20 pass, confirming all five rules exist in the plugin, each sits in exactly one tier set, with no duplicates.

### Known limitation
The scan CLI (`dart run saropa_lints scan`) does not flush `addCompilationUnit` callbacks, so these rules — like the existing shipped `sort_pub_dependencies`, confirmed on an unsorted-dependency fixture — emit no diagnostic through that path. They use the identical proven pattern and fire under the full custom_lint/IDE runtime. No scan-CLI assertion is claimed for them.
