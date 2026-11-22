import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:saropa_lints/src/rules/data/type_rules.dart';
import 'package:test/test.dart';

/// Collects the token for [name] from parsed [source] (real scanner tokens).
Token _tokenNamed(String source, String name) {
  Token? t = parseString(
    content: source,
    throwIfDiagnostics: false,
  ).unit.beginToken;
  while (t != null && !t.isEof) {
    if (t.lexeme == name) return t;
    t = t.next;
  }
  throw StateError('token $name not found');
}

void main() {
  // Reproducer from plans/history/2026.11/2026.11.21/invalid_field_name_false_positive.md: `when` is a
  // contextual keyword and a legal record field name; it must NOT be flagged.
  const src = 'final ({DateTime when, bool isMoved}) fit = f();';

  test('contextual keyword `when` is not a reserved keyword label', () {
    expect(
      InvalidRecordFieldNameRule.isReservedKeywordToken(
        _tokenNamed(src, 'when'),
      ),
      isFalse,
    );
  });

  test('ordinary identifier is not flagged', () {
    expect(
      InvalidRecordFieldNameRule.isReservedKeywordToken(
        _tokenNamed(src, 'isMoved'),
      ),
      isFalse,
    );
  });

  // Positive case: genuine reserved words must still be detected, so the
  // fix does not silently disable the rule.
  test('reserved word `class` is still flagged', () {
    expect(
      InvalidRecordFieldNameRule.isReservedKeywordToken(
        _tokenNamed('class A {}', 'class'),
      ),
      isTrue,
    );
  });
}
