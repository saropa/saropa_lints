// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Inserts `from: 0.0` into an empty `.forward()` call.
///
/// Matches [PreferAnimationControllerForwardFromZeroRule] diagnostics. The
/// rule only fires on calls with an empty argument list (no positional or
/// named args), so this fix never has to rewrite or merge existing arguments —
/// it just fills the empty parens.
class PreferAnimationControllerForwardFromZeroFix extends SaropaFixProducer {
  PreferAnimationControllerForwardFromZeroFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferAnimationControllerForwardFromZero',
    80,
    "Restart from zero with forward(from: 0.0)",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Diagnostic is reported at the MethodInvocation for `.forward()`; the
    // covering node can be the invocation itself, its method name identifier,
    // or the argument list depending on where the cursor lands.
    final AstNode? node = coveringNode;
    if (node == null) return;

    final MethodInvocation? call = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (call == null) return;

    // Guard: only rewrite if we are still on a `.forward()` call. The rule
    // never flags anything else, but a user might re-apply the fix after
    // they partially edited the source.
    if (call.methodName.name != 'forward') return;

    // Guard: only rewrite when the argument list is empty. If the user has
    // already added an argument (including `from: 0.0`), bail out instead
    // of producing double arguments.
    final ArgumentList args = call.argumentList;
    if (args.arguments.isNotEmpty) return;

    await builder.addDartFileEdit(file, (b) {
      // Insert the named argument between the parens. The argument list
      // source range spans `(` to `)` inclusive, so targeting
      // `leftParenthesis.end` places the text immediately after the `(`.
      b.addSimpleInsertion(args.leftParenthesis.end, 'from: 0.0');
    });
  }
}
