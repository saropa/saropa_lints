import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/platforms/window_postmessage_scheduling_args.dart';
import 'package:test/test.dart';

/// Unit tests for [windowPostMessageArgsLookLikeSchedulingHack].
///
/// Covers "before" scheduling-hack shapes vs "after" / benign shapes without
/// requiring a resolved `dart:html` SDK binding (that is covered by the
/// example fixture + plugin integration).
void main() {
  group('windowPostMessageArgsLookLikeSchedulingHack', () {
    test('true for postMessage("", "*")', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w) {
  w.postMessage('', '*');
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isTrue);
    });

    test('true for postMessage(null, "*")', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w) {
  w.postMessage(null, '*');
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isTrue);
    });

    test('true when third arg is empty list (no message ports)', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w) {
  w.postMessage('', '*', []);
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isTrue);
    });

    test('false when third arg is non-empty list (likely real ports)', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w) {
  w.postMessage('', '*', [x]);
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isFalse);
    });

    test('false for non-empty message (real payload)', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w) {
  w.postMessage('ping', '*');
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isFalse);
    });

    test('false for explicit origin string (not wildcard)', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w) {
  w.postMessage('', 'https://example.com');
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isFalse);
    });

    test('false for dynamic second arg (not a string literal)', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w, String o) {
  w.postMessage('', o);
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isFalse);
    });

    test('false for other method names', () {
      final inv = _firstMethodNamed('send', r'''
void f(dynamic w) {
  w.send('', '*');
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isFalse);
    });

    test('false when fewer than two positional arguments', () {
      final inv = _firstPostMessageInvocation(r'''
void f(dynamic w) {
  w.postMessage('');
}
''');
      expect(windowPostMessageArgsLookLikeSchedulingHack(inv), isFalse);
    });
  });
}

MethodInvocation _firstPostMessageInvocation(String source) =>
    _firstMethodNamed('postMessage', source);

MethodInvocation _firstMethodNamed(String name, String source) {
  final parseResult = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final finder = _MethodByNameFinder(name);
  parseResult.unit.accept(finder);
  final MethodInvocation? found = finder.found;
  if (found == null) {
    throw StateError('No MethodInvocation named $name in source');
  }
  return found;
}

final class _MethodByNameFinder extends RecursiveAstVisitor<void> {
  _MethodByNameFinder(this.targetName);

  final String targetName;
  MethodInvocation? found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == targetName) {
      found = node;
      return;
    }
    super.visitMethodInvocation(node);
  }
}
