// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../../analyzer_compat.dart';
import '../../saropa_lint_rule.dart';

// ============================================================================
// INITIALIZER LIST ORDERING RULE
// ============================================================================
//
// Dart evaluates field initializers top-to-bottom according to the FIELD
// DECLARATION order in the class body, regardless of the order entries
// appear in a constructor's initializer list. A mismatched initializer-list
// order is therefore purely a readability trap: two orderings exist for the
// same information, and a reader checking "what does field X get
// initialized to" must cross-reference both.
// ============================================================================

/// Flags a constructor initializer list whose field-assignment entries are
/// ordered differently from the corresponding field declarations in the
/// enclosing class body.
///
/// Since: v15.4.0 | Updated: v15.4.0 | Rule version: v1
///
/// Only [ConstructorFieldInitializer] entries (`: field = expr`) are
/// compared against each other, in the relative order they appear in the
/// initializer list, against the relative order the same fields are
/// declared in the class. `assert(...)` initializers and `super(...)` /
/// `this(...)` redirecting calls are excluded from the comparison entirely
/// — they are not a field-declaration-order concept — so a list mixing
/// asserts with field assignments is only checked among the field
/// assignments.
///
/// **BAD:**
/// ```dart
/// class Point {
///   final int x;
///   final int y;
///
///   Point(int a, int b)
///       : y = b, // y initialized before x, but x is declared first
///         x = a;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Point {
///   final int x;
///   final int y;
///
///   Point(int a, int b)
///       : x = a, // matches declaration order
///         y = b;
/// }
/// ```
class InitializersOrderingRule extends SaropaLintRule {
  InitializersOrderingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention', 'readability'};

  @override
  RuleCost get cost => RuleCost.low;

  // Cheap pre-filter: only files with an initializer-list colon on a
  // constructor can possibly contain a violation. This skips parsing for
  // the large fraction of files with no constructors at all.
  @override
  Set<String>? get requiredPatterns => const {':'};

  @override
  String get exampleBad => 'Point(int a, int b) : y = b, x = a;';

  @override
  String get exampleGood => 'Point(int a, int b) : x = a, y = b;';

  static const LintCode _code = LintCode(
    'initializers_ordering',
    '[initializers_ordering] Constructor initializer list entries are not '
        'ordered to match the declaration order of the fields they assign. '
        'Dart already evaluates field initializers top-to-bottom by '
        'declaration order regardless of initializer-list order, so a '
        'mismatched list order is purely a readability trap: a reader '
        'checking what a field is initialized to must cross-reference two '
        'different orderings instead of scanning linearly. {v1}',
    correctionMessage:
        'Reorder the initializer-list field assignments to match the order '
        'the fields are declared in the class body.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      // Only ConstructorFieldInitializer entries participate in ordering —
      // assert(...) and super(...)/this(...) redirects are excluded by the
      // proposal's edge cases (they are not a field-declaration concept).
      final fieldInitializers = node.initializers
          .whereType<ConstructorFieldInitializer>()
          .toList();
      if (fieldInitializers.length < 2) return;

      final declOrder = _fieldDeclarationOrder(node);
      if (declOrder.isEmpty) return;

      // Map each initializer entry to its declaration index. Fields not
      // found in the enclosing class (e.g. inherited via `this.x` shorthand
      // used elsewhere, or a resolution edge case) are skipped from the
      // comparison rather than treated as a violation, since their true
      // position is unknown.
      final indices = <int>[];
      for (final initializer in fieldInitializers) {
        final fieldName = initializer.fieldName.name;
        final declIndex = declOrder[fieldName];
        if (declIndex == null) continue;
        indices.add(declIndex);
      }
      if (indices.length < 2) return;

      // A strictly non-decreasing sequence of declaration indices means the
      // initializer list already matches field-declaration order. Any
      // out-of-order pair means the list should be reordered; report on the
      // first initializer entry whose declaration index regresses.
      for (var i = 1; i < indices.length; i++) {
        if (indices[i] < indices[i - 1]) {
          reporter.atNode(fieldInitializers[i]);
          return;
        }
      }
    });
  }

  /// Builds a map of field name -> declaration index for every
  /// [FieldDeclaration] in the constructor's enclosing class body, in
  /// source order. Multiple variables in one `final int x, y;` declaration
  /// each get their own index, in the order they appear in that
  /// declaration, so `final int x, y;` still orders `x` before `y`.
  Map<String, int> _fieldDeclarationOrder(ConstructorDeclaration node) {
    // `node.parent` is NOT reliably the enclosing ClassDeclaration: in
    // analyzer 12's declaring-constructors AST, class members live under an
    // intermediate `ClassBody` (`BlockClassBody`) node, so a constructor's
    // direct parent is that body, not the class itself. Walk up via
    // thisOrAncestorOfType instead, which is stable across the analyzer
    // versions this package supports.
    final parent = node.thisOrAncestorOfType<ClassDeclaration>();
    if (parent == null) return const {};

    final order = <String, int>{};
    var index = 0;
    // Use the `.bodyMembers` compat shim (lib/src/analyzer_compat.dart)
    // rather than `.members` directly — ClassDeclaration no longer exposes
    // `.members` in analyzer 12 (members moved under `.body`), and older
    // pinned analyzer versions have their own quirks the shim absorbs.
    for (final member in parent.bodyMembers) {
      if (member is! FieldDeclaration) continue;
      for (final variable in member.fields.variables) {
        order[variable.name.lexeme] = index;
        index++;
      }
    }
    return order;
  }
}
