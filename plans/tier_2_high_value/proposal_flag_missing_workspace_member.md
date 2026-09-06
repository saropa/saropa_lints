# PROPOSAL: Flag Missing Workspace Member

**Status: Implemented**

Created: 2026-09-06

**Companion rule:** inverse of `plans/tier_1_quick_wins/proposal_add_resolution_workspace.md`
(member-side check: package missing `resolution: workspace`). This proposal is the
root-side check. Lower priority than the member-side rule — see Alternatives Considered
in the companion proposal for why the member-side direction was chosen as primary.

## Summary

Flags a workspace root `pubspec.yaml`'s top-level `workspace:` list for missing an
entry that points at a subdirectory containing its own `pubspec.yaml` — i.e. a
package sitting inside the repo tree that pub workspace tooling does not know about.

## Motivation

Once a monorepo has adopted pub workspaces (root `pubspec.yaml` with a `workspace:`
list), scaffolding a new package into the tree with `dart create` or by copying a
sibling directory does not automatically add it to that list. The new package then
resolves independently — its own `pubspec.lock`, no shared lockfile, no protection
from version drift against its siblings — silently defeating the workspace for that
one package while every other member stays correctly wired up. This is easy to miss
because nothing about creating the directory fails or warns; the package simply
never joins the workspace.

## Detection / Behavior

Fires when: a `pubspec.yaml` has a top-level `workspace:` key (i.e. it is a
workspace root), AND a subdirectory of that root contains its own `pubspec.yaml`,
AND that subdirectory's path is not present (after normalization — see Detection
Logic Notes) in the root's `workspace:` list.

**BAD** (root `pubspec.yaml`, `packages/bar` exists with its own `pubspec.yaml` but
is not listed):
```yaml
# pubspec.yaml (workspace root)
name: my_monorepo
workspace:
  - packages/foo
  # packages/bar exists on disk with a pubspec.yaml but is missing here — LINT
```

**GOOD:**
```yaml
# pubspec.yaml (workspace root)
name: my_monorepo
workspace:
  - packages/foo
  - packages/bar
```

## Quick Fix

Insert the missing directory's relative path as a new entry in the `workspace:`
list, alphabetically ordered against existing entries where the list is already
sorted (skip reordering if the existing list isn't sorted, to avoid an unrelated
diff).

## Detection Logic Notes

This rule inverts the walk direction of the companion member-side proposal, so the
same hardening lessons from that proposal's Detection Logic Review apply here in
mirror form:

1. **Scope the subdirectory scan, don't walk the whole repo tree.** A workspace root
   commonly sits above `.dart_tool/`, `build/`, and other generated or vendored
   directories that may contain a stray `pubspec.yaml` (e.g. inside a pub cache
   symlink or a nested `example/` of an *already-listed* member). The scan for
   candidate subdirectories must not descend into a directory that is itself
   already a listed workspace member — a member package's own `example/pubspec.yaml`
   must not be treated as a candidate for the *root's* list, exactly as it must not
   be treated as a workspace member itself in the companion rule. Concretely: once
   `packages/foo` is confirmed as a listed member, do not recurse into
   `packages/foo/example/` looking for further unlisted candidates.
2. **Only scan pubspec-having subdirectories, not arbitrary nesting depth.** Match
   Dart pub's own workspace model: members are typically one or two levels below
   the root (`packages/*`), not arbitrarily deep. An unbounded recursive directory
   walk repeats the exact perf mistake flagged in the companion proposal's cache
   reuse section (uncached, unbounded walk = "the single largest cost in the timing
   profile" on a prior incident) — this scan must be bounded and, if it needs
   memoization, should reuse the same sibling-cache shape recommended there rather
   than adding a third ad hoc walker.
3. **Path normalization for the membership match** — same requirement as the
   companion rule: `workspace:` entries are relative, forward-slash, no-glob paths;
   compare against the discovered subdirectory's path with separator normalization
   (Windows) and trailing-slash/`./`-prefix stripping before an exact string match.
4. **Directories without a `pubspec.yaml` are never candidates.** Only flag a
   subdirectory that itself contains a `pubspec.yaml` — an arbitrary source
   directory (`bin/`, `lib/`, `test/`) is not a package and must never be suggested
   as a missing workspace entry.

## Alternatives Considered

- **Primary vs. companion scope.** The member-side rule (companion proposal) was
  chosen as the higher-confidence, lower-FP direction: a package that already
  declares itself part of the tree but is missing `resolution: workspace` is almost
  always an oversight. A root `workspace:` list missing an entry is a weaker signal
  — the package might be under active development and deliberately excluded (e.g. a
  scratch/experimental directory, a template used by a code generator, a package
  intentionally kept out of the shared lockfile for isolation). This rule should
  default to a lower severity tier than the member-side rule and may need an escape
  hatch (e.g. a `// saropa:ignore-workspace-member` marker or an
  `analysis_options_custom.yaml` exclude list) once real-world false-positive
  patterns are observed — do not add that escape hatch speculatively before
  implementation; confirm the FP class first per project convention (`// ignore:`
  is a last resort, not a default).
- **Combine into a single bidirectional rule instead of two rules.** Rejected:
  the two directions have different confidence levels and likely different default
  severities/tiers (this rule belongs in tier_2_high_value rather than
  tier_1_quick_wins), so separate rules keep the tier assignment honest and let
  users opt into the noisier direction independently.

## Existing Coverage

None. Same grep result as the companion proposal — no existing rule reasons about
pub workspace `workspace:` lists. No implementation should begin here until the
companion member-side rule (`proposal_add_resolution_workspace.md`) has shipped and
its walk/cache infrastructure exists to extend, since this rule's directory-scan
bound (see Detection Logic Notes #1-#2) depends on knowing which subdirectories are
already-listed members — reusing that infrastructure avoids a second, inconsistent
notion of "workspace member" existing in the codebase at once.

## Finish Report (2026-09-06)

New lint rule `flag_missing_workspace_member` (recommended tier, INFO) implemented and registered. The rule fires on workspace root packages (pubspec.yaml with a `workspace:` key) when subdirectories containing their own `pubspec.yaml` are not listed in the `workspace:` list.

**Detection algorithm:** Extracts workspace entries via the refactored `_parseWorkspaceEntries` helper (shared with the companion `add_resolution_workspace` rule). Scans subdirectories up to 3 levels deep. Skips hidden directories (`.dart_tool`, `.git`), `build/` output, and already-listed member directories (preventing example/ false positives). Path comparison uses the same case-insensitive normalization added to the companion rule for Windows compatibility.

**Infrastructure changes:** Refactored `_findWorkspaceMembership` in `project_context_project_file.dart` to extract `_parseWorkspaceEntries` as a reusable static method. Added public `getWorkspaceMembers(projectRoot)` for the new rule to call. Added case-insensitive path comparison on Windows via `Platform.isWindows` to both the membership check and the scan.

**Limitations:** Same `/lib/`-gating limitation as all pubspec rules — workspace roots without a `lib/` directory never trigger. Scan depth capped at 3 levels — deeply nested packages beyond that are missed. No quick fix (the insertion position and alphabetical ordering logic is more complex than the companion rule's simple append).
