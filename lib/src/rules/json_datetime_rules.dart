// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// JSON and DateTime parsing rules for Flutter/Dart applications.
///
/// These rules detect common mistakes when parsing JSON and dates
/// that can cause runtime crashes or data corruption.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';
import '../fixes/json_datetime/use_try_parse_fix.dart';
import '../fixes/json_datetime/use_date_time_try_parse_fix.dart';
import '../fixes/json_datetime/add_null_aware_access_fix.dart';

/// Warns when jsonDecode is used without try-catch.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v2
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
  RequireJsonDecodeTryCatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_json_decode_try_catch',
    '[require_json_decode_try_catch] jsonDecode throws on malformed JSON. Unhandled exceptions can crash the app, cause silent data loss, and make debugging difficult. This is a common source of runtime errors in networked and user-input scenarios. {v2}',
    correctionMessage:
        'Wrap jsonDecode in try-catch for FormatException. Provide user feedback and log errors for diagnostics. Audit all JSON parsing for error handling and add tests for malformed input.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'jsonDecode') return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node);
      }
    });

    context.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      final String source = node.function.toSource();
      if (source != 'jsonDecode') return;

      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node);
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
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v3
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
  AvoidDateTimeParseUnvalidatedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseTryParseFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'avoid_datetime_parse_unvalidated',
    '[avoid_datetime_parse_unvalidated] DateTime.parse throws on invalid input. Unvalidated parsing can crash the app, cause silent failures, and break data flows. This is a common source of bugs in date handling and can lead to missed events or corrupted records. {v3}',
    correctionMessage:
        'Replace with DateTime.tryParse() or wrap in try-catch. Always validate input before parsing and add tests for edge cases. Document date parsing logic for maintainability.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'parse') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node);
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

/// Warns when int/double/num/BigInt/Uri.parse is used without try-catch.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v4
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
  PreferTryParseForDynamicDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_try_parse_for_dynamic_data',
    '[prefer_try_parse_for_dynamic_data] Using parse methods (like int.parse or double.parse) on dynamic or user-provided data can throw exceptions and crash your app if the input is invalid. This exposes your app to stability and security risks, especially when handling external or untrusted data. Always use tryParse to safely handle potentially malformed input and provide a fallback for invalid values. See https://dart.dev/guides/libraries/library-tour#numbers. {v4}',
    correctionMessage:
        'Replace parse with tryParse when converting dynamic or user-controlled data to prevent runtime exceptions and improve app robustness. This practice aligns with Dart’s recommendations for safe type conversion. See https://dart.dev/guides/libraries/library-tour#numbers for guidance.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'parse') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (!_parseTypes.contains(target.name)) return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseTryParseFix(context: context),
  ];

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

/// Warns when Duration constructor can use cleaner units.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v2
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
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
  PreferDurationConstantsRule() : super(code: _code);

  /// Stylistic preference only. No performance or correctness benefit.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_duration_constants',
    '[prefer_duration_constants] Using named Duration constants instead of inline constructors is a naming convention. Both create identical Duration objects with no performance difference. Enable via the stylistic tier. {v2}',
    correctionMessage:
        'Replace with the equivalent larger time unit (e.g., Duration(seconds: 60) becomes Duration(minutes: 1)) for clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
          reporter.atNode(arg);
        } else if (name == 'seconds' && intValue >= 60 && intValue % 60 == 0) {
          reporter.atNode(arg);
        } else if (name == 'minutes' && intValue >= 60 && intValue % 60 == 0) {
          reporter.atNode(arg);
        } else if (name == 'hours' && intValue >= 24 && intValue % 24 == 0) {
          reporter.atNode(arg);
        }
      }
    });
  }
}

/// Warns when DateTime.now() is used in test files.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v2
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
  AvoidDatetimeNowInTestsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_datetime_now_in_tests',
    '[avoid_datetime_now_in_tests] DateTime.now() in tests produces non-deterministic values that vary between runs, causing flaky assertions that pass locally but fail in CI, making test failures impossible to reproduce reliably. {v2}',
    correctionMessage:
        'Use fixed DateTime values (e.g., DateTime(2024, 1, 15)) or inject a clock abstraction for deterministic, reproducible tests.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only run in test files
    final String filePath = context.filePath;
    if (!filePath.endsWith('_test.dart')) return;

    context.addMethodInvocation((MethodInvocation node) {
      // Check for DateTime.now()
      if (node.methodName.name != 'now') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 2 - JSON Serialization Rules
// =============================================================================

/// Warns when toJson methods return non-JSON-encodable types.
///
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidNotEncodableInToJsonRule() : super(code: _code);

  /// Critical issue - causes runtime crashes when encoding JSON.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_not_encodable_in_to_json',
    '[avoid_not_encodable_in_to_json] Value is not JSON-encodable and will cause runtime error. {v2}',
    correctionMessage:
        'Convert to JSON-safe type: use .toIso8601String() for DateTime, '
        '.toJson() for objects, or remove non-serializable values.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
        reporter.atNode(value);
        return;
      }

      // Check for Function types
      if (typeStr.contains('Function') || typeStr.contains('=>')) {
        reporter.atNode(value);
        return;
      }
    }

    // Check for direct DateTime.now() calls
    if (value is MethodInvocation) {
      final target = value.target;
      if (target is SimpleIdentifier && target.name == 'DateTime') {
        reporter.atNode(value);
        return;
      }
    }

    // Check for constructor calls creating non-encodable types
    if (value is InstanceCreationExpression) {
      final typeName = value.constructorName.type.name.lexeme;
      if (_nonEncodableTypes.contains(typeName)) {
        reporter.atNode(value);
        return;
      }
    }

    // Check for simple identifiers that are DateTime, Function, etc.
    if (value is SimpleIdentifier) {
      final type = value.staticType;
      if (type != null) {
        final typeName = type.element?.name ?? '';
        if (_nonEncodableTypes.contains(typeName)) {
          reporter.atNode(value);
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
}

/// Quick fix: Converts DateTime to .toIso8601String().

// =============================================================================
// v4.1.6 Rules - API Response & Date Handling
// =============================================================================

/// Warns when DateTime.parse is used with server dates without format spec.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
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
  RequireDateFormatSpecificationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseDateTimeTryParseFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'require_date_format_specification',
    '[require_date_format_specification] DateTime.parse may fail on server dates due to format mismatches. Unspecified formats can cause runtime errors, silent failures, and broken data flows. This is a common source of bugs in internationalized and backend-driven apps. {v2}',
    correctionMessage:
        'Use DateTime.tryParse() for safety or DateFormat for specific formats. Always specify expected formats and add tests for edge cases. Document date format logic for maintainability.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when non-ISO 8601 date formats are used for serialization.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
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
  PreferIso8601DatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_iso8601_dates',
    '[prefer_iso8601_dates] Locale-specific date format detected instead of ISO 8601. Non-standard date formats break cross-system interoperability and can cause parsing failures or timezone-related data corruption. {v2}',
    correctionMessage:
        'Use toIso8601String() or yyyy-MM-dd format for interoperability. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  // Non-ISO formats that are locale-specific
  static final RegExp _nonIsoPattern = RegExp(
    r'^(MM[/.-]dd|dd[/.-]MM|M[/.-]d|d[/.-]M)',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'DateFormat') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is! StringLiteral) return;

      final String? format = firstArg.stringValue;
      if (format == null) return;

      if (_nonIsoPattern.hasMatch(format)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when JSON fields are accessed without null checks.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
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
  AvoidOptionalFieldCrashRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddNullAwareAccessFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'avoid_optional_field_crash',
    '[avoid_optional_field_crash] JSON field accessed with direct bracket notation on a Map that may contain null values. When the API response omits an optional field, this direct access throws a runtime exception that crashes the app. Defensive null-aware access with ?[] prevents unexpected null pointer errors and provides graceful handling of incomplete or malformed JSON responses. {v2}',
    correctionMessage:
        'Use the null-aware bracket operator ?[] for optional field access, and provide a fallback default value with the ?? operator to handle missing JSON fields safely.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIndexExpression((IndexExpression node) {
      // Check for chained index access: json['x']['y']
      final Expression? target = node.target;
      if (target is! IndexExpression) return;

      // If already using null-aware (?[]), skip
      if (node.question != null) return;
      if (target.question != null) return;

      // Check if this looks like JSON access
      if (_looksLikeJsonAccess(target)) {
        reporter.atNode(node);
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
}

/// Warns when manual JSON key mapping is used instead of @JsonKey.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
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
  PreferExplicitJsonKeysRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_json_keys',
    '[prefer_explicit_json_keys] Use @JsonKey for field name mapping. Manual key mapping in fromJson is error-prone and verbose. Use @JsonKey annotation with json_serializable for clarity. {v2}',
    correctionMessage:
        'Use json_serializable with @JsonKey annotation for cleaner mapping. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
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
        reporter.atNode(node);
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
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireJsonSchemaValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_json_schema_validation',
    '[require_json_schema_validation] JSON API response used without '
        'validation. Malformed data may crash the app or cause unexpected behavior. {v2}',
    correctionMessage:
        'Validate JSON structure with fromJson in try-catch, or check required fields.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// prefer_json_serializable
// =============================================================================

/// Warns when data classes have manual JSON serialization.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferJsonSerializableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_json_serializable',
    '[prefer_json_serializable] Data class with manual JSON serialization. '
        'Manual parsing is error-prone and hard to maintain. {v2}',
    correctionMessage:
        'Use @JsonSerializable() or @freezed for type-safe serialization.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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

// =============================================================================
// require_timezone_display
// =============================================================================

/// Warns when DateFormat is used without timezone patterns for display.
///
/// Since: v4.14.0 | Rule version: v1
///
/// `[HEURISTIC]` - Detects DateFormat constructors that include time patterns
/// (H, h, m, s) but lack timezone indicators (z, Z, v, O, x, X).
///
/// Displaying times without timezone context causes user confusion when times
/// are interpreted in the wrong timezone.
///
/// **BAD:**
/// ```dart
/// final fmt = DateFormat('yyyy-MM-dd HH:mm'); // No timezone!
/// ```
///
/// **GOOD:**
/// ```dart
/// final fmt = DateFormat('yyyy-MM-dd HH:mm z');
/// ```
///
/// GitHub: https://github.com/saropa/saropa_lints/issues/22
class RequireTimezoneDisplayRule extends SaropaLintRule {
  RequireTimezoneDisplayRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_timezone_display',
    '[require_timezone_display] DateFormat includes time components but no '
        'timezone indicator. Users may misinterpret displayed times when the '
        'timezone is ambiguous, leading to missed appointments, incorrect '
        'scheduling, and poor user experience across time zones. {v1}',
    correctionMessage:
        'Add a timezone pattern (z, Z, v, O, x, or X) to the format string, '
        'or append the timezone abbreviation separately.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Time patterns that indicate time is being formatted.
  static final RegExp _timePattern = RegExp(r'[Hhms]');

  /// Timezone patterns that indicate timezone is included.
  static final RegExp _timezonePattern = RegExp(r'[zZvOxX]');

  /// Named constructors that produce time-only formats without timezone.
  /// These are ICU DateFormat factory constructors from the intl package.
  static const Set<String> _timeOnlyConstructors = <String>{
    'Hm',
    'Hms',
    'j',
    'jm',
    'jms',
    'jmv',
    'jmz',
    'jv',
    'jz',
  };

  /// Named constructors that include timezone (safe to skip).
  static const Set<String> _timeWithTzConstructors = <String>{
    'jmv',
    'jmz',
    'jv',
    'jz',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'DateFormat') return;

      final String? namedCtor = node.constructorName.name?.name;

      // Check named constructors (e.g., DateFormat.Hm())
      if (namedCtor != null) {
        if (_timeOnlyConstructors.contains(namedCtor) &&
            !_timeWithTzConstructors.contains(namedCtor)) {
          reporter.atNode(node);
        }
        return;
      }

      // Check format string in default constructor
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      String? formatString;
      if (firstArg is SimpleStringLiteral) {
        formatString = firstArg.value;
      } else if (firstArg is NamedExpression &&
          firstArg.expression is SimpleStringLiteral) {
        formatString = (firstArg.expression as SimpleStringLiteral).value;
      }

      if (formatString == null) return;

      if (_timePattern.hasMatch(formatString) &&
          !_timezonePattern.hasMatch(formatString)) {
        reporter.atNode(node);
      }
    });
  }
}
