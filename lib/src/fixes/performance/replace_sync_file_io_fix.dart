// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace synchronous file I/O method name with async equivalent.
///
/// Matches [AvoidSynchronousFileIoRule]. Replaces the method name only
/// (e.g. `readAsStringSync` → `readAsString`). Callers must add `await` when
/// in an async context; this fix does not insert `await`.
///
/// **For developers:** Uses the same method set as the rule's _syncMethods.
/// No async/await analysis; single source-range replacement only.
class ReplaceSyncFileIoFix extends SaropaFixProducer {
  ReplaceSyncFileIoFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceSyncFileIoFix',
    50,
    'Use async file operation',
  );

  static const Map<String, String> _syncToAsync = <String, String>{
    'readAsStringSync': 'readAsString',
    'readAsBytesSync': 'readAsBytes',
    'readAsLinesSync': 'readAsLines',
    'writeAsStringSync': 'writeAsString',
    'writeAsBytesSync': 'writeAsBytes',
    'existsSync': 'exists',
    'createSync': 'create',
    'deleteSync': 'delete',
    'copySync': 'copy',
    'renameSync': 'rename',
    'statSync': 'stat',
    'listSync': 'list',
  };

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;

    final String name = invocation.methodName.name;
    final String? replacement = _syncToAsync[name];
    if (replacement == null) return;

    final SimpleIdentifier methodId = invocation.methodName;
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(methodId.offset, methodId.length),
        replacement,
      );
    });
  }
}
