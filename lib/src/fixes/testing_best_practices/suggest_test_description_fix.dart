// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: suggest a conventional test description.
///
/// Walks the test body's AST to find expect() calls, extracts the subject
/// from the first argument and the verb from the matcher (second argument),
/// then builds a "should [verb] [subject] [original]" description.
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
  /// Covers assertion-style tests (isTrue/isFalse), collection tests,
  /// error tests, and general matchers for widget/integration contexts.
  static const Map<String, String> _matcherToVerb = {
    // Boolean matchers — common in validator/utility tests
    'istrue': 'accept',
    'isfalse': 'reject',
    // Null matchers
    'isnull': 'return null for',
    'isnotnull': 'return value for',
    // Collection matchers
    'isempty': 'return empty result for',
    'isnotempty': 'return non-empty result for',
    'haslength': 'return correct length for',
    'contains': 'contain',
    'containsall': 'contain all of',
    'everyelement': 'have every element match for',
    // Error/exception matchers
    'throwsa': 'throw when given',
    'throwsexception': 'throw when given',
    'throwsargumenterror': 'throw ArgumentError for',
    'throwsstateerror': 'throw StateError for',
    'throwsformaterror': 'throw FormatError for',
    'throwsunsupportederror': 'throw UnsupportedError for',
    // Equality/comparison matchers
    'equals': 'return expected value for',
    'isa': 'return correct type for',
    'matches': 'match pattern for',
    // Widget test matchers
    'findsonewidge': 'find widget for',
    'findsnothing': 'find nothing for',
    'findswidgets': 'find widgets for',
    'findsatleastne': 'find at least one widget for',
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

    // AST-walk the test body to find expect() calls with subjects and matchers
    final expectInfo = _analyzeTestBody(testCall);

    // Build the suggested description using subject + verb + original
    final suggested = _buildSuggestion(originalDescription, expectInfo);

    // Preserve the original quote style and escape accordingly
    final replacement = _buildQuotedString(descriptionNode, suggested);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(descriptionNode.offset, descriptionNode.length),
        replacement,
      );
    });
  }

  /// Resolve the covering node to a StringLiteral.
  /// Handles SimpleStringLiteral, StringInterpolation, AdjacentStrings,
  /// and walks up if the covering node is a child of the literal.
  StringLiteral? _resolveStringLiteral(AstNode node) {
    if (node is SimpleStringLiteral) return node;
    if (node is StringInterpolation) return node;
    if (node is AdjacentStrings) return node;
    // Walk up in case covering node is a child (e.g. a single component
    // of AdjacentStrings, or a child of StringInterpolation)
    return node.thisOrAncestorOfType<StringLiteral>();
  }

  /// Analyze the test body to extract subject and matcher info from expect().
  _ExpectInfo _analyzeTestBody(MethodInvocation testCall) {
    // Find the closure/function body of the test call
    final args = testCall.argumentList.arguments;
    FunctionBody? body;
    for (final arg in args) {
      if (arg is FunctionExpression) {
        body = arg.body;
        break;
      }
    }
    if (body == null) return const _ExpectInfo(null, 'handle');

    // Collect expect() info from the body
    final collector = _ExpectCollector();
    body.accept(collector);

    if (collector.entries.isEmpty) {
      return const _ExpectInfo(null, 'handle');
    }

    // Use the first expect() call to determine subject and verb
    final first = collector.entries.first;
    final verb = _matcherToVerb[first.matcherName.toLowerCase()] ?? 'handle';
    return _ExpectInfo(first.subject, verb);
  }

  /// Build a description from the expect analysis and original text.
  /// Format: "should [verb] [original]" or
  ///         "[Subject].[method] should [verb] [original]" when subject found.
  String _buildSuggestion(String original, _ExpectInfo info) {
    if (info.subject != null && info.subject!.isNotEmpty) {
      // Subject extracted — use "[Subject] should [verb] [original]" format
      return '${info.subject} should ${info.verb} $original';
    }
    return 'should ${info.verb} $original';
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

/// Info extracted from the first expect() call in a test body.
class _ExpectInfo {
  /// The subject being tested (e.g. "SqlValidator.isReadOnlySql"), or null.
  final String? subject;

  /// The action verb derived from the matcher (e.g. "accept", "reject").
  final String verb;

  const _ExpectInfo(this.subject, this.verb);
}

/// A single expect() call's extracted data.
class _ExpectEntry {
  /// The subject source (first arg of expect), cleaned for readability.
  final String? subject;

  /// The matcher identifier name (second arg of expect).
  final String matcherName;

  const _ExpectEntry(this.subject, this.matcherName);
}

/// AST visitor that collects subject and matcher info from expect() calls.
///
/// For each `expect(actual, matcher)` found, extracts:
/// - The subject: a readable name from the first argument
///   (e.g. `SqlValidator.isReadOnlySql(...)` → "SqlValidator.isReadOnlySql")
/// - The matcher: the identifier name from the second argument
///   (e.g. `isTrue`, `throwsA`)
///
/// Only inspects expect() arguments in AST nodes — ignores matchers
/// that appear in string literals, comments, or non-expect positions.
class _ExpectCollector extends RecursiveAstVisitor<void> {
  /// Collected expect() entries from the test body.
  final List<_ExpectEntry> entries = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'expect' &&
        node.argumentList.arguments.length >= 2) {
      final actual = node.argumentList.arguments[0];
      final matcher = node.argumentList.arguments[1];

      final subject = _extractSubject(actual);
      final matcherName = _extractMatcherName(matcher);

      if (matcherName != null) {
        entries.add(_ExpectEntry(subject, matcherName));
      }
    }
    // Continue walking into nested nodes
    super.visitMethodInvocation(node);
  }

  /// Extract a readable subject name from the expect() first argument.
  /// Returns the class.method name for static calls, the method name for
  /// instance calls, or null if the expression is too complex.
  String? _extractSubject(Expression actual) {
    if (actual is MethodInvocation) {
      // Static call: SqlValidator.isReadOnlySql(...) → "SqlValidator.isReadOnlySql"
      final target = actual.target;
      if (target is SimpleIdentifier) {
        return '${target.name}.${actual.methodName.name}';
      }
      // Instance call: result.length → just the method
      return actual.methodName.name;
    } else if (actual is PrefixedIdentifier) {
      // Property access: obj.field → "obj.field"
      return '${actual.prefix.name}.${actual.identifier.name}';
    } else if (actual is SimpleIdentifier) {
      // Simple variable: result → "result"
      return actual.name;
    } else if (actual is FunctionExpressionInvocation) {
      // Function call: myFunc() — extract from the function reference
      final fn = actual.function;
      if (fn is SimpleIdentifier) return fn.name;
    }
    // Expression too complex (e.g. chained calls, literals) — skip subject
    return null;
  }

  /// Extract the top-level identifier or function name from a matcher expr.
  /// Returns null if the matcher form is unrecognized.
  String? _extractMatcherName(Expression matcher) {
    if (matcher is SimpleIdentifier) {
      // e.g. expect(x, isTrue)
      return matcher.name;
    } else if (matcher is MethodInvocation) {
      // e.g. expect(x, throwsA(isA<Exception>()))
      return matcher.methodName.name;
    } else if (matcher is PrefixedIdentifier) {
      // e.g. expect(x, test_util.isTrue) — use the suffix
      return matcher.identifier.name;
    }
    return null;
  }
}
