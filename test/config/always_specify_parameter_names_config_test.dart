import 'package:saropa_lints/src/config/always_specify_parameter_names_config.dart';
import 'package:test/test.dart';

/// Unit tests for [loadAlwaysSpecifyParameterNamesConfig], the user-configurable
/// allowlist loader for the `always_specify_parameter_names` rule.
void main() {
  group('loadAlwaysSpecifyParameterNamesConfig', () {
    test('null content produces an empty allowlist (no-op default)', () {
      loadAlwaysSpecifyParameterNamesConfig(null);
      expect(userAllowlistedConstructors, isEmpty);
    });

    test('empty content produces an empty allowlist', () {
      loadAlwaysSpecifyParameterNamesConfig('');
      expect(userAllowlistedConstructors, isEmpty);
    });

    test('content with no matching section produces an empty allowlist', () {
      loadAlwaysSpecifyParameterNamesConfig('some_other_key: true\n');
      expect(userAllowlistedConstructors, isEmpty);
    });

    test('parses a single well-formed entry', () {
      loadAlwaysSpecifyParameterNamesConfig('''
always_specify_parameter_names:
  allowlist:
    - class_name: 'Coordinate'
      library_uri: 'package:my_app/models.dart'
      max_args: 2
''');
      expect(userAllowlistedConstructors, hasLength(1));
      expect(userAllowlistedConstructors.first.className, 'Coordinate');
      expect(
        userAllowlistedConstructors.first.libraryUri,
        'package:my_app/models.dart',
      );
      expect(userAllowlistedConstructors.first.maxArgs, 2);
    });

    test('parses multiple entries', () {
      loadAlwaysSpecifyParameterNamesConfig('''
always_specify_parameter_names:
  allowlist:
    - class_name: 'Coordinate'
      library_uri: 'package:my_app/models.dart'
      max_args: 2
    - class_name: 'Vector3'
      library_uri: 'package:my_app/math.dart'
      max_args: 3
''');
      expect(userAllowlistedConstructors, hasLength(2));
      expect(userAllowlistedConstructors[1].className, 'Vector3');
      expect(userAllowlistedConstructors[1].maxArgs, 3);
    });

    test('double-quoted values parse the same as single-quoted', () {
      loadAlwaysSpecifyParameterNamesConfig('''
always_specify_parameter_names:
  allowlist:
    - class_name: "Coordinate"
      library_uri: "package:my_app/models.dart"
      max_args: 2
''');
      expect(userAllowlistedConstructors, hasLength(1));
      expect(userAllowlistedConstructors.first.className, 'Coordinate');
    });

    test('an entry missing max_args is dropped (incomplete entry)', () {
      loadAlwaysSpecifyParameterNamesConfig('''
always_specify_parameter_names:
  allowlist:
    - class_name: 'Coordinate'
      library_uri: 'package:my_app/models.dart'
''');
      expect(userAllowlistedConstructors, isEmpty);
    });

    test('a stale global list is reset when called again with no section', () {
      loadAlwaysSpecifyParameterNamesConfig('''
always_specify_parameter_names:
  allowlist:
    - class_name: 'Coordinate'
      library_uri: 'package:my_app/models.dart'
      max_args: 2
''');
      expect(userAllowlistedConstructors, hasLength(1));

      loadAlwaysSpecifyParameterNamesConfig('unrelated: true\n');
      expect(userAllowlistedConstructors, isEmpty);
    });

    test('allowlist section with no entries produces an empty list', () {
      loadAlwaysSpecifyParameterNamesConfig('''
always_specify_parameter_names:
  allowlist:
''');
      expect(userAllowlistedConstructors, isEmpty);
    });
  });
}
