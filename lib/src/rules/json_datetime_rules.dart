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
    problemMessage:
        '[require_json_decode_try_catch] jsonDecode throws on malformed JSON. Unhandled exceptions can crash the app, cause silent data loss, and make debugging difficult. This is a common source of runtime errors in networked and user-input scenarios.',
    correctionMessage:
        'Wrap jsonDecode in try-catch for FormatException. Provide user feedback and log errors for diagnostics. Audit all JSON parsing for error handling and add tests for malformed input.',
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
        '[avoid_datetime_parse_unvalidated] DateTime.parse throws on invalid input. Unvalidated parsing can crash the app, cause silent failures, and break data flows. This is a common source of bugs in date handling and can lead to missed events or corrupted records.',
    correctionMessage:
        'Replace with DateTime.tryParse() or wrap in try-catch. Always validate input before parsing and add tests for edge cases. Document date parsing logic for maintainability.',
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
        'Using parse methods (like int.parse or double.parse) on dynamic or user-provided data can throw exceptions and crash your app if the input is invalid. This exposes your app to stability and security risks, especially when handling external or untrusted data. Always use tryParse to safely handle potentially malformed input and provide a fallback for invalid values. See https://dart.dev/guides/libraries/library-tour#numbers.',
    correctionMessage:
        'Replace parse with tryParse when converting dynamic or user-controlled data to prevent runtime exceptions and improve app robustness. This practice aligns with Dart’s recommendations for safe type conversion. See https://dart.dev/guides/libraries/library-tour#numbers for guidance.',
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
    problemMessage:
        '[prefer_duration_constants] Duration constructor uses a smaller time unit than necessary, reducing readability and making the intended duration harder to understand at a glance.',
    correctionMessage:
        'Replace with the equivalent larger time unit (e.g., Duration(seconds: 60) becomes Duration(minutes: 1)) for clarity.',
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
    problemMessage:
        '[avoid_datetime_now_in_tests] DateTime.now() in tests produces non-deterministic values that vary between runs, causing flaky assertions that pass locally but fail in CI, making test failures impossible to reproduce reliably.',
    correctionMessage:
        'Use fixed DateTime values (e.g., DateTime(2024, 1, 15)) or inject a clock abstraction for deterministic, reproducible tests.',
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
/// JSON only supports: String, num, bool, null, List, and `Map<String, dynamic>`.
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
    problemMessage:
        '[avoid_not_encodable_in_to_json] Value is not JSON-encodable and will cause runtime error.',
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
        '[require_freezed_json_converter] Freezed class with DateTime/Color field may need a JsonConverter for correct serialization. Missing converters can cause runtime errors, silent data loss, and broken API contracts. This is a common source of serialization bugs in complex models.',
    correctionMessage:
        'Add @JsonSerializable(converters: [...]) for custom types. Audit all Freezed models for converter coverage and add tests for serialization/deserialization. Document converter logic for maintainability.',
    errorSeverity: DiagnosticSeverity.WARNING,
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

            // cspell:ignore annot
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
        '[require_freezed_lint_package] File uses Freezed. Consider adding freezed_lint package for specialized linting.',
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

// =============================================================================
// v4.1.6 Rules - API Response & Date Handling
// =============================================================================

/// Warns when DateTime.parse is used with server dates without format spec.
///
/// DateTime.parse assumes ISO 8601 format but servers often return custom
/// formats. Using parse() without understanding the format causes crashes.
///
/// **BAD:**
/// ```dart
/// final date = DateTime.parse(json['created_at']); // May crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// final date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(json['created_at']);
/// // Or use tryParse for safety:
/// final date = DateTime.tryParse(json['created_at']);
/// ```
class RequireDateFormatSpecificationRule extends SaropaLintRule {
  const RequireDateFormatSpecificationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_date_format_specification',
    problemMessage:
        '[require_date_format_specification] DateTime.parse may fail on server dates due to format mismatches. Unspecified formats can cause runtime errors, silent failures, and broken data flows. This is a common source of bugs in internationalized and backend-driven apps.',
    correctionMessage:
        'Use DateTime.tryParse() for safety or DateFormat for specific formats. Always specify expected formats and add tests for edge cases. Document date format logic for maintainability.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for DateTime.parse()
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;
      if (node.methodName.name != 'parse') return;

      // Check if the argument is from JSON or a variable (not a literal)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      // If it's a string literal, it's probably fine (developer knows the format)
      if (firstArg is StringLiteral) return;

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseDateTimeTryParseFix()];
}

class _UseDateTimeTryParseFix extends DartFix {
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

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use DateTime.tryParse instead',
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

/// Warns when non-ISO 8601 date formats are used for serialization.
///
/// ISO 8601 is the standard for date interchange. Custom formats cause
/// parsing issues across different locales and systems.
///
/// **BAD:**
/// ```dart
/// DateFormat('MM/dd/yyyy').format(date); // US-specific
/// DateFormat('dd.MM.yyyy').format(date); // European
/// ```
///
/// **GOOD:**
/// ```dart
/// date.toIso8601String(); // Standard: 2024-01-15T10:30:00.000Z
/// DateFormat('yyyy-MM-dd').format(date); // ISO date only
/// ```
class PreferIso8601DatesRule extends SaropaLintRule {
  const PreferIso8601DatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_iso8601_dates',
    problemMessage:
        '[prefer_iso8601_dates] Use ISO 8601 format for date serialization.',
    correctionMessage:
        'Use toIso8601String() or yyyy-MM-dd format for interoperability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Non-ISO formats that are locale-specific
  static final RegExp _nonIsoPattern = RegExp(
    r'^(MM[/.-]dd|dd[/.-]MM|M[/.-]d|d[/.-]M)',
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name2.lexeme;
      if (constructorName != 'DateFormat') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is! StringLiteral) return;

      final String? format = firstArg.stringValue;
      if (format == null) return;

      if (_nonIsoPattern.hasMatch(format)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when JSON fields are accessed without null checks.
///
/// Optional JSON fields may be missing. Accessing them directly
/// causes null pointer exceptions.
///
/// **BAD:**
/// ```dart
/// final name = json['user']['name']; // Crashes if user is null!
/// final age = json['age'] as int;    // Crashes if age is null!
/// ```
///
/// **GOOD:**
/// ```dart
/// final name = json['user']?['name'];
/// final age = json['age'] as int?;
/// final age = json['age'] ?? 0;
/// ```
class AvoidOptionalFieldCrashRule extends SaropaLintRule {
  const AvoidOptionalFieldCrashRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_optional_field_crash',
    problemMessage:
        '[avoid_optional_field_crash] JSON field accessed with direct bracket notation on a Map that may contain null values. When the API response omits an optional field, this direct access throws a runtime exception that crashes the app. Defensive null-aware access with ?[] prevents unexpected null pointer errors and provides graceful handling of incomplete or malformed JSON responses.',
    correctionMessage:
        'Use the null-aware bracket operator ?[] for optional field access, and provide a fallback default value with the ?? operator to handle missing JSON fields safely.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      // Check for chained index access: json['x']['y']
      final Expression? target = node.target;
      if (target is! IndexExpression) return;

      // If already using null-aware (?[]), skip
      if (node.question != null) return;
      if (target.question != null) return;

      // Check if this looks like JSON access
      if (_looksLikeJsonAccess(target)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _looksLikeJsonAccess(IndexExpression expr) {
    // Check if the index is a string literal (common for JSON)
    final Expression index = expr.index;
    if (index is! StringLiteral) return false;

    // Check variable names that suggest JSON
    final Expression? target = expr.target;
    if (target is SimpleIdentifier) {
      final String name = target.name.toLowerCase();
      return name.contains('json') ||
          name.contains('data') ||
          name.contains('response') ||
          name.contains('map') ||
          name.contains('result');
    }

    return target != null; // Conservative: flag nested string access
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddNullAwareAccessFix()];
}

class _AddNullAwareAccessFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use null-aware access (?[])',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert ? before the [
        builder.addSimpleInsertion(node.leftBracket.offset, '?');
      });
    });
  }
}

/// Warns when manual JSON key mapping is used instead of @JsonKey.
///
/// Manual key mapping in fromJson is error-prone and verbose.
/// Use @JsonKey annotation with json_serializable for clarity.
///
/// **BAD:**
/// ```dart
/// factory User.fromJson(Map<String, dynamic> json) => User(
///   userName: json['user_name'],  // Manual mapping
///   emailAddress: json['email'],   // Different name
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// @JsonSerializable()
/// class User {
///   @JsonKey(name: 'user_name')
///   final String userName;
///
///   @JsonKey(name: 'email')
///   final String emailAddress;
/// }
/// ```
class PreferExplicitJsonKeysRule extends SaropaLintRule {
  const PreferExplicitJsonKeysRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_json_keys',
    problemMessage:
        '[prefer_explicit_json_keys] Consider using @JsonKey for field name mapping.',
    correctionMessage:
        'Use json_serializable with @JsonKey annotation for cleaner mapping.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Only check factory fromJson constructors
      if (node.factoryKeyword == null) return;
      if (node.name?.lexeme != 'fromJson') return;

      // Check for manual key mapping pattern
      final FunctionBody? body = node.body;
      if (body is! ExpressionFunctionBody) return;

      final Expression expr = body.expression;
      if (expr is! InstanceCreationExpression) return;

      // Count manual mappings (json['key'] patterns)
      int manualMappings = 0;
      for (final Expression arg in expr.argumentList.arguments) {
        if (_isManualJsonAccess(arg)) {
          manualMappings++;
        }
      }

      // If there are multiple manual mappings, suggest @JsonKey
      if (manualMappings >= 3) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isManualJsonAccess(Expression expr) {
    if (expr is NamedExpression) {
      return _isManualJsonAccess(expr.expression);
    }
    if (expr is IndexExpression) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier && target.name == 'json') {
        return true;
      }
    }
    return false;
  }
}

// =============================================================================
// require_json_schema_validation
// =============================================================================

/// Warns when JSON API responses are used without schema validation.
///
/// Alias: validate_json_schema, api_response_validation
///
/// API responses should be validated against a schema before use. Malformed
/// or unexpected data can crash the app or cause security issues.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(Uri.parse('https://api.example.com/user'));
/// final json = jsonDecode(response.body);
/// final user = User(
///   name: json['name'],      // What if null?
///   email: json['email'],    // What if missing?
///   age: json['age'],        // What if string instead of int?
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(Uri.parse('https://api.example.com/user'));
/// final json = jsonDecode(response.body);
///
/// // Option 1: Use json_serializable with error handling
/// try {
///   final user = User.fromJson(json);
/// } on TypeError catch (e) {
///   handleInvalidResponse(e);
/// }
///
/// // Option 2: Validate required fields
/// if (!_validateUserResponse(json)) {
///   throw ApiException('Invalid user response');
/// }
/// final user = User.fromJson(json);
/// ```
class RequireJsonSchemaValidationRule extends SaropaLintRule {
  const RequireJsonSchemaValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_json_schema_validation',
    problemMessage:
        '[require_json_schema_validation] JSON API response used without '
        'validation. Malformed data may crash the app or cause unexpected behavior.',
    correctionMessage:
        'Validate JSON structure with fromJson in try-catch, or check required fields.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for jsonDecode
      if (node.methodName.name != 'jsonDecode' &&
          node.methodName.name != 'json.decode') {
        return;
      }

      // Check if there's validation nearby
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();

      // Check for validation patterns
      if (bodySource.contains('try') ||
          bodySource.contains('fromJson') ||
          bodySource.contains('validate') ||
          bodySource.contains('containsKey') ||
          bodySource.contains('is Map') ||
          bodySource.contains('is List') ||
          bodySource.contains('?[') || // Safe access
          bodySource.contains('??')) {
        return; // Has some validation
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// prefer_json_serializable
// =============================================================================

/// Warns when data classes have manual JSON serialization.
///
/// Alias: use_json_serializable, json_codegen
///
/// Manual JSON parsing is error-prone and tedious. Use json_serializable
/// or freezed for type-safe, maintainable serialization.
///
/// **BAD:**
/// ```dart
/// class User {
///   final String name;
///   final int age;
///   final DateTime? createdAt;
///
///   User({required this.name, required this.age, this.createdAt});
///
///   factory User.fromJson(Map<String, dynamic> json) {
///     return User(
///       name: json['name'] as String,
///       age: json['age'] as int,
///       createdAt: json['created_at'] != null
///           ? DateTime.parse(json['created_at'] as String)
///           : null,
///     );
///   }
///
///   Map<String, dynamic> toJson() => {
///     'name': name,
///     'age': age,
///     'created_at': createdAt?.toIso8601String(),
///   };
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @JsonSerializable()
/// class User {
///   final String name;
///   final int age;
///   @JsonKey(name: 'created_at')
///   final DateTime? createdAt;
///
///   User({required this.name, required this.age, this.createdAt});
///
///   factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
///   Map<String, dynamic> toJson() => _$UserToJson(this);
/// }
/// ```
class PreferJsonSerializableRule extends SaropaLintRule {
  const PreferJsonSerializableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_json_serializable',
    problemMessage:
        '[prefer_json_serializable] Data class with manual JSON serialization. '
        'Manual parsing is error-prone and hard to maintain.',
    correctionMessage:
        'Use @JsonSerializable() or @freezed for type-safe serialization.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has both fromJson factory and toJson method
      bool hasManualFromJson = false;
      bool hasManualToJson = false;
      bool hasCodegenAnnotation = false;

      // Check for annotations
      for (final annotation in node.metadata) {
        final name = annotation.name.name;
        if (name == 'JsonSerializable' ||
            name == 'freezed' ||
            name == 'Freezed') {
          hasCodegenAnnotation = true;
          break;
        }
      }

      if (hasCodegenAnnotation) return;

      // Check members
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          if (member.factoryKeyword != null &&
              member.name?.lexeme == 'fromJson') {
            // Check if it's manual (not calling _$ClassName...)
            final String bodySource = member.body.toSource();
            if (!bodySource.contains(r'_$') &&
                (bodySource.contains("json['") ||
                    bodySource.contains('json["'))) {
              hasManualFromJson = true;
            }
          }
        }
        if (member is MethodDeclaration && member.name.lexeme == 'toJson') {
          final String bodySource = member.body.toSource();
          if (!bodySource.contains(r'_$')) {
            hasManualToJson = true;
          }
        }
      }

      // Warn if has manual serialization
      if (hasManualFromJson && hasManualToJson) {
        reporter.atToken(node.name, code);
      }
    });
  }
}
