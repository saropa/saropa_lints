// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';
import '../../rules/widget/flutter_migration_widget_detection.dart';

/// Replaces `Key? key` + `super(key: key)` with `super.key` on widget constructors.
///
/// Uses [PreferSuperKeyDetection] so edits match [PreferSuperKeyRule] exactly.
class PreferSuperKeyFix extends SaropaFixProducer {
  PreferSuperKeyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferSuperKey',
    80,
    'Use super.key',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final ConstructorDeclaration? ctor = node
        .thisOrAncestorOfType<ConstructorDeclaration>();
    if (ctor == null || ctor.factoryKeyword != null) return;

    final FormalParameter? keyParam =
        PreferSuperKeyDetection.findKeyTypedKeyParameter(ctor);
    if (keyParam == null) return;

    final SuperConstructorInvocation? superKeyOnly =
        PreferSuperKeyDetection.soleSuperKeyForwarding(ctor);
    if (superKeyOnly == null) return;

    await builder.addDartFileEdit(file, (editBuilder) {
      if (ctor.initializers.length == 1) {
        final Token? separator = ctor.separator;
        if (separator != null) {
          editBuilder.addDeletion(
            SourceRange(separator.offset, superKeyOnly.end - separator.offset),
          );
        }
      } else {
        final int idx = ctor.initializers.indexOf(superKeyOnly);
        if (idx >= 0) {
          int start;
          int end;
          if (idx > 0) {
            start = ctor.initializers[idx - 1].end;
            end = superKeyOnly.end;
          } else {
            start = superKeyOnly.offset;
            end = ctor.initializers[idx + 1].offset;
          }
          editBuilder.addDeletion(SourceRange(start, end - start));
        }
      }
      editBuilder.addSimpleReplacement(
        SourceRange(keyParam.offset, keyParam.length),
        'super.key',
      );
    });
  }
}
