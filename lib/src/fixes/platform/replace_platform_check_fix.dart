// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with defaultTargetPlatform
class ReplacePlatformCheckFix extends SaropaFixProducer {
  ReplacePlatformCheckFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replacePlatformCheckFix',
    50,
    'Replace with defaultTargetPlatform',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is PrefixedIdentifier
        ? node
        : node.thisOrAncestorOfType<PrefixedIdentifier>();
    if (target == null) return;

    // Map Platform.isXxx to defaultTargetPlatform check
    final source = target.toSource();
    final platformMap = <String, String>{
      'Platform.isAndroid': 'defaultTargetPlatform == TargetPlatform.android',
      'Platform.isIOS': 'defaultTargetPlatform == TargetPlatform.iOS',
      'Platform.isLinux': 'defaultTargetPlatform == TargetPlatform.linux',
      'Platform.isMacOS': 'defaultTargetPlatform == TargetPlatform.macOS',
      'Platform.isWindows': 'defaultTargetPlatform == TargetPlatform.windows',
      'Platform.isFuchsia': 'defaultTargetPlatform == TargetPlatform.fuchsia',
    };
    final replacement = platformMap[source];
    if (replacement == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
