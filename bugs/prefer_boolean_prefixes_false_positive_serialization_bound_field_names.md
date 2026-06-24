# BUG: `prefer_boolean_prefixes` — fires on fields whose name is bound to a serialization / schema contract

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-24
Rule: `prefer_boolean_prefixes`
File: `lib/src/rules/core/naming_style_rules.dart` (class `PreferBooleanPrefixesRule`, line 682; id registered line 699)
Severity: False positive — Medium (forces a schema migration or a `// ignore:` on a field that is not free to rename)
Rule version: v7

---

## Summary

`prefer_boolean_prefixes` flags `bool` class fields whose *name is an external
persistence / serialization key* — Isar schema property names, Drift column-mapped
fields, `@JsonKey`-bound fields. For these, the Dart identifier is not free to change:
renaming `bool deleted` to `bool isDeleted` renames the stored property/column and
breaks already-persisted data unless a migration runs. A pure naming-convention lint
should not demand a rename of a field whose name is a stored contract, the same way the
rule already whitelists the framework-mandated `value` (Checkbox/Switch/Radio).

The rule has no exemption for this case: it checks every `bool` field declaration and
only skips the exact name `value` plus the prefix/suffix whitelist.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'prefer_boolean_prefixes'" lib/src/rules/
lib/src/rules/core/naming_style_rules.dart:699:    'prefer_boolean_prefixes',

# Negative — NOT in sibling repos
$ grep -rn "'prefer_boolean_prefixes'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
0 matches in sibling repos
```

**Emitter registration:** `lib/src/rules/core/naming_style_rules.dart:699`
**Rule class:** `PreferBooleanPrefixesRule` — `naming_style_rules.dart:682`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints analyzer plugin)

Note: the sibling field/local/param variants (`PreferBooleanPrefixesForLocalsRule` :893,
`PreferBooleanPrefixesForParamsRule` :1079) share the same gap but only the
field-checking `PreferBooleanPrefixesRule` reaches persisted fields, so the fix targets it.

---

## Reproducer

```dart
import 'package:isar/isar.dart';

@collection
class ContactDBModel {
  // The field name `familyNameFirstOverride` IS the stored Isar property name.
  // Renaming it to `isFamilyNameFirstOverride` renames the persisted property
  // and requires a schema migration of every stored row.
  bool? familyNameFirstOverride;   // LINT — but should NOT (name is a storage contract)
}

class VersionPolicyModel {
  VersionPolicyModel.fromJson(Map<String, dynamic> json)
      : forceUpgrade = json['force_upgrade'] as bool;   // value comes from a wire key

  // The field name is read by code keyed on the JSON contract.
  final bool forceUpgrade;          // LINT — renaming desyncs from the wire key
}

class C {
  bool _resolved = false;           // LINT — and CORRECT to flag: private runtime flag,
                                    // freely renamable, not a storage contract. True positive.
}
```

**Frequency:** Always, on any unprefixed `bool` field — including persisted ones the rule
cannot distinguish from ordinary state.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the field name is bound to a serialization/schema contract (Isar `@collection`/`@embedded` property, Drift column-mapped field, `@JsonKey`/`fromJson`-keyed field). Still flag ordinary private/state booleans. |
| **Actual** | `[prefer_boolean_prefixes] Boolean variable must have a prefix ...` reported on the persisted field; the only way to silence is a storage-breaking rename or a per-site `// ignore:`. |

---

## AST Context

```
ClassDeclaration (ContactDBModel)   ← carries @collection metadata
  └─ FieldDeclaration
      └─ VariableDeclarationList (type: bool?)
          └─ VariableDeclaration (familyNameFirstOverride)  ← node reported here
```

The rule's `addFieldDeclaration` callback (`naming_style_rules.dart:791`) reports on the
`VariableDeclaration` without inspecting the enclosing class's annotations or the field's
own annotations.

---

## Root Cause

`PreferBooleanPrefixesRule.runWithReporter` (`naming_style_rules.dart:786–826`) checks the
type is `bool`, strips a leading underscore, and reports unless `_hasValidBooleanName`
passes. `_hasValidBooleanName` only allows the exact name `value` plus the
prefix/suffix whitelist (`_allowedExactNames` :833, `_validPrefixes` :713, `_validSuffixes`
:770). There is:

- no check of the enclosing `ClassDeclaration` annotations (`@collection`, `@embedded`,
  `@DataClassName`, Drift table-row markers),
- no check of the field's own annotations (`@JsonKey`, `@ignore` inverse — i.e. persisted),
- no generated-file / DTO-path skip.

So a field whose name is a stored contract is indistinguishable, to the rule, from a
freely-renamable private flag.

---

## Suggested Fix

Add an exemption when the field's name is contract-bound. Lowest-risk options, in order:

1. **Annotation-based skip (preferred):** if the enclosing class carries a persistence
   annotation (`@collection`, `@embedded`, `@DataClassName`, or a Drift `DataClass`
   supertype) **or** the field carries `@JsonKey`, skip the field. This is precise and
   needs no path config.
2. **Field-annotation skip:** skip any `bool` field annotated `@JsonKey(...)`.
3. **Config escape hatch:** a rule option (e.g. `exemptAnnotatedClasses`) listing
   annotation names whose fields are skipped, defaulting to the persistence set above.

Do NOT broaden to "skip all private fields" — private runtime flags like
`bool _resolved` are genuine true positives and should keep flagging.

Downstream note (Saropa Contacts): the private state flags surfaced alongside these
(`_contactTypeResolved`, `_religionResolved`, `_religionPracticingResolved`,
`_focusModesResolved`, `_bundledDbWasCopied`) are being renamed in-tree as true
positives; only the persisted/serialized field names depend on this exemption.

---

## Fixture Gap

The fixture at `example*/lib/core/prefer_boolean_prefixes_fixture.dart` should include:

1. `bool deleted;` inside an `@collection`-annotated class — expect NO lint.
2. `final bool forceUpgrade;` with a sibling `fromJson` keyed on `'force_upgrade'`, or a
   `@JsonKey`-annotated `bool` field — expect NO lint.
3. `bool _resolved = false;` inside a plain class — expect LINT (true positive preserved).
4. `bool enabled = true;` inside a plain widget/state class — expect LINT (unchanged).

---

## Environment

- saropa_lints version: current `main`, rule `prefer_boolean_prefixes` {v7}
- Triggering project: Saropa Contacts (`d:\src\contacts`) — 113 `prefer_boolean_prefixes`
  hits in `bugs/issue_shrink_wrap.log`; the database-layer subset
  (`contact_db_model.dart`, `contact_group_db_model.dart`, `drift_database.dart`,
  `version_policy_model.dart`, `release_notes_catalog.dart`) is what this report covers.
