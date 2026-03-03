// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace weak crypto identifier (md5, sha1) with sha256.
///
/// Uses the same algorithm set as [AvoidWeakCryptographicAlgorithmsRule].
class ReplaceWeakCryptoFix extends SaropaFixProducer {
  ReplaceWeakCryptoFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceWeakCryptoFix',
    50,
    'Replace with sha256',
  );

  /// Must match AvoidWeakCryptographicAlgorithmsRule._weakAlgorithms.
  static const _weak = <String>{'md5', 'sha1', 'MD5', 'SHA1'};

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final id = node is SimpleIdentifier
        ? node
        : node.thisOrAncestorOfType<SimpleIdentifier>();
    if (id == null || !_weak.contains(id.name)) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(id.offset, id.length),
        'sha256',
      );
    });
  }
}
