import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/rules/architecture/dependency_injection_rules.dart';
import 'package:test/test.dart';

/// Parses a class with one constructor parameter of [typeSrc] and returns
/// whether the rule's type check would flag it (real parser, no stubs).
bool _flags(String typeSrc) {
  final unit = parseString(
    content: 'class A { A($typeSrc p); }',
    throwIfDiagnostics: false,
  ).unit;
  final ctor = (unit.declarations.first as ClassDeclaration)
      .body
      .childEntities
      .whereType<ConstructorDeclaration>()
      .first;
  final param = ctor.parameters.parameters.first as RegularFormalParameter;
  return PreferAbstractionInjectionRule.isConcreteInjectionType(param.type);
}

void main() {
  // FP: a factory closure returning Dio is the injection seam, not a concrete.
  test('Dio Function()? factory is NOT flagged', () {
    expect(_flags('Dio Function()?'), isFalse);
  });

  test('Dio Function() factory is NOT flagged', () {
    expect(_flags('Dio Function()'), isFalse);
  });

  // Positive cases: the rule must still fire on real concrete types.
  // Note: patterns match whole words (\bImpl\b), so compound names such as
  // `DioImpl` are a pre-existing non-match and out of scope for this fix.
  test('Sqlite instance is still flagged', () {
    expect(_flags('Sqlite'), isTrue);
  });

  test('Dio instance is still flagged', () {
    expect(_flags('Dio'), isTrue);
  });

  test('abstract ApiClient is not flagged', () {
    expect(_flags('ApiClient'), isFalse);
  });
}
