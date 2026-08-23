import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/config/pubspec_constraint_parser.dart';
import 'package:saropa_lints/src/rules/config/dart_sdk_migration_rules.dart';
import 'package:saropa_lints/src/tiers.dart';
import 'package:test/test.dart';

/// Tests for Dart SDK 3.13+ migration rules.
///
/// Rules:
///   - prefer_primary_constructor (Professional, INFO)
///
/// `isPrimaryConstructorEligible` and `sdkIsAtLeast` are purely syntactic
/// (no resolved-type dependency), so behavior is verified directly against
/// unresolved `parseString` ASTs rather than the resolved-rule harness — the
/// harness always resolves fixtures under `example/`, whose pubspec SDK
/// lower bound (3.9.0) is below the 3.13.0 gate this rule requires, so it
/// could never observe the rule firing.
void main() {
  // ---------------------------------------------------------------------------
  // Rule Instantiation & Metadata
  // ---------------------------------------------------------------------------

  group('Dart SDK Migration - Rule Instantiation', () {
    test('PreferPrimaryConstructorRule instantiates correctly', () {
      final rule = PreferPrimaryConstructorRule();
      expect(rule.code.lowerCaseName, 'prefer_primary_constructor');
      expect(
        rule.code.problemMessage,
        contains('[prefer_primary_constructor]'),
      );
      // Problem message must be >200 chars per project requirements.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, isNotEmpty);
      // Rule requires class declarations to be present.
      expect(rule.requiresClassDeclaration, isTrue);
      // Purely syntactic — must not opt into resolved-type analysis.
      expect(rule.usesTypeResolution, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Tier Registration
  // ---------------------------------------------------------------------------

  group('Dart SDK Migration - Tier Registration', () {
    test('prefer_primary_constructor is in professionalOnlyRules', () {
      expect(
        professionalOnlyRules.contains('prefer_primary_constructor'),
        isTrue,
        reason: 'prefer_primary_constructor should be in professionalOnlyRules',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // sdkIsAtLeast — boundary behavior
  // ---------------------------------------------------------------------------

  group('sdkIsAtLeast', () {
    test('null lower bound is never at least any version', () {
      expect(sdkIsAtLeast(null, 3, 13), isFalse);
    });

    test('below the minor bound fails', () {
      expect(sdkIsAtLeast(const SemverParts(3, 12, 9), 3, 13), isFalse);
    });

    test('exactly at the bound passes', () {
      expect(sdkIsAtLeast(const SemverParts(3, 13, 0), 3, 13), isTrue);
    });

    test('above the minor bound passes', () {
      expect(sdkIsAtLeast(const SemverParts(3, 14, 0), 3, 13), isTrue);
    });

    test('above the major bound passes regardless of minor', () {
      expect(sdkIsAtLeast(const SemverParts(4, 0, 0), 3, 13), isTrue);
    });

    test('below the major bound fails regardless of minor', () {
      expect(sdkIsAtLeast(const SemverParts(2, 99, 0), 3, 13), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isPrimaryConstructorEligible — fixture cases (15 scenarios from proposal)
  // ---------------------------------------------------------------------------

  group('isPrimaryConstructorEligible - eligible (expect true)', () {
    test('simple class with two final fields', () {
      expect(
        _eligible('''
class SimplePoint {
  SimplePoint(this.x, this.y);
  final double x;
  final double y;
}
'''),
        isTrue,
      );
    });

    test('const constructor with final fields', () {
      expect(
        _eligible('''
class ConstConfig {
  const ConstConfig(this.host, this.port);
  final String host;
  final int port;
}
'''),
        isTrue,
      );
    });

    test('named parameters', () {
      expect(
        _eligible('''
class UserProfile {
  const UserProfile({required this.id, required this.displayName});
  final String id;
  final String displayName;
}
'''),
        isTrue,
      );
    });

    test('optional parameters with defaults', () {
      expect(
        _eligible('''
class Settings {
  Settings({this.timeout = 30, this.retries = 3});
  final int timeout;
  final int retries;
}
'''),
        isTrue,
      );
    });
  });

  group('isPrimaryConstructorEligible - not eligible (expect false)', () {
    test('class extending another class', () {
      expect(
        _eligible('''
class ExtendsAnother extends Base {
  const ExtendsAnother(this.value);
  final String value;
}
'''),
        isFalse,
      );
    });

    test('class with initializer list', () {
      expect(
        _eligible('''
class WithInitializer {
  WithInitializer(this.value) : doubled = value * 2;
  final int value;
  final int doubled;
}
'''),
        isFalse,
      );
    });

    test('class with constructor body', () {
      expect(
        _eligible('''
class WithBody {
  WithBody(this.raw) {
    print(raw);
  }
  final String raw;
}
'''),
        isFalse,
      );
    });

    test('class with factory constructor', () {
      expect(
        _eligible('''
class WithFactory {
  WithFactory(this.data);
  factory WithFactory.empty() => WithFactory('');
  final String data;
}
'''),
        isFalse,
      );
    });

    test('class with non-final fields', () {
      expect(
        _eligible('''
class MutableFields {
  MutableFields(this.counter);
  int counter;
}
'''),
        isFalse,
      );
    });

    test('class with fields not covered by constructor', () {
      expect(
        _eligible('''
class ExtraField {
  ExtraField(this.name);
  final String name;
  final String tag = 'default';
}
'''),
        isFalse,
      );
    });

    test('mixin class', () {
      expect(
        _eligible('''
mixin class MixinClass {
  MixinClass(this.value);
  final int value;
}
'''),
        isFalse,
      );
    });

    test('class with multiple constructors', () {
      expect(
        _eligible('''
class MultipleCtors {
  MultipleCtors(this.label);
  MultipleCtors.named(String prefix) : label = '\$prefix-default';
  final String label;
}
'''),
        isFalse,
      );
    });

    test('empty class with no fields', () {
      expect(
        _eligible('''
class EmptyClass {
  EmptyClass();
}
'''),
        isFalse,
      );
    });

    test('class with `with` clause', () {
      expect(
        _eligible('''
class WithMixin with SomeMixin {
  WithMixin(this.value);
  final int value;
}
'''),
        isFalse,
      );
    });
  });

  group('isPrimaryConstructorEligible - additional edge cases', () {
    test('late final field is excluded (no primary-ctor equivalent)', () {
      expect(
        _eligible('''
class WithLateFinal {
  WithLateFinal(this.value);
  late final int value;
}
'''),
        isFalse,
      );
    });

    test('field with inline initializer is excluded', () {
      expect(
        _eligible('''
class WithFieldInitializer {
  WithFieldInitializer(this.name);
  final String name;
  final String tag = 'default';
}
'''),
        isFalse,
        reason: 'tag is uncovered by the constructor AND has an initializer',
      );
    });

    test('static field is ignored (not an instance field)', () {
      expect(
        _eligible('''
class WithStaticField {
  WithStaticField(this.name);
  final String name;
  static const String tag = 'x';
}
'''),
        isTrue,
        reason: 'static fields are not instance fields and are ignored',
      );
    });

    test('annotated field is excluded (no placement rule yet)', () {
      expect(
        _eligible('''
class WithAnnotatedField {
  WithAnnotatedField(this.value);
  @deprecated
  final int value;
}
'''),
        isFalse,
      );
    });

    test('annotated constructor parameter is excluded', () {
      expect(
        _eligible('''
class WithAnnotatedParam {
  WithAnnotatedParam(@deprecated this.value);
  final int value;
}
'''),
        isFalse,
      );
    });

    test('non-field-formal parameter is excluded', () {
      expect(
        _eligible('''
class WithComputedField {
  WithComputedField(int raw) : value = raw * 2;
  final int value;
}
'''),
        isFalse,
      );
    });
  });
}

/// Parses [source] and returns whether the FIRST class declaration is
/// eligible for primary-constructor migration.
bool _eligible(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final classDecl = result.unit.declarations
      .whereType<ClassDeclaration>()
      .first;
  return isPrimaryConstructorEligible(classDecl);
}
