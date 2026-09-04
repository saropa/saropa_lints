// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Value-type contract lint rules (implements vs extends for Equatable-based
/// types).
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a class uses `implements` on an Equatable-based value type
/// instead of `extends`/`with`, without redeclaring `==` and `hashCode`.
///
/// Since: v14.4.0 | Rule version: v1
///
/// `implements` on a class only enforces the interface (member signatures)
/// of the named type — it does NOT inherit any implementation. A class that
/// `implements` a value type such as `Equatable` (or a class that itself
/// extends `Equatable`/mixes in `EquatableMixin`) must redeclare `props`,
/// `==`, and `hashCode` from scratch. If it does not, instances silently
/// fall back to identity equality (`==` compares references), breaking
/// every `Set`, `Map` key, deduplication, and equality-based test that
/// assumes value semantics. This compiles cleanly and only misbehaves at
/// runtime, making it a hard-to-spot Dart footgun.
///
/// **BAD:**
/// ```dart
/// class UserId implements Equatable {
///   UserId(this.value);
///   final String value;
///   // == and hashCode are NOT inherited — reference equality applies.
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserId extends Equatable {
///   const UserId(this.value);
///   final String value;
///
///   @override
///   List<Object?> get props => [value];
/// }
/// ```
///
/// **GOOD (manual equality contract honored):**
/// ```dart
/// class UserId implements Equatable {
///   const UserId(this.value);
///   final String value;
///
///   @override
///   List<Object?> get props => [value];
///
///   @override
///   bool operator ==(Object other) =>
///       other is UserId && other.value == value;
///
///   @override
///   int get hashCode => value.hashCode;
///
///   @override
///   bool get stringify => false;
/// }
/// ```
class AvoidImplementingValueTypesRule extends SaropaLintRule {
  AvoidImplementingValueTypesRule() : super(code: _code);

  /// Silent runtime bug: equality silently degrades to identity comparison.
  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  // Detection walks resolved supertypes of the implemented interface, so
  // this must run in a resolved context (see saropa-lints-diagnostics
  // resolved-vs-syntactic scan distinction).
  @override
  bool get usesTypeResolution => true;

  // Cheap pre-filter: a class must contain "implements" in source before
  // paying for AST traversal at all.
  @override
  Set<String>? get requiredPatterns => const <String>{'implements'};

  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'avoid_implementing_value_types',
    '[avoid_implementing_value_types] Class implements a value-equality '
        'type (Equatable or a class built on it) without redeclaring both '
        '== and hashCode. The "implements" keyword only enforces the '
        "interface's member signatures — it does not inherit Equatable's "
        'equality implementation. Instances of this class silently fall '
        'back to identity equality, so two objects with identical field '
        'values will not compare as equal in Sets, Map keys, deduplication, '
        'or equality-based test assertions. The code compiles cleanly, so '
        'this defect is only discovered at runtime. {v1}',
    correctionMessage:
        'Change "implements" to "extends Equatable" (or "with '
        'EquatableMixin" if the class already extends another type), or, '
        'if implements is required, manually override both == and hashCode '
        'to match the intended value-equality contract.',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Names that are known, by exact match, to define value equality. Kept
  /// as an exact Set (never substring-matched) per the project's
  /// false-positive doctrine — a class named `MyEquatableWrapper` must not
  /// match via `.contains('Equatable')`.
  static const Set<String> _knownValueEqualityNames = {
    'Equatable',
    'EquatableMixin',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final ImplementsClause? implementsClause = node.implementsClause;
      if (implementsClause == null) return;

      if (!_implementsValueEqualityType(implementsClause)) return;

      // The class only misbehaves if it fails to redeclare its own
      // equality contract — a class that does so has knowingly opted out
      // of the inherited implementation and is not a false positive.
      if (_declaresOwnEqualityContract(node)) return;

      reporter.atNode(implementsClause);
    });
  }

  /// Returns true when [type] is itself a known value-equality type, or is
  /// a resolved class/mixin whose own supertype chain (extends/with/
  /// implements) reaches one. Shared by [_implementsValueEqualityType] (is
  /// the *implemented* interface a value type?) and
  /// [_declaresOwnEqualityContract] (does the class's *own* extends/with
  /// clause already provide value equality?) so both walk the exact same
  /// resolved-type logic instead of drifting apart. Uses resolved element
  /// identity (`allSupertypes`) rather than name substring matching, so an
  /// unrelated `MyEquatableLike` class does not false positive.
  bool _resolvesToValueEqualityType(DartType? type) {
    if (type is! InterfaceType) return false;
    if (_knownValueEqualityNames.contains(type.element.name)) return true;

    for (final InterfaceType supertype in type.element.allSupertypes) {
      if (_knownValueEqualityNames.contains(supertype.element.name)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true when any interface in [clause] is exactly a known
  /// value-equality type, or is a resolved class whose own supertype chain
  /// reaches one — e.g. `implements Equatable` directly, or
  /// `implements BaseId` where `BaseId extends Equatable`.
  bool _implementsValueEqualityType(ImplementsClause clause) {
    for (final NamedType interfaceType in clause.interfaces) {
      final String name = interfaceType.name.lexeme;
      if (_knownValueEqualityNames.contains(name)) return true;
      if (_resolvesToValueEqualityType(interfaceType.type)) return true;
    }
    return false;
  }

  /// Returns true when [node] already has a real, working equality
  /// contract — either because its `extends`/`with` clause resolves to a
  /// known value-equality type (equality is genuinely inherited that way,
  /// unlike via `implements`), or because it redeclares both
  /// `operator ==` and `hashCode` itself.
  ///
  /// The extends/with check exists for the Dart 3 "interface class" idiom:
  /// a class can `with EquatableMixin` (or `extends Equatable`) for real
  /// behavior while separately `implements` an unrelated, Equatable-based
  /// marker/contract interface purely for typing, e.g.
  /// `class Money with EquatableMixin implements ValueObject`. Without this
  /// check, such a class would be flagged even though its equality is
  /// correct — the `implements` clause never contributed the equality here.
  bool _declaresOwnEqualityContract(ClassDeclaration node) {
    final DartType? extendsType = node.extendsClause?.superclass.type;
    if (_resolvesToValueEqualityType(extendsType)) return true;

    final WithClause? withClause = node.withClause;
    if (withClause != null) {
      for (final NamedType mixinType in withClause.mixinTypes) {
        if (_resolvesToValueEqualityType(mixinType.type)) return true;
      }
    }

    // Both members are required together — declaring only one still leaves
    // the equality contract broken (mismatched == and hashCode is its own
    // bug class, but is out of scope for this rule).
    bool hasEquals = false;
    bool hasHashCode = false;
    for (final ClassMember member in node.bodyMembers) {
      if (member is! MethodDeclaration) continue;
      if (member.isOperator && member.name.lexeme == '==') {
        hasEquals = true;
      } else if (member.isGetter && member.name.lexeme == 'hashCode') {
        hasHashCode = true;
      }
    }
    return hasEquals && hasHashCode;
  }
}
