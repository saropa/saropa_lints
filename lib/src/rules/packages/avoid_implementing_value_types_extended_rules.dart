// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Value-type contract lint rules (implements vs extends for Equatable-based
/// types).
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a class uses `implements` on an Equatable-based value type
/// instead of `extends`/`with`, without redeclaring `==` and `hashCode`.
///
/// Since: v14.4.0 | Updated: v14.4.0 | Rule version: v2
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
///
/// **GOOD (equality inherited from an ordinary base class):**
/// ```dart
/// class BaseValue {
///   @override
///   bool operator ==(Object other) => runtimeType == other.runtimeType;
///
///   @override
///   int get hashCode => runtimeType.hashCode;
/// }
///
/// // `extends` DOES inherit implementation, so UserId already has a
/// // working == / hashCode pair — the `implements` clause did not break it.
/// class UserId extends BaseValue implements Equatable {
///   UserId(this.value);
///   final String value;
///
///   @override
///   List<Object?> get props => [value];
/// }
/// ```
///
/// **Detection scope / known limitation.** Identifying the "value type" is
/// only fully reliable when the analysis context is resolved AND the type
/// actually comes from `package:equatable`. This rule therefore uses a
/// three-tier match, weakest last:
///
/// 1. Resolved element declared in `package:equatable/` — authoritative.
/// 2. Resolved element named `Equatable`/`EquatableMixin` from any other
///    library, but only if it structurally corroborates the contract by
///    declaring a `props` getter. This keeps vendored/forked copies and the
///    repo's dependency-free fixtures working, while an unrelated
///    project-local `abstract class Equatable { bool matches(Object o); }`
///    (no `props`) is correctly ignored.
/// 3. Unresolved type (syntactic-only scan, or a missing dependency) —
///    falls back to the bare `Equatable`/`EquatableMixin` name. This tier
///    CAN still false positive on a same-named project-local class, and
///    there is no way to do better without type information. Run with
///    `--resolve` (the IDE plugin path is always resolved) to get tier 1/2.
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
    'avoid_implementing_value_types_extended',
    '[avoid_implementing_value_types_extended] Class implements a value-equality '
        'type (Equatable or a class built on it) without redeclaring both '
        '== and hashCode. The "implements" keyword only enforces the '
        "interface's member signatures — it does not inherit Equatable's "
        'equality implementation. Instances of this class silently fall '
        'back to identity equality, so two objects with identical field '
        'values will not compare as equal in Sets, Map keys, deduplication, '
        'or equality-based test assertions. The code compiles cleanly, so '
        'this defect is only discovered at runtime. {v2}',
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
  ///
  /// A name match alone is NOT sufficient in a resolved context: see
  /// [_isValueEqualityElement], which additionally requires either the
  /// `package:equatable` library origin or structural corroboration.
  static const Set<String> _knownValueEqualityNames = {
    'Equatable',
    'EquatableMixin',
  };

  /// Library-URI prefix that authoritatively identifies the real value type.
  static const String _equatablePackagePrefix = 'package:equatable/';

  /// The member every genuine Equatable-family type declares. Used as
  /// structural corroboration when the resolved element is named
  /// `Equatable`/`EquatableMixin` but does NOT come from
  /// `package:equatable` — e.g. a vendored copy, or this repo's own
  /// dependency-free fixtures. An unrelated project-local marker interface
  /// that merely reuses the name (`abstract class Equatable { bool
  /// matches(Object other); }`) has no `props` getter and is correctly
  /// rejected, which is the false positive this guard exists to kill.
  static const String _valueEqualityMarkerMember = 'props';

  /// Members that together constitute a hand-rolled equality contract.
  static const String _equalsOperatorName = '==';
  static const String _hashCodeGetterName = 'hashCode';

  /// Returns true when [element] is a genuine Equatable-family value type.
  ///
  /// Name match is a necessary but insufficient precondition — the doctrine
  /// comment on [_knownValueEqualityNames] only ever protected against
  /// SUBSTRING false positives, not against an unrelated same-named class
  /// in the user's own codebase. This adds the missing library-identity
  /// gate: `package:equatable` origin is authoritative, and anything else
  /// must corroborate by declaring [_valueEqualityMarkerMember].
  bool _isValueEqualityElement(InterfaceElement element) {
    if (!_knownValueEqualityNames.contains(element.name)) return false;

    // Tier 1: the real package. No further evidence needed.
    if (element.library.uri.toString().startsWith(_equatablePackagePrefix)) {
      return true;
    }

    // Tier 2: same name, different library — demand structural proof. This
    // deliberately keeps the local `Equatable` stand-ins used by
    // example/lib fixtures and the resolved-rule test harness working
    // (they declare `props`) without adding a package:equatable dependency.
    return element.getGetter(_valueEqualityMarkerMember) != null;
  }

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
    if (_isValueEqualityElement(type.element)) return true;

    for (final InterfaceType supertype in type.element.allSupertypes) {
      if (_isValueEqualityElement(supertype.element)) return true;
    }
    return false;
  }

  /// Returns true when any interface in [clause] is a known value-equality
  /// type, or is a resolved class whose own supertype chain reaches one —
  /// e.g. `implements Equatable` directly, or `implements BaseId` where
  /// `BaseId extends Equatable`.
  ///
  /// When the interface RESOLVES, the resolved element is the sole
  /// authority and the source lexeme is deliberately ignored: a
  /// project-local `Equatable` that is not a value type must not be
  /// flagged just because it shares the name. The bare-name fallback is
  /// reached only for types that failed to resolve at all (syntactic-only
  /// scan, or the dependency is genuinely missing), where a name is the
  /// only signal available.
  bool _implementsValueEqualityType(ImplementsClause clause) {
    for (final NamedType interfaceType in clause.interfaces) {
      final DartType? type = interfaceType.type;
      if (type is InterfaceType) {
        if (_resolvesToValueEqualityType(type)) return true;
        continue;
      }
      if (_knownValueEqualityNames.contains(interfaceType.name.lexeme)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true when [node] already has a real, working equality
  /// contract, from any of three sources:
  ///
  /// 1. its `extends`/`with` clause resolves to a known value-equality type
  ///    (equality is genuinely inherited that way, unlike via `implements`);
  /// 2. it redeclares both `operator ==` and `hashCode` in its own body;
  /// 3. it inherits a hand-rolled `==`/`hashCode` pair from an ordinary
  ///    base class or mixin — see [_inheritsEqualityImplementation].
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
      if (member.isOperator && member.name.lexeme == _equalsOperatorName) {
        hasEquals = true;
      } else if (member.isGetter && member.name.lexeme == _hashCodeGetterName) {
        hasHashCode = true;
      }
    }
    if (hasEquals && hasHashCode) return true;

    // Last: equality that is real but INHERITED rather than written here.
    return _inheritsEqualityImplementation(node);
  }

  /// Returns true when [node] inherits a working, hand-rolled equality
  /// contract from an ordinary (non-Equatable) supertype.
  ///
  /// This was the rule's headline false positive: scanning only
  /// `node.bodyMembers` made inherited equality invisible, so
  /// `class UserId extends BaseValue implements Equatable` was flagged even
  /// though `BaseValue` hand-rolls `==`/`hashCode` and `extends` genuinely
  /// inherits that implementation. Equality is not broken there, so the
  /// diagnostic was simply wrong.
  ///
  /// Only implementation-bearing clauses are consulted:
  /// * the `extends` chain — walked transitively, because the declaring
  ///   ancestor may be several levels up;
  /// * the `with` clause — mixins copy implementation in.
  ///
  /// `implements` is pointedly NOT consulted: an interface declaring `==`
  /// contributes a signature only, which is the exact footgun this rule
  /// exists to report.
  bool _inheritsEqualityImplementation(ClassDeclaration node) {
    // Mixins are checked without a chain walk — a mixin that hand-rolls the
    // pair declares it directly; anything it inherits comes from its own
    // superclass constraint, which the class's extends chain already covers.
    final WithClause? withClause = node.withClause;
    if (withClause != null) {
      for (final NamedType mixinType in withClause.mixinTypes) {
        final DartType? type = mixinType.type;
        if (type is InterfaceType && _declaresEqualityPair(type.element)) {
          return true;
        }
      }
    }

    final DartType? extendsType = node.extendsClause?.superclass.type;
    if (extendsType is! InterfaceType) return false;

    // The analyzer's element model can hold a semantically invalid,
    // cyclic inheritance graph (documented on InterfaceElement.supertype),
    // so the visited set is a required infinite-loop guard, not a
    // micro-optimization.
    final Set<InterfaceElement> visited = <InterfaceElement>{};
    InterfaceElement? current = extendsType.element;
    while (current != null && visited.add(current)) {
      // Stop at Object: it declares == and hashCode for EVERY class, so
      // walking into it would make this check unconditionally true and
      // silence the rule entirely.
      if (_isCoreObject(current)) break;
      if (_declaresEqualityPair(current)) return true;
      current = current.supertype?.element;
    }
    return false;
  }

  /// Whether [element] itself declares BOTH `operator ==` and `hashCode`.
  /// Uses the declared-members lookups (not `lookUp*`), so inherited
  /// `Object.==` never counts — the chain walk handles inheritance
  /// explicitly and deliberately.
  bool _declaresEqualityPair(InterfaceElement element) =>
      element.getMethod(_equalsOperatorName) != null &&
      element.getGetter(_hashCodeGetterName) != null;

  /// Whether [element] is `dart:core`'s `Object`. Name alone is not enough
  /// — a project-local class may also be called `Object`.
  bool _isCoreObject(InterfaceElement element) =>
      element.name == 'Object' && element.library.uri.toString() == 'dart:core';
}
