// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';

import '../saropa_lint_rule.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns against any usage of adjacent strings.
///
/// Adjacent strings can be confusing and error-prone.
///
/// Example of **bad** code:
/// ```dart
/// final message = 'Hello' 'World';
/// ```
///
/// Example of **good** code:
/// ```dart
/// final message = 'HelloWorld';
/// ```
class AvoidAdjacentStringsRule extends SaropaLintRule {
  const AvoidAdjacentStringsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_adjacent_strings',
    problemMessage: 'Avoid using adjacent strings.',
    correctionMessage: 'Combine into a single string or use concatenation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAdjacentStrings((AdjacentStrings node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when accessing enum values by index (`EnumName.values[i]`).
class AvoidEnumValuesByIndexRule extends SaropaLintRule {
  const AvoidEnumValuesByIndexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_enum_values_by_index',
    problemMessage: 'Avoid accessing enum values by index.',
    correctionMessage: 'Use EnumName.byName() or switch on specific values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      // Check for .values property access
      if (target.propertyName.name != 'values') return;

      // Check if target is likely an enum (PascalCase identifier)
      final Expression? enumTarget = target.target;
      if (enumTarget is SimpleIdentifier) {
        final String name = enumTarget.name;
        if (name.isNotEmpty && name[0] == name[0].toUpperCase() && !name.startsWith('_')) {
          reporter.atNode(node, code);
        }
      } else if (enumTarget is PrefixedIdentifier) {
        final String name = enumTarget.identifier.name;
        if (name.isNotEmpty && name[0] == name[0].toUpperCase() && !name.startsWith('_')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Uri constructor is called with an invalid URI string.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final uri = Uri.parse('not a valid uri[]');
/// ```
///
/// #### GOOD:
/// ```dart
/// final uri = Uri.parse('https://example.com/path');
/// ```
class AvoidIncorrectUriRule extends SaropaLintRule {
  const AvoidIncorrectUriRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_incorrect_uri',
    problemMessage: 'URI string appears to be malformed.',
    correctionMessage: 'Check the URI for syntax errors.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Uri') return;

      final String methodName = node.methodName.name;
      if (methodName != 'parse' && methodName != 'tryParse') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is! SimpleStringLiteral) return;

      final String uriString = firstArg.value;

      // Basic validation checks
      if (_hasInvalidUriCharacters(uriString)) {
        reporter.atNode(firstArg, code);
      }
    });

    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Uri') return;

      // Check for Uri() constructor with invalid string argument
      // The main Uri constructor uses named parameters, so check Uri.parse pattern above
    });
  }

  bool _hasInvalidUriCharacters(String uri) {
    // Check for obviously invalid characters
    const Set<String> invalidChars = <String>{
      '[',
      ']',
      '{',
      '}',
      '|',
      '\\',
      '^',
      '`',
      '<',
      '>',
    };

    for (int i = 0; i < uri.length; i++) {
      if (invalidChars.contains(uri[i])) {
        // Allow [ ] in IPv6 addresses
        if ((uri[i] == '[' || uri[i] == ']') && uri.contains('://[')) {
          continue;
        }
        return true;
      }
    }

    // Check for spaces (should be encoded)
    if (uri.contains(' ') && !uri.contains('%20')) {
      return true;
    }

    return false;
  }
}

/// Warns when enum types are used directly as fields in Isar `@collection` classes.
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
  void _checkFieldDeclaration(FieldDeclaration node, SaropaDiagnosticReporter reporter) {
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
      final ClassDeclaration? clazz =
          node.parent is ClassDeclaration ? node.parent as ClassDeclaration : null;
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
          buffer
              .writeln('$indent    return $cacheFieldName ??= $enumTypeBase.values.byName(value);');
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
          buffer
              .writeln('$indent    return $cacheFieldName ??= $enumTypeBase.values.byName(value);');
          buffer.writeln('$indent  } on ArgumentError {');
          buffer.writeln("$indent    throw StateError('Invalid $enumTypeBase value: \$value');");
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

/// Warns when late keyword is used.
///
/// Late variables can lead to runtime errors if accessed before initialization.
/// Consider using nullable types or initializing in the constructor.
class AvoidLateKeywordRule extends SaropaLintRule {
  const AvoidLateKeywordRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_late_keyword',
    problemMessage: "Avoid using 'late' keyword.",
    correctionMessage: 'Use nullable type with null check, or initialize in constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final AstNode? parent = node.parent;
      if (parent is VariableDeclarationList && parent.lateKeyword != null) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (node.fields.lateKeyword != null) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a getter is called without parentheses in print/debugPrint.
///
/// This catches common cases where a method/getter reference is passed to
/// print instead of calling it.
///
/// Example of **bad** code:
/// ```dart
/// print(list.length);  // OK - property
/// print(myMethod);  // BAD - probably meant myMethod()
/// ```
///
/// Example of **good** code:
/// ```dart
/// print(myMethod());  // Method is called
/// ```
class AvoidMissedCallsRule extends SaropaLintRule {
  const AvoidMissedCallsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_missed_calls',
    problemMessage: 'Function reference passed to print. Did you mean to call it?',
    correctionMessage: 'Add parentheses () to call the function.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'print' && methodName != 'debugPrint') {
        return;
      }

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;

      // Check if argument is a simple identifier (potential tear-off)
      if (firstArg is SimpleIdentifier) {
        // Check if it looks like a function name (starts with verb)
        final String name = firstArg.name;
        if (_looksLikeFunctionName(name)) {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }

  bool _looksLikeFunctionName(String name) {
    // Common function prefixes that indicate it should be called
    const List<String> prefixes = <String>[
      'get',
      'set',
      'fetch',
      'load',
      'save',
      'create',
      'build',
      'make',
      'compute',
      'calculate',
      'process',
      'handle',
      'on',
      'do',
      'run',
      'execute',
      'init',
      'dispose',
      'start',
      'stop',
    ];

    final String lower = name.toLowerCase();
    for (final String prefix in prefixes) {
      if (lower.startsWith(prefix) && name.length > prefix.length) {
        // Check if next char is uppercase (camelCase)
        if (name[prefix.length].toUpperCase() == name[prefix.length]) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Warns when a set literal is used where another type is expected.
///
/// This catches cases where `{}` is used but interpreted as a Set
/// when a Map was likely intended.
///
/// Example of **bad** code:
/// ```dart
/// Map<String, int> map = {};  // This is actually a Set literal!
/// var items = {1, 2, 3};  // Set when Map might be expected
/// ```
///
/// Example of **good** code:
/// ```dart
/// Map<String, int> map = <String, int>{};  // Explicit Map
/// Set<int> items = {1, 2, 3};  // Explicit Set type
/// ```
class AvoidMisusedSetLiteralsRule extends SaropaLintRule {
  const AvoidMisusedSetLiteralsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_misused_set_literals',
    problemMessage: 'Set literal may be misused. '
        'Empty `{}` without type annotation creates a Map, not a Set.',
    correctionMessage: 'Add explicit type annotation: `<Type>{}` for Set '
        'or `<K, V>{}` for Map.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      // Only check empty literals without type arguments
      if (node.elements.isNotEmpty) return;
      if (node.typeArguments != null) return;

      // Check if context expects a specific type
      final DartType? contextType = node.staticType;
      if (contextType == null) return;

      // Warn if the empty literal could be ambiguous
      final String typeStr = contextType.getDisplayString();
      if (typeStr.startsWith('Map<') || typeStr.startsWith('Set<')) {
        // Type is inferred, but empty {} can be confusing
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an object is passed as an argument to its own method.
///
/// Example of **bad** code:
/// ```dart
/// list.add(list);  // Adding list to itself
/// map[key] = map;  // Assigning map to itself
/// ```
///
/// Example of **good** code:
/// ```dart
/// list.add(item);
/// map[key] = value;
/// ```
class AvoidPassingSelfAsArgumentRule extends SaropaLintRule {
  const AvoidPassingSelfAsArgumentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_passing_self_as_argument',
    problemMessage: 'Object is passed as argument to its own method.',
    correctionMessage: 'Avoid passing an object to its own method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();

      // Check if any argument matches the target
      for (final Expression arg in node.argumentList.arguments) {
        final Expression actualArg = arg is NamedExpression ? arg.expression : arg;
        if (actualArg.toSource() == targetSource) {
          reporter.atNode(actualArg, code);
        }
      }
    });
  }
}

/// Warns when a function calls itself directly (recursive call).
///
/// Recursive functions can lead to stack overflow if not properly guarded.
/// Consider using iteration or ensuring proper base cases.
///
/// Example of **bad** code:
/// ```dart
/// int factorial(int n) {
///   return n * factorial(n - 1);  // Missing base case check
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// int factorial(int n) {
///   if (n <= 1) return 1;
///   return n * factorial(n - 1);
/// }
/// // or use iteration
/// int factorial(int n) {
///   int result = 1;
///   for (int i = 2; i <= n; i++) {
///     result *= i;
///   }
///   return result;
/// }
/// ```
class AvoidRecursiveCallsRule extends SaropaLintRule {
  const AvoidRecursiveCallsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_recursive_calls',
    problemMessage: 'Function contains a recursive call to itself.',
    correctionMessage: 'Ensure proper base case exists or consider using iteration.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final String functionName = node.name.lexeme;
      final FunctionBody body = node.functionExpression.body;

      _checkBodyForRecursion(body, functionName, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      final FunctionBody body = node.body;

      _checkBodyForRecursion(body, methodName, reporter);
    });
  }

  void _checkBodyForRecursion(
    FunctionBody body,
    String functionName,
    SaropaDiagnosticReporter reporter,
  ) {
    final _RecursiveCallVisitor visitor = _RecursiveCallVisitor(functionName, reporter, code);
    body.accept(visitor);
  }
}

class _RecursiveCallVisitor extends RecursiveAstVisitor<void> {
  _RecursiveCallVisitor(this.functionName, this.reporter, this.code);

  final String functionName;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == functionName && node.realTarget == null) {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final Expression function = node.function;
    if (function is SimpleIdentifier && function.name == functionName) {
      reporter.atNode(node, code);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

/// Warns when toString() method calls itself, causing infinite recursion.
///
/// Example of **bad** code:
/// ```dart
/// class User {
///   @override
///   String toString() => 'User: $this';  // Calls toString() recursively
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class User {
///   final String name;
///   @override
///   String toString() => 'User: $name';
/// }
/// ```
class AvoidRecursiveToStringRule extends SaropaLintRule {
  const AvoidRecursiveToStringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_recursive_tostring',
    problemMessage: 'toString() method calls itself recursively.',
    correctionMessage: 'Avoid using \$this or this.toString() inside toString().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'toString') return;
      if (node.returnType?.toSource() != 'String') {
        // Check if it could still be toString override
        final DartType? returnType = node.returnType?.type;
        if (returnType != null && !returnType.isDartCoreString) return;
      }

      final FunctionBody body = node.body;
      final _ToStringRecursionVisitor visitor = _ToStringRecursionVisitor(reporter, code);
      body.accept(visitor);
    });
  }
}

class _ToStringRecursionVisitor extends RecursiveAstVisitor<void> {
  _ToStringRecursionVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    // Check for $this in string interpolation
    final Expression expression = node.expression;
    if (expression is ThisExpression) {
      reporter.atNode(node, code);
    }
    super.visitInterpolationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for this.toString() or toString() on this
    if (node.methodName.name == 'toString') {
      final Expression? target = node.realTarget;
      if (target == null || target is ThisExpression) {
        reporter.atNode(node, code);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when referencing discarded/underscore-prefixed variables.
///
/// Variables starting with underscore are meant to be unused.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final _unused = getValue();
/// print(_unused); // Using a "discarded" variable
/// ```
///
/// #### GOOD:
/// ```dart
/// final value = getValue();
/// print(value);
/// ```
class AvoidReferencingDiscardedVariablesRule extends SaropaLintRule {
  const AvoidReferencingDiscardedVariablesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_referencing_discarded_variables',
    problemMessage: 'Avoid referencing variables marked as discarded.',
    correctionMessage: 'Variables starting with _ should not be used. Rename the variable.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      // Check for underscore-prefixed local variables (not private members)
      // Single underscore is a wildcard, we check for _name pattern
      if (name.length > 1 &&
          name.startsWith('_') &&
          !name.startsWith('__') &&
          RegExp(r'^_[a-z]').hasMatch(name)) {
        // Use resolved element to distinguish locals from members/methods
        final element = node.element;

        // If we cannot resolve the element, be conservative and skip
        if (element == null) return;

        // Only flag local variables; skip class members/getters/setters/methods/etc.
        if (element is! LocalVariableElement) {
          return;
        }

        // Skip if this identifier is part of its own declaration
        final AstNode? parent = node.parent;
        if (parent is VariableDeclaration && parent.name == node.token) return;

        // Skip assignment on the left-hand side
        if (parent is AssignmentExpression && parent.leftHandSide == node) {
          return;
        }

        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when @pragma('vm:prefer-inline') is used redundantly.
///
/// Pragma inline annotations should only be used when necessary.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// int get value => 1; // Trivial getter, inlining is automatic
/// ```
///
/// #### GOOD:
/// ```dart
/// int get value => 1; // Let compiler decide
/// // OR for complex cases:
/// @pragma('vm:prefer-inline')
/// Matrix4 computeTransform() => /* complex computation */;
/// ```
class AvoidRedundantPragmaInlineRule extends SaropaLintRule {
  const AvoidRedundantPragmaInlineRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_pragma_inline',
    problemMessage: 'Pragma inline may be redundant for trivial methods.',
    correctionMessage: 'Remove pragma for simple getters/methods that inline automatically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check for pragma annotation
      bool hasPragmaInline = false;
      Annotation? pragmaAnnotation;

      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'pragma') {
          final ArgumentList? args = annotation.arguments;
          if (args != null && args.arguments.isNotEmpty) {
            final Expression firstArg = args.arguments.first;
            if (firstArg is SimpleStringLiteral) {
              if (firstArg.value.contains('inline')) {
                hasPragmaInline = true;
                pragmaAnnotation = annotation;
                break;
              }
            }
          }
        }
      }

      if (!hasPragmaInline || pragmaAnnotation == null) return;

      // Check if method is trivial (expression body with simple expression)
      final FunctionBody body = node.body;
      if (body is ExpressionFunctionBody) {
        final Expression expr = body.expression;
        // Simple expressions that would inline anyway
        if (expr is SimpleIdentifier ||
            expr is Literal ||
            expr is ThisExpression ||
            expr is PrefixedIdentifier) {
          reporter.atNode(pragmaAnnotation, code);
        }
      }
    });
  }
}

/// Warns when String.substring() is used.
///
/// `substring` can cause runtime errors if indices are out of bounds.
/// Prefer safer alternatives like pattern matching, split, or replaceRange.
///
/// Example of **bad** code:
/// ```dart
/// final result = text.substring(5, 10);
/// ```
///
/// Example of **good** code:
/// ```dart
/// final result = text.length >= 10 ? text.substring(5, 10) : text;
/// // or use split/pattern matching for extracting parts
/// ```
class AvoidSubstringRule extends SaropaLintRule {
  const AvoidSubstringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_substring',
    problemMessage: 'Avoid using substring() as it can throw if indices '
        'are out of bounds.',
    correctionMessage: 'Consider bounds checking or using safer string '
        'manipulation methods.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'substring') {
        final DartType? targetType = node.realTarget?.staticType;
        if (targetType != null && targetType.isDartCoreString) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when unknown pragma annotations are used.
///
/// Only known pragma values should be used.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @pragma('unknown:value')
/// void foo() { }
/// ```
///
/// #### GOOD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// void foo() { }
/// ```
class AvoidUnknownPragmaRule extends SaropaLintRule {
  const AvoidUnknownPragmaRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unknown_pragma',
    problemMessage: 'Unknown pragma annotation.',
    correctionMessage: 'Use a known pragma value or remove the annotation.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _knownPragmas = <String>{
    'vm:prefer-inline',
    'vm:never-inline',
    'vm:entry-point',
    'vm:external-name',
    'vm:invisible',
    'vm:recognized',
    'vm:idempotent',
    'vm:cachable-idempotent',
    'vm:isolate-unsendable',
    'vm:deeply-immutable',
    'vm:awaiter-link',
    'dart2js:noInline',
    'dart2js:tryInline',
    'dart2js:as:trust',
    'dart2js:late:check',
    'dart2js:late:trust',
    'dart2js:resource-identifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAnnotation((Annotation node) {
      if (node.name.name != 'pragma') return;

      final ArgumentList? args = node.arguments;
      if (args == null || args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! SimpleStringLiteral) return;

      final String pragmaValue = firstArg.value;
      if (!_knownPragmas.contains(pragmaValue)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a function parameter is unused.
///
/// Unused parameters can indicate dead code or incomplete implementation.
///
/// Example of **bad** code:
/// ```dart
/// void process(String data, int count) {
///   print(data);  // count is never used
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void process(String data, int count) {
///   print('$data x $count');
/// }
/// // Or mark as intentionally unused:
/// void process(String data, int _) { ... }
/// ```
class AvoidUnusedParametersRule extends SaropaLintRule {
  const AvoidUnusedParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unused_parameters',
    problemMessage: 'Parameter is never used.',
    correctionMessage: 'Remove the parameter or prefix with underscore if intentionally unused.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkParameters(
        node.functionExpression.parameters,
        node.functionExpression.body,
        reporter,
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip overrides (parameters may be required by interface)
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') {
          return;
        }
      }

      _checkParameters(node.parameters, node.body, reporter);
    });
  }

  void _checkParameters(
    FormalParameterList? params,
    FunctionBody? body,
    SaropaDiagnosticReporter reporter,
  ) {
    if (params == null || body == null) return;

    // Collect parameter names
    final Map<String, FormalParameter> paramMap = <String, FormalParameter>{};
    for (final FormalParameter param in params.parameters) {
      final String? name = param.name?.lexeme;
      if (name != null && !name.startsWith('_')) {
        paramMap[name] = param;
      }
    }

    if (paramMap.isEmpty) return;

    // Find all used identifiers in the body
    final Set<String> usedNames = <String>{};
    body.visitChildren(_IdentifierCollector(usedNames));

    // Report unused parameters
    for (final MapEntry<String, FormalParameter> entry in paramMap.entries) {
      if (!usedNames.contains(entry.key)) {
        reporter.atNode(entry.value, code);
      }
    }
  }
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  _IdentifierCollector(this.names);
  final Set<String> names;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when weak cryptographic algorithms like MD5 or SHA1 are used.
///
/// MD5 and SHA1 are considered cryptographically broken and should not be used
/// for security purposes.
///
/// Example of **bad** code:
/// ```dart
/// import 'dart:convert';
/// import 'package:crypto/crypto.dart';
/// final hash = md5.convert(utf8.encode('password'));
/// final hash2 = sha1.convert(utf8.encode('password'));
/// ```
///
/// Example of **good** code:
/// ```dart
/// import 'package:crypto/crypto.dart';
/// final hash = sha256.convert(utf8.encode('password'));
/// ```
class AvoidWeakCryptographicAlgorithmsRule extends SaropaLintRule {
  const AvoidWeakCryptographicAlgorithmsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_weak_cryptographic_algorithms',
    problemMessage: 'Weak cryptographic algorithm detected.',
    correctionMessage: 'Use stronger algorithms like SHA-256 or SHA-512 instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _weakAlgorithms = <String>{
    'md5',
    'sha1',
    'MD5',
    'SHA1',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      if (_weakAlgorithms.contains(node.name)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a function returns a value that should have @useResult.
class MissingUseResultAnnotationRule extends SaropaLintRule {
  const MissingUseResultAnnotationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'missing_use_result_annotation',
    problemMessage: 'Function returns a value that might be ignored. Consider adding @useResult.',
    correctionMessage: 'Add @useResult annotation to indicate return value should be used.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip void returns and setters
      if (node.isSetter) return;
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      final String typeStr = returnType.toSource();
      if (typeStr == 'void' || typeStr == 'Future<void>') return;

      // Skip if already has useResult annotation
      for (final Annotation annotation in node.metadata) {
        final String name = annotation.name.name;
        if (name == 'useResult' || name == 'UseResult') return;
      }

      // Check for common builder/factory patterns that should use @useResult
      final String methodName = node.name.lexeme;
      final List<String> builderPatterns = <String>[
        'build',
        'create',
        'make',
        'generate',
        'compute',
        'calculate',
        'parse',
        'convert',
        'transform',
      ];

      for (final String pattern in builderPatterns) {
        if (methodName.toLowerCase().startsWith(pattern)) {
          reporter.atToken(node.name, code);
          return;
        }
      }
    });
  }
}

/// Warns when a member is declared with type `Object`.
///
/// Using Object type is often a sign of missing generics or improper typing.
///
/// Example of **bad** code:
/// ```dart
/// class MyClass {
///   Object data;  // Too generic
///   Object process(Object input) => input;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyClass<T> {
///   T data;
///   T process(T input) => input;
/// }
/// ```
class NoObjectDeclarationRule extends SaropaLintRule {
  const NoObjectDeclarationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'no_object_declaration',
    problemMessage: 'Avoid declaring members with type Object.',
    correctionMessage: 'Use a more specific type or generics.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? type = node.fields.type;
      if (type is NamedType && type.name.lexeme == 'Object') {
        reporter.atNode(type, code);
      }
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'Object') {
        reporter.atNode(returnType, code);
      }
    });
  }
}

/// Warns when only one inlining annotation is used.
///
/// If using vm:prefer-inline, also use dart2js:tryInline for consistency.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// void foo() { }
/// ```
///
/// #### GOOD:
/// ```dart
/// @pragma('vm:prefer-inline')
/// @pragma('dart2js:tryInline')
/// void foo() { }
/// ```
class PreferBothInliningAnnotationsRule extends SaropaLintRule {
  const PreferBothInliningAnnotationsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_both_inlining_annotations',
    problemMessage: 'Use both VM and dart2js inlining pragmas.',
    correctionMessage: 'Add matching dart2js:tryInline or vm:prefer-inline.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkAnnotations(NodeList<Annotation> metadata, Token reportAt) {
      bool hasVmInline = false;
      bool hasDart2jsInline = false;

      for (final Annotation annotation in metadata) {
        if (annotation.name.name != 'pragma') continue;

        final ArgumentList? args = annotation.arguments;
        if (args == null || args.arguments.isEmpty) continue;

        final Expression firstArg = args.arguments.first;
        if (firstArg is! SimpleStringLiteral) continue;

        final String value = firstArg.value;
        if (value == 'vm:prefer-inline' || value == 'vm:never-inline') {
          hasVmInline = true;
        }
        if (value == 'dart2js:tryInline' || value == 'dart2js:noInline') {
          hasDart2jsInline = true;
        }
      }

      if (hasVmInline != hasDart2jsInline) {
        reporter.atToken(reportAt, code);
      }
    }

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      checkAnnotations(node.metadata, node.name);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      checkAnnotations(node.metadata, node.name);
    });
  }
}

/// Warns when using `MediaQuery.of(context).size` instead of dedicated methods.
///
/// Flutter provides dedicated methods like `MediaQuery.sizeOf(context)` which
/// are more efficient and clearer.
///
/// Example of **bad** code:
/// ```dart
/// final size = MediaQuery.of(context).size;
/// final padding = MediaQuery.of(context).padding;
/// ```
///
/// Example of **good** code:
/// ```dart
/// final size = MediaQuery.sizeOf(context);
/// final padding = MediaQuery.paddingOf(context);
/// ```
class PreferDedicatedMediaQueryMethodRule extends SaropaLintRule {
  const PreferDedicatedMediaQueryMethodRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_dedicated_media_query_method',
    problemMessage: 'Prefer dedicated MediaQuery method.',
    correctionMessage: 'Use MediaQuery.sizeOf(context), MediaQuery.paddingOf(context), etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _dedicatedProperties = <String>{
    'size',
    'padding',
    'viewInsets',
    'viewPadding',
    'orientation',
    'devicePixelRatio',
    'textScaleFactor',
    'platformBrightness',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      // Check for pattern: MediaQuery.of(context).size
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;

      // Check if it's MediaQuery.of(...)
      final Expression? targetTarget = target.target;
      if (targetTarget is! SimpleIdentifier) return;
      if (targetTarget.name != 'MediaQuery') return;
      if (target.methodName.name != 'of') return;

      // Check if the property is one that has a dedicated method
      final String propertyName = node.propertyName.name;
      if (_dedicatedProperties.contains(propertyName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when enum values are found using firstWhere instead of byName.
///
/// Example of **bad** code:
/// ```dart
/// MyEnum.values.firstWhere((e) => e.name == 'value');
/// ```
///
/// Example of **good** code:
/// ```dart
/// MyEnum.values.byName('value');
/// ```
class PreferEnumsByNameRule extends SaropaLintRule {
  const PreferEnumsByNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_enums_by_name',
    problemMessage: 'Use Enum.values.byName() instead of firstWhere with name comparison.',
    correctionMessage: 'Replace .firstWhere((e) => e.name == x) with .byName(x).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'firstWhere') return;

      // Check if target is .values
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;
      if (target.propertyName.name != 'values') return;

      // Check if the argument is a function that compares .name
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is FunctionExpression) {
        final FunctionBody body = firstArg.body;
        if (body is ExpressionFunctionBody) {
          final Expression expr = body.expression;
          // Check for pattern: e.name == 'something' or 'something' == e.name
          if (expr is BinaryExpression && expr.operator.type == TokenType.EQ_EQ) {
            final bool isNameComparison =
                _isNameAccess(expr.leftOperand) || _isNameAccess(expr.rightOperand);
            if (isNameComparison) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }

  bool _isNameAccess(Expression expr) {
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'name';
    }
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'name';
    }
    return false;
  }
}

/// Warns when inline function callbacks should be extracted.
class PreferExtractingFunctionCallbacksRule extends SaropaLintRule {
  const PreferExtractingFunctionCallbacksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_extracting_function_callbacks',
    problemMessage: 'Consider extracting this callback to a named function.',
    correctionMessage: 'Extract large inline callbacks to improve readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxCallbackLines = 10;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Skip if not used as an argument
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression && parent is! ArgumentList) return;

      // Check function body size
      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody) return;

      final CompilationUnit unit = node.root as CompilationUnit;
      final int startLine = unit.lineInfo.getLocation(body.offset).lineNumber;
      final int endLine = unit.lineInfo.getLocation(body.end).lineNumber;
      final int lineCount = endLine - startLine + 1;

      if (lineCount > _maxCallbackLines) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when null-aware elements could be used in collections.
class PreferNullAwareElementsRule extends SaropaLintRule {
  const PreferNullAwareElementsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_null_aware_elements',
    problemMessage: 'Use null-aware element syntax (?element) for nullable values.',
    correctionMessage: 'Replace "if (x != null) x" with "?x" in collection.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfElement((IfElement node) {
      // Check for pattern: if (x != null) x
      final Expression condition = node.expression;
      if (condition is! BinaryExpression) return;
      if (condition.operator.lexeme != '!=') return;

      final Expression right = condition.rightOperand;
      if (right is! NullLiteral) return;

      final Expression left = condition.leftOperand;
      if (left is! SimpleIdentifier) return;

      // Check if then element is the same identifier
      final CollectionElement thenElement = node.thenElement;
      if (thenElement is! Expression) return;
      if (thenElement is! SimpleIdentifier) return;
      if (thenElement.name != left.name) return;

      // Check there's no else element
      if (node.elseElement != null) return;

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferNullAwareElementsFix()];
}

class _PreferNullAwareElementsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIfElement((IfElement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Re-validate the pattern: if (x != null) x
      final Expression condition = node.expression;
      if (condition is! BinaryExpression) return;
      if (condition.operator.lexeme != '!=') return;

      final Expression right = condition.rightOperand;
      if (right is! NullLiteral) return;

      final Expression left = condition.leftOperand;
      if (left is! SimpleIdentifier) return;

      final CollectionElement thenElement = node.thenElement;
      if (thenElement is! SimpleIdentifier) return;
      if (thenElement.name != left.name) return;
      if (node.elseElement != null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use null-aware element syntax',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Replace "if (x != null) x" with "?x"
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '?${left.name}',
        );
      });
    });
  }
}

/// Warns when spreading a nullable collection without null-aware spread.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final list = [...?nullableList ?? []];
/// final combined = items != null ? [...items] : [];
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = [...?nullableList];
/// final combined = [...?items];
/// ```
class PreferNullAwareSpreadRule extends SaropaLintRule {
  const PreferNullAwareSpreadRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_null_aware_spread',
    problemMessage: 'Use null-aware spread (...?) for nullable collections.',
    correctionMessage: 'Replace with ...?nullableCollection.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSpreadElement((SpreadElement node) {
      // Check for ...?(x ?? []) pattern
      final Expression expr = node.expression;
      if (node.isNullAware && expr is BinaryExpression) {
        if (expr.operator.lexeme == '??') {
          final Expression right = expr.rightOperand;
          if (right is ListLiteral && right.elements.isEmpty) {
            reporter.atNode(node, code);
          }
        }
      }
    });

    // Check for ternary patterns like: items != null ? [...items] : []
    context.registry.addConditionalExpression((ConditionalExpression node) {
      final Expression condition = node.condition;
      final Expression thenExpr = node.thenExpression;
      final Expression elseExpr = node.elseExpression;

      // Check for x != null ? [...x] : [] pattern
      if (condition is BinaryExpression &&
          condition.operator.lexeme == '!=' &&
          condition.rightOperand is NullLiteral) {
        if (thenExpr is ListLiteral &&
            thenExpr.elements.length == 1 &&
            elseExpr is ListLiteral &&
            elseExpr.elements.isEmpty) {
          final CollectionElement firstElement = thenExpr.elements.first;
          if (firstElement is SpreadElement && !firstElement.isNullAware) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when @visibleForTesting should be used on members.
///
/// Test-only members should be annotated.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Foo {
///   // Used only in tests but not annotated
///   void testHelper() { }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Foo {
///   @visibleForTesting
///   void testHelper() { }
/// }
/// ```
class PreferVisibleForTestingOnMembersRule extends SaropaLintRule {
  const PreferVisibleForTestingOnMembersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_visible_for_testing_on_members',
    problemMessage: 'Test helper members should use @visibleForTesting.',
    correctionMessage: 'Add @visibleForTesting annotation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _testIndicators = <String>{
    'test',
    'Test',
    'mock',
    'Mock',
    'fake',
    'Fake',
    'stub',
    'Stub',
    'spy',
    'Spy',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Skip test files
    if (resolver.path.contains('_test.dart') ||
        resolver.path.contains('/test/') ||
        resolver.path.contains('\\test\\')) {
      return;
    }

    void checkMember(Token nameToken, NodeList<Annotation> metadata) {
      final String name = nameToken.lexeme;

      // Check if name suggests it's for testing
      bool suggestsTest = false;
      for (final String indicator in _testIndicators) {
        if (name.contains(indicator)) {
          suggestsTest = true;
          break;
        }
      }

      if (!suggestsTest) return;

      // Check if already has @visibleForTesting
      for (final Annotation annotation in metadata) {
        if (annotation.name.name == 'visibleForTesting') return;
      }

      reporter.atToken(nameToken, code);
    }

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      checkMember(node.name, node.metadata);
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        checkMember(variable.name, node.metadata);
      }
    });
  }
}

/// Warns when a named parameter is passed as null explicitly.
///
/// Example of **bad** code:
/// ```dart
/// void foo({String? name}) { }
/// foo(name: null);  // Explicitly passing null
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo({String? name}) { }
/// foo();  // Omit the parameter instead of passing null
/// ```
class AvoidAlwaysNullParametersRule extends SaropaLintRule {
  const AvoidAlwaysNullParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_always_null_parameters',
    problemMessage: 'Parameter is explicitly passed as null.',
    correctionMessage: 'Omit the parameter instead of passing null explicitly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check each method invocation for null arguments
    context.registry.addMethodInvocation((MethodInvocation node) {
      for (final Expression arg in node.argumentList.arguments) {
        // Only check named parameters passed as explicit null
        if (arg is NamedExpression && arg.expression is NullLiteral) {
          reporter.atNode(arg, code);
        }
      }
    });

    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      for (final Expression arg in node.argumentList.arguments) {
        // Only check named parameters passed as explicit null
        if (arg is NamedExpression && arg.expression is NullLiteral) {
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when an instance method assigns to a static field.
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   static int counter = 0;
///   void increment() {
///     counter++;  // Instance method modifying static
///   }
/// }
/// ```
class AvoidAssigningToStaticFieldRule extends SaropaLintRule {
  const AvoidAssigningToStaticFieldRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_assigning_to_static_field',
    problemMessage: 'Instance method should not modify static field.',
    correctionMessage: 'Make the method static or use instance field.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration classNode) {
      // Collect static field names
      final Set<String> staticFields = <String>{};
      for (final ClassMember member in classNode.members) {
        if (member is FieldDeclaration && member.isStatic) {
          for (final VariableDeclaration field in member.fields.variables) {
            staticFields.add(field.name.lexeme);
          }
        }
      }

      if (staticFields.isEmpty) return;

      // Check instance methods
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && !member.isStatic) {
          _checkMethodBody(member.body, staticFields, reporter);
        }
      }
    });
  }

  void _checkMethodBody(
    FunctionBody body,
    Set<String> staticFields,
    SaropaDiagnosticReporter reporter,
  ) {
    body.visitChildren(_StaticFieldAssignmentVisitor(staticFields, reporter, _code));
  }
}

class _StaticFieldAssignmentVisitor extends RecursiveAstVisitor<void> {
  _StaticFieldAssignmentVisitor(this.staticFields, this.reporter, this.code);

  final Set<String> staticFields;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && staticFields.contains(left.name)) {
      reporter.atNode(node, code);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final Expression operand = node.operand;
    if (operand is SimpleIdentifier && staticFields.contains(operand.name)) {
      reporter.atNode(node, code);
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final Expression operand = node.operand;
    final TokenType op = node.operator.type;
    if ((op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) &&
        operand is SimpleIdentifier &&
        staticFields.contains(operand.name)) {
      reporter.atNode(node, code);
    }
    super.visitPrefixExpression(node);
  }
}

/// Warns when an async method is called in a sync function without await.
///
/// Example of **bad** code:
/// ```dart
/// void doWork() {
///   fetchData();  // Async call, result ignored
/// }
/// ```
class AvoidAsyncCallInSyncFunctionRule extends SaropaLintRule {
  const AvoidAsyncCallInSyncFunctionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_async_call_in_sync_function',
    problemMessage: 'Async call in sync function without handling the Future.',
    correctionMessage: 'Use await, .then(), or unawaited() for the async call.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check if the return type is Future
      final DartType? returnType = node.staticType;
      if (returnType == null) return;

      final String typeName = returnType.getDisplayString();
      if (!typeName.startsWith('Future')) return;

      // Check if we're in a sync function
      final FunctionBody? enclosingBody = _findEnclosingFunctionBody(node);
      if (enclosingBody == null) return;
      if (enclosingBody.isAsynchronous) return; // OK in async functions

      // Check if the Future is being handled
      final AstNode? parent = node.parent;

      // OK if assigned, awaited, returned, or passed as argument
      if (parent is VariableDeclaration) return;
      if (parent is AssignmentExpression) return;
      if (parent is ReturnStatement) return;
      if (parent is ArgumentList) return;
      if (parent is AwaitExpression) return;
      if (parent is MethodInvocation) {
        // Check for .then(), .catchError(), etc.
        final String methodName = parent.methodName.name;
        if (methodName == 'then' || methodName == 'catchError' || methodName == 'whenComplete') {
          return;
        }
      }

      // Unhandled Future in sync context
      if (parent is ExpressionStatement) {
        reporter.atNode(node, code);
      }
    });
  }

  FunctionBody? _findEnclosingFunctionBody(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }
}

/// Warns when loop conditions are too complex.
///
/// Example of **bad** code:
/// ```dart
/// while (a && b || c && d && e) { }
/// ```
class AvoidComplexLoopConditionsRule extends SaropaLintRule {
  const AvoidComplexLoopConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_complex_loop_conditions',
    problemMessage: 'Loop condition is too complex.',
    correctionMessage: 'Extract condition to a boolean variable or method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxOperators = 2;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addWhileStatement((WhileStatement node) {
      _checkCondition(node.condition, reporter);
    });

    context.registry.addDoStatement((DoStatement node) {
      _checkCondition(node.condition, reporter);
    });

    context.registry.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is ForParts) {
        final Expression? condition = parts.condition;
        if (condition != null) {
          _checkCondition(condition, reporter);
        }
      }
    });
  }

  void _checkCondition(Expression condition, SaropaDiagnosticReporter reporter) {
    final int operatorCount = _countLogicalOperators(condition);
    if (operatorCount > _maxOperators) {
      reporter.atNode(condition, code);
    }
  }

  int _countLogicalOperators(Expression expr) {
    int count = 0;
    if (expr is BinaryExpression) {
      final TokenType op = expr.operator.type;
      if (op == TokenType.AMPERSAND_AMPERSAND || op == TokenType.BAR_BAR) {
        count++;
      }
      count += _countLogicalOperators(expr.leftOperand);
      count += _countLogicalOperators(expr.rightOperand);
    } else if (expr is ParenthesizedExpression) {
      count += _countLogicalOperators(expr.expression);
    }
    return count;
  }
}

/// Warns when both sides of a binary expression are constants.
///
/// Example of **bad** code:
/// ```dart
/// if (1 > 2) { }  // Always false
/// final x = 'a' + 'b';  // Should be 'ab'
/// ```
class AvoidConstantConditionsRule extends SaropaLintRule {
  const AvoidConstantConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_constant_conditions',
    problemMessage: 'Condition with constant values can be simplified.',
    correctionMessage: 'Evaluate the constant expression at compile time.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final TokenType op = node.operator.type;

      // Only check comparison operators
      if (op != TokenType.EQ_EQ &&
          op != TokenType.BANG_EQ &&
          op != TokenType.LT &&
          op != TokenType.LT_EQ &&
          op != TokenType.GT &&
          op != TokenType.GT_EQ) {
        return;
      }

      // Check if both sides are literals
      if (_isConstant(node.leftOperand) && _isConstant(node.rightOperand)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isConstant(Expression expr) {
    return expr is IntegerLiteral ||
        expr is DoubleLiteral ||
        expr is BooleanLiteral ||
        expr is StringLiteral ||
        expr is NullLiteral;
  }
}

/// Warns when contradicting conditions are used.
///
/// Example of **bad** code:
/// ```dart
/// if (x > 5 && x < 3) { }  // Always false
/// if (x == null && x.length > 0) { }  // Second part throws
/// ```
class AvoidContradictoryExpressionsRule extends SaropaLintRule {
  const AvoidContradictoryExpressionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_contradictory_expressions',
    problemMessage: 'Contradictory conditions detected.',
    correctionMessage: 'Review the logic - conditions may never be satisfied.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (node.operator.type != TokenType.AMPERSAND_AMPERSAND) return;

      // Check for x == null && x.something
      final Expression left = node.leftOperand;
      final Expression right = node.rightOperand;

      if (_isNullCheck(left, true)) {
        final String? varName = _getNullCheckedVariable(left);
        if (varName != null && _usesVariable(right, varName)) {
          reporter.atNode(node, code);
        }
      }

      // Check for opposite comparisons like x > 5 && x < 3
      if (left is BinaryExpression && right is BinaryExpression) {
        if (_areOppositeComparisons(left, right)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _isNullCheck(Expression expr, bool checkingForNull) {
    if (expr is BinaryExpression) {
      final TokenType op = expr.operator.type;
      if (checkingForNull) {
        return op == TokenType.EQ_EQ &&
            (expr.leftOperand is NullLiteral || expr.rightOperand is NullLiteral);
      }
      return op == TokenType.BANG_EQ &&
          (expr.leftOperand is NullLiteral || expr.rightOperand is NullLiteral);
    }
    return false;
  }

  String? _getNullCheckedVariable(Expression expr) {
    if (expr is BinaryExpression) {
      if (expr.leftOperand is NullLiteral && expr.rightOperand is SimpleIdentifier) {
        return (expr.rightOperand as SimpleIdentifier).name;
      }
      if (expr.rightOperand is NullLiteral && expr.leftOperand is SimpleIdentifier) {
        return (expr.leftOperand as SimpleIdentifier).name;
      }
    }
    return null;
  }

  bool _usesVariable(Expression expr, String varName) {
    if (expr is SimpleIdentifier) return expr.name == varName;
    if (expr is PrefixedIdentifier) return expr.prefix.name == varName;
    if (expr is PropertyAccess) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) return target.name == varName;
    }
    if (expr is MethodInvocation) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) return target.name == varName;
    }
    if (expr is BinaryExpression) {
      return _usesVariable(expr.leftOperand, varName) || _usesVariable(expr.rightOperand, varName);
    }
    return false;
  }

  bool _areOppositeComparisons(BinaryExpression left, BinaryExpression right) {
    // Very basic check for x > a && x < b where b < a
    // Full implementation would be more sophisticated
    final String leftSource = left.leftOperand.toSource();
    final String rightSource = right.leftOperand.toSource();

    if (leftSource != rightSource) return false;

    final TokenType leftOp = left.operator.type;
    final TokenType rightOp = right.operator.type;

    // Check for obvious contradictions like x > 5 && x < 3
    if ((leftOp == TokenType.GT || leftOp == TokenType.GT_EQ) &&
        (rightOp == TokenType.LT || rightOp == TokenType.LT_EQ)) {
      final Expression leftVal = left.rightOperand;
      final Expression rightVal = right.rightOperand;

      if (leftVal is IntegerLiteral && rightVal is IntegerLiteral) {
        // x > 5 && x < 3 is a contradiction
        if (leftVal.value != null && rightVal.value != null && leftVal.value! >= rightVal.value!) {
          return true;
        }
      }
    }

    return false;
  }
}

/// Warns when catch blocks have identical bodies.
///
/// Example of **bad** code:
/// ```dart
/// try { ... }
/// on FormatException catch (e) { print(e); }
/// on IOException catch (e) { print(e); }  // Same as above
/// ```
class AvoidIdenticalExceptionHandlingBlocksRule extends SaropaLintRule {
  const AvoidIdenticalExceptionHandlingBlocksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_identical_exception_handling_blocks',
    problemMessage: 'Catch blocks have identical code.',
    correctionMessage: 'Combine exception types: on FormatException, IOException catch (e).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      final NodeList<CatchClause> catches = node.catchClauses;
      if (catches.length < 2) return;

      final List<String> bodies = <String>[];
      for (final CatchClause clause in catches) {
        bodies.add(clause.body.toSource());
      }

      // Check for duplicates
      final Set<String> seen = <String>{};
      for (int i = 0; i < bodies.length; i++) {
        if (seen.contains(bodies[i])) {
          reporter.atNode(catches[i], code);
        }
        seen.add(bodies[i]);
      }
    });
  }
}

/// Warns when a late final field is assigned twice.
///
/// Example of **bad** code:
/// ```dart
/// late final int value;
/// void init() {
///   value = 1;
///   value = 2;  // Error at runtime
/// }
/// ```
class AvoidLateFinalReassignmentRule extends SaropaLintRule {
  const AvoidLateFinalReassignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_late_final_reassignment',
    problemMessage: 'Late final field may be assigned multiple times.',
    correctionMessage: 'Ensure late final fields are only assigned once.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration classNode) {
      // Collect late final field names
      final Set<String> lateFinalFields = <String>{};
      for (final ClassMember member in classNode.members) {
        if (member is FieldDeclaration) {
          if (member.fields.isLate && member.fields.isFinal) {
            for (final VariableDeclaration field in member.fields.variables) {
              if (field.initializer == null) {
                lateFinalFields.add(field.name.lexeme);
              }
            }
          }
        }
      }

      if (lateFinalFields.isEmpty) return;

      // Track assignments per method
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration) {
          final Map<String, int> assignments = <String, int>{};
          member.body.visitChildren(
            _LateFinalAssignmentCounter(lateFinalFields, assignments, reporter, _code),
          );
        }
        if (member is ConstructorDeclaration) {
          final Map<String, int> assignments = <String, int>{};
          member.body.visitChildren(
            _LateFinalAssignmentCounter(lateFinalFields, assignments, reporter, _code),
          );
        }
      }
    });
  }
}

class _LateFinalAssignmentCounter extends RecursiveAstVisitor<void> {
  _LateFinalAssignmentCounter(this.lateFinalFields, this.assignments, this.reporter, this.code);

  final Set<String> lateFinalFields;
  final Map<String, int> assignments;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && lateFinalFields.contains(left.name)) {
      final int count = assignments[left.name] ?? 0;
      assignments[left.name] = count + 1;
      if (count >= 1) {
        reporter.atNode(node, code);
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when Completer.completeError is called without stack trace.
///
/// Example of **bad** code:
/// ```dart
/// completer.completeError(error);  // Missing stack trace
/// ```
///
/// Example of **good** code:
/// ```dart
/// completer.completeError(error, stackTrace);
/// ```
class AvoidMissingCompleterStackTraceRule extends SaropaLintRule {
  const AvoidMissingCompleterStackTraceRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_missing_completer_stack_trace',
    problemMessage: 'completeError() called without stack trace.',
    correctionMessage: 'Pass the stack trace as second argument.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'completeError') return;

      // Check argument count
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.length < 2) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a map indexed by enum is missing some enum values.
///
/// Example of **bad** code:
/// ```dart
/// enum Status { active, inactive, pending }
/// final map = {Status.active: 'A', Status.inactive: 'I'};  // Missing pending
/// ```
class AvoidMissingEnumConstantInMapRule extends SaropaLintRule {
  const AvoidMissingEnumConstantInMapRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_missing_enum_constant_in_map',
    problemMessage: 'Map may be missing enum constant keys.',
    correctionMessage: 'Ensure all enum values are present in the map.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (!node.isMap) return;
      if (node.elements.isEmpty) return;

      // Check if keys are enum values
      String? enumTypeName;
      final Set<String> usedValues = <String>{};

      for (final CollectionElement element in node.elements) {
        if (element is MapLiteralEntry) {
          final Expression key = element.key;
          if (key is PrefixedIdentifier) {
            enumTypeName ??= key.prefix.name;
            if (key.prefix.name == enumTypeName) {
              usedValues.add(key.identifier.name);
            }
          }
        }
      }

      // If we found enum keys, check if it looks incomplete
      // Full implementation would resolve the enum to get all values
      if (enumTypeName != null && usedValues.length >= 2 && usedValues.length <= 5) {
        // Heuristic: if we have 2-5 values, suggest checking for completeness
        // A full implementation would resolve the enum type
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when function parameters are reassigned.
///
/// Example of **bad** code:
/// ```dart
/// void process(int value) {
///   value = value * 2;  // Mutating parameter
/// }
/// ```
class AvoidMutatingParametersRule extends SaropaLintRule {
  const AvoidMutatingParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_mutating_parameters',
    problemMessage: 'Parameter is being reassigned.',
    correctionMessage: 'Create a local variable instead of mutating the parameter.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final Set<String> paramNames = <String>{};
      for (final FormalParameter param in params.parameters) {
        final Token? name = param.name;
        if (name != null) paramNames.add(name.lexeme);
      }

      if (paramNames.isEmpty) return;

      node.functionExpression.body.visitChildren(
        _ParameterMutationVisitor(paramNames, reporter, _code),
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      final Set<String> paramNames = <String>{};
      for (final FormalParameter param in params.parameters) {
        final Token? name = param.name;
        if (name != null) paramNames.add(name.lexeme);
      }

      if (paramNames.isEmpty) return;

      node.body.visitChildren(
        _ParameterMutationVisitor(paramNames, reporter, _code),
      );
    });
  }
}

class _ParameterMutationVisitor extends RecursiveAstVisitor<void> {
  _ParameterMutationVisitor(this.paramNames, this.reporter, this.code);

  final Set<String> paramNames;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && paramNames.contains(left.name)) {
      reporter.atNode(node, code);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final Expression operand = node.operand;
    if (operand is SimpleIdentifier && paramNames.contains(operand.name)) {
      reporter.atNode(node, code);
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final TokenType op = node.operator.type;
    if (op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) {
      final Expression operand = node.operand;
      if (operand is SimpleIdentifier && paramNames.contains(operand.name)) {
        reporter.atNode(node, code);
      }
    }
    super.visitPrefixExpression(node);
  }
}

// cspell:ignore valuel
/// Warns when variable names are too similar.
///
/// Example of **bad** code:
/// ```dart
/// final value1 = 1;
/// final valuel = 2;  // Too similar to value1
/// ```
class AvoidSimilarNamesRule extends SaropaLintRule {
  const AvoidSimilarNamesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_similar_names',
    problemMessage: 'Variable name is too similar to another.',
    correctionMessage: 'Use more distinct names to avoid confusion.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final List<String> names = <String>[];
      final List<Token> tokens = <Token>[];

      node.visitChildren(_VariableCollector(names, tokens));

      // Check for similar names
      for (int i = 0; i < names.length; i++) {
        for (int j = i + 1; j < names.length; j++) {
          if (_areTooSimilar(names[i], names[j])) {
            reporter.atToken(tokens[j], code);
          }
        }
      }
    });
  }

  bool _areTooSimilar(String a, String b) {
    // Skip if one is much longer than the other
    if ((a.length - b.length).abs() > 2) return false;

    // Check for common confusable patterns
    // 1 and l, 0 and O
    final String normalizedA = a.replaceAll('1', 'l').replaceAll('0', 'O').toLowerCase();
    final String normalizedB = b.replaceAll('1', 'l').replaceAll('0', 'O').toLowerCase();

    if (normalizedA == normalizedB && a != b) return true;

    // Check edit distance for short names
    if (a.length <= 5 && b.length <= 5) {
      final int distance = _editDistance(a.toLowerCase(), b.toLowerCase());
      if (distance == 1) return true;
    }

    return false;
  }

  int _editDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final List<List<int>> dp = List<List<int>>.generate(
      a.length + 1,
      (int i) => List<int>.generate(b.length + 1, (int j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = <int>[
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((int a, int b) => a < b ? a : b);
      }
    }

    return dp[a.length][b.length];
  }
}

class _VariableCollector extends RecursiveAstVisitor<void> {
  _VariableCollector(this.names, this.tokens);

  final List<String> names;
  final List<Token> tokens;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    tokens.add(node.name);
    super.visitVariableDeclaration(node);
  }
}

/// Warns when nullable parameters are never passed null.
///
/// Example of **bad** code:
/// ```dart
/// void foo(String? x) { }
/// foo('a');  // Never null
/// foo('b');  // Never null
/// ```
class AvoidUnnecessaryNullableParametersRule extends SaropaLintRule {
  const AvoidUnnecessaryNullableParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_nullable_parameters',
    problemMessage: 'Nullable parameter is never passed null.',
    correctionMessage: 'Consider making the parameter non-nullable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This is a simplified version - full implementation would track
    // all call sites across the codebase
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      for (final FormalParameter param in params.parameters) {
        // Check if parameter type is nullable
        TypeAnnotation? type;
        if (param is SimpleFormalParameter) {
          type = param.type;
        } else if (param is DefaultFormalParameter) {
          final FormalParameter normalParam = param.parameter;
          if (normalParam is SimpleFormalParameter) {
            type = normalParam.type;
          }
        }

        if (type == null) continue;

        // Check if nullable
        if (type.question != null) {
          // This is a simplified heuristic
          // Full implementation would analyze call sites
        }
      }
    });
  }
}

/// Warns when a function always returns null.
///
/// Example of **bad** code:
/// ```dart
/// String? getValue() {
///   if (condition) return null;
///   return null;  // Always null
/// }
/// ```
class FunctionAlwaysReturnsNullRule extends SaropaLintRule {
  const FunctionAlwaysReturnsNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'function_always_returns_null',
    problemMessage: 'Function always returns null.',
    correctionMessage: 'Consider changing return type to void or returning meaningful values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(node.functionExpression.body, node.name, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, node.name, reporter);
    });
  }

  void _checkFunctionBody(FunctionBody body, Token nameToken, SaropaDiagnosticReporter reporter) {
    if (body is ExpressionFunctionBody) {
      if (body.expression is NullLiteral) {
        reporter.atToken(nameToken, code);
      }
      return;
    }

    if (body is BlockFunctionBody) {
      final List<ReturnStatement> returns = <ReturnStatement>[];
      body.block.visitChildren(_ReturnCollector(returns));

      if (returns.isEmpty) return;

      // Check if all returns are null
      final bool allNull = returns.every((ReturnStatement ret) {
        final Expression? expr = ret.expression;
        return expr == null || expr is NullLiteral;
      });

      if (allNull && returns.isNotEmpty) {
        reporter.atToken(nameToken, code);
      }
    }
  }
}

class _ReturnCollector extends RecursiveAstVisitor<void> {
  _ReturnCollector(this.returns);

  final List<ReturnStatement> returns;

  @override
  void visitReturnStatement(ReturnStatement node) {
    returns.add(node);
    super.visitReturnStatement(node);
  }

  // Don't descend into nested functions
  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip
  }
}

/// Warns when accessing collection elements by constant index in a loop.
///
/// Example of **bad** code:
/// ```dart
/// for (var i = 0; i < items.length; i++) {
///   print(items[0]);  // Always accessing first element
/// }
/// ```
class AvoidAccessingCollectionsByConstantIndexRule extends SaropaLintRule {
  const AvoidAccessingCollectionsByConstantIndexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_accessing_collections_by_constant_index',
    problemMessage: 'Accessing collection by constant index inside loop.',
    correctionMessage: 'Use the loop variable or extract the element before the loop.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });

    context.registry.addWhileStatement((WhileStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });

    context.registry.addDoStatement((DoStatement node) {
      node.body.visitChildren(_ConstantIndexVisitor(reporter, _code));
    });
  }
}

class _ConstantIndexVisitor extends RecursiveAstVisitor<void> {
  _ConstantIndexVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitIndexExpression(IndexExpression node) {
    final Expression index = node.index;
    if (index is IntegerLiteral) {
      reporter.atNode(node, code);
    }
    super.visitIndexExpression(node);
  }
}

/// Warns when a class doesn't override toString().
///
/// Example of **bad** code:
/// ```dart
/// class User {
///   final String name;
///   User(this.name);
///   // Missing toString override
/// }
/// ```
class AvoidDefaultToStringRule extends SaropaLintRule {
  const AvoidDefaultToStringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_default_tostring',
    problemMessage: 'Class should override toString() for better debugging.',
    correctionMessage: 'Add a toString() method that returns meaningful information.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (node.abstractKeyword != null) return;

      bool hasFields = false;
      bool hasToString = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          hasFields = true;
        }
        if (member is MethodDeclaration && member.name.lexeme == 'toString') {
          hasToString = true;
        }
      }

      if (hasFields && !hasToString) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when the same constant value is defined multiple times.
///
/// Example of **bad** code:
/// ```dart
/// const errorMessage = 'Error occurred';
/// const failureMessage = 'Error occurred';  // Same value
/// ```
class AvoidDuplicateConstantValuesRule extends SaropaLintRule {
  const AvoidDuplicateConstantValuesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_constant_values',
    problemMessage: 'Duplicate constant value found.',
    correctionMessage: 'Reuse the existing constant instead of duplicating.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Map<String, Token> seenConstants = <String, Token>{};

      for (final CompilationUnitMember declaration in unit.declarations) {
        if (declaration is TopLevelVariableDeclaration) {
          if (!declaration.variables.isConst) continue;

          for (final VariableDeclaration variable in declaration.variables.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer is StringLiteral) {
              final String value = initializer.toSource();
              if (seenConstants.containsKey(value)) {
                reporter.atToken(variable.name, code);
              } else {
                seenConstants[value] = variable.name;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when the same initializer expression is used twice.
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   final int a;
///   final int b;
///   Foo() : a = compute(), b = compute();  // Same initializer
/// }
/// ```
class AvoidDuplicateInitializersRule extends SaropaLintRule {
  const AvoidDuplicateInitializersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_initializers',
    problemMessage: 'Duplicate initializer expression.',
    correctionMessage: 'Extract the common initialization to a variable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      final NodeList<ConstructorInitializer> initializers = node.initializers;
      if (initializers.length < 2) return;

      final Set<String> seenExpressions = <String>{};

      for (final ConstructorInitializer init in initializers) {
        if (init is ConstructorFieldInitializer) {
          final String exprSource = init.expression.toSource();
          if (init.expression is Literal) continue;
          if (init.expression is SimpleIdentifier) continue;

          if (seenExpressions.contains(exprSource)) {
            reporter.atNode(init, code);
          } else {
            seenExpressions.add(exprSource);
          }
        }
      }
    });
  }
}

/// Warns when an override just calls super without additional logic.
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void dispose() {
///   super.dispose();  // Just calls super, no additional logic
/// }
/// ```
class AvoidUnnecessaryOverridesRule extends SaropaLintRule {
  const AvoidUnnecessaryOverridesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_overrides',
    problemMessage: 'Override only calls super without additional logic.',
    correctionMessage: 'Remove the unnecessary override.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      bool hasOverride = false;
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') {
          hasOverride = true;
          break;
        }
      }
      if (!hasOverride) return;

      final FunctionBody body = node.body;

      if (body is ExpressionFunctionBody) {
        final Expression expr = body.expression;
        if (expr is MethodInvocation) {
          final Expression? target = expr.target;
          if (target is SuperExpression && expr.methodName.name == node.name.lexeme) {
            reporter.atNode(node, code);
          }
        }
      }

      if (body is BlockFunctionBody) {
        final NodeList<Statement> statements = body.block.statements;
        if (statements.length == 1) {
          final Statement stmt = statements.first;
          if (stmt is ExpressionStatement) {
            final Expression expr = stmt.expression;
            if (expr is MethodInvocation) {
              final Expression? target = expr.target;
              if (target is SuperExpression && expr.methodName.name == node.name.lexeme) {
                reporter.atNode(node, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when a statement has no effect.
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   x;  // Statement has no effect
///   1 + 2;  // Result is not used
/// }
/// ```
class AvoidUnnecessaryStatementsRule extends SaropaLintRule {
  const AvoidUnnecessaryStatementsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_statements',
    problemMessage: 'Statement has no effect.',
    correctionMessage: 'Remove the unnecessary statement or use its value.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExpressionStatement((ExpressionStatement node) {
      final Expression expr = node.expression;

      if (expr is MethodInvocation) return;
      if (expr is FunctionExpressionInvocation) return;
      if (expr is AssignmentExpression) return;
      if (expr is PostfixExpression) return;
      if (expr is PrefixExpression) {
        final TokenType op = expr.operator.type;
        if (op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) return;
      }
      if (expr is AwaitExpression) return;
      if (expr is ThrowExpression) return;
      if (expr is CascadeExpression) return;

      if (expr is SimpleIdentifier ||
          expr is Literal ||
          expr is BinaryExpression ||
          expr is PropertyAccess ||
          expr is PrefixedIdentifier) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an assignment is never used.
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   var x = 1;
///   x = 2;  // x is never read after this
/// }
/// ```
class AvoidUnusedAssignmentRule extends SaropaLintRule {
  const AvoidUnusedAssignmentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unused_assignment',
    problemMessage: 'Assignment may be unused.',
    correctionMessage: 'Remove the unused assignment or use the variable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, List<AstNode>> assignments = <String, List<AstNode>>{};
      final Set<String> usedVariables = <String>{};

      node.visitChildren(_AssignmentUsageVisitor(assignments, usedVariables));

      for (final MapEntry<String, List<AstNode>> entry in assignments.entries) {
        if (entry.value.length > 1) {
          for (int i = 0; i < entry.value.length - 1; i++) {
            reporter.atNode(entry.value[i], code);
          }
        }
      }
    });
  }
}

class _AssignmentUsageVisitor extends RecursiveAstVisitor<void> {
  _AssignmentUsageVisitor(this.assignments, this.usedVariables);

  final Map<String, List<AstNode>> assignments;
  final Set<String> usedVariables;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier) {
      assignments.putIfAbsent(left.name, () => <AstNode>[]);
      assignments[left.name]!.add(node);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final AstNode? parent = node.parent;
    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      return;
    }
    usedVariables.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when an instance is created but never used.
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   MyClass();  // Instance created but not used
/// }
/// ```
class AvoidUnusedInstancesRule extends SaropaLintRule {
  const AvoidUnusedInstancesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unused_instances',
    problemMessage: 'Instance created but not used.',
    correctionMessage: 'Assign the instance to a variable or remove it.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExpressionStatement((ExpressionStatement node) {
      final Expression expr = node.expression;
      if (expr is InstanceCreationExpression) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a variable is null-checked but not used afterward.
///
/// Example of **bad** code:
/// ```dart
/// if (x != null) {
///   print('exists');  // x is not used
/// }
/// ```
class AvoidUnusedAfterNullCheckRule extends SaropaLintRule {
  const AvoidUnusedAfterNullCheckRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unused_after_null_check',
    problemMessage: 'Variable is null-checked but not used in the body.',
    correctionMessage: 'Use the variable or simplify the condition.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final Expression condition = node.expression;

      String? checkedVariable;
      if (condition is BinaryExpression) {
        if (condition.operator.type == TokenType.BANG_EQ) {
          if (condition.rightOperand is NullLiteral && condition.leftOperand is SimpleIdentifier) {
            checkedVariable = (condition.leftOperand as SimpleIdentifier).name;
          }
          if (condition.leftOperand is NullLiteral && condition.rightOperand is SimpleIdentifier) {
            checkedVariable = (condition.rightOperand as SimpleIdentifier).name;
          }
        }
      }

      if (checkedVariable == null) return;

      final bool isUsed = _containsIdentifier(node.thenStatement, checkedVariable);
      if (!isUsed) {
        reporter.atNode(condition, code);
      }
    });
  }

  bool _containsIdentifier(AstNode node, String name) {
    bool found = false;
    node.visitChildren(_IdentifierFinder(name, () => found = true));
    return found;
  }
}

class _IdentifierFinder extends RecursiveAstVisitor<void> {
  _IdentifierFinder(this.name, this.onFound);

  final String name;
  final void Function() onFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) onFound();
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when using default/wildcard case with enums.
///
/// Example of **bad** code:
/// ```dart
/// switch (status) {
///   case Status.active: ...
///   default: ...  // May hide unhandled enum values
/// }
/// ```
class AvoidWildcardCasesWithEnumsRule extends SaropaLintRule {
  const AvoidWildcardCasesWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_wildcard_cases_with_enums',
    problemMessage: 'Avoid using default/wildcard case with enums.',
    correctionMessage: 'Handle all enum values explicitly for exhaustiveness checking.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final Expression expression = node.expression;
      final DartType? type = expression.staticType;
      if (type == null) return;

      final String typeName = type.getDisplayString();
      if (!_looksLikeEnumType(typeName)) return;

      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) {
          reporter.atNode(member, code);
        }
      }
    });
  }

  bool _looksLikeEnumType(String typeName) {
    if (typeName.isEmpty) return false;
    final String clean = typeName.replaceAll('?', '');
    if (clean == 'int' ||
        clean == 'String' ||
        clean == 'bool' ||
        clean == 'double' ||
        clean == 'Object' ||
        clean == 'dynamic') {
      return false;
    }
    return clean[0] == clean[0].toUpperCase() && !clean.contains('<');
  }
}

/// Warns when a function always returns the same value.
///
/// Example of **bad** code:
/// ```dart
/// int getValue(bool condition) {
///   if (condition) return 42;
///   return 42;  // Always returns 42
/// }
/// ```
class FunctionAlwaysReturnsSameValueRule extends SaropaLintRule {
  const FunctionAlwaysReturnsSameValueRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'function_always_returns_same_value',
    problemMessage: 'Function always returns the same value.',
    correctionMessage: 'Consider returning a constant or simplifying the function.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(node.functionExpression.body, node.name, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, node.name, reporter);
    });
  }

  void _checkFunctionBody(FunctionBody body, Token nameToken, SaropaDiagnosticReporter reporter) {
    if (body is! BlockFunctionBody) return;

    final List<ReturnStatement> returns = <ReturnStatement>[];
    body.block.visitChildren(_ReturnCollector(returns));

    if (returns.length < 2) return;

    String? firstValue;
    bool allSame = true;

    for (final ReturnStatement ret in returns) {
      final Expression? expr = ret.expression;
      if (expr == null) {
        allSame = false;
        break;
      }

      final String value = expr.toSource();
      firstValue ??= value;

      if (value != firstValue) {
        allSame = false;
        break;
      }
    }

    if (allSame && firstValue != null) {
      reporter.atToken(nameToken, code);
    }
  }
}

/// Warns when the same condition appears in nested if statements.
///
/// Example of **bad** code:
/// ```dart
/// if (x > 0) {
///   if (x > 0) {  // Same condition
///     ...
///   }
/// }
/// ```
class NoEqualNestedConditionsRule extends SaropaLintRule {
  const NoEqualNestedConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_nested_conditions',
    problemMessage: 'Nested condition is identical to outer condition.',
    correctionMessage: 'Remove the redundant nested condition.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final String outerCondition = node.expression.toSource();
      node.thenStatement.visitChildren(_NestedConditionChecker(outerCondition, reporter, _code));
    });
  }
}

class _NestedConditionChecker extends RecursiveAstVisitor<void> {
  _NestedConditionChecker(this.outerCondition, this.reporter, this.code);

  final String outerCondition;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitIfStatement(IfStatement node) {
    final String innerCondition = node.expression.toSource();
    if (innerCondition == outerCondition) {
      reporter.atNode(node.expression, code);
    }
    super.visitIfStatement(node);
  }
}

/// Warns when switch cases have identical bodies.
///
/// Example of **bad** code:
/// ```dart
/// switch (x) {
///   case 1: return 'a';
///   case 2: return 'a';  // Same as case 1
/// }
/// ```
class NoEqualSwitchCaseRule extends SaropaLintRule {
  const NoEqualSwitchCaseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_switch_case',
    problemMessage: 'Switch cases have identical bodies.',
    correctionMessage: 'Combine cases or extract common code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final List<String> caseBodies = <String>[];
      final List<SwitchMember> members = <SwitchMember>[];

      for (final SwitchMember member in node.members) {
        if (member is SwitchCase && member.statements.isNotEmpty) {
          final String body = member.statements.map((Statement s) => s.toSource()).join();
          caseBodies.add(body);
          members.add(member);
        }
      }

      final Set<String> seen = <String>{};
      for (int i = 0; i < caseBodies.length; i++) {
        if (seen.contains(caseBodies[i])) {
          reporter.atNode(members[i], code);
        }
        seen.add(caseBodies[i]);
      }
    });
  }
}

/// Warns when isEmpty/isNotEmpty is used after where().
///
/// Example of **bad** code:
/// ```dart
/// list.where((e) => e > 5).isEmpty;
/// ```
///
/// Example of **good** code:
/// ```dart
/// !list.any((e) => e > 5);
/// ```
class PreferAnyOrEveryRule extends SaropaLintRule {
  const PreferAnyOrEveryRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_any_or_every',
    problemMessage: 'Use any() or every() instead of where().isEmpty.',
    correctionMessage: 'Replace where().isEmpty with !any() or where().isNotEmpty with any().',
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
      if (propertyName != 'isEmpty' && propertyName != 'isNotEmpty') return;

      final Expression? target = node.target;
      if (target is MethodInvocation && target.methodName.name == 'where') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when index-based for loop can be replaced with for-in.
///
/// Example of **bad** code:
/// ```dart
/// for (var i = 0; i < list.length; i++) {
///   print(list[i]);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// for (final item in list) {
///   print(item);
/// }
/// ```
class PreferForInRule extends SaropaLintRule {
  const PreferForInRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_for_in',
    problemMessage: 'Index-based loop can be replaced with for-in.',
    correctionMessage: 'Use for-in loop for cleaner iteration.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is! ForPartsWithDeclarations) return;

      final NodeList<VariableDeclaration> variables = parts.variables.variables;
      if (variables.length != 1) return;

      final VariableDeclaration indexVar = variables.first;
      final Expression? initializer = indexVar.initializer;
      if (initializer is! IntegerLiteral || initializer.value != 0) return;

      final String indexName = indexVar.name.lexeme;

      final Expression? condition = parts.condition;
      if (condition is! BinaryExpression) return;
      if (condition.operator.type != TokenType.LT) return;

      final NodeList<Expression> updaters = parts.updaters;
      if (updaters.length != 1) return;

      final Expression updater = updaters.first;
      bool isSimpleIncrement = false;
      if (updater is PostfixExpression &&
          updater.operand is SimpleIdentifier &&
          (updater.operand as SimpleIdentifier).name == indexName) {
        isSimpleIncrement = true;
      }
      if (updater is PrefixExpression &&
          updater.operand is SimpleIdentifier &&
          (updater.operand as SimpleIdentifier).name == indexName) {
        isSimpleIncrement = true;
      }

      if (isSimpleIncrement) {
        reporter.atToken(node.forKeyword, code);
      }
    });
  }
}

/// Warns when duplicate patterns appear in pattern matching.
///
/// Example of **bad** code:
/// ```dart
/// switch (value) {
///   case (int x, int y) when x > 0:
///   case (int x, int y) when x > 0:  // Duplicate pattern
/// }
/// ```
class AvoidDuplicatePatternsRule extends SaropaLintRule {
  const AvoidDuplicatePatternsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_patterns',
    problemMessage: 'Duplicate pattern detected.',
    correctionMessage: 'Remove or combine the duplicate patterns.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((SwitchExpression node) {
      final Set<String> seenPatterns = <String>{};
      for (final SwitchExpressionCase caseClause in node.cases) {
        final String patternSource = caseClause.guardedPattern.toSource();
        if (seenPatterns.contains(patternSource)) {
          reporter.atNode(caseClause.guardedPattern, code);
        } else {
          seenPatterns.add(patternSource);
        }
      }
    });

    context.registry.addSwitchStatement((SwitchStatement node) {
      final Set<String> seenPatterns = <String>{};
      for (final SwitchMember member in node.members) {
        if (member is SwitchPatternCase) {
          final String patternSource = member.guardedPattern.toSource();
          if (seenPatterns.contains(patternSource)) {
            reporter.atNode(member.guardedPattern, code);
          } else {
            seenPatterns.add(patternSource);
          }
        }
      }
    });
  }
}

/// Warns when an extension type contains another extension type.
///
/// Example of **bad** code:
/// ```dart
/// extension type Inner(int value) {}
/// extension type Outer(Inner inner) {}  // Nested extension type
/// ```
class AvoidNestedExtensionTypesRule extends SaropaLintRule {
  const AvoidNestedExtensionTypesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nested_extension_types',
    problemMessage: 'Extension type contains another extension type.',
    correctionMessage: 'Consider using the underlying type directly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionTypeDeclaration((ExtensionTypeDeclaration node) {
      final RepresentationDeclaration representation = node.representation;

      final DartType? fieldType = representation.fieldType.type;
      if (fieldType == null) return;

      // Check if the field type is itself an extension type
      if (fieldType.element is ExtensionTypeElement) {
        reporter.atNode(representation.fieldType, code);
      }
    });
  }
}

/// Warns when slow collection methods are used.
///
/// Methods like `sync*` generators for simple collections can be slow.
///
/// Example of **bad** code:
/// ```dart
/// Iterable<int> getItems() sync* {
///   yield 1;
///   yield 2;
/// }
/// ```
class AvoidSlowCollectionMethodsRule extends SaropaLintRule {
  const AvoidSlowCollectionMethodsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_slow_collection_methods',
    problemMessage: 'Using sync* generator for simple collection may be slow.',
    correctionMessage: 'Consider returning a List directly for small collections.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkForSyncStar(node.functionExpression.body, node.name, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkForSyncStar(node.body, node.name, reporter);
    });
  }

  void _checkForSyncStar(FunctionBody body, Token nameToken, SaropaDiagnosticReporter reporter) {
    if (body.keyword?.lexeme != 'sync') return;
    if (body.star == null) return;

    // Count yield statements
    int yieldCount = 0;
    body.visitChildren(_YieldCounter((int count) => yieldCount = count));

    // Warn if only a few yields (could be a simple list)
    if (yieldCount > 0 && yieldCount <= 5) {
      reporter.atToken(nameToken, code);
    }
  }
}

class _YieldCounter extends RecursiveAstVisitor<void> {
  _YieldCounter(this.onCount);

  final void Function(int) onCount;
  int _count = 0;

  @override
  void visitYieldStatement(YieldStatement node) {
    _count++;
    onCount(_count);
    super.visitYieldStatement(node);
  }
}

/// Warns when a class field is never assigned a value.
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   String? name;  // Never assigned
///   void bar() {
///     print(name);  // Always null
///   }
/// }
/// ```
class AvoidUnassignedFieldsRule extends SaropaLintRule {
  const AvoidUnassignedFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unassigned_fields',
    problemMessage: 'Field may never be assigned a value.',
    correctionMessage: 'Initialize the field or ensure it is assigned.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Set<String> assignedFields = <String>{};
      final Map<String, Token> nullableFields = <String, Token>{};

      // Collect nullable fields without initializers
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final DartType? type = variable.declaredElement?.type;
            if (type != null && type.nullabilitySuffix == NullabilitySuffix.question) {
              if (variable.initializer == null) {
                nullableFields[variable.name.lexeme] = variable.name;
              }
            }
          }
        }
      }

      // Check constructors for assignments
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          for (final ConstructorInitializer init in member.initializers) {
            if (init is ConstructorFieldInitializer) {
              assignedFields.add(init.fieldName.name);
            }
          }
          for (final FormalParameter param in member.parameters.parameters) {
            if (param is FieldFormalParameter) {
              assignedFields.add(param.name.lexeme);
            }
          }
        }
      }

      // Check method bodies for assignments
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
        if (member is ConstructorDeclaration && member.body is BlockFunctionBody) {
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
      }

      // Report unassigned fields
      for (final MapEntry<String, Token> entry in nullableFields.entries) {
        if (!assignedFields.contains(entry.key)) {
          reporter.atToken(entry.value, code);
        }
      }
    });
  }
}

class _FieldAssignmentVisitor extends RecursiveAstVisitor<void> {
  _FieldAssignmentVisitor(this.assignedFields);

  final Set<String> assignedFields;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier) {
      assignedFields.add(left.name);
    }
    if (left is PrefixedIdentifier && left.prefix.name == 'this') {
      assignedFields.add(left.identifier.name);
    }
    if (left is PropertyAccess) {
      final Expression? target = left.target;
      if (target is ThisExpression) {
        assignedFields.add(left.propertyName.name);
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when a late field is never assigned a value.
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   late String name;  // Never assigned - will throw at runtime
/// }
/// ```
class AvoidUnassignedLateFieldsRule extends SaropaLintRule {
  const AvoidUnassignedLateFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unassigned_late_fields',
    problemMessage: 'Late field may never be assigned.',
    correctionMessage: 'Ensure the late field is assigned before use.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Set<String> assignedFields = <String>{};
      final Map<String, Token> lateFields = <String, Token>{};

      // Collect late fields without initializers
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && member.fields.isLate) {
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.initializer == null) {
              lateFields[variable.name.lexeme] = variable.name;
            }
          }
        }
      }

      if (lateFields.isEmpty) return;

      // Check constructors and methods for assignments
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          for (final ConstructorInitializer init in member.initializers) {
            if (init is ConstructorFieldInitializer) {
              assignedFields.add(init.fieldName.name);
            }
          }
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
        if (member is MethodDeclaration) {
          member.body.visitChildren(_FieldAssignmentVisitor(assignedFields));
        }
      }

      // Report unassigned late fields
      for (final MapEntry<String, Token> entry in lateFields.entries) {
        if (!assignedFields.contains(entry.key)) {
          reporter.atToken(entry.value, code);
        }
      }
    });
  }
}

/// Warns when late is used but field is assigned in constructor.
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   late final String name;
///   Foo(this.name);  // late is unnecessary
/// }
/// ```
class AvoidUnnecessaryLateFieldsRule extends SaropaLintRule {
  const AvoidUnnecessaryLateFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_late_fields',
    problemMessage: 'Late keyword is unnecessary when field is assigned in constructor.',
    correctionMessage: 'Remove the late keyword.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Map<String, FieldDeclaration> lateFields = <String, FieldDeclaration>{};

      // Collect late fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && member.fields.isLate) {
          for (final VariableDeclaration variable in member.fields.variables) {
            lateFields[variable.name.lexeme] = member;
          }
        }
      }

      if (lateFields.isEmpty) return;

      // Check all constructors
      bool allConstructorsAssign(String fieldName) {
        int constructorCount = 0;
        int assignmentCount = 0;

        for (final ClassMember member in node.members) {
          if (member is ConstructorDeclaration) {
            constructorCount++;
            bool assigned = false;

            // Check field formal parameters
            for (final FormalParameter param in member.parameters.parameters) {
              if (param is FieldFormalParameter && param.name.lexeme == fieldName) {
                assigned = true;
                break;
              }
            }

            // Check initializers
            if (!assigned) {
              for (final ConstructorInitializer init in member.initializers) {
                if (init is ConstructorFieldInitializer && init.fieldName.name == fieldName) {
                  assigned = true;
                  break;
                }
              }
            }

            if (assigned) assignmentCount++;
          }
        }

        return constructorCount > 0 && constructorCount == assignmentCount;
      }

      // Report unnecessary late fields
      for (final MapEntry<String, FieldDeclaration> entry in lateFields.entries) {
        if (allConstructorsAssign(entry.key)) {
          reporter.atNode(entry.value, code);
        }
      }
    });
  }
}

/// Warns when a nullable field is always non-null.
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   String? name;  // Always assigned non-null value
///   Foo(String n) : name = n;
/// }
/// ```
class AvoidUnnecessaryNullableFieldsRule extends SaropaLintRule {
  const AvoidUnnecessaryNullableFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_nullable_fields',
    problemMessage: 'Nullable field appears to always have a non-null value.',
    correctionMessage: 'Consider making the field non-nullable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final Map<String, Token> nullableFields = <String, Token>{};
      final Set<String> assignedNullFields = <String>{};
      final Set<String> constructorInitializedFields = <String>{};

      // Collect nullable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final DartType? type = variable.declaredElement?.type;
            if (type != null && type.nullabilitySuffix == NullabilitySuffix.question) {
              // Skip if has initializer that's null
              final Expression? init = variable.initializer;
              if (init == null) {
                nullableFields[variable.name.lexeme] = variable.name;
              } else if (init is! NullLiteral) {
                nullableFields[variable.name.lexeme] = variable.name;
              }
            }
          }
        }
      }

      if (nullableFields.isEmpty) return;

      // Check constructors
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          for (final FormalParameter param in member.parameters.parameters) {
            if (param is FieldFormalParameter) {
              constructorInitializedFields.add(param.name.lexeme);
            }
          }
          for (final ConstructorInitializer init in member.initializers) {
            if (init is ConstructorFieldInitializer) {
              constructorInitializedFields.add(init.fieldName.name);
              if (init.expression is NullLiteral) {
                assignedNullFields.add(init.fieldName.name);
              }
            }
          }
        }
      }

      // Check methods for null assignments
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          member.body.visitChildren(_NullAssignmentChecker(assignedNullFields));
        }
      }

      // Report fields that are always non-null
      for (final MapEntry<String, Token> entry in nullableFields.entries) {
        if (constructorInitializedFields.contains(entry.key) &&
            !assignedNullFields.contains(entry.key)) {
          reporter.atToken(entry.value, code);
        }
      }
    });
  }
}

class _NullAssignmentChecker extends RecursiveAstVisitor<void> {
  _NullAssignmentChecker(this.assignedNullFields);

  final Set<String> assignedNullFields;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (node.rightHandSide is NullLiteral) {
      final Expression left = node.leftHandSide;
      if (left is SimpleIdentifier) {
        assignedNullFields.add(left.name);
      }
      if (left is PrefixedIdentifier && left.prefix.name == 'this') {
        assignedNullFields.add(left.identifier.name);
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when a pattern doesn't affect type narrowing.
///
/// Example of **bad** code:
/// ```dart
/// void foo(int x) {
///   if (x case int y) {  // Pattern doesn't narrow type
///     print(y);
///   }
/// }
/// ```
class AvoidUnnecessaryPatternsRule extends SaropaLintRule {
  const AvoidUnnecessaryPatternsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_patterns',
    problemMessage: 'Pattern does not affect type narrowing.',
    correctionMessage: 'Remove the unnecessary pattern or use a simple assignment.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final CaseClause? caseClause = node.caseClause;
      if (caseClause == null) return;

      final GuardedPattern guardedPattern = caseClause.guardedPattern;
      final DartPattern pattern = guardedPattern.pattern;

      // Check if pattern is just a type test on the same type
      if (pattern is DeclaredVariablePattern) {
        final DartType? patternType = pattern.type?.type;
        final DartType? expressionType = node.expression.staticType;

        if (patternType != null && expressionType != null) {
          if (patternType.getDisplayString() == expressionType.getDisplayString()) {
            reporter.atNode(pattern, code);
          }
        }
      }
    });
  }
}

/// Warns when using default/wildcard case with sealed classes.
///
/// Example of **bad** code:
/// ```dart
/// sealed class Shape {}
/// switch (shape) {
///   case Circle(): ...
///   default: ...  // May hide unhandled subclasses
/// }
/// ```
class AvoidWildcardCasesWithSealedClassesRule extends SaropaLintRule {
  const AvoidWildcardCasesWithSealedClassesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_wildcard_cases_with_sealed_classes',
    problemMessage: 'Avoid using default/wildcard case with sealed classes.',
    correctionMessage: 'Handle all sealed class subtypes explicitly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;

      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;

      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) {
          reporter.atNode(member, code);
        }
      }
    });

    context.registry.addSwitchExpression((SwitchExpression node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;

      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;

      for (final SwitchExpressionCase caseClause in node.cases) {
        final DartPattern pattern = caseClause.guardedPattern.pattern;
        if (pattern is WildcardPattern) {
          reporter.atNode(pattern, code);
        }
      }
    });
  }
}

/// Warns when switch expression cases have identical expressions.
///
/// Example of **bad** code:
/// ```dart
/// final result = switch (x) {
///   1 => 'one',
///   2 => 'one',  // Same as case 1
///   _ => 'other',
/// };
/// ```
class NoEqualSwitchExpressionCasesRule extends SaropaLintRule {
  const NoEqualSwitchExpressionCasesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_switch_expression_cases',
    problemMessage: 'Switch expression cases have identical results.',
    correctionMessage: 'Combine patterns or extract common result.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((SwitchExpression node) {
      final Map<String, SwitchExpressionCase> seenExpressions = <String, SwitchExpressionCase>{};

      for (final SwitchExpressionCase caseClause in node.cases) {
        final String exprSource = caseClause.expression.toSource();

        if (seenExpressions.containsKey(exprSource)) {
          reporter.atNode(caseClause.expression, code);
        } else {
          seenExpressions[exprSource] = caseClause;
        }
      }
    });
  }
}

/// Warns when a BytesBuilder should be used for byte operations.
///
/// Example of **bad** code:
/// ```dart
/// final bytes = <int>[];
/// bytes.addAll([1, 2, 3]);
/// bytes.addAll([4, 5, 6]);
/// ```
class PreferBytesBuilderRule extends SaropaLintRule {
  const PreferBytesBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_bytes_builder',
    problemMessage: 'Consider using BytesBuilder for byte list operations.',
    correctionMessage: 'BytesBuilder is more efficient for building byte arrays.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'addAll') return;

      final Expression? target = node.target;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      if (typeName == 'List<int>' || typeName == 'Uint8List') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a ternary expression can be pushed into arguments.
///
/// Example of **bad** code:
/// ```dart
/// condition ? foo(1, 2) : foo(1, 3);
/// ```
///
/// Example of **good** code:
/// ```dart
/// foo(1, condition ? 2 : 3);
/// ```
class PreferPushingConditionalExpressionsRule extends SaropaLintRule {
  const PreferPushingConditionalExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_pushing_conditional_expressions',
    problemMessage: 'Conditional expression can be pushed into arguments.',
    correctionMessage: 'Move the condition into the differing argument.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConditionalExpression((ConditionalExpression node) {
      final Expression thenExpr = node.thenExpression;
      final Expression elseExpr = node.elseExpression;

      // Check if both branches are method calls to the same method
      if (thenExpr is MethodInvocation && elseExpr is MethodInvocation) {
        if (thenExpr.methodName.name == elseExpr.methodName.name) {
          final String? thenTarget = thenExpr.target?.toSource();
          final String? elseTarget = elseExpr.target?.toSource();

          if (thenTarget == elseTarget) {
            // Check if only one argument differs
            final List<Expression> thenArgs = thenExpr.argumentList.arguments.toList();
            final List<Expression> elseArgs = elseExpr.argumentList.arguments.toList();

            if (thenArgs.length == elseArgs.length && thenArgs.length >= 2) {
              int diffCount = 0;
              for (int i = 0; i < thenArgs.length; i++) {
                if (thenArgs[i].toSource() != elseArgs[i].toSource()) {
                  diffCount++;
                }
              }
              if (diffCount == 1) {
                reporter.atNode(node, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when `.new` constructor shorthand can be used.
///
/// Example of **bad** code:
/// ```dart
/// final items = list.map((e) => Item(e));
/// ```
///
/// Example of **good** code:
/// ```dart
/// final items = list.map(Item.new);
/// ```
class PreferShorthandsWithConstructorsRule extends SaropaLintRule {
  const PreferShorthandsWithConstructorsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_shorthands_with_constructors',
    problemMessage: 'Constructor call can use .new shorthand.',
    correctionMessage: 'Replace lambda with ClassName.new.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      final FunctionBody body = node.body;

      Expression? bodyExpr;
      if (body is ExpressionFunctionBody) {
        bodyExpr = body.expression;
      } else if (body is BlockFunctionBody) {
        final NodeList<Statement> statements = body.block.statements;
        if (statements.length == 1 && statements.first is ReturnStatement) {
          bodyExpr = (statements.first as ReturnStatement).expression;
        }
      }

      if (bodyExpr is! InstanceCreationExpression) return;

      final FormalParameterList? paramList = node.parameters;
      if (paramList == null) return;

      final List<FormalParameter> params = paramList.parameters.toList();
      if (params.length != 1) return;

      final String paramName = params.first.name?.lexeme ?? '';

      final ArgumentList args = bodyExpr.argumentList;
      if (args.arguments.length != 1) return;

      final Expression arg = args.arguments.first;
      if (arg is SimpleIdentifier && arg.name == paramName) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when enum shorthand can be used.
///
/// Example of **bad** code:
/// ```dart
/// final status = Status.values.where((e) => e == Status.active);
/// ```
class PreferShorthandsWithEnumsRule extends SaropaLintRule {
  const PreferShorthandsWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_shorthands_with_enums',
    problemMessage: 'Consider using enum shorthand.',
    correctionMessage: 'Simplify the enum access pattern.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for patterns like EnumType.values.where/firstWhere
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      if (target.propertyName.name != 'values') return;

      final Expression? enumType = target.target;
      if (enumType == null) return;

      final DartType? type = enumType.staticType;
      if (type == null) return;

      // Check if it's an enum type access
      final Element? element = type.element;
      if (element is EnumElement) {
        final String methodName = node.methodName.name;
        if (methodName == 'where' || methodName == 'firstWhere' || methodName == 'singleWhere') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when static field shorthand can be used.
///
/// Example of **bad** code:
/// ```dart
/// final color = Colors.values.firstWhere((c) => c == Colors.red);
/// ```
class PreferShorthandsWithStaticFieldsRule extends SaropaLintRule {
  const PreferShorthandsWithStaticFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_shorthands_with_static_fields',
    problemMessage: 'Consider using static field directly.',
    correctionMessage: 'Access the static field directly instead of searching.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'firstWhere' && node.methodName.name != 'singleWhere') {
        return;
      }

      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      // Check for Class.staticList.firstWhere pattern
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! FunctionExpression) return;

      final FunctionBody body = firstArg.body;
      if (body is! ExpressionFunctionBody) return;

      final Expression bodyExpr = body.expression;
      if (bodyExpr is BinaryExpression && bodyExpr.operator.type == TokenType.EQ_EQ) {
        // Check if comparing against a static field
        final Expression right = bodyExpr.rightOperand;
        if (right is PrefixedIdentifier || right is PropertyAccess) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a parameter type doesn't match the accepted type annotation.
///
/// Example of **bad** code:
/// ```dart
/// void process(@Accept(String) int value) {} // Type mismatch
/// ```
class PassCorrectAcceptedTypeRule extends SaropaLintRule {
  const PassCorrectAcceptedTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'pass_correct_accepted_type',
    problemMessage: 'Parameter type does not match accepted type annotation.',
    correctionMessage: 'Ensure the parameter type matches the @Accept annotation.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFormalParameter((FormalParameter node) {
      // Check for Accept-style annotations
      for (final Annotation annotation in node.metadata) {
        final String annotationName = annotation.name.name;
        if (annotationName == 'Accept' || annotationName == 'AcceptType') {
          final ArgumentList? args = annotation.arguments;
          if (args != null && args.arguments.isNotEmpty) {
            final Expression firstArg = args.arguments.first;
            if (firstArg is TypeLiteral) {
              // Get expected type from annotation
              final String expectedTypeName = firstArg.type.toSource();

              // Get actual parameter type
              final TypeAnnotation? paramType = node is SimpleFormalParameter ? node.type : null;

              if (paramType != null) {
                final String actualTypeName = paramType.toSource();
                if (actualTypeName != expectedTypeName &&
                    !actualTypeName.contains(expectedTypeName)) {
                  reporter.atNode(node, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when an optional argument is not passed but could improve clarity.
///
/// Detects method calls that are missing commonly-used optional boolean
/// arguments like `verbose`, `recursive`, `force`, etc.
///
/// Example of **bad** code:
/// ```dart
/// void process(String name, {bool verbose}) {}
/// process('test'); // Missing optional verbose arg
/// ```
class PassOptionalArgumentRule extends SaropaLintRule {
  const PassOptionalArgumentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'pass_optional_argument',
    problemMessage: 'Consider passing the optional argument explicitly.',
    correctionMessage: 'Passing optional arguments can improve code clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Common boolean parameter names that should be passed explicitly
  static const Set<String> _importantBoolParams = <String>{
    'verbose',
    'recursive',
    'force',
    'isRequired',
    'shouldValidate',
    'hasHeader',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      // Find functions that have important optional boolean parameters
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final Set<String> optionalBoolParams = <String>{};
      for (final FormalParameter param in params.parameters) {
        if (param.isNamed || param.isOptional) {
          final String? name = param.name?.lexeme;
          if (name != null && _importantBoolParams.contains(name)) {
            optionalBoolParams.add(name);
          }
        }
      }

      if (optionalBoolParams.isEmpty) return;

      // Store for later checking of call sites
      // This rule checks at declaration site for documentation purposes
      // A more complete implementation would track call sites
    });
  }
}

/// Warns when a file contains multiple top-level declarations.
///
/// Example of **bad** code:
/// ```dart
/// // my_file.dart
/// class Foo {}
/// class Bar {} // Should be in separate file
/// ```
class PreferSingleDeclarationPerFileRule extends SaropaLintRule {
  const PreferSingleDeclarationPerFileRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_single_declaration_per_file',
    problemMessage: 'File contains multiple top-level declarations.',
    correctionMessage: 'Consider splitting into separate files.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      // Count significant top-level declarations
      int classCount = 0;
      int enumCount = 0;
      int mixinCount = 0;
      ClassDeclaration? secondClass;

      for (final CompilationUnitMember member in node.declarations) {
        if (member is ClassDeclaration) {
          classCount++;
          if (classCount == 2) {
            secondClass = member;
          }
        } else if (member is EnumDeclaration) {
          enumCount++;
        } else if (member is MixinDeclaration) {
          mixinCount++;
        }
      }

      // Report if there are multiple major declarations
      final int majorDeclarations = classCount + enumCount + mixinCount;
      if (majorDeclarations > 1 && secondClass != null) {
        // Skip if it looks like a private helper class
        if (!secondClass.name.lexeme.startsWith('_')) {
          reporter.atNode(secondClass, code);
        }
      }
    });
  }
}

/// Warns when a switch statement could be converted to a switch expression.
///
/// Example of **bad** code:
/// ```dart
/// String result;
/// switch (value) {
///   case 1: result = 'one'; break;
///   case 2: result = 'two'; break;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final result = switch (value) {
///   1 => 'one',
///   2 => 'two',
/// };
/// ```
class PreferSwitchExpressionRule extends SaropaLintRule {
  const PreferSwitchExpressionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_expression',
    problemMessage: 'Consider using a switch expression instead.',
    correctionMessage: 'Switch expressions are more concise for value mapping.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      // Check if all cases are simple assignments or returns
      bool allSimpleAssignments = true;
      String? targetVariable;
      bool allReturns = true;

      for (final SwitchMember member in node.members) {
        if (member is SwitchCase) {
          final List<Statement> statements = member.statements;
          if (statements.isEmpty) {
            allSimpleAssignments = false;
            allReturns = false;
            continue;
          }

          // Check first non-break statement
          for (final Statement stmt in statements) {
            if (stmt is BreakStatement) continue;

            if (stmt is ExpressionStatement) {
              final Expression expr = stmt.expression;
              if (expr is AssignmentExpression) {
                final Expression left = expr.leftHandSide;
                if (left is SimpleIdentifier) {
                  if (targetVariable == null) {
                    targetVariable = left.name;
                  } else if (targetVariable != left.name) {
                    allSimpleAssignments = false;
                  }
                } else {
                  allSimpleAssignments = false;
                }
              } else {
                allSimpleAssignments = false;
              }
              allReturns = false;
            } else if (stmt is ReturnStatement) {
              allSimpleAssignments = false;
            } else {
              allSimpleAssignments = false;
              allReturns = false;
            }
          }
        } else if (member is SwitchDefault) {
          // Default case - check same pattern
          for (final Statement stmt in member.statements) {
            if (stmt is! BreakStatement &&
                stmt is! ReturnStatement &&
                stmt is! ExpressionStatement) {
              allSimpleAssignments = false;
              allReturns = false;
            }
          }
        }
      }

      // Report if it's a good candidate for switch expression
      if ((allSimpleAssignments && targetVariable != null) || allReturns) {
        reporter.atToken(node.switchKeyword, code);
      }
    });
  }
}

/// Warns when if-else chains on enum values could use a switch.
///
/// Example of **bad** code:
/// ```dart
/// if (status == Status.active) {
///   // ...
/// } else if (status == Status.pending) {
///   // ...
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (status) {
///   case Status.active: // ...
///   case Status.pending: // ...
/// }
/// ```
class PreferSwitchWithEnumsRule extends SaropaLintRule {
  const PreferSwitchWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_with_enums',
    problemMessage: 'Consider using switch statement for enum comparisons.',
    correctionMessage: 'Switch provides exhaustiveness checking for enums.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Only check if statements with else-if chains
      if (node.elseStatement == null) return;

      // Check if condition compares an enum
      final Expression condition = node.expression;
      if (condition is! BinaryExpression) return;
      if (condition.operator.type != TokenType.EQ_EQ) return;

      // Check if comparing against enum value
      final Expression left = condition.leftOperand;
      final Expression right = condition.rightOperand;

      bool isEnumComparison = false;
      SimpleIdentifier? enumVariable;

      if (_isEnumValue(right)) {
        if (left is SimpleIdentifier) {
          enumVariable = left;
          isEnumComparison = true;
        }
      } else if (_isEnumValue(left)) {
        if (right is SimpleIdentifier) {
          enumVariable = right;
          isEnumComparison = true;
        }
      }

      if (!isEnumComparison || enumVariable == null) return;

      // Count else-if branches comparing same variable
      int branchCount = 1;
      Statement? elseStmt = node.elseStatement;

      while (elseStmt is IfStatement) {
        final Expression elseCondition = elseStmt.expression;
        if (elseCondition is BinaryExpression && elseCondition.operator.type == TokenType.EQ_EQ) {
          final Expression elseLeft = elseCondition.leftOperand;
          final Expression elseRight = elseCondition.rightOperand;

          if ((elseLeft is SimpleIdentifier && elseLeft.name == enumVariable.name) ||
              (elseRight is SimpleIdentifier && elseRight.name == enumVariable.name)) {
            branchCount++;
          }
        }
        elseStmt = elseStmt.elseStatement;
      }

      // Report if there are 3+ branches
      if (branchCount >= 3) {
        reporter.atToken(node.ifKeyword, code);
      }
    });
  }

  bool _isEnumValue(Expression expr) {
    if (expr is PrefixedIdentifier) {
      // Check if it looks like EnumType.value
      final String prefix = expr.prefix.name;
      if (prefix.isNotEmpty && prefix[0] == prefix[0].toUpperCase()) {
        return true;
      }
    } else if (expr is PropertyAccess) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) {
        final String name = target.name;
        if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Warns when if-else chains on sealed class could use exhaustive switch.
///
/// Example of **bad** code:
/// ```dart
/// if (result is Success) {
///   // ...
/// } else if (result is Error) {
///   // ...
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (result) {
///   case Success(): // ...
///   case Error(): // ...
/// }
/// ```
class PreferSwitchWithSealedClassesRule extends SaropaLintRule {
  const PreferSwitchWithSealedClassesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_with_sealed_classes',
    problemMessage: 'Consider using switch with sealed class for exhaustiveness.',
    correctionMessage: 'Switch provides exhaustiveness checking for sealed classes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Only check if statements with else-if chains
      if (node.elseStatement == null) return;

      // Check if condition is a type check
      final Expression condition = node.expression;
      if (condition is! IsExpression) return;

      final Expression target = condition.expression;
      if (target is! SimpleIdentifier) return;

      final String variableName = target.name;

      // Count type check branches
      int branchCount = 1;
      Statement? elseStmt = node.elseStatement;

      while (elseStmt is IfStatement) {
        final Expression elseCondition = elseStmt.expression;
        if (elseCondition is IsExpression) {
          final Expression elseTarget = elseCondition.expression;
          if (elseTarget is SimpleIdentifier && elseTarget.name == variableName) {
            branchCount++;
          }
        }
        elseStmt = elseStmt.elseStatement;
      }

      // Report if there are 2+ type check branches
      if (branchCount >= 2) {
        reporter.atToken(node.ifKeyword, code);
      }
    });
  }
}

/// Warns when test assertions could use more specific matchers.
///
/// Example of **bad** code:
/// ```dart
/// expect(list.length, equals(0));
/// expect(string.contains('x'), isTrue);
/// ```
///
/// Example of **good** code:
/// ```dart
/// expect(list, isEmpty);
/// expect(string, contains('x'));
/// ```
class PreferTestMatchersRule extends SaropaLintRule {
  const PreferTestMatchersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_test_matchers',
    problemMessage: 'Use a more specific test matcher.',
    correctionMessage: 'Specific matchers provide better error messages.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    final String path = resolver.source.fullName;
    if (!path.contains('test') && !path.endsWith('_test.dart')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'expect') return;

      final List<Expression> args = node.argumentList.arguments.toList();
      if (args.length < 2) return;

      final Expression actual = args[0];
      final Expression matcher = args[1];

      // Check for list.length == 0 pattern
      if (actual is PropertyAccess && actual.propertyName.name == 'length') {
        if (matcher is MethodInvocation && matcher.methodName.name == 'equals') {
          final List<Expression> matcherArgs = matcher.argumentList.arguments.toList();
          if (matcherArgs.isNotEmpty) {
            final Expression matcherArg = matcherArgs[0];
            if (matcherArg is IntegerLiteral && matcherArg.value == 0) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }

      // Check for .contains() with isTrue/isFalse
      if (actual is MethodInvocation && actual.methodName.name == 'contains') {
        if (matcher is SimpleIdentifier) {
          if (matcher.name == 'isTrue' || matcher.name == 'isFalse') {
            reporter.atNode(node, code);
            return;
          }
        }
      }

      // Check for .isEmpty with isTrue/isFalse
      if (actual is PropertyAccess &&
          (actual.propertyName.name == 'isEmpty' || actual.propertyName.name == 'isNotEmpty')) {
        if (matcher is SimpleIdentifier &&
            (matcher.name == 'isTrue' || matcher.name == 'isFalse')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when `FutureOr<T>` could be unwrapped for cleaner handling.
///
/// Example of **bad** code:
/// ```dart
/// FutureOr<int> getValue() => 42;
/// void process() {
///   final value = getValue();
///   if (value is Future<int>) {
///     value.then((v) => print(v));
///   } else {
///     print(value);
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<int> getValue() async => 42;
/// void process() async {
///   final value = await getValue();
///   print(value);
/// }
/// ```
class PreferUnwrappingFutureOrRule extends SaropaLintRule {
  const PreferUnwrappingFutureOrRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_unwrapping_future_or',
    problemMessage: 'Consider using async/await instead of FutureOr handling.',
    correctionMessage: 'Async/await simplifies FutureOr handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Check for pattern: if (value is Future<T>)
      final Expression condition = node.expression;
      if (condition is! IsExpression) return;

      final TypeAnnotation type = condition.type;
      if (type is! NamedType) return;

      if (type.name.lexeme == 'Future') {
        // This is checking if something is a Future, likely FutureOr handling
        final Expression target = condition.expression;
        if (target is SimpleIdentifier) {
          reporter.atNode(node, code);
        }
      }
    });

    // Also check for FutureOr return types that could be simplified
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'FutureOr') {
        // Check if body is simple enough to just be async
        final FunctionBody body = node.functionExpression.body;
        if (body is BlockFunctionBody) {
          // Has block body - might benefit from being async
          bool hasAwait = false;
          body.accept(_AwaitFinderVisitor((bool found) => hasAwait = found));
          if (!hasAwait) {
            reporter.atNode(returnType, code);
          }
        }
      }
    });
  }
}

class _AwaitFinderVisitor extends RecursiveAstVisitor<void> {
  _AwaitFinderVisitor(this.onFound);
  final void Function(bool) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(true);
  }
}

// =============================================================================
// HARD COMPLEXITY RULES
// =============================================================================

/// Warns when type arguments can be inferred and are redundant.
///
/// Example of **bad** code:
/// ```dart
/// final list = <String>['a', 'b'];  // Type can be inferred
/// final map = Map<String, int>();   // Type can be inferred from usage
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = ['a', 'b'];  // Type inferred as List<String>
/// final map = <String, int>{};  // Explicit when needed
/// ```
class AvoidInferrableTypeArgumentsRule extends SaropaLintRule {
  const AvoidInferrableTypeArgumentsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_inferrable_type_arguments',
    problemMessage: 'Generic type matches inference.',
    correctionMessage: 'Remove redundant type arguments that can be inferred.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null) return;
      if (node.elements.isEmpty) return;

      // Check if all elements are the same type as the declared type
      final String declaredType = typeArgs.arguments.first.toSource();
      bool allMatch = true;

      for (final CollectionElement element in node.elements) {
        if (element is Expression) {
          final DartType? elementType = element.staticType;
          if (elementType == null) {
            allMatch = false;
            break;
          }
          final String elementTypeName = elementType.getDisplayString();
          if (elementTypeName != declaredType && !elementTypeName.startsWith(declaredType)) {
            allMatch = false;
            break;
          }
        }
      }

      if (allMatch && node.elements.isNotEmpty) {
        reporter.atNode(typeArgs, code);
      }
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null) return;
      if (node.elements.isEmpty) return;

      // For non-empty literals with type args, the types can often be inferred
      reporter.atNode(typeArgs, code);
    });
  }
}

/// Warns when an empty collection default value is passed explicitly.
///
/// This is a conservative rule that only flags clearly redundant patterns:
/// - Empty list literals: `[]` or `const []`
/// - Empty map literals: `{}` or `const {}`
///
/// Example of **bad** code:
/// ```dart
/// void foo({List<int> items = const []}) {}
/// foo(items: const []);  // Passing default value explicitly
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo({List<int> items = const []}) {}
/// foo();  // Omit argument when using default
/// ```
class AvoidPassingDefaultValuesRule extends SaropaLintRule {
  const AvoidPassingDefaultValuesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_passing_default_values',
    problemMessage: 'Empty collection argument is likely the default value.',
    correctionMessage: 'Omit the argument to use the default value.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkArguments(node.argumentList, reporter);
    });

    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      _checkArguments(node.argumentList, reporter);
    });
  }

  void _checkArguments(ArgumentList argList, SaropaDiagnosticReporter reporter) {
    for (final Expression arg in argList.arguments) {
      if (arg is! NamedExpression) continue;

      final Expression value = arg.expression;

      // Only flag empty collection literals - these are almost always defaults
      if (_isEmptyCollectionLiteral(value)) {
        reporter.atNode(arg, code);
      }
    }
  }

  bool _isEmptyCollectionLiteral(Expression expr) {
    // Check for empty list literal
    if (expr is ListLiteral && expr.elements.isEmpty) {
      return true;
    }
    // Check for empty set/map literal
    if (expr is SetOrMapLiteral && expr.elements.isEmpty) {
      return true;
    }
    return false;
  }
}

/// Warns when an extension method shadows a class method.
///
/// Example of **bad** code:
/// ```dart
/// extension StringExt on String {
///   int get length => 0;  // Shadows String.length
/// }
/// ```
class AvoidShadowedExtensionMethodsRule extends SaropaLintRule {
  const AvoidShadowedExtensionMethodsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_shadowed_extension_methods',
    problemMessage: 'Extension method shadows class method.',
    correctionMessage: 'Rename the extension method to avoid shadowing.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      final DartType? type = extendedType.type;
      if (type == null) return;

      final Element? typeElement = type.element;
      if (typeElement is! InterfaceElement) return;

      // Get all method names from the extended type
      final Set<String> classMethods = <String>{};
      for (final MethodElement method in typeElement.methods) {
        final String? name = method.name;
        if (name != null) classMethods.add(name);
      }

      // Check extension members
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          if (classMethods.contains(methodName)) {
            reporter.atToken(member.name, code);
          }
        }
      }
    });
  }
}

/// Warns when a late local variable is initialized immediately.
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   late final x = compute();  // late is unnecessary
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo() {
///   final x = compute();  // No late needed
/// }
/// ```
class AvoidUnnecessaryLocalLateRule extends SaropaLintRule {
  const AvoidUnnecessaryLocalLateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_local_late',
    problemMessage: 'Late variable initialized immediately.',
    correctionMessage: 'Remove the late keyword for immediately initialized variables.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclarationStatement((VariableDeclarationStatement node) {
      final VariableDeclarationList variables = node.variables;
      if (!variables.isLate) return;

      for (final VariableDeclaration variable in variables.variables) {
        if (variable.initializer != null) {
          // Variable has an initializer, late is unnecessary
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when an overriding method specifies default values that look suspicious.
///
/// This rule flags overriding methods that specify non-standard default values,
/// which may indicate they differ from the parent class definition.
///
/// Example of **bad** code:
/// ```dart
/// class Parent {
///   void foo({int x = 0}) {}
/// }
/// class Child extends Parent {
///   @override
///   void foo({int x = 42}) {}  // Non-zero default is suspicious
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class Parent {
///   void foo({int x = 0}) {}
/// }
/// class Child extends Parent {
///   @override
///   void foo({int x = 0}) {}  // Matches parent
/// }
/// ```
class MatchBaseClassDefaultValueRule extends SaropaLintRule {
  const MatchBaseClassDefaultValueRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'match_base_class_default_value',
    problemMessage: 'Override has non-standard default value.',
    correctionMessage: 'Verify this matches the parent class default value.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration classNode) {
      // Get parent class
      final ExtendsClause? extendsClause = classNode.extendsClause;
      if (extendsClause == null) return;

      // Check each method in the class
      for (final ClassMember member in classNode.members) {
        if (member is! MethodDeclaration) continue;

        // Check if it's an override
        bool isOverride = false;
        for (final Annotation annotation in member.metadata) {
          if (annotation.name.name == 'override') {
            isOverride = true;
            break;
          }
        }
        if (!isOverride) continue;

        final FormalParameterList? params = member.parameters;
        if (params == null) continue;

        // Check parameters with default values
        for (final FormalParameter param in params.parameters) {
          if (param is! DefaultFormalParameter) continue;

          final Expression? defaultValue = param.defaultValue;
          if (defaultValue == null) continue;

          // Flag non-standard defaults that are likely to differ from parent
          if (_isNonStandardDefault(defaultValue)) {
            reporter.atNode(defaultValue, code);
          }
        }
      }
    });
  }

  bool _isNonStandardDefault(Expression expr) {
    // Standard defaults that are typically safe: null, false, 0, '', [], {}
    if (expr is NullLiteral) return false;
    if (expr is BooleanLiteral && !expr.value) return false;
    if (expr is IntegerLiteral && expr.value == 0) return false;
    if (expr is DoubleLiteral && expr.value == 0.0) return false;
    if (expr is SimpleStringLiteral && expr.value.isEmpty) return false;
    if (expr is ListLiteral && expr.elements.isEmpty) return false;
    if (expr is SetOrMapLiteral && expr.elements.isEmpty) return false;

    // Non-zero integers, non-empty strings, true booleans are suspicious
    if (expr is IntegerLiteral && expr.value != 0) return true;
    if (expr is BooleanLiteral && expr.value) return true;
    if (expr is SimpleStringLiteral && expr.value.isNotEmpty) return true;

    return false;
  }
}

/// Warns when a variable could be declared closer to its usage.
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   final x = 1;
///   // ... 20 lines of code not using x ...
///   print(x);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo() {
///   // ... 20 lines of code ...
///   final x = 1;
///   print(x);
/// }
/// ```
class MoveVariableCloserToUsageRule extends SaropaLintRule {
  const MoveVariableCloserToUsageRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'move_variable_closer_to_its_usage',
    problemMessage: 'Scope analysis.',
    correctionMessage: 'Consider moving the variable declaration closer to its first use.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _minLineDistance = 10;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, int> declarationLines = <String, int>{};
      final Map<String, int> firstUsageLines = <String, int>{};
      final Map<String, VariableDeclaration> declarations = <String, VariableDeclaration>{};

      // First pass: collect declarations
      for (final Statement statement in node.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable in statement.variables.variables) {
            final String name = variable.name.lexeme;
            declarationLines[name] = resolver.lineInfo.getLocation(variable.offset).lineNumber;
            declarations[name] = variable;
          }
        }
      }

      // Second pass: find first usage of each variable
      node.visitChildren(
        _FirstUsageVisitor(declarationLines.keys.toSet(), firstUsageLines, resolver),
      );

      // Check distances
      for (final String name in declarationLines.keys) {
        final int declLine = declarationLines[name]!;
        final int? useLine = firstUsageLines[name];

        if (useLine != null && useLine - declLine > _minLineDistance) {
          final VariableDeclaration? decl = declarations[name];
          if (decl != null) {
            reporter.atToken(decl.name, code);
          }
        }
      }
    });
  }
}

class _FirstUsageVisitor extends RecursiveAstVisitor<void> {
  _FirstUsageVisitor(this.variableNames, this.firstUsageLines, this.resolver);

  final Set<String> variableNames;
  final Map<String, int> firstUsageLines;
  final CustomLintResolver resolver;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final String name = node.name;
    if (variableNames.contains(name) && !firstUsageLines.containsKey(name)) {
      // Skip if this is the declaration itself
      if (node.parent is VariableDeclaration &&
          (node.parent as VariableDeclaration).name == node.token) {
        return;
      }
      firstUsageLines[name] = resolver.lineInfo.getLocation(node.offset).lineNumber;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when a variable could be moved outside a loop.
///
/// Example of **bad** code:
/// ```dart
/// for (int i = 0; i < 10; i++) {
///   final regex = RegExp(r'\d+');  // Created every iteration
///   print(regex.hasMatch('$i'));
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final regex = RegExp(r'\d+');
/// for (int i = 0; i < 10; i++) {
///   print(regex.hasMatch('$i'));
/// }
/// ```
class MoveVariableOutsideIterationRule extends SaropaLintRule {
  const MoveVariableOutsideIterationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'move_variable_outside_iteration',
    problemMessage: 'Loop invariant code motion.',
    correctionMessage: 'Move the variable declaration outside the loop.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkLoopBody(Statement body) {
      if (body is! Block) return;

      for (final Statement statement in body.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable in statement.variables.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            // Check if initializer is a constant expression or only uses
            // values available outside the loop
            if (_isLoopInvariant(initializer)) {
              reporter.atToken(variable.name, code);
            }
          }
        }
      }
    }

    context.registry.addForStatement((ForStatement node) {
      checkLoopBody(node.body);
    });

    context.registry.addWhileStatement((WhileStatement node) {
      checkLoopBody(node.body);
    });

    context.registry.addDoStatement((DoStatement node) {
      checkLoopBody(node.body);
    });
  }

  bool _isLoopInvariant(Expression expr) {
    // Check for common loop-invariant patterns
    if (expr is InstanceCreationExpression) {
      // Constructor calls with only literal arguments
      for (final Expression arg in expr.argumentList.arguments) {
        if (!_isConstant(arg)) return false;
      }
      return true;
    }

    if (expr is MethodInvocation) {
      // Static method calls with constant args
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) {
        final String name = target.name;
        // Check if it's a type name (static call)
        if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
          for (final Expression arg in expr.argumentList.arguments) {
            if (!_isConstant(arg)) return false;
          }
          return true;
        }
      }
    }

    return false;
  }

  bool _isConstant(Expression expr) {
    if (expr is Literal) return true;
    if (expr is NamedExpression) return _isConstant(expr.expression);
    return false;
  }
}

/// Warns when a class overrides == but not the parent's ==.
///
/// Example of **bad** code:
/// ```dart
/// class Parent {
///   @override
///   bool operator ==(Object other) => other is Parent;
/// }
/// class Child extends Parent {
///   @override
///   bool operator ==(Object other) =>
///       other is Child;  // Doesn't call super or check Parent equality
/// }
/// ```
class PreferOverridingParentEqualityRule extends SaropaLintRule {
  const PreferOverridingParentEqualityRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_overriding_parent_equality',
    problemMessage: '== implementation consistency.',
    correctionMessage: 'Consider calling super.== or checking parent class equality.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has an == operator
      MethodDeclaration? equalityOperator;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == '==' && member.isOperator) {
          equalityOperator = member;
          break;
        }
      }

      if (equalityOperator == null) return;

      // Check if parent class has == operator
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superType = extendsClause.superclass;
      final DartType? superDartType = superType.type;
      if (superDartType == null) return;

      final Element? superElement = superDartType.element;
      if (superElement is! InterfaceElement) return;

      // Check if parent has custom == (not just Object.==)
      bool parentHasCustomEquals = false;
      for (final MethodElement method in superElement.methods) {
        if (method.name == '==' && !method.isAbstract) {
          // Check if it's from Object or a custom implementation
          final enclosing = (method as Element).enclosingElement;
          final String? enclosingName = enclosing is InterfaceElement ? enclosing.name : null;
          if (enclosingName != null && enclosingName != 'Object') {
            parentHasCustomEquals = true;
            break;
          }
        }
      }

      if (!parentHasCustomEquals) return;

      // Check if the child's == calls super.==
      bool callsSuper = false;
      equalityOperator.body.visitChildren(_SuperEqualityChecker(() => callsSuper = true));

      if (!callsSuper) {
        reporter.atToken(equalityOperator.name, code);
      }
    });
  }
}

class _SuperEqualityChecker extends RecursiveAstVisitor<void> {
  _SuperEqualityChecker(this.onSuperFound);

  final void Function() onSuperFound;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '==') {
      if (node.leftOperand is SuperExpression || node.rightOperand is SuperExpression) {
        onSuperFound();
      }
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression) {
      onSuperFound();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when more specific switch cases should come before general ones.
///
/// Example of **bad** code:
/// ```dart
/// switch (value) {
///   case int _: print('int');
///   case int x when x > 0: print('positive');  // Unreachable
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (value) {
///   case int x when x > 0: print('positive');
///   case int _: print('other int');
/// }
/// ```
class PreferSpecificCasesFirstRule extends SaropaLintRule {
  const PreferSpecificCasesFirstRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_specific_cases_first',
    problemMessage: 'Switch case specificity.',
    correctionMessage: 'Place more specific cases before general ones.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((SwitchExpression node) {
      _checkCaseOrder(
        node.cases.map((SwitchExpressionCase c) => c.guardedPattern).toList(),
        reporter,
      );
    });

    context.registry.addSwitchStatement((SwitchStatement node) {
      final List<GuardedPattern> patterns = <GuardedPattern>[];
      for (final SwitchMember member in node.members) {
        if (member is SwitchPatternCase) {
          patterns.add(member.guardedPattern);
        }
      }
      _checkCaseOrder(patterns, reporter);
    });
  }

  void _checkCaseOrder(List<GuardedPattern> patterns, SaropaDiagnosticReporter reporter) {
    for (int i = 0; i < patterns.length - 1; i++) {
      final GuardedPattern current = patterns[i];
      final GuardedPattern next = patterns[i + 1];

      // Check if current is a general pattern and next is more specific
      final bool currentHasGuard = current.whenClause != null;
      final bool nextHasGuard = next.whenClause != null;

      // If current has no guard but next has a guard with same base pattern,
      // the order might be wrong
      if (!currentHasGuard && nextHasGuard) {
        final String currentPattern = current.pattern.toSource();
        final String nextPattern = next.pattern.toSource();

        // Simple heuristic: same type pattern but one has a guard
        if (_sameBaseType(currentPattern, nextPattern)) {
          reporter.atNode(next, code);
        }
      }
    }
  }

  bool _sameBaseType(String pattern1, String pattern2) {
    // Extract base type from patterns like "int _" or "int x"
    final RegExp typePattern = RegExp(r'^(\w+)');
    final RegExpMatch? match1 = typePattern.firstMatch(pattern1);
    final RegExpMatch? match2 = typePattern.firstMatch(pattern2);

    if (match1 != null && match2 != null) {
      return match1.group(1) == match2.group(1);
    }
    return false;
  }
}

/// Warns when a property is accessed after destructuring provides it.
///
/// Example of **bad** code:
/// ```dart
/// final (x, y) = point;
/// print(point.x);  // Already have x from destructuring
/// ```
///
/// Example of **good** code:
/// ```dart
/// final (x, y) = point;
/// print(x);  // Use destructured variable
/// ```
class UseExistingDestructuringRule extends SaropaLintRule {
  const UseExistingDestructuringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'use_existing_destructuring',
    problemMessage: 'Redundant property access.',
    correctionMessage: 'Use the destructured variable instead of accessing the property.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, Set<String>> destructuredVars = <String, Set<String>>{};

      for (final Statement statement in node.statements) {
        // Find pattern variable declarations
        if (statement is PatternVariableDeclarationStatement) {
          final PatternVariableDeclaration decl = statement.declaration;
          final Expression initializer = decl.expression;
          final DartPattern pattern = decl.pattern;

          if (initializer is SimpleIdentifier) {
            final String sourceName = initializer.name;
            final Set<String> fields = <String>{};

            // Extract field names from pattern
            pattern.visitChildren(_PatternFieldCollector(fields));

            if (fields.isNotEmpty) {
              destructuredVars[sourceName] = fields;
            }
          }
        }

        // Check for property accesses on destructured sources
        statement.visitChildren(
          _DestructuredPropertyAccessChecker(destructuredVars, reporter, _code),
        );
      }
    });
  }
}

class _PatternFieldCollector extends RecursiveAstVisitor<void> {
  _PatternFieldCollector(this.fields);

  final Set<String> fields;

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    fields.add(node.name.lexeme);
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitPatternField(PatternField node) {
    final PatternFieldName? name = node.name;
    if (name != null && name.name != null) {
      fields.add(name.name!.lexeme);
    }
    super.visitPatternField(node);
  }
}

class _DestructuredPropertyAccessChecker extends RecursiveAstVisitor<void> {
  _DestructuredPropertyAccessChecker(this.destructuredVars, this.reporter, this.code);

  final Map<String, Set<String>> destructuredVars;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier) {
      final Set<String>? fields = destructuredVars[target.name];
      if (fields != null && fields.contains(node.propertyName.name)) {
        reporter.atNode(node, code);
      }
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final Set<String>? fields = destructuredVars[node.prefix.name];
    if (fields != null && fields.contains(node.identifier.name)) {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when a new variable is created that duplicates an existing one.
///
/// Example of **bad** code:
/// ```dart
/// final name = user.name;
/// final userName = user.name;  // Redundant
/// print('$name, $userName');
/// ```
///
/// Example of **good** code:
/// ```dart
/// final name = user.name;
/// print('$name, $name');
/// ```
class UseExistingVariableRule extends SaropaLintRule {
  const UseExistingVariableRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'use_existing_variable',
    problemMessage: 'Redundant variable creation.',
    correctionMessage: 'Use the existing variable instead of creating a duplicate.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, Token> expressionToVariable = <String, Token>{};

      for (final Statement statement in node.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable in statement.variables.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            // Skip literals and simple values
            if (initializer is Literal) continue;
            if (initializer is SimpleIdentifier) continue;

            final String exprSource = initializer.toSource();

            if (expressionToVariable.containsKey(exprSource)) {
              // This expression was already assigned to another variable
              reporter.atToken(variable.name, code);
            } else {
              expressionToVariable[exprSource] = variable.name;
            }
          }
        }
      }
    });
  }
}

/// Warns when the same string literal appears 3 or more times in a file.
///
/// Duplicate string literals are candidates for extraction to constants,
/// which improves maintainability and reduces the risk of typos.
///
/// This rule triggers at 3+ occurrences (Professional tier).
/// See also: `avoid_duplicate_string_literals_pair` for 2+ occurrences.
///
/// **Excluded strings:**
/// - Strings shorter than 4 characters
/// - Package/dart import prefixes
/// - URLs (http://, https://)
/// - Interpolation-only strings
///
/// **BAD:**
/// ```dart
/// void process() {
///   print('Loading...');
///   showMessage('Loading...');
///   log('Loading...');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// const kLoadingMessage = 'Loading...';
///
/// void process() {
///   print(kLoadingMessage);
///   showMessage(kLoadingMessage);
///   log(kLoadingMessage);
/// }
/// ```
class AvoidDuplicateStringLiteralsRule extends SaropaLintRule {
  const AvoidDuplicateStringLiteralsRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_string_literals',
    problemMessage: 'String literal appears 3+ times in this file. Consider extracting '
        'to a constant.',
    correctionMessage: 'Extract this string to a named constant for maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Minimum occurrences to trigger this rule
  static const int _minOccurrences = 3;

  /// Minimum string length to consider (shorter strings are often intentional)
  static const int _minLength = 4;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track occurrences and report when threshold is reached.
    // Note: Map state is per-file since runWithReporter is called per-file.
    final Map<String, List<AstNode>> stringOccurrences = <String, List<AstNode>>{};

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip short strings
      if (value.length < _minLength) return;

      // Skip excluded patterns
      if (_shouldSkipString(value)) return;

      final List<AstNode> occurrences = stringOccurrences.putIfAbsent(value, () => <AstNode>[]);
      occurrences.add(node);

      // Report when we hit the threshold (report the current node)
      // and when we exceed it (each subsequent occurrence)
      if (occurrences.length >= _minOccurrences) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _shouldSkipString(String value) {
    // Skip import-like strings
    if (value.startsWith('package:') || value.startsWith('dart:')) {
      return true;
    }

    // Skip URLs
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return true;
    }

    // Skip interpolation-only strings (e.g., '$foo')
    if (value.startsWith(r'$') && !value.contains(' ')) {
      return true;
    }

    // Skip file paths that look like asset paths
    if (value.startsWith('assets/') || value.startsWith('images/')) {
      return true;
    }

    return false;
  }
}

/// Warns when the same string literal appears 2 or more times in a file.
///
/// This is a stricter version of `avoid_duplicate_string_literals` that
/// triggers at just 2 occurrences (Comprehensive tier).
///
/// Duplicate string literals are candidates for extraction to constants,
/// which improves maintainability and reduces the risk of typos.
///
/// **Excluded strings:**
/// - Strings shorter than 4 characters
/// - Package/dart import prefixes
/// - URLs (http://, https://)
/// - Interpolation-only strings
///
/// **BAD:**
/// ```dart
/// void process() {
///   print('Processing data...');
///   log('Processing data...');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// const kProcessingMessage = 'Processing data...';
///
/// void process() {
///   print(kProcessingMessage);
///   log(kProcessingMessage);
/// }
/// ```
class AvoidDuplicateStringLiteralsPairRule extends SaropaLintRule {
  const AvoidDuplicateStringLiteralsPairRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_string_literals_pair',
    problemMessage: 'String literal appears 2+ times in this file. Consider extracting '
        'to a constant.',
    correctionMessage: 'Extract this string to a named constant for maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Minimum occurrences to trigger this rule
  static const int _minOccurrences = 2;

  /// Minimum string length to consider
  static const int _minLength = 4;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track occurrences and report when threshold is reached.
    // Note: Map state is per-file since runWithReporter is called per-file.
    final Map<String, List<AstNode>> stringOccurrences = <String, List<AstNode>>{};

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip short strings
      if (value.length < _minLength) return;

      // Skip excluded patterns
      if (_shouldSkipString(value)) return;

      final List<AstNode> occurrences = stringOccurrences.putIfAbsent(value, () => <AstNode>[]);
      occurrences.add(node);

      // Report when we hit the threshold (report the current node)
      // and when we exceed it (each subsequent occurrence)
      if (occurrences.length >= _minOccurrences) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _shouldSkipString(String value) {
    // Skip import-like strings
    if (value.startsWith('package:') || value.startsWith('dart:')) {
      return true;
    }

    // Skip URLs
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return true;
    }

    // Skip interpolation-only strings (e.g., '$foo')
    if (value.startsWith(r'$') && !value.contains(' ')) {
      return true;
    }

    // Skip file paths that look like asset paths
    if (value.startsWith('assets/') || value.startsWith('images/')) {
      return true;
    }

    return false;
  }
}
