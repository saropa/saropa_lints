# PROPOSAL: Flag `json_serializable` Enum Fields Missing `unknownEnumValue` Fallback

**Status: Open**

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
