# PROPOSAL: Flag `json_serializable` Enum Fields Missing `unknownEnumValue` Fallback

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `specify_unknown_enum_value` to flag an enum-typed field inside a `@JsonSerializable()`-annotated class that has no `unknownEnumValue` configured on its `@JsonKey`/`@JsonEnum` annotation. Without this fallback, a JSON payload containing an enum string the client hasn't shipped support for yet (a new value added server-side) throws during deserialization instead of degrading gracefully.

**Closes gap:** dart_code_metrics_presets `specify-unknown-enum-value` (github.com/CQLabs/dart-code-metrics-presets, `json_serializable.yaml` preset). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`json_serializable` lets an enum field declare `@JsonKey(unknownEnumValue: MyEnum.unknown)` (or a class-level `@JsonEnum(unknownEnumValue: ...)`) so that when the backend sends an enum string not present in the generated `_$MyEnumEnumMap`, deserialization falls back to the configured sentinel value instead of throwing a `CheckedFromJsonException`. This is a classic forward-compatibility gap: backend teams routinely add new enum values ahead of client releases, and a client without this fallback crashes on any payload carrying the new value — for enums as innocuous as an app-wide "notification type" or "status" field, this can crash the app open on the home screen. Nothing in saropa today looks at `json_serializable` enum wiring specifically; this is genuinely new territory (verified via `Grep` for `unknownEnumValue`/`JsonEnum`/`JsonKey` across `lib/src/rules/` — no existing coverage).

---

## Detection / Behavior

Flag an enum-typed field declared inside a class annotated `@JsonSerializable()` (or `@JsonSerializable(explicitToJson: true)`, any argument variant) when that field's `@JsonKey(...)` annotation (if present) has no `unknownEnumValue:` argument, AND the enclosing class has no class-level `@JsonEnum(unknownEnumValue: ...)` covering the same enum type. A field with no `@JsonKey` at all is also flagged — it has no annotation site to carry the fallback, so it's the most exposed case.

### Should flag (bad code)

```dart
enum NotificationType { message, reminder, promo }

@JsonSerializable()
class NotificationPayload {
  // LINT — enum field has no unknownEnumValue fallback; a new backend value
  // (e.g. "digest") crashes deserialization instead of degrading gracefully.
  final NotificationType type;

  NotificationPayload(this.type);

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);
}
```

### Should pass (good code)

```dart
enum NotificationType { message, reminder, promo, unknown }

@JsonSerializable()
class NotificationPayload {
  // OK — unrecognized backend values fall back to NotificationType.unknown
  // instead of throwing.
  @JsonKey(unknownEnumValue: NotificationType.unknown)
  final NotificationType type;

  NotificationPayload(this.type);

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Depends on the `json_serializable` package's annotation API (`@JsonSerializable`, `@JsonKey`, `@JsonEnum`) — this is a niche, package-specific rule, not a general-purpose correctness check. Projects that don't use `json_serializable` for enum decoding get zero value from it. Comprehensive/opt-in matches saropa's placement for other single-package-dependent rules.

---

## Edge Cases

1. **Enum field on a class with no `fromJson` factory / not actually round-tripped through JSON** — should pass; only classes carrying `@JsonSerializable()` (or a class-level `@JsonEnum`) are in scope, since those are the only ones that generate a `.fromJson` decoder that can throw on an unrecognized value.
2. **Enum field marked `@JsonKey(ignore: true)` or `includeFromJson: false`** — should pass; the field is never populated from JSON, so no fallback is needed.
3. **Nullable enum field (`NotificationType?`)** — should still flag if `unknownEnumValue` is absent; nullability does not by itself provide a decode fallback unless `json_serializable`'s default (returning `null` for unrecognized values on a nullable field with no explicit `unknownEnumValue`) is judged intentional. Note for implementation: `json_serializable` treats a nullable enum with no `unknownEnumValue` as "unrecognized value decodes to `null`" — flag anyway with a distinct correction message suggesting either an explicit `unknownEnumValue` or a deliberate `// ignore:` if `null` is the intended fallback, since silent `null` can still surprise downstream non-null-aware code.
4. **List<EnumType> / Map<String, EnumType> fields** — should flag the same way; `json_serializable` supports `unknownEnumValue` on collection-typed enum fields identically.
5. **Enum declared without any non-sentinel members that could serve as a safe fallback (e.g. every member is meaningful, no natural "unknown" value)** — should still flag; the correction message should suggest adding an `unknown`/`unrecognized` member to the enum as the target for `unknownEnumValue`, not skip the diagnostic.

---

## Alternatives Considered

- **Only flag class-level `@JsonEnum` classes, skip per-field `@JsonKey`** — rejected; per-field `@JsonKey(unknownEnumValue: ...)` is the more common idiom in real `json_serializable` codebases and is where the gap most often appears.
- **Quick fix that adds `unknownEnumValue: EnumType.values.first`** — considered but risky: picking an arbitrary existing member as the "unknown" fallback can silently misrepresent real data (e.g. falling back to `NotificationType.message` for an actually-unrecognized type). Prefer no auto-fix, or a fix that only fires when the enum already has an `unknown`/`unrecognized`-named member to target.

---

## Decision

---

## Implementation Notes

---

## Commits

## Finish Report (2026-09-04)

### Issues

- **`createFactory: false` false positive.** `_hasAnnotation(enclosingClass.metadata, 'JsonSerializable')` (rule file, line 138-141) checks only for the annotation's presence, never its arguments. `@JsonSerializable(createFactory: false)` (toJson-only codegen, no `fromJson`/decoder generated at all) still puts the class "in scope," so a field with no `unknownEnumValue` is flagged even though there is no decode path that can ever throw. Fix: read the `createFactory` named argument off the `@JsonSerializable` annotation the same way `_hasNamedArgument`/`_namedBoolArgumentEquals` already do for `@JsonKey`, and bail out when it is explicitly `false`.
- **Custom `fromJson:` converter false positive.** `@JsonKey(fromJson: myEnumFromJson)` routes decoding through a hand-written function instead of the generated `_$MyEnumEnumMap` lookup — `unknownEnumValue` is inapplicable (json_serializable ignores it when a custom `fromJson` converter is present) and any unknown-value handling lives inside that function. The rule's `jsonKey != null` branch (lines 166-170) checks `ignore`, `includeFromJson`, and `unknownEnumValue` but never `fromJson`, so this is flagged as a false positive. Fix: add `if (_hasNamedArgument(jsonKey, 'fromJson')) return;` alongside the existing early-outs.
- **Prefixed annotation imports are a false negative.** `_findAnnotation` matches via `annotation.name.name == name` (line 183). For `@json.JsonSerializable()` (a `PrefixedIdentifier`, common when `json_annotation` is imported with a prefix), `Identifier.name` returns the full `"json.JsonSerializable"` string, which never equals the bare `'JsonSerializable'`/`'JsonKey'`/`'JsonEnum'` literals compared against — the class is silently treated as out of scope and no field inside it is ever flagged. Not tested; not mentioned as a known limitation in the doc comment.

### Concerns

- **Class-level `@JsonEnum` without `@JsonSerializable()` is out of scope, contrary to the proposal text.** Proposal edge case 1 (and the rule doc comment, line 32) both say classes are in scope when they carry `@JsonSerializable()` "or a class-level `@JsonEnum`," but the implementation's very first scope gate (line 138-142) requires `JsonSerializable` unconditionally and returns before `@JsonEnum` is ever consulted for scoping (it's only checked afterward, as a way to *clear* an already-in-scope class). A class annotated only `@JsonEnum(unknownEnumValue: ...)` with no `@JsonSerializable()` is real json_serializable usage (e.g. a shared enum-decoding config class) and is never scanned. Low real-world impact since the two annotations are almost always paired, but the doc comment overstates current coverage.
- **Name-only annotation matching (no import/type check).** `_findAnnotation` matches any annotation whose simple name is `JsonSerializable`/`JsonKey`/`JsonEnum`, regardless of which package it comes from. A project with an unrelated locally-defined class of the same name (exactly what the fixture itself does, by necessity, to stay import-free) would false-positive in the same way. This is a known, accepted category of imprecision for annotation-name-based rules elsewhere in the codebase, but worth flagging since it's not called out in the doc comment's "known limitations" paragraph the way the cross-file `@JsonEnum`-on-enum case is.
- **Nullable-enum distinct message (proposal edge case 3) was not implemented.** The proposal explicitly calls for "a distinct correction message suggesting either an explicit `unknownEnumValue` or a deliberate `// ignore:` if `null` is the intended fallback" for nullable enum fields with no fallback. The shipped rule does flag nullable fields (confirmed correct per the doc comment, lines 239-240) but uses the exact same generic `correctionMessage` for both nullable and non-nullable fields — the "distinct message" design point from the proposal was dropped silently, and there's no fixture/test case for a nullable enum field at all.
- **Map key type is never checked for enum-ness.** `_findEnumElement`'s `Map` branch (line 252-254) only recurses into `typeArguments[1]` (the value). An enum used as a map *key* (`Map<NotificationType, int>`) is unusual for JSON (keys serialize as strings) but not impossible with a custom `JsonKey` converter; falls outside current detection with no note in the doc comment about it being deliberate vs. an oversight.

### Opportunities

- `_findAnnotation`/`_hasNamedArgument`/`_namedBoolArgumentEquals` are generic "does this annotation carry a boolean/named arg" helpers with no `json_serializable`-specific logic — worth checking `lib/src/` for an existing shared annotation-argument utility before any similar codegen rule is added next, to avoid re-writing this exact pattern a third time (the doc comment for `require_json_decode_try_catch`, the "sibling" rule referenced at line 84, is a natural place such a helper would already live if it exists).
- The recursive `_findEnumElement` handles `List`/`Set`/`Iterable`/`Map` by bare type name (`element.name`) rather than checking against `dart:core`'s actual `List`/`Set`/etc. via `type.isDartCoreList` or similar analyzer helpers — a user-defined class literally named `List` (however unlikely) would be misidentified. Minor, but `isDartCoreList`/`isDartCoreSet`/`isDartCoreMap`/`isDartCoreIterable` on `InterfaceType` are the more precise/idiomatic analyzer APIs for this and would also read more clearly than string comparison.

### Recommendations

1. **High priority — fix the two false positives** (`createFactory: false`, `@JsonKey(fromJson: ...)`) before this ships further; both are realistic patterns in production `json_serializable` code, not exotic edge cases. Add fixture cases (`NotificationPayloadCreateFactoryFalseGood`, `NotificationPayloadCustomFromJsonGood`) and `expect_lint`-free assertions alongside the existing "GOOD near-miss" fixtures.
2. **Medium priority — fix the prefixed-import false negative** if the codebase's convention leans toward prefixed `json_annotation` imports anywhere; otherwise at minimum document it as a known limitation next to the existing cross-file `@JsonEnum`-on-enum caveat (rule doc comment, lines 38-41).
3. **Medium priority — add the missing fixture/test coverage** the proposal itself called out: nullable enum field (edge case 3), `Map<K, Enum>` field (edge case 4 mentions List *and* Map, only List is fixtured), and an enum with no natural "unknown" member (edge case 5). None of these are currently exercised even though the proposal enumerates them explicitly.
4. **Low priority — strengthen the unit test.** The current test (`test/rules/codegen/specify_unknown_enum_value_test.dart`) only pins rule metadata and fixture-file existence; it never runs the rule against the fixture to confirm the `expect_lint` markers actually fire (matches the project-wide "unit tests are instantiation pins only" pattern) — run the fixture through the scan CLI (`dart run saropa_lints scan example/lib/codegen --tier comprehensive --files specify_unknown_enum_value_fixture.dart --format json`) to confirm the 3 `expect_lint` lines fire and the 5 "GOOD" classes stay silent, since that has not been independently verified in this review.
5. **Low priority — correct the doc comment's scope claim** (line 32, "and a class-level `@JsonEnum(...)` covering it") to match the actual implementation (JsonSerializable-gated first), or change the implementation to match the doc — currently the two disagree.
