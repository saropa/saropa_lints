// ignore_for_file: depend_on_referenced_packages

/// Utilities for detecting the context of literal values (numbers, strings).
///
/// Provides helpers to determine if a literal is in a const context,
/// annotation, import/export directive, or regex pattern.
library;

import 'package:analyzer/dart/ast/ast.dart';

/// Checks if a literal node is in a const context (const variable, const
/// constructor, const collection).
///
/// Returns true if the literal should be allowed because it's already
/// declared as const.
bool isLiteralInConstContext(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is VariableDeclarationList && current.isConst) return true;
    if (current is InstanceCreationExpression && current.isConst) return true;
    if (current is ListLiteral && current.constKeyword != null) return true;
    if (current is SetOrMapLiteral && current.constKeyword != null) {
      return true;
    }
    current = current.parent;
  }

  return false;
}

/// Checks if a node is inside an annotation (e.g., @deprecated, @override).
///
/// Returns true if the literal is part of an annotation and should be allowed.
bool isInAnnotation(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is Annotation) return true;
    current = current.parent;
  }

  return false;
}

/// Checks if a node is inside an import or export directive.
///
/// Returns true if the literal is part of an import/export path.
bool isInImportOrExport(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is ImportDirective || current is ExportDirective) return true;
    current = current.parent;
  }

  return false;
}

/// Checks if a string literal is being used as a regex pattern.
///
/// Detects patterns like:
/// - `RegExp(r'pattern')` or `RegExp('pattern')`
/// - `RegExp()` constructor calls (with or without 'new')
/// - Raw strings (`r'...'`) that look like regex patterns
///
/// Returns true if the string is being used as a regex pattern.
bool isStringUsedAsRegexPattern(AstNode node) {
  if (node is! SimpleStringLiteral) return false;

  final parent = node.parent;

  // Check if it's an argument to RegExp constructor
  if (parent is ArgumentList) {
    final grandparent = parent.parent;
    if (grandparent is InstanceCreationExpression) {
      final constructorName = grandparent.constructorName.toString();
      // Match RegExp, dart:core.RegExp, or RegExp with type params
      if (constructorName.contains('RegExp')) {
        return true;
      }
    } else if (grandparent is MethodInvocation) {
      // Handle RegExp() constructor call without 'new'
      final method = grandparent.methodName.name;
      if (method == 'RegExp') {
        return true;
      }
    }
  }

  // Check if this is a raw string (common for regex patterns)
  // Raw strings often contain regex-specific syntax like \d, \w, etc.
  if (node.isRaw && _looksLikeRegex(node.value)) {
    return true;
  }

  return false;
}

/// Checks if a string value looks like a regex pattern.
///
/// Detects common regex syntax patterns:
/// - Anchors: ^, $
/// - Character classes: \d, \w, \s, \D, \W, \S
/// - Character sets: [abc], [a-z], [^a-z]
/// - Quantifiers: +, *, ?, {n,m}
/// - Groups: (abc)
/// - Alternation: a|b
///
/// Returns true if the string contains regex-like patterns.
bool _looksLikeRegex(String value) {
  // Regex patterns commonly contain these patterns
  final regexIndicators = <Pattern>[
    RegExp(r'\^|\$'), // Anchors: ^, $
    RegExp(r'\\[dDwWsS]'), // Character classes: \d, \w, \s, etc.
    RegExp(r'\[.*?\]'), // Character sets: [abc], [a-z]
    RegExp(r'[+*?{]'), // Quantifiers: +, *, ?, {n,m}
    RegExp(r'\(.*?\)'), // Groups: (abc)
    RegExp(r'\|'), // Alternation: a|b
  ];

  return regexIndicators.any((pattern) => value.contains(pattern));
}

/// Checks if a string literal is a test description.
///
/// Test descriptions are the first argument to test framework methods like:
/// - `test('description', ...)`
/// - `group('description', ...)`
/// - `testWidgets('description', ...)`
/// - `testGoldens('description', ...)`
/// - `setUp('description', ...)` (rare but possible)
/// - `tearDown('description', ...)` (rare but possible)
///
/// Returns true if the string is a test description and should be allowed.
bool isTestDescription(AstNode node) {
  final parent = node.parent;
  if (parent is ArgumentList) {
    final grandparent = parent.parent;
    if (grandparent is MethodInvocation) {
      final methodName = grandparent.methodName.name;
      // First argument to test(), group(), testWidgets(), etc.
      if ((methodName == 'test' ||
              methodName == 'group' ||
              methodName == 'testWidgets' ||
              methodName == 'testGoldens' ||
              methodName == 'setUp' ||
              methodName == 'tearDown') &&
          parent.arguments.isNotEmpty &&
          parent.arguments.first == node) {
        return true;
      }
    }
  }

  return false;
}

/// Checks if a node is inside an `expect()` call.
///
/// In test files, values inside `expect()` are either the actual value
/// under test or the expected result — both are self-documenting in context
/// and should generally be exempt from magic literal rules.
///
/// Walks up the parent chain and returns true if an `expect()` method
/// invocation is found before reaching a function body boundary.
bool isInExpectCall(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodInvocation && current.methodName.name == 'expect') {
      return true;
    }
    if (current is FunctionBody) break;
    current = current.parent;
  }

  return false;
}
