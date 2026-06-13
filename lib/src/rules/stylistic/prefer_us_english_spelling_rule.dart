// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../../saropa_lint_rule.dart';
import '../data/uk_to_us_spellings.dart';

/// Flags British spellings in comments and prose string literals so a project
/// can standardize on American English.
///
/// This is an **opinionated, opt-in** rule (stylistic tier — not enabled in any
/// correctness tier). American vs British spelling is a house-style choice, not
/// a correctness issue.
///
/// What is scanned:
/// - line, block, and doc comments,
/// - simple string literals that read like prose (contain a space) — single
///   token strings are skipped because they are usually identifiers, map keys,
///   enum names, or URIs where a British-looking spelling is often an external
///   API contract, not author prose.
///
/// What is skipped to avoid false positives:
/// - comments carrying an existing `ignore` or `cspell` directive,
/// - any comment or string containing a URL (`://`),
/// - import/export/part URIs.
///
/// The word list is generated from the project's single canonical spelling
/// dictionary (see `lib/src/rules/data/uk_to_us_spellings.dart`), so the rule
/// and the publish/commit-time audit never drift apart.
///
/// ## Bad Example (flagged)
/// ```dart
/// // Initialise the colour palette before the first paint.
/// final label = 'Saved your favourite colour';
/// ```
///
/// ## Good Example
/// ```dart
/// // Initialize the color palette before the first paint.
/// final label = 'Saved your favorite color';
/// ```
class PreferUsEnglishSpellingRule extends SaropaLintRule {
  PreferUsEnglishSpellingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => "// Initialise the colour palette";

  @override
  String get exampleGood => "// Initialize the color palette";

  static const LintCode _code = LintCode(
    'prefer_us_english_spelling',
    '[prefer_us_english_spelling] A British English spelling was found in a '
        'comment or prose string literal. This project standardizes on American '
        'English, so mixed spellings make text inconsistent and harder to search '
        '(for example a search for "color" misses "colour"). Replace the flagged '
        'word with its American spelling. {v1}',
    correctionMessage:
        'Replace the British spelling with the American English equivalent.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Matches runs of ASCII letters. British spellings are looked up word by
  /// word; the offset of each match maps directly into source because the scan
  /// runs over the raw lexeme, not an unescaped value.
  static final RegExp _wordPattern = RegExp(r'[A-Za-z]+');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Comments are not AST nodes, so walk the token stream and inspect each
    // token's preceding comment chain. The EOF token's comments are scanned
    // too so trailing file comments are not missed.
    context.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;
      while (token != null) {
        Token? comment = token.precedingComments;
        while (comment != null) {
          _scanComment(comment, reporter);
          comment = comment.next;
        }
        if (token.isEof) break;
        token = token.next;
      }
    });

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      _scanStringLiteral(node, reporter);
    });
  }

  /// Reports British spellings inside a single comment token.
  void _scanComment(Token comment, SaropaDiagnosticReporter reporter) {
    final String lexeme = comment.lexeme;
    final String lower = lexeme.toLowerCase();

    // Respect existing suppression conventions and skip URL-bearing comments
    // (a British-looking fragment in a link is not author prose).
    if (lower.contains('cspell') ||
        lower.contains('ignore') ||
        lower.contains('://')) {
      return;
    }

    _reportWords(lexeme, comment.offset, reporter);
  }

  /// Reports British spellings inside a prose string literal.
  void _scanStringLiteral(
    SimpleStringLiteral node,
    SaropaDiagnosticReporter reporter,
  ) {
    // Import/export/part URIs are not user-facing prose.
    if (node.parent is UriBasedDirective) return;

    final String value = node.value;

    // Prose heuristic: only multi-word strings are scanned. Single-token
    // strings are usually identifiers, keys, enum names, or URIs where a
    // British-looking spelling is frequently an external contract.
    if (!value.contains(' ')) return;
    if (value.contains('://')) return;

    // Scan the raw lexeme so offsets map to source (quotes, r-prefix, and
    // escapes are all preserved); the word regex only matches letters.
    _reportWords(node.literal.lexeme, node.literal.offset, reporter);
  }

  /// Finds each British word in [text] and reports its exact source span.
  ///
  /// [baseOffset] is the source offset of [text]'s first character, so the
  /// reported span covers only the offending word, not the whole comment or
  /// string.
  void _reportWords(
    String text,
    int baseOffset,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final Match match in _wordPattern.allMatches(text)) {
      final String word = match.group(0)!;
      final String? us = kUkToUsSpellings[word.toLowerCase()];
      if (us == null) continue;

      reporter.atOffset(
        offset: baseOffset + match.start,
        length: word.length,
      );
    }
  }
}
