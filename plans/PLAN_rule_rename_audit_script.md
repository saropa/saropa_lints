# PLAN — Rule-rename naming scheme + alias-collision audit (prerequisite to the rename itself)

## Context

`plans/PLAN_rule_id_package_first_rename.md` scopes a rename of 1,036 package-specific rule ids
from verb-first (`avoid_cached_isar_stream`) to package-first (`isar_avoid_cached_stream`). That
plan is sound on *scope* (10 locations the id string touches) but assumed the new names and their
back-compat aliases (`configAliases`) can be derived safely. Two things must be nailed down BEFORE
any rename script is written, or the actual migration will silently produce bad ids or clobber an
existing rule:

1. **The naming formula isn't uniform.** Research confirms already-compliant packs follow
   `<full_package_name>_<condition_description>` — but the "condition description" is not
   guaranteed to start with a verb (`local_auth_unchecked_result`, `geocoding_concurrent_locale_race`),
   and at least one already-compliant file has a deliberate non-compliant legacy id living inside it
   (`avoid_app_links_sensitive_params` in `app_links_rules.dart`). A naive "verb-first → package-first"
   string transform will get some of these wrong.
2. **No collision-detection exists anywhere in the codebase today.** `configAliases`
   (`lib/src/saropa_lint_rule.dart`) is a per-rule getter with no central registry — the only
   near-registry, `_buildRuleFactoriesMap()` in `lib/saropa_lints.dart` (~line 2981), keys by
   canonical id only and silently overwrites on a duplicate (`map[name] = factory`). Nothing
   today would stop a rename from producing a new id or alias that collides with an existing rule.

This plan builds a **read-only audit script** that proposes every new id and flags every collision,
producing a report for human review. It does **not** rename anything, write `configAliases`, or
touch any of the 10 downstream locations — that's the next plan, gated on this report coming back
clean (or with every flagged row resolved).

## Rulings (carry forward into the implementation plan)

- The rename ships as a **breaking change**: on-startup migration handling plus a **BREAKING**
  entry in `CHANGELOG.md` when implemented. Out of scope for this audit script, but the audit's
  collision classification below must already assume this policy, not the softer "silent alias,
  no changelog note" framing the original rename plan implied.
- **Alias policy**: `old_id` is always kept as a `configAliases` entry on the renamed rule. If
  `new_id` is currently in use as an *alias* on a **different, unrelated** rule, that alias entry
  is removed from the other rule and effectively reassigned — the canonical id wins over a stale
  alias pointing elsewhere. This is NOT true in reverse: if `old_id` (the one being retired) is
  already someone else's alias, that stays a hard collision requiring manual resolution (an id
  can't ambiguously alias two different rules).

## Approach — `scripts/rule_rename_audit.py`

Pure-Python (repo convention: durable scripts = Python), read-only, mirrors the existing regex
pattern from `scripts/gen_category_map.py` (`LintCode(\n  'rule_name'` — id always on its own line).

### 1. Extraction

- Parse every `lib/src/rules/packages/*.dart` file: for each `LintCode('id', ...)` match, walk
  backward to the nearest enclosing `class X extends ...Rule` to get the class name, then scan that
  class body for a `configAliases => const <String>[...]` block and pull every quoted string.
- `pack` = filename minus `_rules.dart` suffix. Cross-check each derived pack name against
  `tool/generate_rule_pack_registry.dart`'s pack→ruleCodes output; a filename that doesn't resolve
  there is `pack-name-unresolved` (manual review), not guessed.
- Parse `lib/src/rules/core/*.dart` the same way, tagged `origin="core"` — used only for collision
  checks, never proposed for rename.
- Record per rule: `id, aliases, file, pack, class_name`.

### 2. Compliance check (per id, not per file)

`pack_tokens = pack.split('_')`; an id is compliant iff `id.split('_')[:len(pack_tokens)] ==
pack_tokens`. Evaluated per-id, always — a file being "mostly compliant" never suppresses checking
an individual id, so the `avoid_app_links_sensitive_params` class of anomaly surfaces as its own
`needs-review` row instead of being silently swept in as compliant.

### 3. New-id derivation (token-aligned, not substring)

```python
def derive_new_id(id_, pack_tokens):
    id_tokens = id_.split('_')
    n = len(pack_tokens)
    positions = [i for i in range(len(id_tokens) - n + 1)
                 if id_tokens[i:i + n] == pack_tokens]
    if not positions:
        return None, "pack-token-not-found"          # manual naming required
    if len(positions) > 1:
        return None, "ambiguous-multiple-occurrences"  # manual pick required
    i = positions[0]
    rest = id_tokens[:i] + id_tokens[i + n:]
    if not rest:
        return None, "empty-after-removal"
    new_id = "_".join(pack_tokens + rest)
    return (id_, "already-compliant") if new_id == id_ else (new_id, "ok")
```

Token-aligned matching (list equality on `_`-split tokens, not substring search) is what prevents
a package token like `isar` from matching inside an unrelated longer token. Multi-word packs
(`device_calendar_plus`) are matched as one contiguous block. 0 or 2+ occurrences of the pack token
are never auto-resolved — always flagged for a human to pick.

### 4. Collision detection

Build one flat namespace map first:

```python
by_name: dict[str, list[Origin]] = defaultdict(list)
for r in all_rules:          # core + packages, ids AND aliases
    by_name[r.id].append(Origin(r, "canonical-id"))
    for a in r.aliases:
        by_name[a].append(Origin(r, "existing-alias"))
```

For every proposed `(old_id -> new_id)`, check and record ALL hits (not just first). Per the alias
ruling above, `new_id`-vs-`canonical-id` and `new_id`-vs-`existing-alias` are different severities:

1. `new_id` already live under `by_name` as another rule's **canonical-id** → hard `collision`
   (can't steal someone's actual id).
2. `new_id` already live under `by_name` as another rule's **existing-alias** → `alias-reassign`
   (not a blocker): report `detail="remove '<new_id>' from <owner_rule>'s configAliases"` as an
   actionable step for the implementation plan, per the ruling that the canonical id wins.
3. `new_id` was already proposed as another rule's `new_id` in this same batch → hard `collision`
   (dedup bug — exactly the class of bug `_buildRuleFactoriesMap()`'s silent overwrite currently hides).
4. `old_id` (which becomes a future `configAliases` entry) already exists elsewhere as an id or
   alias, of ANY kind (canonical or alias) → hard `collision` — the reverse case is never
   auto-resolved, since an id can't ambiguously alias two different rules.
5. `new_id` collides with `CORE_DART_LINT_NAMES` → hard `collision` — reuse the existing check by
   importing `scripts.modules._tier_integrity.CORE_DART_LINT_NAMES` directly (same import path
   `scripts/check_rule_name.py` already uses), don't reimplement.

As each rename is accepted, insert its `new_id` and `old_id`-as-future-alias into the same
`by_name` map before evaluating the next one, so within-batch collisions across different packs
are caught too.

### 5. Output

CSV: `old_id,new_id,pack,source_file,status,collision_detail`, `status ∈ {clean, alias-reassign,
needs-review, collision, already-compliant}`. Sort collisions first, then needs-review, then
alias-reassign, then pack — worst-first triage. Write to `scripts/output/rule_rename_audit.csv` (or similar — not committed, this is a
working artifact for the next planning pass).

## Explicitly out of scope for this plan

- Writing `configAliases`, doc comments, or `Formerly:` message prefixes.
- Editing `tiers.dart`, the YAML tier presets, generated files, extension TS lists, or test fixtures.
- Deciding the final naming scheme for `needs-review` rows — that's a human call informed by the
  report, done pack-by-pack in the actual rename plan.
- Designing the on-startup migration mechanism and the `CHANGELOG.md` BREAKING entry text — the
  Rulings section above locks in that these are required, but the mechanism itself (what runs at
  plugin startup, what it does when it finds an old id in a user's config) is designed in the
  next plan, once this audit's collision report is clean.

## Verification

- Run `python scripts/rule_rename_audit.py` and confirm it produces output without editing any
  `.dart`/`.yaml`/`.ts`/`.json` file (diff check: `git status` before/after must be identical
  except the new report file).
- Spot-check the report against known cases: `avoid_app_links_sensitive_params` must appear as
  `needs-review`/anomaly (not silently treated as compliant); a pack with zero non-compliant ids
  (e.g. `flutter_map`) must produce zero rows or all-`already-compliant` rows; `bloc`'s ~110 rules
  must all produce a `new_id` (report any that don't resolve as failures to investigate, not ignore).
- Manually review every `collision` and `needs-review` row before the next plan (the actual rename
  script) starts — those rows are the actual purpose of this tool.

## Critical files

- `scripts/rule_rename_audit.py` — new file, this plan's deliverable
- `scripts/gen_category_map.py` — regex pattern to mirror
- `scripts/check_rule_name.py` / `scripts/modules/_tier_integrity.py` — `CORE_DART_LINT_NAMES` import
- `lib/src/saropa_lint_rule.dart` — `configAliases` getter shape (line ~2491)
- `tool/generate_rule_pack_registry.dart` — pack→ruleCodes cross-check source
- `lib/src/rules/packages/app_links_rules.dart` — known anomaly case to validate against
