// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces the mixin name token `TickerProviderStateMixin` with
/// `SingleTickerProviderStateMixin`.
///
/// Matches [PreferSingleTickerProviderStateMixinRule] diagnostics. The
/// replacement is a pure rename: both mixins live in
/// `package:flutter/widgets.dart` and share the `vsync: this` protocol, so no
/// import or argument restructuring is needed.
class PreferSingleTickerProviderStateMixinFix extends SaropaFixProducer {
  PreferSingleTickerProviderStateMixinFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferSingleTickerProviderStateMixin',
    80,
    'Replace TickerProviderStateMixin with SingleTickerProviderStateMixin',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Diagnostic is reported at the NamedType inside the WithClause; the
    // covering node is usually that NamedType or an identifier inside it.
    final AstNode? node = coveringNode;
    if (node == null) return;

    final NamedType? namedType = node is NamedType
        ? node
        : node.thisOrAncestorOfType<NamedType>();
    if (namedType == null) return;

    // Guard: only rewrite when we are still targeting the plural mixin. If
    // the user already swapped it, the fix is a no-op rather than a surprise.
    if (namedType.name.lexeme != 'TickerProviderStateMixin') return;

    await builder.addDartFileEdit(file, (b) {
      // Replace just the identifier token; surrounding `with`/`,` context is
      // preserved so multi-mixin clauses rewrite cleanly.
      b.addSimpleReplacement(
        SourceRange(namedType.name.offset, namedType.name.length),
        'SingleTickerProviderStateMixin',
      );
    });
  }
}
