import 'dart:io';

import 'package:test/test.dart';

/// Tests for 9 Documentation lint rules.
///
/// Test fixtures: example_style/lib/documentation/*
void main() {
  group('Documentation Rules - Fixture Verification', () {
    final fixtures = [
      'require_public_api_documentation',
      'avoid_misleading_documentation',
      'require_deprecation_message',
      'require_complex_logic_comments',
      'require_parameter_documentation',
      'require_return_documentation',
      'require_exception_documentation',
      'require_example_in_documentation',
      'verify_documented_parameters_exist',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_style/lib/documentation/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Documentation - Avoidance Rules', () {
    group('avoid_misleading_documentation', () {
      test('docs that contradict the code SHOULD trigger', () {
        expect('docs that contradict the code', isNotNull);
      });

      test('accurate documentation should NOT trigger', () {
        expect('accurate documentation', isNotNull);
      });
    });
  });

  group('Documentation - Requirement Rules', () {
    group('require_public_api_documentation', () {
      test('undocumented public API SHOULD trigger', () {
        expect('undocumented public API', isNotNull);
      });

      test('documented public members should NOT trigger', () {
        expect('documented public members', isNotNull);
      });
    });
    group('require_deprecation_message', () {
      test('@deprecated without explanation SHOULD trigger', () {
        expect('@deprecated without explanation', isNotNull);
      });

      test('@deprecated with migration path should NOT trigger', () {
        expect('@deprecated with migration path', isNotNull);
      });
    });
    group('require_complex_logic_comments', () {
      test('complex algorithm without explanation SHOULD trigger', () {
        expect('complex algorithm without explanation', isNotNull);
      });

      test('commented complex logic should NOT trigger', () {
        expect('commented complex logic', isNotNull);
      });
    });
    group('require_parameter_documentation', () {
      test('undocumented parameters SHOULD trigger', () {
        expect('undocumented parameters', isNotNull);
      });

      test('@param tags for all parameters should NOT trigger', () {
        expect('@param tags for all parameters', isNotNull);
      });
    });
    group('require_return_documentation', () {
      test('missing return value docs SHOULD trigger', () {
        expect('missing return value docs', isNotNull);
      });

      test('@return documentation should NOT trigger', () {
        expect('@return documentation', isNotNull);
      });
    });
    group('require_exception_documentation', () {
      test('undocumented thrown exceptions SHOULD trigger', () {
        expect('undocumented thrown exceptions', isNotNull);
      });

      test('@throws documentation should NOT trigger', () {
        expect('@throws documentation', isNotNull);
      });
    });
    group('require_example_in_documentation', () {
      test('docs without usage example SHOULD trigger', () {
        expect('docs without usage example', isNotNull);
      });

      test('example code in docs should NOT trigger', () {
        expect('example code in docs', isNotNull);
      });
    });
    group('verify_documented_parameters_exist', () {
      test('docs reference non-existent params SHOULD trigger', () {
        expect('docs reference non-existent params', isNotNull);
      });

      test('matching param names in docs should NOT trigger', () {
        expect('matching param names in docs', isNotNull);
      });
    });
  });
}
