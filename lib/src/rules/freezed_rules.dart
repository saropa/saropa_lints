// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Freezed-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper usage of the freezed package including
/// JSON serialization, arrow syntax, private constructors, and more.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// FREEZED RULES
// =============================================================================

/// Warns when both @freezed and @JsonSerializable are used on same class.
///
/// Alias: freezed_json_conflict, duplicate_json_annotation
///
/// @freezed already generates JSON serialization. Adding @JsonSerializable
/// causes conflicts and duplicate code.
///
/// **BAD:**
/// ```dart
/// @freezed
/// @JsonSerializable()  // Conflict!
/// class User with _$User {
///   factory User({String? name}) = _User;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({String? name}) = _User;
///   factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
/// }
/// ```
class AvoidFreezedJsonSerializableConflictRule extends SaropaLintRule {
  const AvoidFreezedJsonSerializableConflictRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_freezed_json_serializable_conflict',
    problemMessage:
        '[avoid_freezed_json_serializable_conflict] Combining Freezed and json_serializable annotations incorrectly can result in code generation conflicts, leading to broken serialization, runtime errors, or data loss. This can cause your app to fail when parsing or serializing JSON, especially in production environments. Always follow the recommended integration patterns to ensure reliable code generation. See https://pub.dev/packages/freezed#json_serializable.',
    correctionMessage:
        'Review and adjust your Freezed and json_serializable usage to avoid annotation conflicts, following the official documentation for correct integration. This ensures consistent and reliable serialization behavior. See https://pub.dev/packages/freezed#json_serializable for best practices.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      bool hasFreezed = false;
      Annotation? jsonSerializableAnnotation;

      for (final annotation in node.metadata) {
        final name = annotation.name.name.toLowerCase();
        if (name == 'freezed') {
          hasFreezed = true;
        }

        // cspell:ignore jsonserializable
        if (name == 'jsonserializable') {
          jsonSerializableAnnotation = annotation;
        }
      }

      if (hasFreezed && jsonSerializableAnnotation != null) {
        reporter.atNode(jsonSerializableAnnotation, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => [_RemoveJsonSerializableFix()];
}

class _RemoveJsonSerializableFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() != 'jsonserializable') continue;

        final changeBuilder = reporter.createChangeBuilder(
          message: 'Remove @JsonSerializable()',
          priority: 80,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addDeletion(annotation.sourceRange);
        });
        return;
      }
    });
  }
}

// cspell:ignore freezed_fromjson_syntax
/// Warns when Freezed fromJson has block body instead of arrow syntax.
///
/// Alias: freezed_fromjson_syntax, freezed_arrow_required
///
/// Freezed fromJson factory must use arrow syntax for code generation.
///
/// **BAD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User.fromJson(Map<String, dynamic> json) {
///     return _$UserFromJson(json);  // Block body - won't work!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
/// }
/// ```
class RequireFreezedArrowSyntaxRule extends SaropaLintRule {
  const RequireFreezedArrowSyntaxRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_arrow_syntax',
    problemMessage:
        '[require_freezed_arrow_syntax] The fromJson factory in a @freezed class must use arrow syntax (=>) to ensure correct code generation. Using block syntax ({}) breaks the generated code, causing runtime errors, missing serialization, and build_runner failures. This leads to broken deserialization and hard-to-debug bugs in your models.',
    correctionMessage:
        'Change the fromJson factory to use arrow syntax. Example: factory User.fromJson(Map<String, dynamic> json) => _\$UserFromJson(json);',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check for @freezed annotation
      bool hasFreezed = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'freezed') {
          hasFreezed = true;
          break;
        }
      }

      if (!hasFreezed) return;

      // Check fromJson factory
      for (final member in node.members) {
        if (member is ConstructorDeclaration &&
            member.factoryKeyword != null &&
            member.name?.lexeme == 'fromJson') {
          // Check if it uses block body instead of arrow
          final body = member.body;
          if (body is BlockFunctionBody) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => [_ConvertToArrowSyntaxFix()];
}

class _ConvertToArrowSyntaxFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      for (final member in node.members) {
        if (member is! ConstructorDeclaration) continue;
        if (member.factoryKeyword == null) continue;
        if (member.name?.lexeme != 'fromJson') continue;
        if (!member.sourceRange.intersects(analysisError.sourceRange)) continue;

        final body = member.body;
        if (body is! BlockFunctionBody) continue;

        final block = body.block;
        if (block.statements.length != 1) continue;

        final statement = block.statements.first;
        if (statement is! ReturnStatement) continue;

        final expression = statement.expression;
        if (expression == null) continue;

        final changeBuilder = reporter.createChangeBuilder(
          message: 'Convert to arrow syntax',
          priority: 80,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleReplacement(
            body.sourceRange,
            '=> ${expression.toSource()};',
          );
        });
        return;
      }
    });
  }
}

/// Warns when Freezed class is missing the private constructor.
///
/// Alias: freezed_private_ctor, freezed_underscore_ctor
///
/// Freezed classes need a private constructor for methods like copyWith.
///
/// **BAD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({String? name}) = _User;
///   // Missing: const User._();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   const User._();  // Required for custom methods
///   factory User({String? name}) = _User;
/// }
/// ```
class RequireFreezedPrivateConstructorRule extends SaropaLintRule {
  const RequireFreezedPrivateConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_private_constructor',
    problemMessage:
        '[require_freezed_private_constructor] Missing private constructor '
        'breaks code generation, causing build_runner to fail.',
    correctionMessage: 'Add: const ClassName._();',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check for @freezed annotation
      bool hasFreezed = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'freezed') {
          hasFreezed = true;
          break;
        }
      }

      if (!hasFreezed) return;

      // Check for private constructor (ClassName._)
      bool hasPrivateConstructor = false;
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          final ctorName = member.name?.lexeme ?? '';
          if (ctorName == '_') {
            hasPrivateConstructor = true;
            break;
          }
        }
      }

      // Only warn if class has custom methods that need the private ctor
      bool hasCustomMethods = false;
      for (final member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme != 'toString' &&
            member.name.lexeme != 'toJson') {
          hasCustomMethods = true;
          break;
        }
      }

      if (!hasPrivateConstructor && hasCustomMethods) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => [_AddPrivateConstructorFix()];
}

class _AddPrivateConstructorFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final className = node.name.lexeme;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add const $className._()',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.leftBracket.end,
          '\n  const $className._();',
        );
      });
    });
  }
}

/// Warns when Freezed is used without explicit_to_json in build.yaml for nested objects.
///
/// Alias: freezed_explicit_json, require_explicit_to_json
///
/// When using Freezed with nested objects, explicit_to_json: true is required
/// in build.yaml to ensure proper JSON serialization of nested objects.
/// Without it, nested objects may not serialize correctly.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({
///     required String name,
///     required Address address, // Nested object - needs explicit_to_json
///   }) = _User;
/// }
/// ```
///
/// #### GOOD:
/// Configure in build.yaml:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       json_serializable:
///         options:
///           explicit_to_json: true
/// ```
class RequireFreezedExplicitJsonRule extends SaropaLintRule {
  const RequireFreezedExplicitJsonRule() : super(code: _code);

  /// Potential bug. Nested objects may not serialize correctly.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_explicit_json',
    problemMessage:
        '[require_freezed_explicit_json] Freezed class with nested objects may need explicit_to_json in build.yaml. Freezed requires explicit_to_json: true in build.yaml to correctly serialize nested objects into JSON. Without this setting, nested toJson() calls produce Instance-of strings instead of actual JSON data.',
    correctionMessage:
        'Add explicit_to_json: true to build.yaml under json_serializable options. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has @freezed annotation
      if (!_hasFreezedAnnotation(node)) return;

      // Check if class has nested objects (non-primitive types)
      if (!_hasNestedObjects(node)) return;

      // If we get here, the class has nested objects
      reporter.atNode(node, code);
    });
  }

  bool _hasFreezedAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String annotationName = annotation.name.name;
      if (annotationName == 'freezed' || annotationName == 'Freezed') {
        return true;
      }
    }
    return false;
  }

  bool _hasNestedObjects(ClassDeclaration node) {
    // Check factory constructors for complex type parameters
    for (final ClassMember member in node.members) {
      if (member is ConstructorDeclaration && member.factoryKeyword != null) {
        for (final FormalParameter param in member.parameters.parameters) {
          if (_isComplexType(param)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _isComplexType(FormalParameter param) {
    TypeAnnotation? type;

    if (param is SimpleFormalParameter) {
      type = param.type;
    } else if (param is DefaultFormalParameter) {
      final FormalParameter innerParam = param.parameter;
      if (innerParam is SimpleFormalParameter) {
        type = innerParam.type;
      }
    }

    if (type is NamedType) {
      final String typeName = type.name2.lexeme;
      // Skip primitive types, common Flutter/Dart types, and collections
      const Set<String> primitiveTypes = <String>{
        'String',
        'int',
        'double',
        'bool',
        'num',
        'dynamic',
        'Object',
        'void',
        'DateTime',
        'Duration',
        'Uri',
        'BigInt',
        'List',
        'Map',
        'Set',
        'Iterable',
      };
      if (!primitiveTypes.contains(typeName)) {
        // Check if it's a type argument of a collection
        final TypeArgumentList? typeArgs = type.typeArguments;
        if (typeArgs == null) {
          return true; // Non-primitive, non-collection type
        }
      }

      // Check type arguments for nested complex types
      final TypeArgumentList? typeArgs = type.typeArguments;
      if (typeArgs != null) {
        for (final TypeAnnotation arg in typeArgs.arguments) {
          if (arg is NamedType) {
            final String argTypeName = arg.name2.lexeme;
            const Set<String> innerPrimitiveTypes = <String>{
              'String',
              'int',
              'double',
              'bool',
              'num',
              'dynamic',
              'Object',
            };
            if (!innerPrimitiveTypes.contains(argTypeName)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }
}

/// Warns when Freezed nullable fields could use @Default annotation instead.
///
/// Alias: freezed_default_annotation, prefer_freezed_defaults
///
/// Using @Default annotation instead of nullable types provides clearer
/// intent and better code when the field should have a default value
/// rather than being truly optional.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({
///     required String name,
///     int? count, // Should this be nullable or have a default?
///     List<String>? items, // Empty list might be better default
///   }) = _User;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({
///     required String name,
///     @Default(0) int count, // Clear default value
///     @Default([]) List<String> items, // Empty list as default
///   }) = _User;
/// }
/// ```
class PreferFreezedDefaultValuesRule extends SaropaLintRule {
  const PreferFreezedDefaultValuesRule() : super(code: _code);

  /// Style preference. Clearer intent for optional fields.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_freezed_default_values',
    problemMessage:
        '[prefer_freezed_default_values] Freezed nullable field could use @Default annotation instead. Using @Default annotation instead of nullable types provides clearer intent and better code when the field must have a default value rather than being truly optional.',
    correctionMessage:
        'Use @Default(value) instead of nullable type if field has a sensible default. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has @freezed annotation
      if (!_hasFreezedAnnotation(node)) return;

      // Check factory constructors for nullable parameters without @Default
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration && member.factoryKeyword != null) {
          for (final FormalParameter param in member.parameters.parameters) {
            if (_isNullableWithoutDefault(param)) {
              reporter.atNode(param, code);
            }
          }
        }
      }
    });
  }

  bool _hasFreezedAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String annotationName = annotation.name.name;
      if (annotationName == 'freezed' || annotationName == 'Freezed') {
        return true;
      }
    }
    return false;
  }

  bool _isNullableWithoutDefault(FormalParameter param) {
    // Handle DefaultFormalParameter (optional parameters)
    FormalParameter actualParam = param;
    if (param is DefaultFormalParameter) {
      actualParam = param.parameter;
    }

    // Check if parameter has @Default annotation
    final NodeList<Annotation>? metadata =
        actualParam is NormalFormalParameter ? actualParam.metadata : null;
    if (metadata != null) {
      for (final Annotation annotation in metadata) {
        if (annotation.name.name == 'Default') {
          return false; // Already has @Default
        }
      }
    }

    // Check if type is nullable
    if (actualParam is SimpleFormalParameter) {
      final TypeAnnotation? type = actualParam.type;
      if (type is NamedType) {
        // Check for ? suffix indicating nullable
        if (type.question != null) {
          return true;
        }
      }
    }

    return false;
  }
}

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
        '[require_freezed_lint_package] File uses Freezed. Add freezed_lint package for specialized linting. Heuristic warning: This rule cannot verify if freezed_lint is in your pubspec.yaml. It simply reminds developers using Freezed to Add freezed_lint to their dev_dependencies. Disable this rule if you have already installed freezed_lint.',
    correctionMessage:
        'Add freezed_lint to dev_dependencies. Disable this rule if already installed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

/// Warns when Freezed is used for logic classes like Blocs or Services.
///
/// Freezed is designed for immutable data classes. Using it for Blocs,
/// Cubits, or Services adds unnecessary complexity.
///
/// **BAD:**
/// ```dart
/// @freezed
/// class UserBloc with _$UserBloc {
///   // Freezed on a Bloc - overkill!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   const factory User({required String name}) = _User;
/// }
///
/// class UserBloc extends Bloc<UserEvent, UserState> {
///   // Regular class for logic
/// }
/// ```
class AvoidFreezedForLogicClassesRule extends SaropaLintRule {
  const AvoidFreezedForLogicClassesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_freezed_for_logic_classes',
    problemMessage:
        '[avoid_freezed_for_logic_classes] Freezed annotation on logic class. '
        'Freezed is meant for data classes, not Blocs/Services.',
    correctionMessage:
        'Remove @freezed from logic classes. Use regular classes for Blocs/Services.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _logicClassSuffixes = <String>{
    'Bloc',
    'Cubit',
    'Service',
    'Repository',
    'Controller',
    'Provider',
    'Notifier',
    'Manager',
    'UseCase',
    'Interactor',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if has @freezed annotation
      bool hasFreezed = false;
      for (final annotation in node.metadata) {
        final name = annotation.name.name;
        if (name == 'freezed' || name == 'Freezed') {
          hasFreezed = true;
          break;
        }
      }

      if (!hasFreezed) return;

      // Check if class name suggests it's a logic class
      final String className = node.name.lexeme;
      for (final suffix in _logicClassSuffixes) {
        if (className.endsWith(suffix)) {
          reporter.atToken(node.name, code);
          return;
        }
      }
    });
  }
}

/// Warns when data classes could benefit from using freezed.
///
/// Alias: use_freezed, immutable_data_class
///
/// Data classes with multiple fields benefit from freezed for immutability,
/// copyWith, equality, and serialization. Pure data classes without freezed
/// require manual boilerplate.
///
/// **BAD:**
/// ```dart
/// class User {
///   final String name;
///   final int age;
///   final String? email;
///
///   User({required this.name, required this.age, this.email});
///
///   User copyWith({String? name, int? age, String? email}) {
///     return User(
///       name: name ?? this.name,
///       age: age ?? this.age,
///       email: email ?? this.email,
///     );
///   }
///
///   @override
///   bool operator ==(Object other) =>
///       identical(this, other) ||
///       other is User &&
///           name == other.name &&
///           age == other.age &&
///           email == other.email;
///
///   @override
///   int get hashCode => name.hashCode ^ age.hashCode ^ email.hashCode;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   const factory User({
///     required String name,
///     required int age,
///     String? email,
///   }) = _User;
///
///   factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
/// }
/// ```
class PreferFreezedForDataClassesRule extends SaropaLintRule {
  const PreferFreezedForDataClassesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_freezed_for_data_classes',
    problemMessage:
        '[prefer_freezed_for_data_classes] Data class with manual copyWith/equals. '
        'Consider using @freezed to eliminate boilerplate.',
    correctionMessage:
        'Add @freezed annotation and let code generation handle copyWith, ==, hashCode.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if already using freezed/equatable
      for (final annotation in node.metadata) {
        final name = annotation.name.name;
        if (name == 'freezed' ||
            name == 'Freezed' ||
            name == 'immutable' ||
            name == 'JsonSerializable') {
          return; // Already using code generation
        }
      }

      // Check for extends Equatable
      final extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final superclass = extendsClause.superclass.name.lexeme;
        if (superclass == 'Equatable') return;
      }

      // Count data class indicators
      int finalFieldCount = 0;
      bool hasCopyWith = false;
      bool hasEqualsOverride = false;
      bool hasHashCodeOverride = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          if (member.fields.isFinal) {
            finalFieldCount += member.fields.variables.length;
          }
        }
        if (member is MethodDeclaration) {
          final name = member.name.lexeme;
          if (name == 'copyWith') hasCopyWith = true;
          if (name == '==') hasEqualsOverride = true;
          if (name == 'hashCode') hasHashCodeOverride = true;
        }
      }

      // Suggest freezed if:
      // - Has 3+ final fields AND
      // - Has manual copyWith OR manual equals/hashCode
      if (finalFieldCount >= 3 &&
          (hasCopyWith || (hasEqualsOverride && hasHashCodeOverride))) {
        reporter.atToken(node.name, code);
      }
    });
  }
}
