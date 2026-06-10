import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:test/test.dart';

/// Unit tests for the pure-AST bounds-guard recognition in [AvoidSubstringRule].
///
/// The rule's report path is gated on `isDartCoreString` (a resolved-type
/// check), so end-to-end firing cannot be exercised on an unresolved
/// `parseString` AST or by the scan CLI. The guard logic itself, however, is
/// entirely syntactic, so [AvoidSubstringRule.guardsBoundsForTesting] is tested
/// directly here. `true` = the call is recognized as in-bounds (NO lint);
/// `false` = unguarded (the rule would report).
void main() {
  // Finds the first `.substring(...)` invocation in a parsed snippet.
  MethodInvocation firstSubstring(String body) {
    final unit = parseString(content: body, throwIfDiagnostics: false).unit;
    final finder = _SubstringFinder();
    unit.accept(finder);
    return finder.found!;
  }

  bool guarded(String body) =>
      AvoidSubstringRule.guardsBoundsForTesting(firstSubstring(body));

  group('avoid_string_substring guard recognition — NO lint (guarded)', () {
    test('else-branch of indexOf ternary (< 0)', () {
      expect(
        guarded('''
String f(String local) {
  final int i = local.indexOf('+');
  return i < 0 ? local : local.substring(0, i);
}
'''),
        isTrue,
      );
    });

    test('else-branch of indexOf ternary (== -1)', () {
      expect(
        guarded('''
String f(String raw) {
  final int n = raw.indexOf('\\n');
  return n == -1 ? raw : raw.substring(0, n);
}
'''),
        isTrue,
      );
    });

    test('substring inside the if condition', () {
      expect(
        guarded('''
void f(String rawOp, RegExp r) {
  final int dotIndex = rawOp.indexOf('.');
  if (dotIndex > 0 && r.hasMatch(rawOp.substring(0, dotIndex))) {
    use();
  }
}
'''),
        isTrue,
      );
    });

    test('isEmpty ternary guard (literal index)', () {
      expect(
        guarded("String f(String t) => t.isEmpty ? t : t.substring(1);"),
        isTrue,
      );
    });

    test('isNotEmpty ternary guard', () {
      expect(
        guarded(
          "String f(String n) => n.isNotEmpty ? n.substring(0, 1) : '?';",
        ),
        isTrue,
      );
    });

    test('startsWith early-exit guard, literal index', () {
      expect(
        guarded('''
String? f(String fragment) {
  if (!fragment.startsWith('p/')) return null;
  return fragment.substring(2);
}
'''),
        isTrue,
      );
    });

    test('isEmpty early-return guard, then literal-index slice', () {
      expect(
        guarded('''
String f(String content) {
  if (content.isEmpty) return content;
  return content.substring(1);
}
'''),
        isTrue,
      );
    });

    test('startsWith early-exit + prefix.length arg (PrefixedIdentifier)', () {
      expect(
        guarded('''
String? f(String value, String prefix) {
  if (!value.startsWith(prefix)) return null;
  return value.substring(prefix.length);
}
'''),
        isTrue,
      );
    });

    test('match.start arg (PropertyAccess) after null guard', () {
      expect(
        guarded('''
String f(String text, RegExp marker) {
  final RegExpMatch? match = marker.firstMatch(text);
  if (match == null) return text;
  return text.substring(0, match.start);
}
'''),
        isTrue,
      );
    });

    test('regex hasMatch format guard early-exit', () {
      expect(
        guarded('''
int? f(String key, RegExp pattern) {
  if (!pattern.hasMatch(key)) return null;
  return int.tryParse(key.substring(0, 2));
}
'''),
        isTrue,
      );
    });

    test('post-loop slice bounded by a preceding while', () {
      expect(
        guarded('''
String f(String source, int start) {
  int i = start;
  while (i < source.length) {
    i++;
  }
  return source.substring(start, i);
}
'''),
        isTrue,
      );
    });

    test('then-branch of ternary (regression guard)', () {
      expect(
        guarded("String f(String s, int i) => i > 0 ? s.substring(0, i) : s;"),
        isTrue,
      );
    });
  });

  group('avoid_string_substring guard recognition — LINT (unguarded)', () {
    test('no guard at all', () {
      expect(guarded("String f(String s) => s.substring(2);"), isFalse);
    });

    test('ternary condition unrelated to the index', () {
      expect(
        guarded(
          "String f(String s, int i, bool flag) => "
          "flag ? s : s.substring(0, i);",
        ),
        isFalse,
      );
    });
  });
}

/// Captures the first `.substring(...)` invocation encountered.
class _SubstringFinder extends RecursiveAstVisitor<void> {
  MethodInvocation? found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found == null && node.methodName.name == 'substring') {
      found = node;
    }
    super.visitMethodInvocation(node);
  }
}
