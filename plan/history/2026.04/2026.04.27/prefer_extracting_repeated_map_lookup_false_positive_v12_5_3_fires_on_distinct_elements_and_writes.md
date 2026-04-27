# BUG: `prefer_extracting_repeated_map_lookup` — consolidated report (distinct elements + write contexts + consumer-only reproductions)

**Status: Closed** (fix landed on `main`; shipped for users as **v12.5.4** per [CHANGELOG.md](../../../../CHANGELOG.md) § [12.5.4]. Consumer should **upgrade** past 12.5.3 and re-run `dart analyze` on the reproducer files; remove temporary `// ignore:` once clean.)

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-27
Rule: `prefer_extracting_repeated_map_lookup`
File: `lib/src/rules/config/sdk_migration_batch2_rules.dart` (rule at line 1133, collector at line 1219, `inSetterContext()` skip at line 1231, element-aware bucketing at line 1242–1247)
Severity: False positive (high — same-name shadowing and write skip BOTH appear to be inactive in the published v12.5.3 the consumer actually resolves)
Rule version: v1 | Since: v10.10.0 | Updated: v12.5.3

---

## Summary

Two new failure modes observed in `d:\src\contacts` (which has `saropa_lints: 12.5.3` pinned in `pubspec.lock`):

1. **Variable shadowing flagged on declaration line.** A function-scope local that shadows the function parameter triggers the rule even though the inner local has its own distinct `LocalVariableElement` and there is no `IndexExpression` on the flagged line — only a `PropertyAccess` (`firstGroup?.contactSaropaUUIDs`).
2. **Same-name loop variables in sibling scopes still conflate.** Two `for-in` loops, each with its own `final ContactModel? contact = …`, write to `contactIndustryMap[contact]` in their respective scopes. The v12.5.3 element-aware bucketing should put these in different buckets (different `LocalVariableElement`s), and the v12.5.3 `inSetterContext()` skip should drop the writes entirely. Both writes still get reported.

Both behaviors contradict what `_IndexExpressionCollector` is documented (and visibly coded) to do at HEAD. Either the published v12.5.3 build does not contain those guards, the analyzer's element resolution returns `null` for these sites in the consumer environment, or the published rule is structurally different from `lib/src/rules/config/sdk_migration_batch2_rules.dart` at HEAD.

This is now the canonical merged report. It supersedes the narrower write-only note:
[`prefer_extracting_repeated_map_lookup_false_positive_writes_still_counted_after_v12_5_3_fix.md`](./prefer_extracting_repeated_map_lookup_false_positive_writes_still_counted_after_v12_5_3_fix.md).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ cd D:/src/saropa_lints && grep -rn "'prefer_extracting_repeated_map_lookup'" lib/src/rules/
lib/src/rules/config/sdk_migration_batch2_rules.dart:1149:    'prefer_extracting_repeated_map_lookup',

# Class registration
$ grep -rn "PreferExtractingRepeatedMapLookup" lib/
lib/saropa_lints.dart:2860:  PreferExtractingRepeatedMapLookupRule.new,
lib/src/rules/config/sdk_migration_batch2_rules.dart:1133:class PreferExtractingRepeatedMapLookupRule extends SaropaLintRule {
```

**Emitter registration:** `lib/src/rules/config/sdk_migration_batch2_rules.dart:1149`
**Rule class:** `PreferExtractingRepeatedMapLookupRule` — registered in `lib/saropa_lints.dart:2860`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#2` (consumer's IDE)

**Consumer pinned version (proves attribution by version, not just label):**

```
$ grep -A 5 "name: saropa_lints" d:/src/contacts/pubspec.lock
      name: saropa_lints
      sha256: "47fbcf421f3fa778c9d9ba45d2dccea9a9b07b6b02ab8c43ea5b4be354b4b9f0"
      url: "https://pub.dev"
    source: hosted
    version: "12.5.3"
```

---

## Reproducer A — Variable shadowing flagged on a declaration line that contains no `IndexExpression`

Real code from `d:\src\contacts\lib\database\drift_middleware\maintenance\contact_group_admin_io.dart`, function `dbContactGroupClean`:

```dart
static Future<bool> dbContactGroupClean({
  List<String>? contactSaropaUUIDs,                                    // ← parameter
}) async {
  try {
    // ... ~35 lines of unrelated work ...

    if (contactGroups.length == 1) {
      final ContactGroupModel? firstGroup = contactGroups.firstOrNull;
      if (firstGroup?.contactGroupSaropaUUID ==
          SaropaSystemContactGroupUtils.systemContactGroupUUID) {
        // LINT — false positive — flagged at column 11-27 ("final List<String") with code
        //        `prefer_extracting_repeated_map_lookup`. There is NO `IndexExpression`
        //        on this line — the RHS is `firstGroup?.contactSaropaUUIDs`, a
        //        `PropertyAccess` on a class instance. The inner local also has its own
        //        `LocalVariableElement` distinct from the function parameter on line 1.
        final List<String>? contactSaropaUUIDs = firstGroup?.contactSaropaUUIDs;
        if (contactSaropaUUIDs?.length == 1 &&
            contactSaropaUUIDs?.firstOrNull == SaropaSystemContactUtils.systemContactUUID) {
          return true;
        }
      }
    }

    contactSaropaUUIDs ??= await DatabaseContactIO.dbContactLoadAllRawUUIDs();   // back to parameter
    if (contactSaropaUUIDs == null || contactSaropaUUIDs.isEmpty) return false;
    // ... function continues using parameter — no `[]` operator on `contactSaropaUUIDs` anywhere ...
  } on Object catch (error, stack) {
    debugException(error, stack);
    return false;
  }
}
```

**Note:** I grep-confirmed that `contactSaropaUUIDs[…]` (indexed access) does NOT appear anywhere in this function body. Every access is either a property/method call (`.length`, `.firstOrNull`, `.contains(…)`, `.where(…)`) or assignment (`??=`). The rule's collector visits `IndexExpression` nodes, so it should never have anything to bucket here. Yet a `prefer_extracting_repeated_map_lookup` diagnostic is emitted at the variable declaration line.

**Frequency:** Always — reproduces every time this file is analyzed.

---

## Reproducer B — Same-name loop variable in sibling scopes; writes still counted

Real code from `d:\src\contacts\lib\utils\contact_group\contact_group_industry_utils.dart`:

```dart
static Future<List<ContactGroupModel>?> _resolveContactGroups({
  required List<ContactModel> contacts,
  // ...
}) async {
  try {
    // ...
    final Map<ContactModel, List<IndustryTypeEnum>> contactIndustryMap =
        <ContactModel, List<IndustryTypeEnum>>{};

    // Outer loop A — `contact` is a `for-in` loop variable here
    for (ContactModel contact in contacts) {
      final List<IndustryTypeEnum>? types = _findIndustryTypes(contact: contact);
      if (types != null) {
        contactIndustryMap[contact] = types;                              // WRITE — distinct LocalVariableElement A
      }
    }

    // ... unrelated work ...

    if (orgTypes != null && orgTypes.isNotEmpty) {
      for (MapEntry<…> orgType in orgTypes.entries) {
        // ...
        for (String contactUUID in orgType.key.contactSaropaUUIDs!) {
          // Inner loop B — `contact` here is a NEW LocalVariableElement
          // (declared via `firstWhereOrNull` on a fresh line)
          final ContactModel? contact = contacts.firstWhereOrNull(
            (ContactModel contact) => contact.contactSaropaUUID == contactUUID,
          );
          if (contact == null) continue;

          final List<IndustryTypeEnum>? types = contactIndustryMap[contact];   // READ — element B
          if (types != null) {
            orgType.value.addAll(types);
          }

          contactIndustryMap[contact] = orgType.value.toUnique();              // LINT (false positive)
        }
      }
    }
  } on Object catch (error, stack) {
    debugException(error, stack);
  }
}
```

In the function body `contactIndustryMap[contact]` appears 3 times:

| Line | Form | Kind | `contact` element |
|------|------|------|-------------------|
| 62  | `contactIndustryMap[contact] = types;`              | write | loop A |
| 95  | `final List<IndustryTypeEnum>? types = contactIndustryMap[contact];` | read  | loop B (different) |
| 102 | `contactIndustryMap[contact] = orgType.value.toUnique();` | write | loop B (different) |

After the v12.5.3 fix, the bucket population should be:
- Lines 62 and 102: skipped via `inSetterContext()` → not added.
- Line 95: added with key `(contactIndustryMap-element, loop-B-contact-element)`.
- Final bucket count: **1** — well below the threshold of 3.

Yet the rule fires on line 102 (the second write).

**Frequency:** Always — reproduces every time this file is analyzed.

---

## Expected vs Actual

| Site | Expected | Actual |
|------|----------|--------|
| `contact_group_admin_io.dart` declaration line | No diagnostic — no `IndexExpression` exists on this line | `[prefer_extracting_repeated_map_lookup]` reported at col 11-27 |
| `contact_group_industry_utils.dart` line 102 (write) | No diagnostic — write skipped via `inSetterContext()` | `[prefer_extracting_repeated_map_lookup]` reported at col 13-40 |

Reading the rule source at HEAD (line 1231 `if (node.inSetterContext()) return;` + line 1242–1247 element-aware bucketing) **both diagnostics should be impossible**. They happen anyway.

---

## AST Context

### Reproducer A

```
MethodDeclaration (dbContactGroupClean)
  └─ FormalParameterList
  │   └─ DefaultFormalParameter
  │       └─ SimpleFormalParameter
  │           └─ ... `contactSaropaUUIDs` (parameter LocalVariableElement P)
  └─ BlockFunctionBody
      └─ Block
          └─ TryStatement
              └─ Block
                  └─ IfStatement (contactGroups.length == 1)
                      └─ Block
                          ├─ VariableDeclarationStatement
                          │   └─ ... `firstGroup`
                          └─ IfStatement (firstGroup?.contactGroupSaropaUUID == ...)
                              └─ Block
                                  └─ VariableDeclarationStatement              ← reported here
                                      └─ VariableDeclaration (`contactSaropaUUIDs`, LocalVariableElement L)
                                          └─ PropertyAccess (`firstGroup?.contactSaropaUUIDs`)  ← NO IndexExpression
```

There is no `IndexExpression` anywhere on this declaration. The `_IndexExpressionCollector.visitIndexExpression` callback should never fire for this AST shape.

### Reproducer B

```
MethodDeclaration (_resolveContactGroups)
  └─ BlockFunctionBody
      └─ Block
          └─ TryStatement
              └─ Block
                  ├─ ... contactIndustryMap declaration
                  ├─ ForStatement (outer loop A — `contact` LocalVariableElement A)
                  │   └─ Block
                  │       └─ IfStatement
                  │           └─ Block
                  │               └─ ExpressionStatement
                  │                   └─ AssignmentExpression  ('=')
                  │                       └─ IndexExpression (contactIndustryMap[contact])  ← WRITE — element A
                  └─ ForStatement (loop over orgTypes.entries)
                      └─ Block
                          └─ ForStatement (inner loop B — `contact` LocalVariableElement B)
                              └─ Block
                                  ├─ VariableDeclarationStatement
                                  │   └─ VariableDeclaration (`types`)
                                  │       └─ IndexExpression (contactIndustryMap[contact])  ← READ — element B
                                  └─ ExpressionStatement
                                      └─ AssignmentExpression  ('=')
                                          └─ IndexExpression (contactIndustryMap[contact])  ← WRITE — element B  ← REPORTED
```

The two `IndexExpression`s under loop A vs loop B reference the same `contactIndustryMap` (element identity X) but two distinct `contact` `LocalVariableElement`s (A vs B). Element-aware bucketing should produce two separate buckets `(X, A)` and `(X, B)`, with the writes filtered out before bucketing. Yet a single-bucket-with-3-occurrences result is being computed somehow.

---

## Root Cause

### Hypothesis A: Published v12.5.3 build differs from source at HEAD

The rule source visible in `D:\src\saropa_lints\lib\src\rules\config\sdk_migration_batch2_rules.dart` already has both fixes (`inSetterContext()` skip line 1231, element-aware bucketing line 1242–1247). The previous investigation bug also confirmed `dart test` passes in-repo. Two possibilities:

- v12.5.3 was published before those fixes landed in source, and HEAD is ahead of pub.dev.
- The pub.dev artifact `47fbcf421f3fa778c9d9ba45d2dccea9a9b07b6b02ab8c43ea5b4be354b4b9f0` was built from a branch that does not contain the fixes.

**To check:** unpack `~/.pub-cache/hosted/pub.dev/saropa_lints-12.5.3/lib/src/rules/config/sdk_migration_batch2_rules.dart` and grep for `inSetterContext` and the element-aware bucketing comment. If absent, the publish is stale and a re-publish under v12.5.4 closes this immediately.

### Hypothesis B: Element resolution returns `null` in the consumer

If `target.element` (line 1283 of HEAD source) returns `null` for `contactIndustryMap` in the consumer's analyzer environment — perhaps because the consumer-side analyzer can't resolve the `Map<…>` type, or because the element comes through an extension/getter chain that the consumer's resolver collapses differently — the code falls through to `('text', target.toSource())` (line 1286). That fallback is exactly the textual bucketing that re-introduces the cross-scope conflation.

Reproducer A's odd "diagnostic on a line with no IndexExpression" claim could be explained the same way: the diagnostic anchor reports at the `nodes[i]`'s `offset`, but if the visitor traversed a synthetic / forwarding node and the offset points at the parent `VariableDeclaration` rather than the inner `IndexExpression`, it would visually land on the declaration line. (Or — the IDE's diagnostic line/column values are stale, the modelVersionId notwithstanding. Both happen.)

**To check:** add a stage-1 logging build of the rule that emits `target.element?.runtimeType` and `targetFingerprint.runtimeType` to a side-channel and run it against the consumer. If the fingerprints are tuples of `('text', 'contactIndustryMap')`, hypothesis B is confirmed.

### Hypothesis C: A second visitor pass that's not in the source we read

Long-shot — there could be a second visitor or a base-class visitor that contributes nodes to the same `lookupCounts` map without going through the setter-context check. Worth a grep for `_lookups.putIfAbsent` outside `_IndexExpressionCollector`.

---

## Implemented Fix

Implemented in `lib/src/rules/config/sdk_migration_batch2_rules.dart`:

1. Added a **defensive structural write-context guard** (`_isWriteContext`) so assignment/compound/prefix/postfix write-backs are skipped even if `inSetterContext()` behaves unexpectedly in consumer analyzer environments.
2. Restricted collection to **map-like targets only** (`_isMapLikeTarget`) to align behavior with lint intent/message and avoid non-map indexable noise.
3. Removed target source-text fallback for bucketing and switched to **resolved-element-only target fingerprints**; unresolved targets are now skipped instead of text-bucketed.

These changes bias toward avoiding false positives in ambiguous resolution states.

---

## Fixture Coverage

Added/updated fixture coverage in `example/lib/sdk_migration_batch2/prefer_extracting_repeated_map_lookup_fixture.dart`:

- `goodSwipeLikeReadThenWrites` (mirrors contacts swipe-loop/index-mutation write pattern)
- `goodInnerLocalShadowsParameter` (parameter shadowing declaration line case)
- `goodSameNameLoopVarsInSiblingScopes` (sibling-scope same-name variables + read/write mix)

---

## Changes Made

- Consolidated investigation scope into this single report.
- Implemented collector hardening in `sdk_migration_batch2_rules.dart`.
- Added regression guard fixtures for the three consumer-reported shapes.

---

## Tests Added

- Fixture-only regression coverage in `example/lib/sdk_migration_batch2/prefer_extracting_repeated_map_lookup_fixture.dart`.
- Local `dart test` pass after changes.

---

## Commits

- `b90b1df4` — fix: tighten `prefer_extracting_repeated_map_lookup` bucketing (writes, map-like targets, resolved target fingerprints) + fixture updates.
- Related release notes: CHANGELOG **[12.5.4]** (`prefer_extracting_repeated_map_lookup` bullet under **Fixed**).

---

## Environment

- saropa_lints version: 12.5.3 (pinned in `d:\src\contacts\pubspec.lock`, sha256 `47fbcf421f3fa778c9d9ba45d2dccea9a9b07b6b02ab8c43ea5b4be354b4b9f0`)
- Triggering project: `d:\src\contacts`
- Triggering files:
  - `lib/database/drift_middleware/maintenance/contact_group_admin_io.dart` (function `dbContactGroupClean`, lines 202-298 in current version) — diagnostic at line 242:11-27 (note: line numbers shift by ±1 with edits; ignore comment placement around the declaration)
  - `lib/utils/contact_group/contact_group_industry_utils.dart` (function `_resolveContactGroups`) — diagnostic at line 102:13-40
- Suppressions added in consumer (per-site `// ignore:` with `--` rationale) — **remove after upgrading to ≥12.5.4** once `dart analyze` is clean.
- Related superseded note (same folder, if present elsewhere): `prefer_extracting_repeated_map_lookup_false_positive_writes_still_counted_after_v12_5_3_fix.md` — consolidated into this report; closure applies to merged scope.
- Prior history: `plan/history/2026.04/2026.04.26/prefer_extracting_repeated_map_lookup_false_positive_writes_and_cross_scope_loop_vars.md` (closed in v12.5.3)
