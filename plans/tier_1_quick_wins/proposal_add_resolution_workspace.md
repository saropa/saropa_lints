# PROPOSAL: Add Resolution Workspace

**Status: Implemented**

## Finish Report (2026-09-06)

New lint rule `add_resolution_workspace` (recommended tier, WARNING) implemented and registered. The rule flags a package listed in a Dart pub workspace whose own pubspec.yaml is missing the `resolution: workspace` top-level key — a silent version-drift bug that pub only catches at `pub get` time, not at edit time.

**Detection algorithm:** Walk from the package root's parent to the nearest ancestor pubspec.yaml (stop at the first one found, never skip past it). Parse the ancestor's `workspace:` list (block-style and flow-style). If the package's relative path appears in the list but the package's own pubspec lacks `resolution: workspace`, fire.

**Key design decisions:**
- Separate `_workspaceRootByPackageDir` cache in `ProjectContext` rather than reusing `_rootByDir` — different starting point (package root's parent vs. file's parent) and different answer shape.
- Walk terminates at first ancestor pubspec to prevent the `example/` false positive (the single most common nested-pubspec layout in Dart).
- Path normalization via `_canonicalRelativePath` helper (strips `./`, trailing `/`, normalizes separators) so Windows checkouts and various `workspace:` entry spellings all match.
- Regex allows trailing YAML comments on the `resolution:` line.
- Flow-style `workspace: [a, b]` parsing alongside block-style.

**Code review findings addressed:** collapsed dead `_WorkspaceInfo` class to plain `String?`, used shared `normalizePath()` instead of inline `replaceAll`, fixed regex rejecting trailing comments, fixed column-0 comments truncating member list, added flow-style list parsing.

**Quick fix:** `AddResolutionWorkspaceFix` (SaropaFixProducer) inserts `resolution: workspace` as a top-level YAML key into the package's pubspec.yaml. Uses `addGenericFileEdit` (same cross-file pattern as `RaiseSdkLowerBoundFix`) since the diagnostic attaches to a `.dart` token. Inserts after the `environment:` block when present, or at end of file otherwise.

**Limitations:** Rule inherits the `/lib/`-gating pattern from sibling pubspec rules — bin-only packages with no `lib/` directory are never flagged. `_reportedRoots` static Set follows the pre-existing pattern of not being wired to `clearCache()`. No fixture file because the rule targets `.yaml` content read from disk, not `.dart` AST nodes.

## Finish Report (2026-09-06) — Hardening Pass

Code review of the initial implementation identified four defensive gaps in the quick fix and detection regex, plus zero behavioral test coverage beyond metadata pinning.

**Fixes applied:**
1. `AddResolutionWorkspaceFix.compute()` now re-checks `resolutionWorkspaceRe` against the live pubspec content before inserting. Guards against stale diagnostics (pubspec edited since last analysis) and batch "fix all" applies that would otherwise insert a duplicate `resolution:` key.
2. The `envMatch != null` branch now checks whether the matched block ends with a newline and prepends one if absent — prevents `sdk: ^3.6.0resolution: workspace` corruption when the environment block sits at EOF without a trailing newline.
3. `_environmentBlockRe` continuation pattern now tolerates blank or whitespace-only lines inside the environment block (`(?:(?:[ \t]+\S[^\n]*|[ \t]*)\n)*`) — a legal YAML style that previously ended the match early, causing the insertion point to land mid-block.
4. `resolutionWorkspaceRe` now accepts quoted scalars (`resolution: "workspace"`, `resolution: 'workspace'`) via `['"]?workspace['"]?` — valid YAML that previously caused a false positive.

**Shared regex:** Extracted `resolutionWorkspaceRe` as a top-level export in `add_resolution_workspace_fix.dart` so both the rule and the fix reference the same pattern without circular imports. The rule delegates via `static final _resolutionWorkspaceRe = resolutionWorkspaceRe`.

**Test coverage added (22 tests):**
- `resolutionWorkspaceRe` group (9 tests): bare match, trailing whitespace, YAML comment, double-quoted, single-quoted, indented no-match, wrong value, multi-line pubspec match, absent key.
- `getWorkspaceMembers` group (7 tests): block-style, flow-style, column-0 comments, no workspace key, empty list, block terminated by next top-level key, nonexistent directory.
- `getWorkspaceRoot` group (6 tests): listed member found, unlisted member null, no workspace key stops walk, example/ false-positive guard, Windows case-insensitive match, null/empty input.

**Additional hardening (same pass):**
- Tightened `resolutionWorkspaceRe` to require matching quote pairs via alternation (`workspace|"workspace"|'workspace'`) rather than independent optional quotes.
- Confirmed `_environmentBlockRe` already uses `[ \t]+` for continuation lines, covering tab indentation.
- Added mismatched-quote negative test.

**Companion rule added:** `workspace_dependency_version_sync` (recommended tier, INFO) — flags a workspace whose member packages declare different constraint strings for the same dependency. Fires once per workspace root, parsing all members' pubspec.yaml files via the existing `parsePubspecConstraints` infrastructure. No quick fix (which member's version should win is a human decision). Registered in all 3 places (`_allRuleFactories`, `recommendedOnlyRules`, metadata test).

Created: 2026-09-02

## Summary

Flags a package's `pubspec.yaml` that lives inside a Dart/Flutter pub workspace (a sibling `pubspec.yaml` above it declares `workspace:`) but does not itself declare `resolution: workspace`.

## Motivation

Dart 3.6 introduced pub workspaces so a monorepo can share a single lockfile and resolve inter-package dependencies without `path:` overrides or `melos bootstrap`. A member package that omits `resolution: workspace` falls back to independent resolution — its own `pubspec.lock`, its own dependency graph — which silently defeats the workspace and reintroduces version drift between packages that are supposed to be locked together. This is easy to miss when scaffolding a new package into an existing monorepo, since `dart create` does not add the field automatically.

## Detection / Behavior

Fires when: the containing project root's `pubspec.yaml` (or an ancestor within the repo) has a top-level `workspace:` list naming this package's directory, AND this package's own `pubspec.yaml` has an `environment:` block without a `resolution: workspace` entry.

**BAD** (member package, root `pubspec.yaml` has `workspace: [packages/foo]`):
```yaml
# packages/foo/pubspec.yaml
name: foo
environment:
  sdk: ^3.6.0
```

**GOOD:**
```yaml
# packages/foo/pubspec.yaml
name: foo
environment:
  sdk: ^3.6.0
resolution: workspace
```

## Quick Fix

Insert `resolution: workspace` immediately after the `environment:` block (or after `sdk:` inside it, matching the layout `dart create` produces for workspace members).

## Alternatives Considered

Could instead flag the root pubspec for missing `workspace:` entries that point at directories with a `pubspec.yaml` — the inverse direction. Rejected as the primary scope: a missing `workspace:` line is a deliberate omission (the package isn't meant to join the workspace) far more often than a missing `resolution: workspace` is deliberate, so the member-side check has a much lower false-positive rate.

## Existing Coverage

None. Grepped `lib/src/` for `resolution`/`workspace` — no existing rule reasons about pub workspaces or the `resolution:` key. `lib/src/config/pubspec_constraint_parser.dart` and `lib/src/rules/config/pubspec_constraint_rules.dart` only parse version-constraint ranges (SDK/dependency bounds), not workspace membership, so this would need a new small parser (read the current pubspec plus walk parent directories for a `workspace:` list) rather than reusing that infrastructure directly. The existing `_reportPubspecOnce`-style pattern (read pubspec.yaml from disk once per root, attach diagnostic to the top of a `lib/` Dart file) is directly reusable for the reporting mechanics.

## Detection Logic Review (2026-09-06)

Evaluated against the four concerns raised for this proposal: opted-out members, no
parent workspace, nested workspaces, and reliability of the parent-directory walk.
Conclusion: the core premise is sound, but the "walk parent directories" spec as
written is under-specified in a way that risks a concrete false positive on a very
common Dart layout (a package's own `example/` subdirectory). Must be fixed before
implementation.

### 1. "Listed in workspace but intentionally opted out" — not a real state, no FP risk

Dart pub workspaces enforce this pairing bidirectionally: if a package's directory
appears in an ancestor's `workspace:` list, `dart pub get` run from the workspace root
already fails with a hard error unless that package declares `resolution: workspace`.
There is no supported way to be listed and opt out — the listing *is* the opt-in.
So concern 1 is not a real false-positive source; the rule's premise (listed ⇒
must declare) matches pub's own enforcement. Worth stating explicitly in the proposal
so a future implementer doesn't add unnecessary "opt-out" escape-hatch logic.

### 2. No parent pubspec with `workspace:` — handled correctly IF the walk terminates on
   the first ancestor pubspec.yaml found, not just the first one that happens to have
   `workspace:`.

This is the one substantive bug in the current spec. "the containing project root's
pubspec.yaml (**or an ancestor within the repo**)" reads as "keep walking up past
pubspecs that don't have `workspace:` until you find one that does." That is wrong
and will misfire on the single most common nested-pubspec layout in the Dart
ecosystem: a package's own `example/` directory, which has its own `pubspec.yaml`
with no `workspace:` key, sitting under a package that itself might be a workspace
member several levels further up.

Concretely: `packages/foo/example/pubspec.yaml` — walking from `example/`'s parent
looking for the *nearest* pubspec.yaml lands on `packages/foo/pubspec.yaml`. That
pubspec is a normal package manifest with no `workspace:` key. If the walker treats
"no `workspace:` key" as "keep going" rather than "stop, this package is not a
workspace member," it will continue up to the repo root, find `workspace: [packages/foo]`,
and incorrectly conclude that `example/` itself needs `resolution: workspace` — it
does not; only `packages/foo` does. `example/` is a deliberately separate,
non-workspace package (it depends on its parent via a `path:` override), and this
repo (`saropa_lints`) has exactly this shape (`example/pubspec.yaml` under the
package root).

**Required fix:** the walk must stop at the *first* ancestor directory containing a
pubspec.yaml, full stop — check only that pubspec's `workspace:` list (if any) for
membership. If that first ancestor has no `workspace:` key, or has one that doesn't
list this package, the rule does not fire. Do not skip past a plain pubspec.yaml
searching for a workspace root further up. This matches the existing
`ProjectContextProjectFile.findProjectRoot` walk semantics exactly (nearest pubspec
wins, walk stops there) — see reuse note in section 4.

### 3. Nested workspaces — not currently possible in Dart pub, so not a real edge case
   once fix #2 is applied

Dart pub workspaces do not support a workspace member that is itself a workspace
root; `dart pub get` does not define behavior for that shape and it is not a
pattern in circulation. Once the walk stops at the first ancestor pubspec (fix #2),
"nested workspace" collapses into the same case as #2 — the first ancestor pubspec
answers the question and the walk never reaches a second one. No separate handling
needed; this concern is resolved as a corollary of the fix in #2, not independently.

### 4. Reliability of the parent-directory walk — reuse existing infra instead of a new
   walker; two additional gaps to close

- **Reuse, don't reimplement.** `lib/src/project_context_project_file.dart`
  (`ProjectContextProjectFile.findProjectRoot`, lines ~64-110) already implements
  exactly the "walk up, stop at nearest pubspec.yaml, memoize every directory
  visited" algorithm this rule needs — applied to the *parent* of the package
  being checked. Its doc comment records a prior incident: an unmemoized per-node
  parent walk was "the single largest cost in the timing profile" on a 165-file
  scan before the `_rootByDir` cache was added. The proposal's "Existing Coverage"
  section explicitly says this would need "a new small parser" that "walk[s] parent
  directories" — that is the same mistake being reintroduced from scratch. The new
  rule should extend/reuse this cache (or add a sibling cache keyed the same way for
  the workspace-root lookup) rather than writing an unbounded, uncached walk.
- **Bound the walk when no ancestor pubspec exists at all.** `findProjectRoot`
  already bounds on `dir.path.length > 1` (filesystem root). The new rule's
  "workspace root" walk should reuse the same bound — needed for packages opened
  outside any repo, or for the (already-excluded-by-fix-#2) case of no ancestor
  pubspec anywhere above the parent directory.
- **Path normalization for the membership match.** `workspace:` entries are
  author-written relative paths (forward slashes, no glob support in current Dart
  pub). Comparing them against the computed relative path from the found ancestor
  to the package directory must normalize separators (Windows) and strip any
  trailing slash / `./` prefix before an exact string compare — an unnormalized
  compare will silently under-fire on Windows checkouts.

### Spec correction: `resolution: workspace` is not nested under `environment:`

The BAD/GOOD examples show `resolution: workspace` correctly as a top-level key,
sibling to `environment:` — that matches Dart's actual schema. But the prose in
"Detection / Behavior" says the rule fires when "this package's own pubspec.yaml has
an `environment:` block **without** a `resolution: workspace` entry," which reads as
gating detection on the presence of an `environment:` block. The check should simply
be "top-level `resolution:` key is absent (or not `workspace`)," independent of
whether/where `environment:` appears — a member pubspec without an `environment:`
block at all should still fire if it's a listed workspace member.

### Revised scope for implementation

1. Locate the nearest ancestor pubspec.yaml above the package's own directory
   (reuse/extend `ProjectContextProjectFile`'s cached walk — do not add a fresh
   uncached walker).
2. If that ancestor has no `workspace:` key, or its list (normalized) doesn't
   contain this package's relative path, do not fire.
3. If it does list this package, fire when the package's own pubspec.yaml lacks a
   top-level `resolution: workspace` key (regardless of `environment:` block
   presence/shape).
4. No opt-out branch needed (see #1) and no nested-workspace branch needed (see #3)
   — both collapse into the single-ancestor-check above once #2's walk bound is
   correct.

## Test Fixtures

Fixture layout mirrors the "nearest ancestor pubspec, stop there" algorithm above —
each fixture pins one branch of the revised walk so a regression in the walk
termination (the bug this review found) fails a test instead of shipping quietly.

### Fixture 1 — happy path: member package missing `resolution: workspace`

```
example/lib/workspace_member_missing_resolution/
  pubspec.yaml            # root: workspace: [packages/foo]
  packages/foo/pubspec.yaml  # no `resolution:` key — LINT
```

`packages/foo/pubspec.yaml`:
```yaml
name: foo
environment:
  sdk: ^3.6.0
# LINT: package is listed in the workspace root's `workspace:` but does not
# declare `resolution: workspace`, so it resolves independently instead of
# joining the shared lockfile.
```

Root `pubspec.yaml` (nearest ancestor pubspec above `packages/foo/`, one level up):
```yaml
name: root
workspace:
  - packages/foo
```

### Fixture 2 — `example/` FP case: nested pubspec must NOT fire

This is the false-positive scenario the walk-termination fix exists for. The walk
from `packages/foo/example/` must stop at `packages/foo/pubspec.yaml` (the *nearest*
ancestor pubspec) and never continue up to the repo root's `workspace:` list, even
though the repo root does list `packages/foo`.

```
example/lib/workspace_example_subdir_no_fp/
  pubspec.yaml                      # root: workspace: [packages/foo]
  packages/foo/pubspec.yaml         # workspace member, has resolution: workspace
  packages/foo/example/pubspec.yaml # standalone example package — NOT a member
```

`packages/foo/example/pubspec.yaml`:
```yaml
name: foo_example
environment:
  sdk: ^3.6.0
dependencies:
  foo:
    path: ../
# NO LINT: nearest ancestor pubspec is packages/foo/pubspec.yaml, which has no
# `workspace:` key at all. The walk must stop there — it must not skip past this
# plain pubspec searching further up for one that happens to declare `workspace:`.
```

Regression this fixture guards: an implementation that treats "ancestor pubspec
with no `workspace:` key" as "keep walking" (rather than "stop, not a member")
would incorrectly walk past `packages/foo/pubspec.yaml` to the repo root, find
`workspace: [packages/foo]`, and misfire on `example/pubspec.yaml`.

### Fixture 3 — package not in any workspace: NOT fire

```
example/lib/workspace_not_present/
  packages/standalone/pubspec.yaml  # nearest ancestor has no workspace: key at all
```

`packages/standalone/pubspec.yaml`:
```yaml
name: standalone
environment:
  sdk: ^3.6.0
# NO LINT: nearest ancestor pubspec (this file's own directory, since no parent
# pubspec.yaml exists above it in the fixture tree) has no `workspace:` key, so
# there is no workspace to be a member of. Also covers the "opened outside any
# repo" case where the walk hits the filesystem root bound without finding a
# pubspec at all.
```

### Fixture 4 — already declares `resolution: workspace`: NOT fire

```
example/lib/workspace_member_has_resolution/
  pubspec.yaml               # root: workspace: [packages/foo]
  packages/foo/pubspec.yaml  # has resolution: workspace already
```

`packages/foo/pubspec.yaml`:
```yaml
name: foo
environment:
  sdk: ^3.6.0
resolution: workspace
# NO LINT: package is listed in the workspace root and already declares
# resolution: workspace — this is the correct, already-fixed state.
```

Each fixture needs a paired `test/rules/.../resolution_workspace_test.dart` case
per the standard `// LINT` marker convention (see `Skill(lint-rules)`); listed here
as the detection spec, not as implemented test code.

## Implementation Notes — Cache Reuse Assessment

Read `lib/src/project_context_project_file.dart` (`ProjectContext.findProjectRoot`,
lines ~64-116, and its backing cache `_rootByDir` at ~line 62) to check whether this
rule can reuse that cache directly for the workspace-root lookup, or needs its own.

**Finding: needs a separate cache, cannot reuse `_rootByDir` as-is.**

`_rootByDir` answers a different question than this rule needs:

- `findProjectRoot` walks up from a *file's parent directory* and stops at the
  **nearest** ancestor pubspec.yaml — i.e. "what package owns this file." For a file
  under `packages/foo/lib/`, that's `packages/foo`.
- This rule needs, for a given *package directory* (`packages/foo`, itself already a
  pubspec root), the answer to a different question: "what pubspec.yaml sits
  immediately **above** this package root, and does its `workspace:` list name me?"
  That's a walk starting one level higher (`packages/foo`'s parent, i.e. `packages/`),
  looking for the nearest pubspec.yaml *above the package*, not above an arbitrary file.

Calling `findProjectRoot(packageDir)` directly does not answer this: passed a
directory rather than a file, `findProjectRoot` takes `Directory(normalized).parent`
of whatever is passed, so the caller has to pass a synthetic path one level inside
the package root to make the existing "take the parent" logic line up — fragile
coupling to an internal implementation detail, not a real API for this purpose. The
correct reuse point is the **loop body pattern**, not the cached map: the same
walk-up-checking-`existsSync` shape, same filesystem-root bound
(`dir.path.length > 1`), same back-fill-on-first-answer memoization strategy — but
keyed and rooted differently.

**Recommendation:** add a sibling cache, e.g. `_workspaceRootByPackageDir` in the
same file/class, keyed by normalized package directory (not file path), holding the
resolved ancestor-pubspec path (or `null`) plus whatever of that ancestor's
`workspace:` list is needed for the membership check. Implement it as a close copy
of `findProjectRoot`'s loop (start one directory above the package root instead of
above a file's parent; same `visited` back-fill; same OSError guard) rather than
generalizing `findProjectRoot` itself — the two callers have different starting
points and `findProjectRoot`'s doc comment and existing callers are load-bearing
(see the PERF-CRITICAL comment on `_rootByDir`, ~line 51: the cache exists because
per-node uncached walks were "the single largest cost in the timing profile" on a
165-file scan). Widening `findProjectRoot`'s contract to serve both callers risks
regressing that existing hot path for a marginal reuse gain; a small sibling cache
with the same *shape* (walk-up, `existsSync`, memoize, bound at filesystem root)
achieves the reuse goal (no new unbounded/uncached walker, per the review's
Detection Logic Review §4) without touching the proven cache.
