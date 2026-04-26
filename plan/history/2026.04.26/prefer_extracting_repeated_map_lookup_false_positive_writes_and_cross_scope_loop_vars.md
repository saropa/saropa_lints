# `prefer_extracting_repeated_map_lookup` — false positive: rule counts assignment writes (`map[key] = ...`) as lookups, and conflates the same `map[varName]` text across different scopes when the variable refers to different values

**Status:** Fixed (Unreleased)

Filed: 2026-04-26
Fixed: 2026-04-26
Rule: `prefer_extracting_repeated_map_lookup`
File: `lib/src/rules/config/sdk_migration_batch2_rules.dart` (line 1124, code at 1139–1185)
Severity: False positive (multiple flaws — write-counting + scope-blind text matching)
Rule version: v1 | Severity in code: INFO | Impact: low

---

## Resolution

Flaws A and B addressed in `_IndexExpressionCollector`:

- **Skip writes** — `if (node.inSetterContext()) return;` excludes both
  `map[k] = v` and compound forms like `map[k] += 1`. They cannot be hoisted
  into a local; the `[]=` operation must remain on the map.
- **Element-based bucketing** — bucket key changed from a source-text string
  to a `(targetFingerprint, indexFingerprint)` record. For variable indices
  and identifier targets the fingerprint is the resolved analyzer `Element`
  (compared by identity), so two `cache[uuid]` expressions in two different
  `for` loops — each declaring its own `uuid` — go into separate buckets and
  are no longer counted as repeated lookups of one. Literal indices still
  bucket by value (`('lit', 'timeout')` / `('int', '0')`).
- **Indices that cannot be resolved are not bucketed** rather than falling
  back to text — this preserves scope safety for the false-positive shapes
  the bug describes.

Flaw C (path-sensitivity) is **not** addressed in this change. The bug calls
it out as a longer-term improvement and notes that fixes A+B alone close
every false positive in the contacts project. Tracked here, not in a
separate file, so it is visible if a related case lands in future.

Fixture updated with all six false-positive guards from the bug
(`example/lib/sdk_migration_batch2/prefer_extracting_repeated_map_lookup_fixture.dart`).
The canonical positive case (3 reads of the same literal key) and a new
positive case (3 reads of a literal key interleaved with prints) remain.

---

## Summary

The rule's stated goal — "extract repeated `map[key]` lookups into a local variable" — is sound for the canonical case where a single function reads the same key three times in a row. The implementation, however, has two systemic flaws that produce false positives at high rates:

1. **Writes are counted as lookups.** `map[key] = value` (an `IndexExpression` on the left side of an assignment) is collected by the visitor identically to a read. Hoisting an assignment target into a local is impossible — the assignment must remain a `[]=` operator on the map. Sites where the only "duplicate access" is one read plus several writes are unfixable per the rule's own correction, yet the rule reports them anyway.

2. **Source-text matching ignores variable scope.** The collector uses `node.toSource()` (or equivalent) as the cluster key. So `cache[uuid]` in three separate `for` loops — each with its own `uuid` variable referencing a different value — is treated as three accesses to the same key. Different functions of the same uuid in different scopes are not the same lookup, but the rule cannot tell.

The combined effect: any function that does `map[loopVar] = value` inside several sequential loops (a common Drift / data-aggregation pattern) gets reported on the third loop forward, with no fix that satisfies the rule's correction message.

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_extracting_repeated_map_lookup'" lib/src/rules/
lib/src/rules/config/sdk_migration_batch2_rules.dart:1140:    'prefer_extracting_repeated_map_lookup',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/config/sdk_migration_batch2_rules.dart:1124` (`PreferExtractingRepeatedMapLookupRule`)
**Rule class:** `PreferExtractingRepeatedMapLookupRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

### Pattern A — writes counted as lookups (`activity_utils.dart:778`)

```dart
List<ActivityModel>? toMostRecentActivityType() {
  // …
  final Map<String, ActivityModel> mostRecentByKey = <String, ActivityModel>{};

  for (ActivityModel activity in this) {
    // …
    final ActivityModel? existing = mostRecentByKey[key];           // 1st: read into a local — already extracted!
    if (existing == null) {
      activity.isMostRecent = true;
      mostRecentByKey[key] = activity;                              // 2nd: WRITE
    } else {
      // …
      if (cmp == -1) {
        existing.isMostRecent = false;
        activity.isMostRecent = true;
        mostRecentByKey[key] = activity;                            // 3rd: WRITE  ← LINT — but should NOT lint
      } else {
        activity.isMostRecent = false;
      }
    }
  }
  // …
}
```

The function ALREADY extracts the read into a local (`existing`). The two remaining `mostRecentByKey[key]` references are assignment targets — they cannot be lifted into a local; they must remain `[]=` operations on the map. The rule's correction message does not apply, but the rule still fires.

### Pattern B — different loop variables conflated (`activity_drift_io.dart:695`)

```dart
Future<Map<String, String>> _buildDisplayNameCache() async {
  final Map<String, String> cache = <String, String>{};

  // results[0] / [1] / [2] are different result lists; each loop has its
  // own `uuid` declaration referring to a different value space.

  for (final OrganizationModel org in orgs) {
    final String? uuid = org.organizationSaropaUUID;                // org-side uuid
    if (uuid == null) continue;
    cache[uuid] = ...;                                              // 1st: cache[uuid]
  }

  for (final FamilyGroupModel family in families) {
    final String? uuid = family.familyGroupSaropaUUID;              // family-side uuid (different scope)
    if (uuid == null) continue;
    cache[uuid] = ...;                                              // 2nd: cache[uuid]
  }

  for (final ContactGroupModel group in groups) {
    final String? uuid = group.contactGroupSaropaUUID;              // group-side uuid (different scope)
    if (uuid == null) continue;
    cache[uuid] = ...;                                              // 3rd: cache[uuid] ← LINT — but should NOT lint
  }
  return cache;
}
```

The three `uuid` identifiers are independent local variables in three independent loop scopes. They are also all writes. The rule sees the textually identical `cache[uuid]` three times and flags the third — even though no single value of `uuid` is accessed more than once.

### Pattern C — read inside one loop + write inside another loop (`activity_drift_io.dart:1432-1443`)

```dart
Future<Map<String, QuickLaunchActivitySummary>> dbActivitySummaryForContacts({
  required List<String> contactUUIDs,
}) async {
  // …
  final Map<String, int> counts = <String, int>{};
  // …

  for (final ActivityDBModel activity in activities) {
    final String? uuid = activity.contactSaropaUUID;                  // activity-loop uuid
    if (uuid == null) continue;
    counts[uuid] = (counts[uuid] ?? 0) + 1;                           // read + write of activity-loop uuid (2 occurrences)
    // …
  }

  // …

  for (final String uuid in contactUUIDs) {                           // contactUUIDs-loop uuid (different scope)
    final int count = counts[uuid] ?? 0;                              // ← LINT — but should NOT lint (3rd `counts[uuid]` text, but DIFFERENT uuid scope)
    // …
  }
}
```

The first loop reads/writes `counts[uuid]` for an `activity.contactSaropaUUID`-derived uuid. The second loop uses a completely different `uuid` from `contactUUIDs`. Same text `counts[uuid]`, different values, different scopes. Rule cannot tell.

**Frequency:** Always — any function that uses `map[loopVar]` in three or more loops, OR mixes a read with multiple writes of the same map[key].

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | The rule fires only when 3+ **reads** of the same `map[key]` exist in a single execution path with the **same value of `key`**. Writes (`map[key] = value`) are not counted. Loop variables and other shadowed identifiers in different scopes are not conflated. |
| **Actual** | All `IndexExpression` occurrences with the same source-text fingerprint are pooled into one cluster regardless of read/write or scope. The rule reports at the third occurrence even when no extraction would be valid or beneficial. |

---

## AST Context

```
ForStatement
  └─ Block
      ├─ VariableDeclarationStatement (uuid₁)
      ├─ AssignmentExpression
      │   ├─ leftHandSide: IndexExpression (cache[uuid₁])      ← collected as `cache[uuid]` (write)
      │   └─ rightHandSide: ...

ForStatement
  └─ Block
      ├─ VariableDeclarationStatement (uuid₂)                  ← DIFFERENT scope, different value
      ├─ AssignmentExpression
      │   ├─ leftHandSide: IndexExpression (cache[uuid₂])      ← collected as `cache[uuid]` (write — same text, different identity)
      │   └─ rightHandSide: ...
```

The rule's collector at `sdk_migration_batch2_rules.dart:1187–…`:

```dart
class _IndexExpressionCollector extends RecursiveAstVisitor<void> {
  // …
  @override
  void visitIndexExpression(IndexExpression node) {
    super.visitIndexExpression(node);
    // Normalize to source text and bucket all occurrences together.
    // No check for `node.inSetterContext()` (write) vs. read.
    // No check for the resolved Element of the key identifier
    // (so `uuid` from one loop and `uuid` from another are treated identically).
    // …
  }
}
```

---

## Root Cause

### Flaw A: writes are not excluded

The visitor records every `IndexExpression`, including those on the left-hand side of an assignment. `IndexExpression.inSetterContext()` returns true for those — easy to filter:

```dart
@override
void visitIndexExpression(IndexExpression node) {
  super.visitIndexExpression(node);
  if (node.inSetterContext()) return;  // writes can't be hoisted
  // …
}
```

### Flaw B: source-text matching conflates scoped names

`cache[uuid]` in two different loops textually matches but resolves to different identifiers. Replace source-text bucketing with element-based bucketing:

- Bucket key = `(target.staticElement.location, key.staticElement.location)` rather than `node.toSource()`.
- For literal keys (e.g. `json['country.id']`), the key is constant and the existing text fingerprint is fine.
- For variable keys (e.g. `cache[uuid]`), require that the resolved `Element` of the key identifier is identical across all bucketed occurrences. Different `uuid` declarations in different scopes resolve to different `Element` instances and therefore go into separate buckets.

### Flaw C: no path-sensitivity

Even after Flaws A and B are fixed, the rule still does not check whether the multiple read accesses are reachable on the same execution path. Two reads in two different `if`-branches that never both execute are not "repeated" in any meaningful sense. This is a known difficult problem (path-sensitive analysis); the cheap conservative approach is to require the accesses to be in the same `Block` with no early-return between them. That closes another large class of false positives.

---

## Suggested Fix

Three layered fixes:

1. **Skip writes** (1-line change in the visitor — see Flaw A).
2. **Element-based bucketing for variable keys** (5-line change — see Flaw B).
3. **Optional: same-block, no-early-return guard** (10-20 lines for path sensitivity).

Fixes 1+2 together close every false positive in the contacts project. Fix 3 is a longer-term improvement.

---

## Fixture Gap

The fixture should include:

1. **Three sequential reads of `config['timeout']`** — expect LINT on 3rd (canonical case)
2. **Three writes `cache[k] = v`** in a function — expect NO lint *(currently false positive — writes counted)*
3. **Read into local + 2 writes** (`final v = m[k]; m[k] = a; m[k] = b;`) — expect NO lint *(currently false positive)*
4. **`map[loopVarA]`, `map[loopVarB]`, `map[loopVarC]`** in three different loops, each declaring its own loop variable — expect NO lint *(currently false positive)*
5. **`map['literal']`, `map['literal']`, `map['literal']`** with same literal key — expect LINT (text matching is correct here)
6. **`mapA[k]`, `mapB[k]`, `mapC[k]`** — expect NO lint (different maps)
7. **Two reads of `m[k]` in different `if` branches that cannot both execute** — judgement call: probably NO lint (path-sensitivity)

Cases 2, 3, 4 are the contacts cases.

---

## Downstream

Tracked in `contacts/`. Until the upstream fix lands:

- 3 sites get per-site `// ignore: prefer_extracting_repeated_map_lookup -- …` directives (Pattern A and Pattern B occurrences in `activity_utils.dart`, `activity_drift_io.dart` × 2).
- 1 site (`country_city_model.dart` — Pattern that *is* a real cleanup opportunity, where 3 literal-key lookups appear in two different debug blocks) gets a real fix: lift `json['country.id']`, `json['country.code']`, `json['country.name']` into locals at the top of the factory and reference the locals in the debug strings.

---

## Environment

- saropa_lints version: 12.5.1+
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
