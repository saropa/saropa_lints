// ignore_for_file: unused_element, unused_field

/// Fixture for `specify_unknown_enum_value`.
///
/// Enum-typed fields inside a `@JsonSerializable()` class should configure an
/// `unknownEnumValue` fallback (per-field via `@JsonKey`, or class-wide via
/// `@JsonEnum`) so a backend value the client hasn't shipped support for yet
/// degrades gracefully instead of throwing during decode.
library;

class JsonSerializable {
  const JsonSerializable({this.createFactory});
  final bool? createFactory;
}

class JsonKey {
  const JsonKey({
    this.unknownEnumValue,
    this.ignore,
    this.includeFromJson,
    this.fromJson,
  });
  final Object? unknownEnumValue;
  final bool? ignore;
  final bool? includeFromJson;
  final Object? fromJson;
}

class JsonEnum {
  const JsonEnum({this.unknownEnumValue});
  final Object? unknownEnumValue;
}

// Local stand-in for the hand-written converter a real project would pass to
// `@JsonKey(fromJson: ...)` — its body is irrelevant, only its presence as a
// named argument matters to the rule.
NotificationType _notificationTypeFromJson(String value) =>
    NotificationType.message;

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

@JsonSerializable(createFactory: false)
class NotificationPayloadCreateFactoryFalseGood {
  // OK — createFactory: false means json_serializable never generates a
  // fromJson decoder for this class, so there is no decode path that can
  // throw on an unrecognized enum value.
  final NotificationType type;

  NotificationPayloadCreateFactoryFalseGood(this.type);
}

@JsonSerializable()
class NotificationPayloadCustomFromJsonGood {
  // OK — a custom fromJson converter replaces the generated enum-map
  // lookup entirely; json_serializable ignores unknownEnumValue when a
  // custom converter is configured, so any unknown-value handling lives
  // inside the converter function instead.
  @JsonKey(fromJson: _notificationTypeFromJson)
  final NotificationType type;

  NotificationPayloadCustomFromJsonGood(this.type);
}

@JsonSerializable()
class NotificationPayloadNullableBad {
  // A nullable enum field with no unknownEnumValue still flags: an
  // unrecognized backend value silently decodes to null rather than
  // throwing, which can still surprise downstream non-null-aware code.
  // expect_lint: specify_unknown_enum_value
  final NotificationType? type;

  NotificationPayloadNullableBad(this.type);
}

@JsonSerializable()
class NotificationPayloadMapBad {
  // Map<K, Enum> fields are supported by unknownEnumValue on the value type
  // identically to bare enum fields, so this should flag the same way.
  // expect_lint: specify_unknown_enum_value
  final Map<String, NotificationType> typesById;

  NotificationPayloadMapBad(this.typesById);
}

@JsonSerializable()
class NotificationPayloadMapGood {
  // OK — the map value's unrecognized entries fall back to
  // NotificationTypeSafe.unknown instead of throwing.
  @JsonKey(unknownEnumValue: NotificationTypeSafe.unknown)
  final Map<String, NotificationTypeSafe> typesById;

  NotificationPayloadMapGood(this.typesById);
}

// Class-level @JsonEnum with no @JsonSerializable of its own — a shared
// enum-decoding config class, still in scope per the rule's doc comment.
@JsonEnum()
class NotificationPayloadJsonEnumOnlyBad {
  // expect_lint: specify_unknown_enum_value
  final NotificationType type;

  NotificationPayloadJsonEnumOnlyBad(this.type);
}

@JsonEnum(unknownEnumValue: NotificationTypeSafe.unknown)
class NotificationPayloadJsonEnumOnlyGood {
  // OK — the class-level @JsonEnum(unknownEnumValue: ...) covers this field
  // even though the class carries no @JsonSerializable() of its own.
  final NotificationTypeSafe type;

  NotificationPayloadJsonEnumOnlyGood(this.type);
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
