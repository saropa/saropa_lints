// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

/// Isar database rules for Flutter applications.
///
/// These rules detect common Isar database anti-patterns and
/// data corruption risks.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when enum types are used directly as fields in Isar `@collection` classes.
///
/// Alias: avoid_isar_enum_index_change, isar_enum_corruption, isar_enum_index
///
/// Storing enums directly in Isar is dangerous because:
/// - Renaming an enum value breaks existing data
/// - Reordering enum values corrupts data (stored as index)
///
/// The correct pattern is to store the enum as a String and use a cached getter:
///
/// Example of **bad** code:
/// ```dart
/// @collection
/// class Contact {
///   CountryEnum? country;  // DANGEROUS: stored as index
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @collection
/// class Contact {
///   String? countryCode;  // Store as string in DB
///
///   @ignore
///   CountryEnum? _country;  // Cached (ignored by Isar)
///
///   @ignore
///   CountryEnum? get country => _country ??= CountryEnum.tryParse(countryCode);
/// }
/// ```
class AvoidIsarEnumFieldRule extends SaropaLintRule {
  const AvoidIsarEnumFieldRule() : super(code: _code);

  /// Data corruption risk: renaming/reordering enums breaks persisted rows.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_enum_field',
    problemMessage: 'Enum fields in Isar collections can cause data corruption '
        'if the enum is renamed or reordered.',
    correctionMessage: 'Store the enum as a String field and use an @ignore '
        'getter to parse it. See rule documentation for the pattern.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Type name suffixes that typically indicate an enum
  static const List<String> _enumSuffixes = <String>[
    'Enum',
    'Type',
    'Status',
    'Mode',
    'Kind',
    'Category',
    'State',
  ];

  /// Types that look like enums but are safe (not actually enums)
  static const Set<String> _safeTypes = <String>{
    'DateTime',
    'DateTimeType',
    'IndexType',
    'String',
    'int',
    'double',
    'bool',
    'Int8List',
    'Int16List',
    'Int32List',
    'Int64List',
    'Float32List',
    'Float64List',
    'Uint8List',
    'List',
    'Id',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this class has @collection annotation
      if (!_hasCollectionAnnotation(node)) {
        return;
      }

      // Check each field in the class
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          _checkFieldDeclaration(member, reporter);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AvoidIsarEnumFieldFix()];

  /// Check if a class has the @collection annotation
  bool _hasCollectionAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'collection') {
        return true;
      }
    }
    return false;
  }

  /// Check if a field has the @ignore annotation
  bool _hasIgnoreAnnotation(FieldDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'ignore') {
        return true;
      }
    }
    return false;
  }

  /// Check a field declaration for enum type usage
  void _checkFieldDeclaration(
      FieldDeclaration node, SaropaDiagnosticReporter reporter) {
    // Skip if field has @ignore annotation
    if (_hasIgnoreAnnotation(node)) {
      return;
    }

    final TypeAnnotation? type = node.fields.type;
    if (type == null) {
      return;
    }

    final String typeName = _extractTypeName(type);
    if (typeName.isEmpty) {
      return;
    }

    // Skip safe types
    if (_safeTypes.contains(typeName)) {
      return;
    }

    // Check if the type looks like an enum
    if (_looksLikeEnumType(typeName)) {
      reporter.atNode(node.fields, code);
    }
  }

  /// Extract the base type name from a type annotation
  String _extractTypeName(TypeAnnotation type) {
    if (type is NamedType) {
      return type.name.lexeme;
    }
    return '';
  }

  /// Check if a type name looks like an enum type based on naming conventions
  bool _looksLikeEnumType(String typeName) {
    // Remove nullable suffix for checking
    String cleanName = typeName;
    if (cleanName.endsWith('?')) {
      cleanName = cleanName.replaceAll('?', '');
    }

    for (final String suffix in _enumSuffixes) {
      if (cleanName.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }
}

class _AvoidIsarEnumFieldFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    final String fileContent = resolver.source.contents.data;

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.fields.variables.length != 1) return;
      if (_hasIgnoreAnnotation(node)) return;

      final TypeAnnotation? type = node.fields.type;
      if (type is! NamedType) return;

      final VariableDeclaration variable = node.fields.variables.first;
      final ClassDeclaration? clazz = node.parent is ClassDeclaration
          ? node.parent as ClassDeclaration
          : null;
      if (clazz == null || !_hasCollectionAnnotation(clazz)) return;

      final bool isNullable = type.question != null;
      final String enumTypeSource = type.name.toString();
      final String enumTypeBase = enumTypeSource.endsWith('?')
          ? enumTypeSource.substring(0, enumTypeSource.length - 1)
          : enumTypeSource;
      final String enumGetterType = enumTypeSource;
      final String cacheFieldType =
          enumGetterType.endsWith('?') ? enumGetterType : '$enumGetterType?';
      final String stringType = isNullable ? 'String?' : 'String';

      final String variableName = variable.name.lexeme;
      final String stringFieldName = '${variableName}Name';
      final String cacheFieldName = '_$variableName';

      if (_classHasMemberNamed(clazz, stringFieldName) ||
          _classHasMemberNamed(clazz, cacheFieldName)) {
        return;
      }

      final String indent = _computeIndent(fileContent, node.offset);
      final String storageModifiers = _buildStorageModifiers(node);

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace enum field with string storage + helper',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final StringBuffer buffer = StringBuffer();

        final Comment? docs = node.documentationComment;
        if (docs != null) {
          buffer.writeln('$indent${docs.toSource()}');
        }

        for (final Annotation annotation in node.metadata) {
          buffer.writeln('$indent${annotation.toSource()}');
        }

        buffer.writeln('$indent$storageModifiers$stringType $stringFieldName;');
        buffer.writeln();
        buffer.writeln('$indent@ignore');
        buffer.writeln('$indent$cacheFieldType $cacheFieldName;');
        buffer.writeln();
        buffer.writeln('$indent@ignore');
        buffer.writeln('$indent$enumGetterType get $variableName {');
        buffer.writeln('$indent  final value = $stringFieldName;');
        if (isNullable) {
          buffer.writeln('$indent  if (value == null) return $cacheFieldName;');
          buffer.writeln('$indent  try {');
          buffer.writeln(
              '$indent    return $cacheFieldName ??= $enumTypeBase.values.byName(value);');
          buffer.writeln('$indent  } on ArgumentError {');
          buffer.writeln('$indent    return null;');
          buffer.writeln('$indent  }');
        } else {
          buffer.writeln('$indent  final cached = $cacheFieldName;');
          buffer.writeln('$indent  if (cached != null) return cached;');
          buffer.writeln('$indent  if (value == null) {');
          buffer.writeln(
              "$indent    throw StateError('$stringFieldName is null for $variableName');");
          buffer.writeln('$indent  }');
          buffer.writeln('$indent  try {');
          buffer.writeln(
              '$indent    return $cacheFieldName ??= $enumTypeBase.values.byName(value);');
          buffer.writeln('$indent  } on ArgumentError {');
          buffer.writeln(
              "$indent    throw StateError('Invalid $enumTypeBase value: \$value');");
          buffer.writeln('$indent  }');
        }
        buffer.writeln('$indent}');

        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          buffer.toString(),
        );
      });
    });
  }

  bool _classHasMemberNamed(ClassDeclaration clazz, String name) {
    for (final ClassMember member in clazz.members) {
      if (member is FieldDeclaration) {
        for (final VariableDeclaration variable in member.fields.variables) {
          if (variable.name.lexeme == name) {
            return true;
          }
        }
      }
      if (member is MethodDeclaration && member.name.lexeme == name) {
        return true;
      }
    }
    return false;
  }

  String _buildStorageModifiers(FieldDeclaration node) {
    final StringBuffer modifiers = StringBuffer();
    if (node.isStatic) modifiers.write('static ');

    final VariableDeclarationList fields = node.fields;
    if (fields.lateKeyword != null) modifiers.write('late ');
    if (fields.isFinal || fields.keyword?.lexeme == 'final') {
      modifiers.write('final ');
    }

    return modifiers.toString();
  }

  bool _hasCollectionAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'collection') {
        return true;
      }
    }
    return false;
  }

  bool _hasIgnoreAnnotation(FieldDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'ignore') {
        return true;
      }
    }
    return false;
  }

  String _computeIndent(String content, int offset) {
    final int lineStart = content.lastIndexOf('\n', offset - 1);
    final int start = lineStart == -1 ? 0 : lineStart + 1;
    final int firstNonWhitespace = content.indexOf(RegExp(r'[^\s]'), start);
    if (firstNonWhitespace == -1 || firstNonWhitespace > offset) {
      return content.substring(start, offset);
    }
    return content.substring(start, firstNonWhitespace);
  }
}
