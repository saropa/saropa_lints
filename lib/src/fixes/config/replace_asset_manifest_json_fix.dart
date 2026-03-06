// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace 'AssetManifest.json' with 'AssetManifest.bin'.
///
/// Matches [AvoidAssetManifestJsonRule]. Uses the binary manifest path
/// as the replacement; the rule doc also suggests AssetManifest API.
class ReplaceAssetManifestJsonFix extends SaropaFixProducer {
  ReplaceAssetManifestJsonFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceAssetManifestJson',
    50,
    "Replace with 'AssetManifest.bin'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final SimpleStringLiteral? literal = node is SimpleStringLiteral
        ? (node.value == 'AssetManifest.json' ? node : null)
        : node.thisOrAncestorOfType<SimpleStringLiteral>();
    if (literal == null || literal.value != 'AssetManifest.json') return;

    final String replacement =
        literal.isSingleQuoted ? "'AssetManifest.bin'" : '"AssetManifest.bin"';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(literal.offset, literal.length),
        replacement,
      );
    });
  }
}
