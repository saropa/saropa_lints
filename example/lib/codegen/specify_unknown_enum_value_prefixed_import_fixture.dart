// ignore_for_file: unused_element, unused_field

/// Group fixture for `specify_unknown_enum_value`'s prefixed-import support.
///
/// Not named `specify_unknown_enum_value_fixture.dart` on purpose — the
/// `fixture_integrity_test` classifies a non-exact-name fixture as a "group
/// fixture" (logged, not asserted against a single rule name), which is the
/// right bucket for a fixture that exists purely to exercise one edge case
/// (`import '...' as prefix;` then `@prefix.JsonSerializable()`) rather than
/// duplicate the main fixture's full coverage.
library;

import 'specify_unknown_enum_value_fixture.dart' as json;

@json.JsonSerializable()
class PrefixedNotificationPayloadBad {
  // `@json.JsonSerializable()` is a prefixed annotation (PrefixedIdentifier
  // "json.JsonSerializable", not the bare "JsonSerializable" literal) — the
  // rule must still recognize it and flag this field.
  // expect_lint: specify_unknown_enum_value
  final json.NotificationType type;

  PrefixedNotificationPayloadBad(this.type);
}

@json.JsonSerializable()
class PrefixedNotificationPayloadGood {
  // OK — @json.JsonKey(unknownEnumValue: ...) is recognized the same way as
  // the class-level annotation above.
  @json.JsonKey(unknownEnumValue: json.NotificationTypeSafe.unknown)
  final json.NotificationTypeSafe type;

  PrefixedNotificationPayloadGood(this.type);
}
