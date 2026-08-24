// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:meta/meta.dart' show visibleForTesting;

// Provides SafeClassDeclMembers compat extension (.bodyMembers, .nameToken,
// .nameTypeParameters) that bridges analyzer 9-13 API differences.
import '../../analyzer_compat.dart';
import '../../native/saropa_fix.dart';
import '../../rules/config/dart_sdk_migration_rules.dart'
    show isPrimaryConstructorEligible;

/// Quick fix: Rewrite an eligible class to Dart 3.13+ primary constructor
/// syntax.
///
/// Companion fix for `PreferPrimaryConstructorRule`. Only rewrites the
/// signature (`class Foo(...)` / `class const Foo(...)`) — the `const`
/// keyword placement is non-obvious: it goes between `class` and the class
/// name, NOT before `class` (`const class Foo(...)` is a parse error) and
/// NOT attached to the parameter list. Verified against `dart analyze` on
/// Dart 3.13.1.
///
/// Declines to edit (no-op `compute`) when a field's type can't be read
/// verbatim from source (untyped final field) — leaving the class flagged
/// as detection-only rather than risk emitting a parameter with no type.
class PreferPrimaryConstructorFix extends SaropaFixProducer {
  PreferPrimaryConstructorFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferPrimaryConstructorFix',
    4000,
    'Convert to primary constructor',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final classDecl = node is ClassDeclaration
        ? node
        : node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;
    // Defensive re-check: the fix must never fire on a class the rule itself
    // would not flag, even if the AST shifted between diagnostic and fix.
    if (!isPrimaryConstructorEligible(classDecl)) return;

    // Re-locate the single unnamed generative constructor and the source
    // text of each instance field's type (mirrors isPrimaryConstructorEligible,
    // which already proved these exist and are well-formed).
    ConstructorDeclaration? ctor;
    final fieldTypeSource = <String, String>{};
    // Uses .bodyMembers from the analyzer_compat.dart extension,
    // which bridges analyzer 9-13 API differences.
    for (final ClassMember member in classDecl.bodyMembers) {
      if (member is ConstructorDeclaration &&
          member.factoryKeyword == null &&
          member.name == null) {
        ctor = member;
      } else if (member is FieldDeclaration && !member.isStatic) {
        final typeAnnotation = member.fields.type;
        // An untyped final field (`final x;`) has no source text to carry
        // into a primary-constructor parameter — bail rather than guess.
        if (typeAnnotation == null) return;
        for (final variable in member.fields.variables) {
          fieldTypeSource[variable.name.lexeme] = typeAnnotation.toSource();
        }
      }
    }
    if (ctor == null) return;

    final paramsSource = buildPrimaryConstructorParamsSource(
      ctor.parameters,
      fieldTypeSource,
    );
    if (paramsSource == null) return;

    final isConst = ctor.constKeyword != null;

    await builder.addDartFileEdit(file, (builder) {
      // `const` sits between `class` and the class name in primary-ctor
      // syntax (`class const Foo(...)`), not before `class` or after `Foo`.
      if (isConst) {
        // Uses .nameToken from the analyzer_compat.dart extension,
        // which bridges analyzer 9-13 API differences.
        builder.addSimpleInsertion(classDecl.nameToken.offset, 'const ');
      }

      // Replace everything from after the class name (and type parameters,
      // if any) through the closing brace with `(<params>);`. Everything
      // before that point — doc comment, annotations, `class` keyword,
      // name, type parameters — is left untouched.
      // Migrated: .typeParameters → .nameTypeParameters (compat extension),
      // .nameToken from compat extension (analyzer 9-13 bridge).
      final replaceStart =
          classDecl.nameTypeParameters?.end ?? classDecl.nameToken.end;
      builder.addSimpleReplacement(
        SourceRange(replaceStart, classDecl.end - replaceStart),
        '($paramsSource);',
      );
    });
  }
}

/// Builds the primary-constructor parameter list text, preserving the
/// original required/optional-positional/named grouping and default
/// values. Returns null if a parameter's field type could not be resolved
/// (should not happen given `isPrimaryConstructorEligible` already passed).
///
/// Top-level and `@visibleForTesting` so the string-building logic can be
/// tested directly against a parsed [FormalParameterList] without driving
/// the full `ChangeBuilder`/analysis-server fix-application machinery,
/// which this codebase has no test harness for.
@visibleForTesting
String? buildPrimaryConstructorParamsSource(
  FormalParameterList params,
  Map<String, String> fieldTypeSource,
) {
  final required = <String>[];
  final grouped = <String>[];
  String? groupOpen;
  String? groupClose;

  // Migrated: DefaultFormalParameter is removed in analyzer 13.
  // Each FormalParameter now carries .defaultClause directly.
  // The wrapping layer (DefaultFormalParameter.parameter) is gone —
  // the param IS the actual parameter now.
  for (final FormalParameter param in params.parameters) {
    if (param is! FieldFormalParameter) return null;

    final name = param.name.lexeme;
    final type = fieldTypeSource[name];
    if (type == null) return null;

    // Migrated: .defaultValue → .defaultClause?.value (analyzer 13 API).
    final defaultText = param.defaultClause != null
        ? ' = ${param.defaultClause!.value.toSource()}'
        : '';

    if (param.isRequiredPositional) {
      required.add('final $type $name');
    } else if (param.isOptionalPositional) {
      groupOpen = '[';
      groupClose = ']';
      grouped.add('final $type $name$defaultText');
    } else if (param.isRequiredNamed) {
      groupOpen = '{';
      groupClose = '}';
      grouped.add('required final $type $name');
    } else {
      // Optional named.
      groupOpen = '{';
      groupClose = '}';
      grouped.add('final $type $name$defaultText');
    }
  }

  final parts = <String>[...required];
  if (grouped.isNotEmpty) {
    parts.add('$groupOpen${grouped.join(', ')}$groupClose');
  }
  return parts.join(', ');
}
