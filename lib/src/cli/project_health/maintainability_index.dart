/// Maintainability Index (0..100) — the single sortable "headline" health score.
///
/// Uses the SEI/Microsoft formula: Halstead volume + cyclomatic complexity +
/// lines of code + comment ratio. Halstead volume is computed from the parser's
/// own token stream (no extra AST pass, no resolution), keeping it cheap.
/// Higher = more maintainable.
library;

import 'dart:math' as math;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Numeric/string literal token types treated as Halstead "operands" alongside
/// identifiers. Keywords and punctuation are "operators".
const Set<TokenType> _literalTypes = {
  TokenType.STRING,
  TokenType.INT,
  TokenType.DOUBLE,
  TokenType.HEXADECIMAL,
};

/// Halstead volume `N * log2(n)` where N = total operators+operands and
/// n = distinct operators+operands. Returns 0 for empty/unparseable input.
double halsteadVolume(String content) => halsteadVolumeFromUnit(
  parseString(content: content, throwIfDiagnostics: false).unit,
);

/// Like [halsteadVolume] but reuses an already-parsed [unit] (single parse).
double halsteadVolumeFromUnit(CompilationUnit unit) {
  final operators = <String>{};
  final operands = <String>{};
  var totalOperators = 0;
  var totalOperands = 0;

  Token? t = unit.beginToken;
  while (t != null && t.type != TokenType.EOF) {
    if (_isOperand(t)) {
      operands.add(t.lexeme);
      totalOperands++;
    } else {
      operators.add(t.lexeme);
      totalOperators++;
    }
    final next = t.next;
    if (next == null || identical(next, t)) break;
    t = next;
  }

  final vocabulary = operators.length + operands.length;
  final length = totalOperators + totalOperands;
  if (vocabulary == 0 || length == 0) return 0;
  return length * (math.log(vocabulary) / math.ln2);
}

bool _isOperand(Token t) {
  if (t.keyword != null) return false; // keywords are operators
  if (t.type == TokenType.IDENTIFIER) return true;
  return _literalTypes.contains(t.type);
}

/// Inputs to [maintainabilityIndex]. Bundled so the function takes one argument
/// rather than four positional values.
class MaintainabilityInputs {
  const MaintainabilityInputs({
    required this.halsteadVolume,
    required this.cyclomatic,
    required this.loc,
    required this.commentRatio,
  });

  final double halsteadVolume;

  /// Representative cyclomatic complexity for the file (the worst function).
  final int cyclomatic;

  final int loc;

  /// Comment lines as a fraction of total lines (0..1).
  final double commentRatio;
}

/// The 0..100 (clamped) Maintainability Index — the user-facing score.
double maintainabilityIndex(MaintainabilityInputs i) =>
    maintainabilityIndexRaw(i).clamp(0.0, 100.0);

/// The UNCLAMPED index: can go negative for very large/complex files. Used only
/// to RANK the worst-of-the-worst — the clamped score saturates at 0, so a
/// 5,000-line file and a 3,000-line file both read 0; the raw value separates
/// them. Not shown to users as a score.
double maintainabilityIndexRaw(MaintainabilityInputs i) {
  final volume = math.max(i.halsteadVolume, 1.0);
  final loc = math.max(i.loc, 1);
  final raw =
      171 -
      5.2 * math.log(volume) -
      0.23 * i.cyclomatic -
      16.2 * math.log(loc) +
      50 * math.sin(math.sqrt(2.4 * i.commentRatio));
  return raw * 100 / 171;
}
