import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../analyzer_compat.dart';
import '../../saropa_lint_rule.dart';

/// Warns when a class overrides both `operator ==` and `hashCode` while
/// still declaring one or more non-final (mutable) instance fields.
///
/// Since: v14.4.0 | Rule version: v2
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
/// Only mutable fields that are *actually referenced* inside the `==` or
/// `hashCode` body are flagged. The extremely common "identity key plus
/// mutable payload" shape — a `final` key used for equality alongside
/// mutable cache/bookkeeping fields deliberately excluded from the equality
/// contract — is correct code and is NOT reported.
///
/// **Known limitations (accepted tradeoffs, not defects):**
/// - Reference detection ([_findReferencedMutableFields]) is a structural
///   identifier scan of the `==` / `hashCode` bodies, not data-flow
///   analysis. A mutable field reached *indirectly* — read inside a helper
///   method that `==` calls, or through a getter that wraps the field — is
///   not seen, so that class is not reported (false negative). This
///   direction is chosen deliberately: at ERROR severity in the Essential
///   tier, a missed report costs a user nothing, whereas a false report on
///   correct code trains users to blanket-`// ignore:` the rule. The scan
///   also matches on name only, so a same-named local variable, parameter,
///   or unrelated method inside those bodies counts as a reference (an
///   over-report guard that can only make the rule *quieter* about nothing
///   — it never invents a field that does not exist on the class).
/// - The Equatable skip ([_extendsOrMixesInEquatable]) is a structural check
///   on the `extends`/`with` clause names, not a resolved-type check against
///   `package:equatable`. A project-local class/mixin that happens to be
///   named `Equatable`/`EquatableMixin` for unrelated reasons will also be
///   skipped (false negative). It also only looks at the *direct*
///   `extends`/`with` clause and does not check `implements Equatable` or
///   transitive inheritance (`class B extends A` where `A extends
///   Equatable`) — both are legal but unusual ways to reach Equatable and
///   are not recognized here.
/// - Mutable fields are only collected from the class that declares
///   `==`/`hashCode` itself ([_findMutableFields] walks `node.bodyMembers`
///   only); a mutable field inherited from a plain (non-Equatable)
///   superclass and referenced by a subclass's `==`/`hashCode` is not
///   detected (false negative).
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
///
/// **GOOD** (mutable payload deliberately excluded from equality):
/// ```dart
/// class CacheEntry {
///   CacheEntry(this.key, this.value);
///   final String key;
///   dynamic value;          // mutated constantly, not part of equality
///   DateTime? lastAccessed; // bookkeeping, not part of equality
///
///   @override
///   bool operator ==(Object other) => other is CacheEntry && other.key == key;
///
///   @override
///   int get hashCode => key.hashCode;
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
    'avoid_equals_and_hash_code_on_mutable_classes_extended',
    '[avoid_equals_and_hash_code_on_mutable_classes_extended] This non-final '
        'instance field is read by the hand-written operator == or hashCode '
        'of its class. == and hashCode must stay consistent with an '
        "object's state for as long as it lives inside a hash-based "
        'collection (HashSet, HashMap, a Set, or a Map key). Mutating a '
        'field the equality contract depends on, after the object is '
        'inserted, silently corrupts the collection: lookups fail, '
        'duplicates appear, and remove() stops working, producing '
        'intermittent bugs that are rarely caught by tests that do not '
        'mutate-then-query. Mutable fields that == and hashCode ignore are '
        'not reported. {v2}',
    correctionMessage:
        'Make this field final, drop it from == and hashCode so the equality '
        'contract only depends on immutable state, or stop overriding == and '
        'hashCode on this mutable class. Making fields final may require a '
        'copyWith method for updates.',
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

      // Only mutable fields the equality contract actually depends on are a
      // defect. Flagging every mutable field (the rule's original v1
      // behavior) false-positived on the idiomatic "final identity key plus
      // mutable payload" shape — e.g. a cache entry whose `value` and
      // `lastAccessed` are deliberately excluded from `==`. At ERROR
      // severity in the Essential tier that trained users to blanket-ignore
      // the rule, so detection is narrowed to referenced fields only.
      final List<VariableDeclaration> mutableFields =
          _findReferencedMutableFields(node, equalsMethod, hashCodeGetter);
      if (mutableFields.isEmpty) return;

      for (final VariableDeclaration field in mutableFields) {
        reporter.atNode(field);
      }
    });
  }

  /// Returns true if [node] extends `Equatable` or mixes in
  /// `EquatableMixin`, in which case the dedicated Equatable rule already
  /// covers the mutable-field defect.
  ///
  /// Structural/name-based only (see class-level "Known limitations" doc):
  /// checks the direct `extends`/`with` clause's simple name, not a
  /// resolved type against `package:equatable`, and does not follow
  /// `implements` or transitive `extends` chains.
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

  /// Collects the non-final, non-static instance fields of [node] whose name
  /// appears somewhere inside the body of [equalsMethod] or [hashCodeGetter].
  ///
  /// A mutable field that neither member reads cannot break the equality
  /// contract — mutating it changes nothing that `==`/`hashCode` observe — so
  /// excluding it is what keeps the "identity key plus mutable payload"
  /// pattern quiet. See the class-level "Known limitations" for the
  /// indirection false negative this structural scan accepts.
  List<VariableDeclaration> _findReferencedMutableFields(
    ClassDeclaration node,
    MethodDeclaration equalsMethod,
    MethodDeclaration hashCodeGetter,
  ) {
    // Names mentioned anywhere in either body. Collected once so the field
    // loop below is a set lookup rather than a re-walk per field.
    final Set<String> referenced = _collectIdentifierNames(<AstNode?>[
      equalsMethod.body,
      hashCodeGetter.body,
    ]);
    if (referenced.isEmpty) return const <VariableDeclaration>[];

    final List<VariableDeclaration> mutableFields = <VariableDeclaration>[];
    for (final ClassMember member in node.bodyMembers) {
      // `isFinal` is true for `late final`, so those are correctly treated as
      // immutable; `isConst` fields are implicitly static but are excluded
      // explicitly for clarity.
      if (member is! FieldDeclaration ||
          member.isStatic ||
          member.fields.isFinal ||
          member.fields.isConst) {
        continue;
      }
      for (final VariableDeclaration variable in member.fields.variables) {
        if (referenced.contains(variable.name.lexeme)) {
          mutableFields.add(variable);
        }
      }
    }
    return mutableFields;
  }

  /// Returns every simple identifier name appearing in [roots].
  ///
  /// Walking raw identifiers deliberately catches BOTH access shapes a
  /// hand-written `==` uses for the same field: the bare `field` reference on
  /// `this`, and the `other.field` property access (whose property name is
  /// itself a [SimpleIdentifier]). Names of unrelated locals, parameters and
  /// methods are swept up too — harmless, because the result is only ever
  /// intersected with the class's own declared field names.
  Set<String> _collectIdentifierNames(List<AstNode?> roots) {
    final _IdentifierNameCollector collector = _IdentifierNameCollector();
    for (final AstNode? root in roots) {
      root?.accept(collector);
    }
    return collector.names;
  }
}

/// Gathers the lexemes of all [SimpleIdentifier]s under a subtree.
///
/// A recursive visitor is used instead of a source-text scan so that
/// identifiers inside comments and string literals — which do not read the
/// field — cannot suppress a real diagnostic.
class _IdentifierNameCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}
