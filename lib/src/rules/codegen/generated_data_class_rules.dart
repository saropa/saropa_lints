// ignore_for_file: depend_on_referenced_packages

/// Data-class generator rules (dart_mappable / freezed / json_serializable).
///
/// Flags hand-written serialization and value-equality boilerplate in
/// projects that already depend on a code generator able to produce it.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

/// Packages whose presence means a generator is available to the project.
/// If none is a dependency the suggestion is not actionable, so the rule
/// stays silent (same gating as `prefer_freezed_for_data_classes`).
const Set<String> _generatorPackages = <String>{
  'dart_mappable',
  'freezed',
  'freezed_annotation',
  'json_annotation',
  'json_serializable',
};

/// Annotations that mark a class as already generator-managed.
const Set<String> _generatorAnnotations = <String>{
  'MappableClass',
  'freezed',
  'Freezed',
  'unfreezed',
  'Unfreezed',
  'JsonSerializable',
};

/// Flags classes that hand-write `toJson`/`fromJson`/`copyWith`/`==`+`hashCode`
/// in a project that depends on dart_mappable, freezed or json_serializable.
///
/// Since: v17.8.0 | Rule version: v1
///
/// Hand-written data classes are prone to type and naming errors (a typo in a
/// JSON key compiles fine) and repeat string literals that also trigger
/// `avoid_duplicate_string_literals_pair`. A generator removes that class of
/// bug. This is especially useful for AI-assisted code, which tends to write
/// the boilerplate by hand even when the project mandates a generator.
///
/// A class is reported when it declares at least one instance field AND has a
/// concrete `toJson`, `fromJson` (constructor or static method) or `copyWith`,
/// or both `operator ==` and `hashCode`. `toString` alone and `==` alone are
/// NOT enough: they are common in non-data classes and would be noisy.
///
/// Not reported: classes annotated `@MappableClass`, `@freezed`, `@Freezed`,
/// `@unfreezed`, `@Unfreezed` or `@JsonSerializable`; classes mixing in a
/// generated mixin (`_$Name` or `...Mappable`); abstract classes.
///
/// **BAD:**
/// ```dart
/// class Entitlement {
///   Entitlement({required this.lookupKey});
///   final String lookupKey;
///
///   Map<String, Object?> toJson() => {'lookup_key': lookupKey};
///   factory Entitlement.fromJson(Map<String, dynamic> json) =>
///       Entitlement(lookupKey: json['lookup_key'] as String);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @MappableClass()
/// class Entitlement with EntitlementMappable {
///   Entitlement({required this.lookupKey});
///   final String lookupKey;
/// }
/// ```
class PreferGeneratedDataClassesRule extends SaropaLintRule {
  PreferGeneratedDataClassesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'codegen'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'prefer_generated_data_classes',
    '[prefer_generated_data_classes] This class hand-writes serialization or '
        'value-equality code (toJson, fromJson, copyWith, or == with hashCode) '
        'even though the project depends on a code generator. Hand-written '
        'boilerplate invites type and key-name typos and repeated string '
        'literals; generated code is consistent and cannot drift from the '
        'fields. {v1}',
    correctionMessage:
        'Annotate the class with @MappableClass() (dart_mappable), @freezed, '
        'or @JsonSerializable() and remove the hand-written members.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Cheap structural checks first; the pubspec lookup is cached but
      // still costlier than reading the class's own annotations.
      if (node.abstractKeyword != null) return;
      if (_isGeneratorManaged(node)) return;
      if (!_hasHandWrittenBoilerplate(node)) return;

      // Suggestion is only actionable if a generator is a dependency.
      // Checked per node: the file path is only reliable once a unit is
      // visited.
      final String path = context.filePath;
      if (!_generatorPackages.any(
        (String p) => ProjectContext.hasDependency(path, p),
      )) {
        return;
      }

      reporter.atToken(node.nameToken, code);
    });
  }

  /// True when the class carries a generator annotation or mixes in a
  /// generated mixin, i.e. the generator already owns the members.
  static bool _isGeneratorManaged(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      // `@pkg.freezed` parses as a prefixed name; compare the last segment.
      final String full = annotation.name.name;
      final String last = full.substring(full.lastIndexOf('.') + 1);
      if (_generatorAnnotations.contains(last)) return true;
    }

    final WithClause? withClause = node.withClause;
    if (withClause != null) {
      for (final NamedType mixin in withClause.mixinTypes) {
        final String name = mixin.name.lexeme;
        // `_$User` (freezed / json_serializable) and `UserMappable`
        // (dart_mappable) are the generated mixin naming conventions.
        if (name.startsWith(r'_$') || name.endsWith('Mappable')) return true;
      }
    }
    return false;
  }

  /// True for a class with an instance field plus hand-written
  /// toJson/fromJson/copyWith, or both `==` and `hashCode`.
  static bool _hasHandWrittenBoilerplate(ClassDeclaration node) {
    bool hasInstanceField = false;
    bool hasSerializationOrCopy = false;
    bool hasEquals = false;
    bool hasHashCode = false;

    for (final ClassMember member in node.bodyMembers) {
      if (member is FieldDeclaration && !member.isStatic) {
        hasInstanceField = true;
      } else if (member is ConstructorDeclaration) {
        // `Foo.fromJson(...)` and `factory Foo.fromJson(...)`.
        if (member.name?.lexeme == 'fromJson') hasSerializationOrCopy = true;
      } else if (member is MethodDeclaration && !member.isAbstract) {
        final String name = member.name.lexeme;
        if (name == 'toJson' || name == 'copyWith') {
          hasSerializationOrCopy = true;
        } else if (name == 'fromJson' && member.isStatic) {
          hasSerializationOrCopy = true;
        } else if (name == '==') {
          hasEquals = true;
        } else if (name == 'hashCode' && member.isGetter) {
          hasHashCode = true;
        }
      }
    }

    return hasInstanceField &&
        (hasSerializationOrCopy || (hasEquals && hasHashCode));
  }
}
