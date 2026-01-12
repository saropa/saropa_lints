// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// JSON and DateTime parsing rules for Flutter/Dart applications.
///
/// These rules detect common mistakes when parsing JSON and dates
/// that can cause runtime crashes or data corruption.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when jsonDecode is used without try-catch.
///
/// jsonDecode throws FormatException on malformed JSON. Without
/// error handling, this crashes the app.
///
/// **BAD:**
/// ```dart
/// final data = jsonDecode(response.body);
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final data = jsonDecode(response.body);
/// } on FormatException catch (e) {
///   // Handle malformed JSON
/// }
/// ```
class RequireJsonDecodeTryCatchRule extends SaropaLintRule {
  const RequireJsonDecodeTryCatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_json_decode_try_catch',
    problemMessage: 'jsonDecode throws on malformed JSON. Wrap in try-catch.',
    correctionMessage: 'Add try-catch for FormatException around jsonDecode.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'jsonDecode') return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });

    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final String source = node.function.toSource();
      if (source != 'jsonDecode') return;

      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when DateTime.parse is used without try-catch or tryParse.
///
/// DateTime.parse throws FormatException on invalid date strings.
/// Use tryParse or wrap in try-catch for user-provided dates.
///
/// **BAD:**
/// ```dart
/// final date = DateTime.parse(userInput);
/// ```
///
/// **GOOD:**
/// ```dart
/// final date = DateTime.tryParse(userInput);
/// if (date == null) {
///   // Handle invalid date
/// }
///
/// // Or with try-catch:
/// try {
///   final date = DateTime.parse(userInput);
/// } on FormatException {
///   // Handle invalid date
/// }
/// ```
class AvoidDateTimeParseUnvalidatedRule extends SaropaLintRule {
  const AvoidDateTimeParseUnvalidatedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_datetime_parse_unvalidated',
    problemMessage:
        'DateTime.parse throws on invalid input. Use tryParse or try-catch.',
    correctionMessage: 'Replace with DateTime.tryParse() or wrap in try-catch.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'parse') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseTryParseFix()];
}

class _UseTryParseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      if (node.methodName.name != 'parse') return;
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'DateTime') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use DateTime.tryParse()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'tryParse',
        );
      });
    });
  }
}

/// Warns when int/double/num/BigInt/Uri.parse is used without try-catch.
///
/// These parse methods throw FormatException on invalid input. Dynamic data
/// (user input, API responses, file contents) should use tryParse instead
/// to return null on failure, preventing runtime crashes.
///
/// **BAD:**
/// ```dart
/// final age = int.parse(userInput); // Throws on "abc"!
/// final price = double.parse(json['price'] as String); // Throws on null/invalid!
/// final uri = Uri.parse(untrustedUrl); // Throws on malformed URL!
/// ```
///
/// **GOOD:**
/// ```dart
/// final age = int.tryParse(userInput) ?? 0;
/// final price = double.tryParse(json['price'] as String?) ?? 0.0;
/// final uri = Uri.tryParse(untrustedUrl); // Returns null on invalid URL
/// ```
class PreferTryParseForDynamicDataRule extends SaropaLintRule {
  const PreferTryParseForDynamicDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_try_parse_for_dynamic_data',
    problemMessage:
        'parse() throws on invalid input. Use tryParse() for dynamic data.',
    correctionMessage: 'Replace with tryParse() and handle null result.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _parseTypes = <String>{
    'int',
    'double',
    'num',
    'BigInt',
    'Uri',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'parse') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (!_parseTypes.contains(target.name)) return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseNumTryParseFix()];
}

class _UseNumTryParseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      if (node.methodName.name != 'parse') return;
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use ${target.name}.tryParse()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'tryParse',
        );
      });
    });
  }
}

/// Warns when Duration constructor can use cleaner units.
///
/// Duration(seconds: 60) is clearer as Duration(minutes: 1).
/// This rule suggests using larger units when they divide evenly.
///
/// **BAD:**
/// ```dart
/// Duration(seconds: 60);
/// Duration(milliseconds: 1000);
/// Duration(minutes: 60);
/// ```
///
/// **GOOD:**
/// ```dart
/// Duration(minutes: 1);
/// Duration(seconds: 1);
/// Duration(hours: 1);
/// ```
class PreferDurationConstantsRule extends SaropaLintRule {
  const PreferDurationConstantsRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_duration_constants',
    problemMessage: 'Duration can use a cleaner unit.',
    correctionMessage: 'Use a larger unit for cleaner code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Duration') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final String name = arg.name.label.name;
        final Expression value = arg.expression;

        if (value is! IntegerLiteral) continue;
        final int intValue = value.value ?? 0;
        if (intValue <= 0) continue;

        // Check for conversions
        if (name == 'milliseconds' &&
            intValue >= 1000 &&
            intValue % 1000 == 0) {
          reporter.atNode(arg, code);
        } else if (name == 'seconds' && intValue >= 60 && intValue % 60 == 0) {
          reporter.atNode(arg, code);
        } else if (name == 'minutes' && intValue >= 60 && intValue % 60 == 0) {
          reporter.atNode(arg, code);
        } else if (name == 'hours' && intValue >= 24 && intValue % 24 == 0) {
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when DateTime.now() is used in test files.
///
/// Tests using DateTime.now() can be flaky and hard to debug.
/// Use a clock abstraction or fixed datetime values for predictable tests.
///
/// **BAD:**
/// ```dart
/// // In *_test.dart file:
/// test('checks expiry', () {
///   final now = DateTime.now(); // Flaky!
///   expect(isExpired(now), isFalse);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use fixed datetime or clock package
/// test('checks expiry', () {
///   final fixedTime = DateTime(2024, 1, 15, 10, 30);
///   expect(isExpired(fixedTime), isFalse);
/// });
/// ```
class AvoidDatetimeNowInTestsRule extends SaropaLintRule {
  const AvoidDatetimeNowInTestsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_datetime_now_in_tests',
    problemMessage: 'DateTime.now() in tests can cause flaky behavior.',
    correctionMessage:
        'Use fixed datetime values or a clock abstraction for predictable tests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String filePath = resolver.path;
    if (!filePath.endsWith('_test.dart')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for DateTime.now()
      if (node.methodName.name != 'now') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 2 - JSON Serialization Rules
// =============================================================================

/// Warns when toJson methods return non-JSON-encodable types.
///
/// Alias: not_encodable_in_json, toJson_non_encodable, json_serialization_error
///
/// JSON only supports: String, num, bool, null, List, and Map<String, dynamic>.
/// Types like DateTime, Function, Widget, and custom classes without toJson
/// will cause runtime errors when jsonEncode is called.
///
/// **BAD:**
/// ```dart
/// Map<String, dynamic> toJson() {
///   return {
///     'date': DateTime.now(),        // DateTime not JSON-encodable!
///     'callback': myFunction,        // Function not JSON-encodable!
///     'widget': MyWidget(),          // Widget not JSON-encodable!
///     'user': User(name: 'John'),    // Custom class without toJson!
///   };
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Map<String, dynamic> toJson() {
///   return {
///     'date': DateTime.now().toIso8601String(),  // Serialize to string
///     'userId': user.id,                          // Use primitive value
///     'user': user.toJson(),                      // Call nested toJson
///   };
/// }
/// ```
///
/// **Quick fix available:** For DateTime, suggests `.toIso8601String()`.
class AvoidNotEncodableInToJsonRule extends SaropaLintRule {
  const AvoidNotEncodableInToJsonRule() : super(code: _code);

  /// Critical issue - causes runtime crashes when encoding JSON.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_not_encodable_in_to_json',
    problemMessage: 'Value is not JSON-encodable and will cause runtime error.',
    correctionMessage:
        'Convert to JSON-safe type: use .toIso8601String() for DateTime, '
        '.toJson() for objects, or remove non-serializable values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Types that are known to NOT be JSON-encodable.
  static const Set<String> _nonEncodableTypes = <String>{
    'DateTime',
    'Duration',
    'Function',
    'Symbol',
    'Type',
    'Uri', // Must use .toString()
    'BigInt',
    'Uint8List', // Must use base64 encoding
    'Int8List',
    'Uint16List',
    'Int16List',
    'Uint32List',
    'Int32List',
    'Float32List',
    'Float64List',
    // Flutter types
    'Widget',
    'BuildContext',
    'State',
    'Key',
    'GlobalKey',
    'Element',
    'RenderObject',
    // Common non-serializable types
    'File',
    'Directory',
    'Socket',
    'HttpClient',
    'StreamController',
    'StreamSubscription',
    'Timer',
    'Completer',
    'Future',
    'Stream',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check methods named toJson
      if (node.name.lexeme != 'toJson') return;

      // Check return type is Map<String, dynamic>
      final returnType = node.returnType?.toSource() ?? '';
      if (!returnType.contains('Map') || !returnType.contains('dynamic')) {
        return;
      }

      // Check the body for non-encodable values
      final body = node.body;
      if (body is BlockFunctionBody) {
        _checkBlockForNonEncodable(body.block, reporter);
      } else if (body is ExpressionFunctionBody) {
        _checkExpressionForNonEncodable(body.expression, reporter);
      }
    });
  }

  void _checkBlockForNonEncodable(
    Block block,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final statement in block.statements) {
      if (statement is ReturnStatement) {
        final expression = statement.expression;
        if (expression != null) {
          _checkExpressionForNonEncodable(expression, reporter);
        }
      }
    }
  }

  void _checkExpressionForNonEncodable(
    Expression expression,
    SaropaDiagnosticReporter reporter,
  ) {
    // Check for SetOrMapLiteral (map literals)
    if (expression is SetOrMapLiteral) {
      for (final element in expression.elements) {
        if (element is MapLiteralEntry) {
          _checkMapEntryValue(element.value, reporter);
        }
      }
    }
  }

  void _checkMapEntryValue(
    Expression value,
    SaropaDiagnosticReporter reporter,
  ) {
    // Check the static type if available
    final type = value.staticType;
    if (type != null) {
      final typeName = type.element?.name ?? '';
      final typeStr = type.getDisplayString();

      // Check for known non-encodable types
      if (_nonEncodableTypes.contains(typeName)) {
        reporter.atNode(value, code);
        return;
      }

      // Check for Function types
      if (typeStr.contains('Function') || typeStr.contains('=>')) {
        reporter.atNode(value, code);
        return;
      }
    }

    // Check for direct DateTime.now() calls
    if (value is MethodInvocation) {
      final target = value.target;
      if (target is SimpleIdentifier && target.name == 'DateTime') {
        reporter.atNode(value, code);
        return;
      }
    }

    // Check for constructor calls creating non-encodable types
    if (value is InstanceCreationExpression) {
      final typeName = value.constructorName.type.name.lexeme;
      if (_nonEncodableTypes.contains(typeName)) {
        reporter.atNode(value, code);
        return;
      }
    }

    // Check for simple identifiers that are DateTime, Function, etc.
    if (value is SimpleIdentifier) {
      final type = value.staticType;
      if (type != null) {
        final typeName = type.element?.name ?? '';
        if (_nonEncodableTypes.contains(typeName)) {
          reporter.atNode(value, code);
        }
      }
    }

    // Recursively check nested map literals
    if (value is SetOrMapLiteral) {
      for (final element in value.elements) {
        if (element is MapLiteralEntry) {
          _checkMapEntryValue(element.value, reporter);
        }
      }
    }

    // Check list literals for non-encodable elements
    if (value is ListLiteral) {
      for (final element in value.elements) {
        if (element is Expression) {
          _checkMapEntryValue(element, reporter);
        }
      }
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertDateTimeToIso8601Fix()];
}

/// Quick fix: Converts DateTime to .toIso8601String().
class _ConvertDateTimeToIso8601Fix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'DateTime') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Convert to .toIso8601String()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.end, '.toIso8601String()');
      });
    });

    // Also handle simple identifiers that are DateTime type
    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final type = node.staticType;
      if (type == null) return;

      final typeName = type.element?.name ?? '';
      if (typeName != 'DateTime') return;

      // Only suggest fix if not already calling a method
      final parent = node.parent;
      if (parent is MethodInvocation && parent.target == node) return;
      if (parent is PrefixedIdentifier && parent.prefix == node) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Convert to .toIso8601String()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.end, '.toIso8601String()');
      });
    });
  }
}

// =============================================================================
// require_freezed_json_converter
// =============================================================================

/// Custom types in Freezed classes need JsonConverter.
///
/// Types like DateTime, Color, or custom classes need explicit converters
/// for proper JSON serialization in Freezed.
///
/// **BAD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({
///     required DateTime createdAt,  // Needs converter!
///   }) = _User;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   @JsonSerializable(converters: [DateTimeConverter()])
///   factory User({
///     required DateTime createdAt,
///   }) = _User;
/// }
/// ```
class RequireFreezedJsonConverterRule extends SaropaLintRule {
  const RequireFreezedJsonConverterRule() : super(code: _code);

  /// JSON serialization failures at runtime.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_json_converter',
    problemMessage:
        'Freezed class with DateTime/Color field may need JsonConverter.',
    correctionMessage:
        'Add @JsonSerializable(converters: [...]) for custom types.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Types that typically need converters.
  static const Set<String> _typesNeedingConverter = <String>{
    'DateTime',
    'Duration',
    'Color',
    'Uri',
    'BigInt',
    'Uint8List',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check for @freezed annotation
      bool hasFreezed = false;
      for (final Annotation annotation in node.metadata) {
        final String name = annotation.name.name;
        if (name == 'freezed' || name == 'Freezed') {
          hasFreezed = true;
          break;
        }
      }
      if (!hasFreezed) return;

      // Check for fromJson factory
      bool hasFromJson = false;
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          final String? name = member.name?.lexeme;
          if (name == 'fromJson') {
            hasFromJson = true;
            break;
          }
        }
      }
      if (!hasFromJson) return;

      // Check factory constructors for types needing converters
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration && member.factoryKeyword != null) {
          final FormalParameterList? params = member.parameters;
          if (params == null) continue;

          for (final FormalParameter param in params.parameters) {
            String? typeSource;
            if (param is DefaultFormalParameter) {
              final NormalFormalParameter inner = param.parameter;
              if (inner is SimpleFormalParameter) {
                typeSource = inner.type?.toSource();
              }
            } else if (param is SimpleFormalParameter) {
              typeSource = param.type?.toSource();
            }

            if (typeSource != null) {
              for (final String typeName in _typesNeedingConverter) {
                if (typeSource.contains(typeName)) {
                  // Check if there's a converter annotation
                  bool hasConverter = false;
                  for (final Annotation annotation in member.metadata) {
                    final String annotSource = annotation.toSource();
                    if (annotSource.contains('JsonSerializable') &&
                        annotSource.contains('converters')) {
                      hasConverter = true;
                      break;
                    }
                    if (annotSource.contains('JsonKey') &&
                        (annotSource.contains('fromJson') ||
                            annotSource.contains('toJson'))) {
                      hasConverter = true;
                      break;
                    }
                  }

                  if (!hasConverter) {
                    reporter.atNode(param, code);
                    return;
                  }
                }
              }
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// require_freezed_lint_package
// =============================================================================

/// Install freezed_lint for official linting of Freezed classes.
///
/// **Heuristic warning:** This rule cannot verify if freezed_lint is in your
/// pubspec.yaml. It simply reminds developers using Freezed to consider
/// adding freezed_lint to their dev_dependencies. Disable this rule if you
/// have already installed freezed_lint.
///
/// The freezed_lint package provides specialized rules for Freezed patterns.
///
/// **Recommendation:** Add freezed_lint to dev_dependencies.
class RequireFreezedLintPackageRule extends SaropaLintRule {
  const RequireFreezedLintPackageRule() : super(code: _code);

  /// Missing specialized linting for Freezed patterns.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_lint_package',
    problemMessage:
        'File uses Freezed. Consider adding freezed_lint package for specialized linting.',
    correctionMessage:
        'Add freezed_lint to dev_dependencies. Disable this rule if already installed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Flag the first freezed import as a reminder to add freezed_lint.
    // This is a heuristic - we cannot check if freezed_lint is actually
    // in pubspec.yaml. Users should disable this rule if they've installed it.
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      // Only flag freezed_annotation imports (the main freezed package)
      if (uri == 'package:freezed_annotation/freezed_annotation.dart') {
        reporter.atNode(node, code);
      }
    });
  }
}
