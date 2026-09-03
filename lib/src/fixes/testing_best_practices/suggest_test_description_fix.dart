// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: suggest a conventional test description.
///
/// Walks the test body's AST to find expect() matcher identifiers
/// (not string-matching on source), picks a verb, then prefixes the
/// existing description with "should [verb] [original]".
///
/// Supports bulk application via [CorrectionApplicability.acrossFiles].
class SuggestTestDescriptionFix extends SaropaFixProducer {
  SuggestTestDescriptionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.suggestTestDescription',
    50,
    'Add conventional test description prefix',
  );

  /// Matchers mapped to action verbs for the description prefix.
  /// Keys are lowercase identifier names from expect() matcher arguments.
  static const Map<String, String> _matcherToVerb = {
    'istrue': 'accept',
    'isfalse': 'reject',
    'isempty': 'return empty result for',
    'isnotempty': 'return non-empty result for',
    'isnull': 'return null for',
    'isnotnull': 'return value for',
    'throwsa': 'throw when given',
    'throwsexception': 'throw when given',
    'throwsargumenterror': 'throw ArgumentError for',
    'throwsstateerror': 'throw StateError for',
  };

  @override
  FixKind get fixKind => _fixKind;

  /// Bulk-applicable: all flagged descriptions in the file get fixed at once.
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossFiles;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The diagnostic targets the string literal (first arg of test/testWidgets)
    final descriptionNode = _resolveStringLiteral(node);
    if (descriptionNode == null) return;

    final originalDescription = descriptionNode.stringValue ?? '';
    if (originalDescription.isEmpty) return;

    // Walk up to the test() MethodInvocation to inspect the body
    final testCall = descriptionNode.thisOrAncestorOfType<MethodInvocation>();
    if (testCall == null) return;

    // AST-walk the test body to find expect() matcher identifiers
    final verb = _inferVerbFromAst(testCall);

    // Build the suggested description
    final suggested = 'should $verb $originalDescription';

    // Preserve the original quote style and escape accordingly
    final replacement = _buildQuotedString(descriptionNode, suggested);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(descriptionNode.offset, descriptionNode.length),
        replacement,
      );
    });
  }

  /// Resolve the covering node to a StringLiteral, handling the case
  /// where the node is the literal itself or a parent wrapping it.
  StringLiteral? _resolveStringLiteral(AstNode node) {
    if (node is SimpleStringLiteral) return node;
    if (node is StringInterpolation) return node;
    if (node is AdjacentStrings) return node;
    // Walk up in case covering node is a child of the literal
    return node.thisOrAncestorOfType<StringLiteral>();
  }

  /// Walk the test body AST to find expect() matcher identifiers.
  /// Returns the verb mapped from the first recognized matcher,
  /// or 'handle' as a fallback.
  String _inferVerbFromAst(MethodInvocation testCall) {
    // Find the closure/function body of the test call
    final args = testCall.argumentList.arguments;
    FunctionBody? body;
    for (final arg in args) {
      if (arg is FunctionExpression) {
        body = arg.body;
        break;
      }
    }
    if (body == null) return 'handle';

    // Collect matcher names from expect() calls in the body
    final collector = _MatcherCollector();
    body.accept(collector);

    // Map the first recognized matcher to a verb
    for (final matcherName in collector.matcherNames) {
      final verb = _matcherToVerb[matcherName.toLowerCase()];
      if (verb != null) return verb;
    }

    return 'handle';
  }

  /// Build a properly quoted and escaped string literal.
  /// Preserves the original quote character (single or double).
  String _buildQuotedString(StringLiteral original, String content) {
    final source = original.toSource();

    // Detect whether the original used single or double quotes
    final usesSingleQuote = source.startsWith("'");
    final quoteChar = usesSingleQuote ? "'" : '"';

    // Escape the quote character used by this literal
    final escaped = usesSingleQuote
        ? content.replaceAll("'", "\\'")
        : content.replaceAll('"', '\\"');

    return '$quoteChar$escaped$quoteChar';
  }
}

/// AST visitor that collects matcher identifier names from expect() calls.
///
/// Looks for patterns like `expect(x, isTrue)` and `expect(x, throwsA(...))`,
/// collecting the matcher name ('isTrue', 'throwsA', etc.) from the second
/// argument position. Only inspects expect() arguments — ignores matchers
/// that appear in string literals or comments.
class _MatcherCollector extends RecursiveAstVisitor<void> {
  /// Matcher identifier names found in expect() second-argument position.
  final List<String> matcherNames = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'expect' &&
        node.argumentList.arguments.length >= 2) {
      final matcher = node.argumentList.arguments[1];
      _extractMatcherName(matcher);
    }
    // Continue walking into nested nodes (e.g. expect inside setUp)
    super.visitMethodInvocation(node);
  }

  /// Extract the top-level identifier or function name from a matcher expr.
  void _extractMatcherName(Expression matcher) {
    if (matcher is SimpleIdentifier) {
      // e.g. expect(x, isTrue)
      matcherNames.add(matcher.name);
    } else if (matcher is MethodInvocation) {
      // e.g. expect(x, throwsA(isA<Exception>()))
      matcherNames.add(matcher.methodName.name);
    } else if (matcher is PrefixedIdentifier) {
      // e.g. expect(x, test_util.isTrue) — use the suffix
      matcherNames.add(matcher.identifier.name);
    }
  }
}
