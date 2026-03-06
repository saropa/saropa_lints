// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add missing inlining pragma (vm:prefer-inline or dart2js:tryInline).
///
/// Matches [PreferBothInliningAnnotationsRule].
class AddMissingInliningPragmaFix extends SaropaFixProducer {
  AddMissingInliningPragmaFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addMissingInliningPragma',
    50,
    'Add missing inlining pragma',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final Declaration? decl = node.thisOrAncestorOfType<MethodDeclaration>() ??
        node.thisOrAncestorOfType<FunctionDeclaration>();
    if (decl == null) return;

    final NodeList<Annotation> metadata = switch (decl) {
      MethodDeclaration(:final metadata) => metadata,
      FunctionDeclaration(:final metadata) => metadata,
      _ => throw StateError('unreachable'),
    };

    bool hasVm = false;
    bool hasDart2js = false;
    for (final Annotation a in metadata) {
      if (a.name.name != 'pragma') continue;
      final arg = a.arguments?.arguments.firstOrNull;
      if (arg is! SimpleStringLiteral) continue;
      final v = arg.value;
      if (v == 'vm:prefer-inline' || v == 'vm:never-inline') hasVm = true;
      if (v == 'dart2js:tryInline' || v == 'dart2js:noInline') {
        hasDart2js = true;
      }
    }

    final String pragma = hasVm && !hasDart2js
        ? "@pragma('dart2js:tryInline')"
        : !hasVm && hasDart2js
            ? "@pragma('vm:prefer-inline')"
            : '';
    if (pragma.isEmpty) return;

    final int insertOffset =
        metadata.isNotEmpty ? metadata.last.end : decl.offset;
    final String prefix = metadata.isNotEmpty ? '\n  ' : '';
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(insertOffset, '$prefix$pragma\n  ');
    });
  }
}
