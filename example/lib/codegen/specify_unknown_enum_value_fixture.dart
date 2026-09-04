// ignore_for_file: unused_element, unused_field

/// Fixture for `specify_unknown_enum_value`.
///
/// Enum-typed fields inside a `@JsonSerializable()` class should configure an
/// `unknownEnumValue` fallback (per-field via `@JsonKey`, or class-wide via
/// `@JsonEnum`) so a backend value the client hasn't shipped support for yet
/// degrades gracefully instead of throwing during decode.
library;

class JsonSerializable {
  const JsonSerializable();
}

class JsonKey {
  const JsonKey({this.unknownEnumValue, this.ignore, this.includeFromJson});
  final Object? unknownEnumValue;
  final bool? ignore;
  final bool? includeFromJson;
}

class JsonEnum {
  const JsonEnum({this.unknownEnumValue});
  final Object? unknownEnumValue;
}

enum NotificationType { message, reminder, promo }

enum NotificationTypeSafe { message, reminder, promo, unknown }

// expect_lint: specify_unknown_enum_value
@JsonSerializable()
class NotificationPayloadBad {
  // No @JsonKey at all — the most exposed case: no annotation site carries a
  // fallback, so any unrecognized backend value crashes decoding.
  final NotificationType type;

  NotificationPayloadBad(this.type);
}

@JsonSerializable()
class NotificationPayloadJsonKeyNoFallback {
  // expect_lint: specify_unknown_enum_value
  @JsonKey(name: 'notification_type')
  final NotificationType type;

  NotificationPayloadJsonKeyNoFallback(this.type);
}

@JsonSerializable()
class NotificationPayloadListBad {
  // List<Enum> fields are supported by unknownEnumValue identically to bare
  // enum fields, so this should flag the same way.
  // expect_lint: specify_unknown_enum_value
  final List<NotificationType> types;

  NotificationPayloadListBad(this.types);
}

@JsonSerializable()
class NotificationPayloadGood {
  // OK — unrecognized backend values fall back to NotificationTypeSafe.unknown
  // instead of throwing.
  @JsonKey(unknownEnumValue: NotificationTypeSafe.unknown)
  final NotificationTypeSafe type;

  NotificationPayloadGood(this.type);
}

@JsonEnum(unknownEnumValue: NotificationTypeSafe.unknown)
@JsonSerializable()
class NotificationPayloadClassLevelGood {
  // OK — class-level @JsonEnum(unknownEnumValue: ...) covers this field.
  final NotificationTypeSafe type;

  NotificationPayloadClassLevelGood(this.type);
}

@JsonSerializable()
class NotificationPayloadIgnoredGood {
  // OK — excluded from JSON decoding entirely, so no fallback is needed.
  @JsonKey(ignore: true)
  final NotificationType type;

  NotificationPayloadIgnoredGood(this.type);
}

@JsonSerializable()
class NotificationPayloadNotIncludedGood {
  // OK — never populated from JSON.
  @JsonKey(includeFromJson: false)
  final NotificationType type;

  NotificationPayloadNotIncludedGood(this.type);
}

// GOOD near-miss: non-enum field, should never be flagged even though the
// class carries @JsonSerializable() and the field has no @JsonKey.
@JsonSerializable()
class NotificationPayloadStringFieldGood {
  final String type;

  NotificationPayloadStringFieldGood(this.type);
}

// GOOD near-miss: enum field on a plain class with no JSON annotation at
// all — never round-tripped through JSON, so no fallback is expected.
class PlainEnumHolderGood {
  final NotificationType type;

  PlainEnumHolderGood(this.type);
}
