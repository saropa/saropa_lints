// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Documentation-completeness rule for `enum` declarations and their
/// constants.
///
/// This mirrors `require_public_api_documentation` (classes/methods) but
/// covers enums specifically, since enum declarations and enum values are
/// public API surface just as much as classes and methods, yet were
/// previously not checked by any documentation rule in this package.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a public `enum` declaration or one of its constants lacks a
/// DartDoc comment.
///
/// Since: v14.4.0 | Rule version: v1
///
/// Enum constants are public API exactly like class members: IDE tooltips
/// and pub.dev API docs only surface useful information when a DartDoc
/// comment exists. Undocumented enum values are common because they read
/// as "self-explanatory" at write time but leave future readers guessing
/// at intent, valid ranges, or when to choose one value over another. This
/// rule checks the enum declaration and each of its constants
/// independently — an enhanced enum can document its members while still
/// missing docs on individual values, or vice versa. Private enums (names
/// starting with `_`) are not public API and are skipped, matching
/// `require_public_api_documentation`'s treatment of private classes.
///
/// **BAD:**
/// ```dart
/// enum OrderStatus {
///   pending,
///   shipped,
///   canceled,
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Lifecycle states for a customer order.
/// enum OrderStatus {
///   /// Order has been placed but not yet shipped.
///   pending,
///
///   /// Order has left the warehouse.
///   shipped,
///
///   /// Order was canceled before shipping.
///   canceled,
/// }
/// ```
class DocumentEnumRule extends SaropaLintRule {
  DocumentEnumRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code, same
  /// bucket as the sibling `require_public_api_documentation` rule.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'documentation'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'document_enum',
    '[document_enum] Public enum or enum value is missing a DartDoc '
        'comment. Enum constants are public API exactly like class '
        'members — IDE tooltips and generated API docs only show useful '
        'information when a doc comment exists, and undocumented values '
        'leave future readers guessing at intent or when to choose one '
        'value over another. {v1}',
    correctionMessage:
        'Add a /// doc comment above the enum declaration and/or the '
        'enum constant explaining its purpose.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addEnumDeclaration((EnumDeclaration node) {
      // Skip private enums — not public API, matches
      // require_public_api_documentation's private-class handling.
      if (node.nameToken.lexeme.startsWith('_')) return;

      // Enum declaration itself must be documented.
      if (node.documentationComment == null) {
        reporter.atNode(node);
      }

      // Each constant is checked independently: an enhanced enum can
      // document its declaration while individual values remain
      // undocumented, per the proposal's "Edge Cases" #3.
      for (final EnumConstantDeclaration constant in node.bodyConstants) {
        if (constant.documentationComment == null) {
          reporter.atNode(constant);
        }
      }
    });
  }
}
