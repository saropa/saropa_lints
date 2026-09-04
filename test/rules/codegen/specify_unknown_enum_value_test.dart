import 'dart:io';

import 'package:saropa_lints/src/rules/codegen/specify_unknown_enum_value_rules.dart';
import 'package:test/test.dart';

import '../../helpers/fixture_discovery.dart';
import '../../support/resolved_rule_harness.dart';

/// Tests for the specify_unknown_enum_value lint rule.
///
/// Test fixtures:
///   example/lib/codegen/specify_unknown_enum_value_fixture.dart
///   example/lib/codegen/specify_unknown_enum_value_prefixed_import_fixture.dart
///
/// Behavior tests below use the resolved-rule harness (real type resolution,
/// no dependency on lib/saropa_lints.dart wiring) rather than only pinning
/// rule metadata — see memory/reference_verify_rule_behavior_scan_cli.md for
/// why a scan-only fixture check does not prove a rule actually fires.
///
/// The inline test sources declare their own bare-bones
/// JsonSerializable/JsonKey/JsonEnum classes (mirroring the fixture) since
/// the example package does not depend on json_annotation — only the
/// annotation *shape* (name + named arguments) matters to the rule, not the
/// real package's types.
const String _annotationStubs = '''
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

Status _statusFromJson(String value) => Status.active;

enum Status { active, inactive }
enum StatusSafe { active, inactive, unknown }
''';

void main() {
  group('Specify Unknown Enum Value Rule - Rule Instantiation', () {
    test('SpecifyUnknownEnumValueRule', () {
      final rule = SpecifyUnknownEnumValueRule();
      expect(rule.code.lowerCaseName, 'specify_unknown_enum_value');
      expect(
        rule.code.problemMessage,
        contains('[specify_unknown_enum_value]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Specify Unknown Enum Value Rule - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/codegen');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    test('specify_unknown_enum_value fixture exists', () {
      final file = File(
        'example/lib/codegen/specify_unknown_enum_value_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('prefixed-import fixture exists', () {
      final file = File(
        'example/lib/codegen/'
        'specify_unknown_enum_value_prefixed_import_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
  });

  group('Specify Unknown Enum Value Rule - Behavior (resolved)', () {
    const ruleName = 'specify_unknown_enum_value';

    test('fires on an enum field with no @JsonKey at all', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  final Status status;
  Payload(this.status);
}
''');
      expect(codes, contains(ruleName));
    });

    test(
      'fires on a @JsonKey field with no unknownEnumValue argument',
      () async {
        final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  @JsonKey(ignore: false)
  final Status status;
  Payload(this.status);
}
''');
        expect(codes, contains(ruleName));
      },
    );

    test('does NOT fire when @JsonKey configures unknownEnumValue', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  @JsonKey(unknownEnumValue: StatusSafe.unknown)
  final StatusSafe status;
  Payload(this.status);
}
''');
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire when a class-level @JsonEnum covers the field',
      () async {
        final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonEnum(unknownEnumValue: StatusSafe.unknown)
@JsonSerializable()
class Payload {
  final StatusSafe status;
  Payload(this.status);
}
''');
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire on a @JsonKey(ignore: true) field', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  @JsonKey(ignore: true)
  final Status status;
  Payload(this.status);
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on a @JsonKey(includeFromJson: false) field', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  @JsonKey(includeFromJson: false)
  final Status status;
  Payload(this.status);
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on a non-enum field', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  final String status;
  Payload(this.status);
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on an enum field with no JSON annotation', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
class Payload {
  final Status status;
  Payload(this.status);
}
''');
      expect(codes, isEmpty);
    });

    test('fires on a List<Enum> field with no fallback', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  final List<Status> statuses;
  Payload(this.statuses);
}
''');
      expect(codes, contains(ruleName));
    });

    test('fires on a Map<K, Enum> field with no fallback', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  final Map<String, Status> statusesById;
  Payload(this.statusesById);
}
''');
      expect(codes, contains(ruleName));
    });

    test(
      'does NOT fire on a Map<K, Enum> field with unknownEnumValue',
      () async {
        final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  @JsonKey(unknownEnumValue: StatusSafe.unknown)
  final Map<String, StatusSafe> statusesById;
  Payload(this.statusesById);
}
''');
        expect(codes, isEmpty);
      },
    );

    test('fires on a nullable enum field with no fallback', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  final Status? status;
  Payload(this.status);
}
''');
      expect(codes, contains(ruleName));
    });

    test(
      'does NOT fire on @JsonSerializable(createFactory: false) — no '
      'fromJson decoder is generated, so there is no throwing decode path',
      () async {
        final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable(createFactory: false)
class Payload {
  final Status status;
  Payload(this.status);
}
''');
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire on a @JsonKey(fromJson: ...) custom converter — '
      'json_serializable ignores unknownEnumValue when a converter is set',
      () async {
        final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonSerializable()
class Payload {
  @JsonKey(fromJson: _statusFromJson)
  final Status status;
  Payload(this.status);
}
''');
        expect(codes, isEmpty);
      },
    );

    test('fires on a class-level @JsonEnum with no @JsonSerializable of its '
        'own — a bare enum-decoding config class is still in scope', () async {
      final codes = await reportedRuleCodes(SpecifyUnknownEnumValueRule(), '''
$_annotationStubs
@JsonEnum()
class Payload {
  final Status status;
  Payload(this.status);
}
''');
      expect(codes, contains(ruleName));
    });

    // Prefixed-annotation-import support (`@json.JsonSerializable()`) needs
    // a real cross-file `import '...' as prefix;`, which the single-file
    // resolved-rule harness can't express — covered instead by the
    // dedicated fixture at
    // specify_unknown_enum_value_prefixed_import_fixture.dart, with
    // `expect_lint`/silence assertions checked via the scan CLI per
    // memory/reference_verify_rule_behavior_scan_cli.md.
  });
}
