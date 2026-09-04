import 'package:analyzer/dart/ast/ast.dart';

import '../../analyzer_compat.dart';
import '../../saropa_lint_rule.dart';

/// Warns when a class overrides both `operator ==` and `hashCode` while
/// still declaring one or more non-final (mutable) instance fields.
///
/// Since: v14.4.0 | Rule version: v1
///
/// `==` and `hashCode` are contractually required to stay in sync with the
/// object's observable state for the lifetime the object spends in a
/// hash-based collection (`HashSet`, `HashMap`, as a `Map` key, in a `Set`).
/// If a field used by either method is mutable, changing it after insertion
/// silently corrupts the collection: lookups fail, duplicates appear, and
/// `remove()` stops working. These bugs are intermittent, hard to
/// reproduce, and rarely caught by unit tests that don't mutate-then-query.
///
/// This is a general-purpose counterpart to `avoid_mutable_field_in_equatable`
/// (`lib/src/rules/packages/equatable_rules.dart`), which only covers classes
/// that extend `Equatable`/mix in `EquatableMixin`. Classes that already use
/// Equatable are skipped here to avoid duplicate diagnostics; use the
/// Equatable-specific rule for that case.
///
/// **BAD:**
/// ```dart
/// class Point {
///   Point(this.x, this.y);
///   int x; // mutable
///   int y;
///
///   @override
///   bool operator ==(Object other) =>
///       other is Point && other.x == x && other.y == y;
///
///   @override
///   int get hashCode => Object.hash(x, y);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Point {
///   const Point(this.x, this.y);
///   final int x;
///   final int y;
///
///   @override
///   bool operator ==(Object other) =>
///       other is Point && other.x == x && other.y == y;
///
///   @override
///   int get hashCode => Object.hash(x, y);
/// }
/// ```
class AvoidEqualsAndHashCodeOnMutableClassesRule extends SaropaLintRule {
  AvoidEqualsAndHashCodeOnMutableClassesRule() : super(code: _code);

  /// Correctness bug: hash-based collections silently corrupt when a key's
  /// `==`/`hashCode` inputs mutate after insertion.
  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'correctness'};

  @override
  RuleCost get cost => RuleCost.medium;

  // Cheap pre-filter: both members must textually appear before we pay for
  // an AST walk of the class body.
  @override
  Set<String>? get requiredPatterns => const <String>{'hashCode'};

  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'avoid_equals_and_hash_code_on_mutable_classes',
    '[avoid_equals_and_hash_code_on_mutable_classes] Class overrides both '
        'operator == and hashCode but declares one or more non-final '
        'instance fields. == and hashCode must stay consistent with an '
        "object's state for as long as it lives inside a hash-based "
        'collection (HashSet, HashMap, a Set, or a Map key). Mutating a '
        'field after the object is inserted silently corrupts the '
        'collection: lookups fail, duplicates appear, and remove() stops '
        'working, producing intermittent bugs that are rarely caught by '
        'tests that do not mutate-then-query. {v1}',
    correctionMessage:
        'Make the fields referenced by == and hashCode final, or stop '
        'overriding == and hashCode on this mutable class. Making fields '
        'final may require a copyWith method for updates.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Skip classes already covered by the Equatable-specific rule
      // (avoid_mutable_field_in_equatable) to avoid duplicate diagnostics.
      if (_extendsOrMixesInEquatable(node)) return;

      // Structural check (not string matching) for a hand-written `==`.
      final MethodDeclaration? equalsMethod = _findEqualsOperator(node);
      if (equalsMethod == null) return;

      // Structural check for a hand-written `hashCode` getter.
      final MethodDeclaration? hashCodeGetter = _findHashCodeGetter(node);
      if (hashCodeGetter == null) return;

      // Collect non-final, non-static instance fields. Conservative: any
      // such field is flagged, matching the sibling Equatable rule's
      // approach rather than attempting data-flow analysis of which fields
      // are actually read inside == / hashCode.
      final List<VariableDeclaration> mutableFields = _findMutableFields(
        node,
      );
      if (mutableFields.isEmpty) return;

      for (final VariableDeclaration field in mutableFields) {
        reporter.atNode(field);
      }
    });
  }

  /// Returns true if [node] extends `Equatable` or mixes in
  /// `EquatableMixin`, in which case the dedicated Equatable rule already
  /// covers the mutable-field defect.
  bool _extendsOrMixesInEquatable(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'Equatable') {
      return true;
    }

    final WithClause? withClause = node.withClause;
    if (withClause != null) {
      for (final NamedType mixin in withClause.mixinTypes) {
        if (mixin.name.lexeme == 'EquatableMixin') return true;
      }
    }

    return false;
  }

  /// Finds a hand-written `operator ==` declaration on the class body.
  MethodDeclaration? _findEqualsOperator(ClassDeclaration node) {
    for (final ClassMember member in node.bodyMembers) {
      if (member is MethodDeclaration &&
          member.isOperator &&
          member.name.lexeme == '==') {
        return member;
      }
    }
    return null;
  }

  /// Finds a hand-written `hashCode` getter on the class body.
  MethodDeclaration? _findHashCodeGetter(ClassDeclaration node) {
    for (final ClassMember member in node.bodyMembers) {
      if (member is MethodDeclaration &&
          member.isGetter &&
          member.name.lexeme == 'hashCode') {
        return member;
      }
    }
    return null;
  }

  /// Collects non-final, non-static instance field declarations.
  List<VariableDeclaration> _findMutableFields(ClassDeclaration node) {
    final List<VariableDeclaration> mutableFields = <VariableDeclaration>[];
    for (final ClassMember member in node.bodyMembers) {
      if (member is FieldDeclaration &&
          !member.isStatic &&
          !member.fields.isFinal &&
          !member.fields.isConst) {
        mutableFields.addAll(member.fields.variables);
      }
    }
    return mutableFields;
  }
}
