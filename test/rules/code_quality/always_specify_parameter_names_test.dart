import 'package:saropa_lints/src/rules/code_quality/always_specify_parameter_names_helpers.dart';
import 'package:saropa_lints/src/rules/code_quality/always_specify_parameter_names_rule.dart';
import 'package:test/test.dart';

/// Unit tests for the pure detection helpers in [AlwaysSpecifyParameterNamesRule].
///
/// The rule itself requires type resolution (isDartCoreString etc.), so
/// end-to-end firing is not exercisable against parseString's unresolved AST.
/// These tests verify the confusable-type grouping and run-detection logic
/// that form the rule's core algorithm.
void main() {
  group('areTypesConfusable', () {
    // Two identical types should be confusable
    test('identical String types are confusable', () {
      expect(areTypesConfusable('String', 'String'), isTrue);
    });

    test('identical numeric types are confusable', () {
      expect(areTypesConfusable('numeric', 'numeric'), isTrue);
    });

    test('identical bool types are confusable', () {
      expect(areTypesConfusable('bool', 'bool'), isTrue);
    });

    // Custom types with the same name are confusable (e.g. two Duration args)
    test('identical custom types are confusable', () {
      expect(areTypesConfusable('Duration', 'Duration'), isTrue);
    });

    // Different types are NOT confusable
    test('String vs numeric are NOT confusable', () {
      expect(areTypesConfusable('String', 'numeric'), isFalse);
    });

    test('String vs bool are NOT confusable', () {
      expect(areTypesConfusable('String', 'bool'), isFalse);
    });

    test('numeric vs bool are NOT confusable', () {
      expect(areTypesConfusable('numeric', 'bool'), isFalse);
    });

    test('String vs custom type are NOT confusable', () {
      expect(areTypesConfusable('String', 'Duration'), isFalse);
    });

    // Sentinel types (__dynamic, __object, etc.) are NEVER confusable
    test('dynamic sentinel is never confusable', () {
      expect(areTypesConfusable('__dynamic', '__dynamic'), isFalse);
    });

    test('object sentinel is never confusable', () {
      expect(areTypesConfusable('__object', 'String'), isFalse);
    });

    test('unknown sentinel is never confusable', () {
      expect(areTypesConfusable('__unknown_0', '__unknown_0'), isFalse);
    });
  });

  group('findConfusableRuns', () {
    // Two same-type args → one run
    test('two Strings produce one run', () {
      final runs = findConfusableRuns(['String', 'String']);
      expect(runs, hasLength(1));
      expect(runs.first, equals((0, 1)));
    });

    // Two numeric args → one run (int + double both normalize to "numeric")
    test('two numerics produce one run', () {
      final runs = findConfusableRuns(['numeric', 'numeric']);
      expect(runs, hasLength(1));
      expect(runs.first, equals((0, 1)));
    });

    // Different types → no run
    test('String then int produces no run', () {
      final runs = findConfusableRuns(['String', 'numeric']);
      expect(runs, isEmpty);
    });

    // Single arg → no run (need 2+ to be confusable)
    test('single arg produces no run', () {
      final runs = findConfusableRuns(['String']);
      expect(runs, isEmpty);
    });

    // Empty list → no run
    test('empty list produces no run', () {
      final runs = findConfusableRuns([]);
      expect(runs, isEmpty);
    });

    // Three consecutive Strings → one run spanning all three
    test('three Strings produce one run of length 3', () {
      final runs = findConfusableRuns(['String', 'String', 'String']);
      expect(runs, hasLength(1));
      expect(runs.first, equals((0, 2)));
    });

    // Two same-type args separated by a different type → no run
    test('same types separated by different type produces no run', () {
      final runs = findConfusableRuns(['String', 'numeric', 'String']);
      expect(runs, isEmpty);
    });

    // Two separate runs in one argument list
    test('two separate runs detected independently', () {
      final runs = findConfusableRuns([
        'String',
        'String',
        'numeric',
        'bool',
        'bool',
      ]);
      expect(runs, hasLength(2));
      expect(runs[0], equals((0, 1))); // String run
      expect(runs[1], equals((3, 4))); // bool run
    });

    // Sentinel types break runs — dynamic between two Strings
    test('sentinel types break runs', () {
      final runs = findConfusableRuns(['String', '__dynamic', 'String']);
      expect(runs, isEmpty);
    });

    // Sentinel types at the start don't form a run
    test('sentinel types at boundaries do not form runs', () {
      final runs = findConfusableRuns(['__unknown_0', '__unknown_1', 'String']);
      expect(runs, isEmpty);
    });

    // Mixed: run at the end
    test('run at the end of the list', () {
      final runs = findConfusableRuns(['numeric', 'String', 'String']);
      expect(runs, hasLength(1));
      expect(runs.first, equals((1, 2)));
    });

    // Custom types form runs too (e.g. two Duration args)
    test('custom types form confusable runs', () {
      final runs = findConfusableRuns(['Duration', 'Duration']);
      expect(runs, hasLength(1));
      expect(runs.first, equals((0, 1)));
    });
  });

  group('findAllowlistedMaxArgs', () {
    // Regression test for a false-negative found in review: matching on
    // class name alone would silently exempt a user-defined class that
    // happens to share a name with an allowlisted one.
    test('user-defined class sharing a name is NOT allowlisted', () {
      expect(
        findAllowlistedMaxArgs('Size', 'package:my_app/models.dart'),
        isNull,
      );
      expect(
        findAllowlistedMaxArgs('Offset', 'package:my_app/models.dart'),
        isNull,
      );
    });

    test('dart:ui Offset is allowlisted with max 2 args', () {
      expect(findAllowlistedMaxArgs('Offset', 'dart:ui'), equals(2));
    });

    test('dart:ui Size is allowlisted with max 2 args', () {
      expect(findAllowlistedMaxArgs('Size', 'dart:ui'), equals(2));
    });

    test('dart:ui Rect is allowlisted with max 4 args', () {
      expect(findAllowlistedMaxArgs('Rect', 'dart:ui'), equals(4));
    });

    test('dart:math Point is allowlisted with max 2 args', () {
      expect(findAllowlistedMaxArgs('Point', 'dart:math'), equals(2));
    });

    test('dart:math Rectangle is allowlisted with max 4 args', () {
      expect(findAllowlistedMaxArgs('Rectangle', 'dart:math'), equals(4));
    });

    test('dart:math MutableRectangle is allowlisted with max 4 args', () {
      expect(
        findAllowlistedMaxArgs('MutableRectangle', 'dart:math'),
        equals(4),
      );
    });

    // Right class name, wrong library — must not match (e.g. a hypothetical
    // Point from a different package than dart:math).
    test('right class name but wrong library is NOT allowlisted', () {
      expect(findAllowlistedMaxArgs('Point', 'dart:ui'), isNull);
    });

    test('unknown class name is NOT allowlisted', () {
      expect(findAllowlistedMaxArgs('Duration', 'dart:core'), isNull);
    });

    test('null class name is NOT allowlisted', () {
      expect(findAllowlistedMaxArgs(null, 'dart:ui'), isNull);
    });
  });

  group('rule instantiation pin', () {
    // Verifies the rule can be constructed without throwing — catches
    // missing imports, wrong constructor signatures, broken LintCode, etc.
    test('AlwaysSpecifyParameterNamesRule instantiates', () {
      final rule = AlwaysSpecifyParameterNamesRule();
      // ignore: deprecated_member_use
      expect(rule.code.name, equals('always_specify_parameter_names'));
      expect(rule.usesTypeResolution, isTrue);
    });
  });
}
