// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when pattern contains bottom types (void, Never, Null).
///
/// Bottom types in patterns are usually mistakes since they match nothing
/// or have unexpected behavior.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// switch (value) {
///   case void _: // Never matches
///   case Never _: // Never matches
///   case Null _: // Only matches null
/// }
/// ```
class AvoidBottomTypeInPatternsRule extends SaropaLintRule {
  const AvoidBottomTypeInPatternsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_bottom_type_in_patterns',
    problemMessage:
        '[avoid_bottom_type_in_patterns] Pattern uses bottom type which will never match (void/Never) or only matches null.',
    correctionMessage:
        'Replace with the actual expected type, or use Object? for any value.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _bottomTypes = <String>{'void', 'Never', 'Null'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addDeclaredVariablePattern((DeclaredVariablePattern node) {
      final TypeAnnotation? type = node.type;
      if (type is NamedType) {
        final String typeName = type.name.lexeme;
        if (_bottomTypes.contains(typeName)) {
          reporter.atNode(type, code);
        }
      }
    });

    context.registry.addObjectPattern((ObjectPattern node) {
      final String typeName = node.type.name.lexeme;
      if (_bottomTypes.contains(typeName)) {
        reporter.atNode(node.type, code);
      }
    });
  }
}

/// Warns when record contains bottom types (void, Never, Null).
///
/// Record fields with bottom types are usually mistakes.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// typedef MyRecord = (void, String); // void field
/// (Never, int) badRecord; // Never field
/// ```
class AvoidBottomTypeInRecordsRule extends SaropaLintRule {
  const AvoidBottomTypeInRecordsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_bottom_type_in_records',
    problemMessage:
        '[avoid_bottom_type_in_records] Record field uses void/Never/Null which cannot hold useful values.',
    correctionMessage:
        'Replace with a meaningful type. Use dynamic or Object? if any type is needed.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _bottomTypes = <String>{'void', 'Never', 'Null'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      // Check positional fields
      for (final RecordTypeAnnotationPositionalField field
          in node.positionalFields) {
        final TypeAnnotation type = field.type;
        if (type is NamedType) {
          final String typeName = type.name.lexeme;
          if (_bottomTypes.contains(typeName)) {
            reporter.atNode(type, code);
          }
        }
      }

      // Check named fields
      final RecordTypeAnnotationNamedFields? namedFields = node.namedFields;
      if (namedFields != null) {
        for (final RecordTypeAnnotationNamedField field in namedFields.fields) {
          final TypeAnnotation type = field.type;
          if (type is NamedType) {
            final String typeName = type.name.lexeme;
            if (_bottomTypes.contains(typeName)) {
              reporter.atNode(type, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when explicit field names are used in pattern matching
/// when they match the variable name.
///
/// Example of **bad** code:
/// ```dart
/// final Point(:x, :y) = point;  // OK
/// final Point(x: x, y: y) = point;  // Redundant
/// ```
///
/// Example of **good** code:
/// ```dart
/// final Point(:x, :y) = point;
/// // or when renaming:
/// final Point(x: horizontal, y: vertical) = point;
/// ```
class AvoidExplicitPatternFieldNameRule extends SaropaLintRule {
  const AvoidExplicitPatternFieldNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_explicit_pattern_field_name',
    problemMessage:
        '[avoid_explicit_pattern_field_name] Explicit pattern field name matches variable name.',
    correctionMessage: 'Use shorthand syntax: `:fieldName` instead of '
        '`fieldName: fieldName`.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPatternField((PatternField node) {
      final String? fieldName = node.name?.name?.lexeme;
      final DartPattern pattern = node.pattern;

      if (fieldName == null) return;

      // Check if pattern is a variable pattern with the same name
      if (pattern is DeclaredVariablePattern) {
        final String varName = pattern.name.lexeme;
        if (fieldName == varName) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseShorthandPatternFieldFix()];
}

class _UseShorthandPatternFieldFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPatternField((PatternField node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String? fieldName = node.name?.name?.lexeme;
      final DartPattern pattern = node.pattern;
      if (fieldName == null) return;

      if (pattern is DeclaredVariablePattern) {
        final String varName = pattern.name.lexeme;
        if (fieldName == varName) {
          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Use shorthand :$fieldName',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            // Replace "fieldName: fieldName" with ":fieldName"
            builder.addSimpleReplacement(
              SourceRange(node.offset, node.length),
              ':$fieldName',
            );
          });
        }
      }
    });
  }
}

/// Warns when extension is defined on a Record type.
///
/// Extensions on records can be confusing and are often a sign
/// that a proper class should be used instead.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// extension PointExt on (int, int) {
///   int get sum => $1 + $2;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Point {
///   final int x, y;
///   Point(this.x, this.y);
///   int get sum => x + y;
/// }
/// ```
class AvoidExtensionsOnRecordsRule extends SaropaLintRule {
  const AvoidExtensionsOnRecordsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_extensions_on_records',
    problemMessage:
        '[avoid_extensions_on_records] Extension on record type. Records lack identity for extension discovery.',
    correctionMessage:
        'Create a class with named fields and methods, or use a typedef with extension.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionDeclaration((ExtensionDeclaration node) {
      final ExtensionOnClause? onClause = node.onClause;
      if (onClause == null) return;

      final TypeAnnotation extendedType = onClause.extendedType;
      if (extendedType is RecordTypeAnnotation) {
        reporter.atNode(extendedType, code);
      }
    });
  }
}

/// Warns when Function type is used in record definitions.
///
/// Function types in records are hard to read and maintain.
/// Use a typedef instead.
///
/// Example of **bad** code:
/// ```dart
/// (int, void Function(String)) record = (1, print);
/// ```
///
/// Example of **good** code:
/// ```dart
/// typedef StringCallback = void Function(String);
/// (int, StringCallback) record = (1, print);
/// ```
class AvoidFunctionTypeInRecordsRule extends SaropaLintRule {
  const AvoidFunctionTypeInRecordsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_function_type_in_records',
    problemMessage:
        '[avoid_function_type_in_records] Inline function type in record reduces readability.',
    correctionMessage:
        'Create typedef: typedef MyCallback = void Function(String); then use (int, MyCallback).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      // Check positional fields
      for (final RecordTypeAnnotationPositionalField field
          in node.positionalFields) {
        if (field.type is GenericFunctionType) {
          reporter.atNode(field.type, code);
        }
      }

      // Check named fields
      final RecordTypeAnnotationNamedFields? namedFields = node.namedFields;
      if (namedFields != null) {
        for (final RecordTypeAnnotationNamedField field in namedFields.fields) {
          if (field.type is GenericFunctionType) {
            reporter.atNode(field.type, code);
          }
        }
      }
    });
  }
}

/// Warns when wildcard patterns use Dart keywords.
///
/// Using keywords in wildcard patterns can be confusing.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// switch (value) {
///   case (var class, _): // 'class' is a keyword
/// }
/// ```
class AvoidKeywordsInWildcardPatternRule extends SaropaLintRule {
  const AvoidKeywordsInWildcardPatternRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_keywords_in_wildcard_pattern',
    problemMessage:
        '[avoid_keywords_in_wildcard_pattern] Pattern variable uses a Dart keyword.',
    correctionMessage: 'Use a different variable name.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _keywords = <String>{
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'base',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'Function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'when',
    'while',
    'with',
    'yield',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addDeclaredVariablePattern((DeclaredVariablePattern node) {
      final String name = node.name.lexeme;
      if (_keywords.contains(name)) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when a record type has too many fields.
///
/// Records with many fields become hard to understand.
/// Consider using a class instead.
///
/// ### Configuration
/// Default maximum: 5 fields
class AvoidLongRecordsRule extends SaropaLintRule {
  const AvoidLongRecordsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _maxFields = 5;

  static const LintCode _code = LintCode(
    name: 'avoid_long_records',
    problemMessage:
        '[avoid_long_records] Record has more than $_maxFields fields.',
    correctionMessage: 'Consider using a class for better readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      int fieldCount = node.positionalFields.length;

      final RecordTypeAnnotationNamedFields? namedFields = node.namedFields;
      if (namedFields != null) {
        fieldCount += namedFields.fields.length;
      }

      if (fieldCount > _maxFields) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addRecordLiteral((RecordLiteral node) {
      if (node.fields.length > _maxFields) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when record type mixes named and positional fields.
///
/// Mixing named and positional fields in records reduces readability.
///
/// Example of **bad** code:
/// ```dart
/// (int, {String name}) person;  // Mixed positional and named
/// ```
///
/// Example of **good** code:
/// ```dart
/// ({int age, String name}) person;  // All named
/// // or
/// (int, String) pair;  // All positional
/// ```
class AvoidMixingNamedAndPositionalFieldsRule extends SaropaLintRule {
  const AvoidMixingNamedAndPositionalFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_mixing_named_and_positional_fields',
    problemMessage:
        '[avoid_mixing_named_and_positional_fields] Record mixes named and positional fields.',
    correctionMessage: 'Use either all named or all positional fields.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      final bool hasPositional = node.positionalFields.isNotEmpty;
      final bool hasNamed =
          node.namedFields != null && node.namedFields!.fields.isNotEmpty;

      if (hasPositional && hasNamed) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addRecordLiteral((RecordLiteral node) {
      bool hasPositional = false;
      bool hasNamed = false;

      for (final Expression field in node.fields) {
        if (field is NamedExpression) {
          hasNamed = true;
        } else {
          hasPositional = true;
        }
      }

      if (hasPositional && hasNamed) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when record types are nested.
///
/// Example of **bad** code:
/// ```dart
/// (int, (String, bool)) nested;
/// ({int a, ({String b, bool c}) inner}) deeplyNested;
/// ```
///
/// Example of **good** code:
/// ```dart
/// (int, String, bool) flat;
/// class MyRecord { int a; String b; bool c; }
/// ```
class AvoidNestedRecordsRule extends SaropaLintRule {
  const AvoidNestedRecordsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_records',
    problemMessage: '[avoid_nested_records] Avoid nested record types.',
    correctionMessage: 'Flatten the record or use a class/typedef instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      // Check if any positional field is a record
      for (final RecordTypeAnnotationPositionalField field
          in node.positionalFields) {
        if (field.type is RecordTypeAnnotation) {
          reporter.atNode(node, code);
          return;
        }
      }

      // Check if any named field is a record
      final RecordTypeAnnotationNamedFields? namedFields = node.namedFields;
      if (namedFields != null) {
        for (final RecordTypeAnnotationNamedField field in namedFields.fields) {
          if (field.type is RecordTypeAnnotation) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when a record has only one field.
///
/// Example of **bad** code:
/// ```dart
/// (int,) singleField = (42,);
/// ```
///
/// Example of **good** code:
/// ```dart
/// int value = 42;
/// ```
class AvoidOneFieldRecordsRule extends SaropaLintRule {
  const AvoidOneFieldRecordsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_one_field_records',
    problemMessage:
        '[avoid_one_field_records] Avoid records with only one field.',
    correctionMessage: 'Use the value type directly instead of a record.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      final int namedCount = node.namedFields?.fields.length ?? 0;
      final int fieldCount = node.positionalFields.length + namedCount;
      if (fieldCount == 1) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a positional record field is accessed with $1, $2, etc.
///
/// Example of **bad** code:
/// ```dart
/// final record = (1, 'hello');
/// print(record.$1);
/// ```
///
/// Example of **good** code:
/// ```dart
/// final (number, text) = (1, 'hello');
/// print(number);
/// ```
class AvoidPositionalRecordFieldAccessRule extends SaropaLintRule {
  const AvoidPositionalRecordFieldAccessRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_positional_record_field_access',
    problemMessage:
        '[avoid_positional_record_field_access] Avoid accessing positional record fields with \$1, \$2, etc.',
    correctionMessage: 'Use destructuring or named record fields instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;
      // Check for $1, $2, $3, etc.
      if (RegExp(r'^\$\d+$').hasMatch(propertyName)) {
        reporter.atNode(node.propertyName, code);
      }
    });
  }
}

/// Warns when positional record field has an explicit name that matches
/// the default positional field name pattern ($1, $2, etc.).
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final (int $1, String $2) = record; // Redundant names
/// ```
///
/// #### GOOD:
/// ```dart
/// final (int first, String second) = record; // Meaningful names
/// // or
/// final (int, String) = record; // No names needed
/// ```
class AvoidRedundantPositionalFieldNameRule extends SaropaLintRule {
  const AvoidRedundantPositionalFieldNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_positional_field_name',
    problemMessage:
        '[avoid_redundant_positional_field_name] Positional record field uses redundant default name.',
    correctionMessage: 'Use a meaningful name or omit the name entirely.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      int position = 1;
      for (final RecordTypeAnnotationPositionalField field
          in node.positionalFields) {
        final Token? nameToken = field.name;
        if (nameToken != null) {
          final String name = nameToken.lexeme;
          // Check if using default positional name like $1, $2, etc.
          if (name == '\$$position') {
            reporter.atToken(nameToken, code);
          }
        }
        position++;
      }
    });
  }
}

/// Warns when destructuring is used for only one field.
///
/// Single-field destructuring adds syntax complexity without benefit.
/// Use direct property access instead.
///
/// Example of **bad** code:
/// ```dart
/// final (:name) = person;
/// print(name);
/// ```
///
/// Example of **good** code:
/// ```dart
/// final name = person.name;
/// print(name);
/// ```
class AvoidSingleFieldDestructuringRule extends SaropaLintRule {
  const AvoidSingleFieldDestructuringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_single_field_destructuring',
    problemMessage:
        '[avoid_single_field_destructuring] Avoid destructuring for a single field.',
    correctionMessage: 'Use direct property access instead: final x = obj.x;',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPatternVariableDeclaration((
      PatternVariableDeclaration node,
    ) {
      final DartPattern pattern = node.pattern;

      // Check if it's an object pattern with only one field
      if (pattern is ObjectPattern) {
        if (pattern.fields.length == 1) {
          reporter.atNode(node, code);
        }
      }

      // Check if it's a record pattern with only one field
      if (pattern is RecordPattern) {
        if (pattern.fields.length == 1) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when inline record types should be moved to typedefs.
///
/// Complex record types are easier to read as typedefs.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// ({String name, int age, String email, bool active}) getUser() => ...;
/// ```
///
/// #### GOOD:
/// ```dart
/// typedef User = ({String name, int age, String email, bool active});
/// User getUser() => ...;
/// ```
class MoveRecordsToTypedefsRule extends SaropaLintRule {
  const MoveRecordsToTypedefsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _maxInlineFields = 3;

  static const LintCode _code = LintCode(
    name: 'move_records_to_typedefs',
    problemMessage:
        '[move_records_to_typedefs] Record with >$_maxInlineFields fields should be a typedef.',
    correctionMessage: 'Extract to a typedef for better readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      // Skip if already in a typedef
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is GenericTypeAlias) return;
        parent = parent.parent;
      }

      final int fieldCount =
          node.positionalFields.length + (node.namedFields?.fields.length ?? 0);

      if (fieldCount > _maxInlineFields) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when pattern fields are not in alphabetical order.
///
/// Consistent field ordering in patterns improves readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// if (obj case User(name: n, age: a)) { } // Not alphabetical
/// ```
///
/// #### GOOD:
/// ```dart
/// if (obj case User(age: a, name: n)) { } // Alphabetical
/// ```
class PatternFieldsOrderingRule extends SaropaLintRule {
  const PatternFieldsOrderingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sorted_pattern_fields',
    problemMessage:
        '[prefer_sorted_pattern_fields] Pattern fields should be in alphabetical order.',
    correctionMessage: 'Reorder pattern fields alphabetically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addObjectPattern((ObjectPattern node) {
      final List<String> fieldNames = <String>[];

      for (final PatternField field in node.fields) {
        final PatternFieldName? fieldName = field.name;
        if (fieldName != null) {
          final Token? nameToken = fieldName.name;
          if (nameToken != null) {
            fieldNames.add(nameToken.lexeme);
          }
        }
      }

      // Check if fields are sorted
      for (int i = 1; i < fieldNames.length; i++) {
        if (fieldNames[i].compareTo(fieldNames[i - 1]) < 0) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when pattern null checks can be simplified.
///
/// Use simpler patterns when possible.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// if (value case var x?) { } // Verbose
/// ```
///
/// #### GOOD:
/// ```dart
/// if (value != null) { } // When you don't need the binding
/// // OR
/// if (value case final x?) { } // When you need the binding, use final
/// ```
class PreferSimplerPatternsNullCheckRule extends SaropaLintRule {
  const PreferSimplerPatternsNullCheckRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_simpler_patterns_null_check',
    problemMessage:
        '[prefer_simpler_patterns_null_check] Consider simpler null check pattern.',
    correctionMessage: 'Use != null or final instead of var for null checks.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNullCheckPattern((NullCheckPattern node) {
      final DartPattern pattern = node.pattern;

      // Check for var x? pattern
      if (pattern is DeclaredVariablePattern) {
        final Token? keyword = pattern.keyword;
        if (keyword != null && keyword.lexeme == 'var') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a variable could use wildcard pattern (_) instead.
///
/// If a variable is declared but never used, use _ instead.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final (first, unused) = getRecord();
/// print(first);
/// ```
///
/// #### GOOD:
/// ```dart
/// final (first, _) = getRecord();
/// print(first);
/// ```
class PreferWildcardPatternRule extends SaropaLintRule {
  const PreferWildcardPatternRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_wildcard_pattern',
    problemMessage:
        '[prefer_wildcard_pattern] Unused pattern variable should use wildcard (_).',
    correctionMessage: 'Replace with _ if the value is not used.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This rule needs to track variable usage which is complex
    // For now, just check for obviously unused pattern variables
    // that follow common unused naming patterns

    context.registry.addDeclaredVariablePattern((DeclaredVariablePattern node) {
      final String name = node.name.lexeme;

      // Check for common "unused" naming patterns
      if (name == 'unused' ||
          name == 'ignore' ||
          name == 'ignored' ||
          name.startsWith('unused') ||
          name.startsWith('ignore')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when record fields are not in alphabetical order.
///
/// Consistent field ordering improves readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// typedef Person = ({String name, int age}); // Not alphabetical
/// ```
///
/// #### GOOD:
/// ```dart
/// typedef Person = ({int age, String name}); // Alphabetical
/// ```
class RecordFieldsOrderingRule extends SaropaLintRule {
  const RecordFieldsOrderingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_sorted_record_fields',
    problemMessage:
        '[prefer_sorted_record_fields] Record named fields should be in alphabetical order.',
    correctionMessage: 'Reorder fields alphabetically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addRecordTypeAnnotation((RecordTypeAnnotation node) {
      final List<String> namedFieldNames = <String>[];

      for (final RecordTypeAnnotationNamedField field
          in node.namedFields?.fields ?? <RecordTypeAnnotationNamedField>[]) {
        namedFieldNames.add(field.name.lexeme);
      }

      // Check if named fields are sorted
      for (int i = 1; i < namedFieldNames.length; i++) {
        if (namedFieldNames[i].compareTo(namedFieldNames[i - 1]) < 0) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when multiple positional record accesses could use destructuring.
///
/// When accessing multiple positional fields from the same record variable,
/// pattern destructuring is clearer and more idiomatic (Dart 3.0+).
///
/// Example of **bad** code:
/// ```dart
/// final record = getRecord();
/// print(record.$1);
/// print(record.$2);
/// print(record.$3);
/// ```
///
/// Example of **good** code:
/// ```dart
/// final (first, second, third) = getRecord();
/// print(first);
/// print(second);
/// print(third);
/// ```
class PreferPatternDestructuringRule extends SaropaLintRule {
  const PreferPatternDestructuringRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_pattern_destructuring',
    problemMessage:
        '[prefer_pattern_destructuring] Multiple positional record field accesses could use destructuring.',
    correctionMessage:
        'Use pattern destructuring: final (a, b) = record; (Dart 3.0+).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track record accesses within each block/function scope
    context.registry.addBlock((Block node) {
      _checkBlock(node, reporter);
    });
  }

  void _checkBlock(Block block, SaropaDiagnosticReporter reporter) {
    // Map from variable name to list of positional field accesses
    final Map<String, List<PropertyAccess>> recordAccesses =
        <String, List<PropertyAccess>>{};

    // Visit all statements looking for record field accesses
    for (final Statement statement in block.statements) {
      _collectRecordAccesses(statement, recordAccesses);
    }

    // Report variables with multiple positional accesses
    for (final MapEntry<String, List<PropertyAccess>> entry
        in recordAccesses.entries) {
      if (entry.value.length >= 2) {
        // Report on the first access
        reporter.atNode(entry.value.first, code);
      }
    }
  }

  void _collectRecordAccesses(
    AstNode node,
    Map<String, List<PropertyAccess>> accesses,
  ) {
    if (node is PropertyAccess) {
      final String propertyName = node.propertyName.name;
      // Check for $1, $2, $3, etc.
      if (RegExp(r'^\$\d+$').hasMatch(propertyName)) {
        final Expression? target = node.target;
        if (target is SimpleIdentifier) {
          final String varName = target.name;
          accesses.putIfAbsent(varName, () => <PropertyAccess>[]);
          accesses[varName]!.add(node);
        }
      }
    }

    // Recursively check children
    for (final AstNode child in node.childEntities.whereType<AstNode>()) {
      _collectRecordAccesses(child, accesses);
    }
  }
}
