// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/line_info.dart';

import '../../saropa_lint_rule.dart';
import '../../type_annotation_utils.dart';

class AvoidLateFinalReassignmentRule extends SaropaLintRule {
  AvoidLateFinalReassignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_late_final_reassignment',
    '[avoid_late_final_reassignment] Late final field has multiple assignment paths, which throws a LateInitializationError at runtime on the second write. The compiler cannot catch this statically, so the crash only surfaces during execution of the specific code path that triggers the duplicate assignment. {v4}',
    correctionMessage:
        'Ensure the late final field is assigned exactly once across all code paths, or convert it to a non-final late field if reassignment is intentional.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration classNode) {
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
            _LateFinalAssignmentCounter(
              lateFinalFields,
              assignments,
              reporter,
              _code,
            ),
          );
        }
        if (member is ConstructorDeclaration) {
          final Map<String, int> assignments = <String, int>{};
          member.body.visitChildren(
            _LateFinalAssignmentCounter(
              lateFinalFields,
              assignments,
              reporter,
              _code,
            ),
          );
        }
      }
    });
  }
}

class _LateFinalAssignmentCounter extends RecursiveAstVisitor<void> {
  _LateFinalAssignmentCounter(
    this.lateFinalFields,
    this.assignments,
    this.reporter,
    this.code,
  );

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
        reporter.atNode(node);
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when Completer.completeError is called without stack trace.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
///
/// **Exempt:** Maps that include all enum constants (resolved from the
/// actual enum type) are not flagged.
class AvoidMissingEnumConstantInMapRule extends SaropaLintRule {
  AvoidMissingEnumConstantInMapRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_missing_enum_constant_in_map',
    '[avoid_missing_enum_constant_in_map] Map literal keyed by enum values does not include all enum constants. When a new enum value is added, this map silently returns null for the missing key instead of producing a compile-time error, leading to unexpected null values or fallback behavior at runtime. {v3}',
    correctionMessage:
        'Add entries for all enum constants to the map, or use a switch expression with exhaustiveness checking to ensure every enum value is handled.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (!node.isMap) return;
      if (node.elements.isEmpty) return;

      // Resolve the enum type from the first key
      final EnumElement? enumElement = _resolveEnumKeyType(node);
      if (enumElement == null) return;

      // Get all declared enum constants
      final Set<String> allConstants = <String>{};
      for (final FieldElement f in enumElement.fields) {
        if (f.isEnumConstant) {
          final name = f.name;
          if (name != null) allConstants.add(name);
        }
      }

      // Get all used constants from map keys
      final Set<String> usedConstants = <String>{};
      for (final CollectionElement element in node.elements) {
        if (element is MapLiteralEntry) {
          final Expression key = element.key;
          if (key is PrefixedIdentifier) {
            usedConstants.add(key.identifier.name);
          } else if (key is SimpleIdentifier) {
            usedConstants.add(key.name);
          }
        }
      }

      // Only flag if there are actually missing constants
      final Set<String> missing = allConstants.difference(usedConstants);
      if (missing.isNotEmpty) {
        reporter.atNode(node);
      }
    });
  }

  /// Resolves the enum element from a map literal's key type.
  EnumElement? _resolveEnumKeyType(SetOrMapLiteral node) {
    for (final CollectionElement element in node.elements) {
      if (element is MapLiteralEntry) {
        final Expression key = element.key;
        final DartType? keyType = key.staticType;
        if (keyType is InterfaceType) {
          final element = keyType.element;
          if (element is EnumElement) return element;
        }
      }
    }
    return null;
  }
}

/// Warns when function parameters are reassigned.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: avoid_mutating_parameters (deprecated)
///
/// Parameter reassignment changes what the local variable points to, but does
/// NOT affect the caller's variable. This is purely a code clarity issue - it
/// makes it harder to track what a parameter's value is at any point in the
/// function. The original input value is lost for debugging.
///
/// **BAD:**
/// ```dart
/// void process(int value) {
///   value = value * 2;  // Reassigning parameter
/// }
///
/// void count(int n) {
///   n++;  // Postfix reassignment
///   ++n;  // Prefix reassignment
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void process(int value) {
///   final doubled = value * 2;  // Use local variable
/// }
/// ```
///
/// **Alternative:** Use `final` parameters (Dart 2.17+) to get compile-time
/// enforcement:
/// ```dart
/// void process(final int value) {
///   value = value * 2;  // Compile error!
/// }
/// ```
class AvoidParameterReassignmentRule extends SaropaLintRule {
  AvoidParameterReassignmentRule() : super(code: _code);

  /// Style issue - low impact.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_parameter_reassignment',
    '[avoid_parameter_reassignment] Parameter is being reassigned. '
        'This hides the original input value. {v3}',
    correctionMessage:
        'Create a local variable instead of reassigning the parameter.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final Set<String> paramNames = <String>{};
      for (final FormalParameter param in params.parameters) {
        final Token? name = param.name;
        if (name != null) paramNames.add(name.lexeme);
      }

      if (paramNames.isEmpty) return;

      node.functionExpression.body.visitChildren(
        _ParameterReassignmentVisitor(paramNames, reporter, _code),
      );
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      final Set<String> paramNames = <String>{};
      for (final FormalParameter param in params.parameters) {
        final Token? name = param.name;
        if (name != null) paramNames.add(name.lexeme);
      }

      if (paramNames.isEmpty) return;

      node.body.visitChildren(
        _ParameterReassignmentVisitor(paramNames, reporter, _code),
      );
    });
  }
}

/// Visitor that detects direct reassignment of parameter variables.
///
/// Checks for: `param = value`, `param++`, `param--`, `++param`, `--param`.
class _ParameterReassignmentVisitor extends RecursiveAstVisitor<void> {
  _ParameterReassignmentVisitor(this.paramNames, this.reporter, this.code);

  final Set<String> paramNames;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && paramNames.contains(left.name)) {
      reporter.atNode(node);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final Expression operand = node.operand;
    if (operand is SimpleIdentifier && paramNames.contains(operand.name)) {
      reporter.atNode(node);
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final TokenType op = node.operator.type;
    if (op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) {
      final Expression operand = node.operand;
      if (operand is SimpleIdentifier && paramNames.contains(operand.name)) {
        reporter.atNode(node);
      }
    }
    super.visitPrefixExpression(node);
  }
}

/// Warns when function parameters are mutated (object state modified).
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Mutating a parameter modifies the caller's object, which is a hidden
/// side effect that can cause bugs. The caller may not expect their data
/// to change. This is different from parameter reassignment (which only
/// affects the local reference).
///
/// Detects:
/// - Collection mutations: `param.add()`, `param.clear()`, `param.sort()`
/// - Field assignments: `param.field = value`
/// - Index assignments: `param[i] = value`
/// - Cascade mutations: `param..add()..remove()`
///
/// **BAD:**
/// ```dart
/// void process(List<String> items) {
///   items.add('new');     // Mutates caller's list
///   items.clear();        // Mutates caller's list
/// }
///
/// void updateUser(User user) {
///   user.name = 'changed';  // Mutates caller's object
/// }
///
/// void modify(Map<String, int> map) {
///   map['key'] = 42;  // Index assignment mutation
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void process(List<String> items) {
///   final newItems = [...items, 'new'];  // Create new list
/// }
///
/// User updateUser(User user) {
///   return user.copyWith(name: 'changed');  // Return new instance
/// }
/// ```
class AvoidParameterMutationRule extends SaropaLintRule {
  AvoidParameterMutationRule() : super(code: _code);

  /// High impact - can cause bugs in calling code.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_parameter_mutation',
    '[avoid_parameter_mutation] Parameter object is being mutated. '
        'This modifies the caller\'s data. {v2}',
    correctionMessage:
        'Create a copy of the data instead of mutating the parameter.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Known mutating methods for collection types.
  static const Set<String> _mutatingMethods = <String>{
    // List
    'add',
    'addAll',
    'insert',
    'insertAll',
    'remove',
    'removeAt',
    'removeLast',
    'removeRange',
    'removeWhere',
    'retainWhere',
    'clear',
    'sort',
    'shuffle',
    'setAll',
    'setRange',
    'fillRange',
    'replaceRange',
    // Set
    'removeAll',
    'retainAll',
    // Map
    'addEntries',
    'putIfAbsent',
    'update',
    'updateAll',
    // Queue
    'addFirst',
    'addLast',
    'removeFirst',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunction(
        node.functionExpression.parameters,
        node.functionExpression.body,
        reporter,
      );
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkFunction(node.parameters, node.body, reporter);
    });
  }

  void _checkFunction(
    FormalParameterList? params,
    FunctionBody body,
    SaropaDiagnosticReporter reporter,
  ) {
    if (params == null) return;

    final Set<String> paramNames = <String>{};
    for (final FormalParameter param in params.parameters) {
      final Token? name = param.name;
      if (name != null) paramNames.add(name.lexeme);
    }

    if (paramNames.isEmpty) return;

    body.visitChildren(
      _ParameterMutationVisitor(paramNames, reporter, _code, _mutatingMethods),
    );
  }
}

/// Visitor that detects mutations of parameter objects.
///
/// Checks for: mutating method calls on collections, field assignments,
/// index assignments, and cascade mutations.
class _ParameterMutationVisitor extends RecursiveAstVisitor<void> {
  _ParameterMutationVisitor(
    this.paramNames,
    this.reporter,
    this.code,
    this.mutatingMethods,
  );

  final Set<String> paramNames;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> mutatingMethods;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for param.mutatingMethod() pattern (e.g., list.add())
    final Expression? target = node.target;
    if (target is SimpleIdentifier && paramNames.contains(target.name)) {
      final String methodName = node.methodName.name;
      if (mutatingMethods.contains(methodName)) {
        reporter.atNode(node);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;

    // Check for param.field = value pattern
    if (left is PrefixedIdentifier) {
      final SimpleIdentifier prefix = left.prefix;
      if (paramNames.contains(prefix.name)) {
        reporter.atNode(node);
      }
    }

    // Check for param[index] = value pattern
    if (left is IndexExpression) {
      final Expression? target = left.target;
      if (target is SimpleIdentifier && paramNames.contains(target.name)) {
        reporter.atNode(node);
      }
    }

    super.visitAssignmentExpression(node);
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    // Check for param..add()..remove() pattern
    final Expression target = node.target;
    if (target is SimpleIdentifier && paramNames.contains(target.name)) {
      // Check if any cascade section is a mutation
      for (final Expression section in node.cascadeSections) {
        if (section is MethodInvocation) {
          final String methodName = section.methodName.name;
          if (mutatingMethods.contains(methodName)) {
            reporter.atNode(node);
            return; // Report once per cascade
          }
        }
        if (section is AssignmentExpression) {
          reporter.atNode(node);
          return;
        }
      }
    }
    super.visitCascadeExpression(node);
  }
}

// cspell:ignore valuel
/// Warns when variable names are too similar.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final value1 = 1;
/// final valuel = 2;  // Too similar to value1
/// ```
class AvoidUnnecessaryNullableParametersRule extends SaropaLintRule {
  AvoidUnnecessaryNullableParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_nullable_parameters',
    '[avoid_unnecessary_nullable_parameters] Parameter declared as nullable but null is never passed at any call site. The unnecessary nullable type forces every usage within the function body to handle a null case that cannot occur, adding defensive checks and reducing code clarity. {v4}',
    correctionMessage:
        'Change the parameter type to non-nullable. If null support is needed for future callers, add it when the requirement actually arises rather than preemptively.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // This is a simplified version - full implementation would track
    // all call sites across the codebase
    context.addFunctionDeclaration((FunctionDeclaration node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// A function that always returns null likely has the wrong return type (should
/// be `void`) or is missing meaningful implementation. This indicates dead code
/// or an incomplete implementation that should be addressed.
///
/// Note: Void functions (`void`, `Future<void>`, `FutureOr<void>`) and functions
/// with no explicit return type that only use bare `return;` statements are
/// excluded since early-exit returns are valid in those contexts.
///
/// **BAD:**
/// ```dart
/// String? getValue() {
///   if (condition) return null;
///   return null;  // Always null - should return meaningful value or be void
/// }
///
/// int? getNumber() => null;  // Expression body always returns null
/// ```
///
/// **GOOD:**
/// ```dart
/// void doSomething() {
///   if (!ready) return;  // Early exit in void function is fine
///   performAction();
/// }
///
/// String? getValue() {
///   if (condition) return cachedValue;
///   return computeValue();  // Returns meaningful values
/// }
/// ```
class FunctionAlwaysReturnsNullRule extends SaropaLintRule {
  FunctionAlwaysReturnsNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'function_always_returns_null',
    '[function_always_returns_null] Function returns null on every code path, making the return type effectively void. Callers that check or use the return value are performing dead logic, and the nullable return type misleads developers into thinking the function can return meaningful data. {v6}',
    correctionMessage:
        'Change the return type to void if the function is purely side-effecting, or add meaningful return values for different code paths to make the function useful to callers.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(
        node.functionExpression.body,
        node.returnType,
        node.name,
        reporter,
      );
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, node.returnType, node.name, reporter);
    });
  }

  void _checkFunctionBody(
    FunctionBody body,
    TypeAnnotation? returnType,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
    // Skip generators — they emit values via yield, not return.
    // A bare `return;` in async*/sync* ends the stream/iterable,
    // it does not "return null".
    if (body.isGenerator) return;
    if (body is BlockFunctionBody && body.star != null) return;

    // Belt-and-suspenders: also check return type for generator types.
    // Catches generators even if body.isGenerator fails to resolve
    // correctly in some analyzer versions.
    if (returnType is NamedType) {
      final String typeName = returnType.name.lexeme;
      if (typeName == 'Stream' || typeName == 'Iterable') return;
    }

    // Skip void functions - bare return statements are valid
    if (_isVoidType(returnType)) return;

    if (body is ExpressionFunctionBody) {
      if (body.expression is NullLiteral) {
        reporter.atToken(nameToken);
      }
      return;
    }

    if (body is BlockFunctionBody) {
      final List<ReturnStatement> returns = <ReturnStatement>[];
      body.block.visitChildren(_ReturnCollector(returns));

      if (returns.isEmpty) return;

      // Check if all returns are bare (no expression) vs explicit null
      final bool allBareReturns = returns.every(
        (ReturnStatement ret) => ret.expression == null,
      );
      final bool allNull = returns.every((ReturnStatement ret) {
        final Expression? expr = ret.expression;
        return expr == null || expr is NullLiteral;
      });

      // If no explicit return type and all returns are bare `return;`,
      // this is likely a void function with inferred type - don't flag
      if (returnType == null && allBareReturns) return;

      if (allNull && returns.isNotEmpty) {
        reporter.atToken(nameToken);
      }
    }
  }

  /// Returns true if [returnType] is void, `Future<void>`, or `FutureOr<void>`.
  /// These return types make bare `return;` statements valid.
  bool _isVoidType(TypeAnnotation? returnType) {
    if (returnType == null) return false;

    // Try to use the resolved DartType first (handles type aliases)
    final DartType? resolvedType = returnType.type;
    if (resolvedType != null) {
      return _isDartTypeVoid(resolvedType);
    }

    // Fall back to syntactic check if resolved type unavailable
    if (returnType is! NamedType) return false;

    final String typeName = returnType.name.lexeme;

    if (typeName == 'void') return true;

    // Check for Future<void> or FutureOr<void>
    if (typeName == 'Future' || typeName == 'FutureOr') {
      final TypeArgumentList? typeArgs = returnType.typeArguments;
      if (typeArgs == null || typeArgs.arguments.length != 1) return false;

      final TypeAnnotation arg = typeArgs.arguments.first;
      return arg is NamedType && arg.name.lexeme == 'void';
    }

    return false;
  }

  /// Returns true if [type] is void, `Future<void>`, or `FutureOr<void>`.
  bool _isDartTypeVoid(DartType type) {
    if (type is VoidType) return true;

    // Check for Future<void> or FutureOr<void>
    if (type is InterfaceType) {
      final String? name = type.element.name;
      if (name == 'Future' || name == 'FutureOr') {
        final List<DartType> typeArgs = type.typeArguments;
        if (typeArgs.length == 1 && typeArgs[0] is VoidType) {
          return true;
        }
      }
    }

    return false;
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// for (var i = 0; i < items.length; i++) {
///   print(items[0]);  // Always accessing first element
/// }
/// ```
class AvoidUnusedAssignmentRule extends SaropaLintRule {
  AvoidUnusedAssignmentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_unused_assignment',
    '[avoid_unused_assignment] Variable is assigned a value that is never read before being overwritten or going out of scope. The assignment wastes computation, and the unused result often signals a logic error where the value was meant to be used in a subsequent expression or return statement. {v3}',
    correctionMessage:
        'Remove the assignment if the value is not needed, or use the variable in the intended expression. Check for missing return statements or conditional branches.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final Map<String, List<AstNode>> assignments = <String, List<AstNode>>{};
      final Set<String> usedVariables = <String>{};

      node.visitChildren(_AssignmentUsageVisitor(assignments, usedVariables));

      for (final MapEntry<String, List<AstNode>> entry in assignments.entries) {
        if (entry.value.length <= 1) continue;

        for (int i = 0; i < entry.value.length - 1; i++) {
          final AstNode current = entry.value[i];

          // Don't flag assignments inside loop bodies — the loop
          // condition re-reads the variable on the next iteration.
          if (_isInsideLoop(current)) continue;

          // Don't flag if the NEXT assignment is inside a conditional
          // (may-overwrite): the old value is still live on the else path.
          final AstNode next = entry.value[i + 1];
          if (_isInsideConditionalOnly(next)) continue;

          // Don't flag if the next assignment's RHS reads this variable
          // (e.g. `x = x.toLowerCase()` reads then overwrites).
          if (_nextAssignmentReadsVariable(next, entry.key)) continue;

          // Don't flag if current and next are in opposite branches
          // of the same if/else (mutually exclusive, not sequential).
          if (_areInOppositeBranches(current, next)) continue;

          reporter.atNode(current, code);
        }
      }
    });
  }

  /// Returns true if [node] is inside a loop body (while, do, for).
  static bool _isInsideLoop(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is WhileStatement ||
          current is DoStatement ||
          current is ForStatement) {
        return true;
      }
      // Stop at function boundaries
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }

  /// Returns true if [node] is inside an if-block that has no else branch
  /// (a may-overwrite, not a must-overwrite).
  static bool _isInsideConditionalOnly(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement && current.elseStatement == null) {
        return true;
      }
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }

  /// Returns true if the assignment node's RHS references [varName].
  static bool _nextAssignmentReadsVariable(AstNode node, String varName) {
    if (node is! AssignmentExpression) return false;
    return _containsIdentifier(node.rightHandSide, varName);
  }

  static bool _containsIdentifier(AstNode node, String name) {
    if (node is SimpleIdentifier && node.name == name) return true;
    final finder = _QuickIdentifierFinder(name);
    node.visitChildren(finder);
    return finder.isFound;
  }

  /// Returns true if [a] and [b] are in opposite branches of the same
  /// if/else statement (mutually exclusive execution paths).
  static bool _areInOppositeBranches(AstNode a, AstNode b) {
    AstNode? current = a.parent;
    while (current != null) {
      if (current is IfStatement && current.elseStatement != null) {
        final bool aInThen = _isContainedIn(a, current.thenStatement);
        if (aInThen && _isContainedIn(b, current.elseStatement!)) {
          return true;
        }
        final bool aInElse = _isContainedIn(a, current.elseStatement!);
        if (aInElse && _isContainedIn(b, current.thenStatement)) {
          return true;
        }
      }
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }

  /// Returns true if [node] is positionally within [container].
  static bool _isContainedIn(AstNode node, AstNode container) {
    return node.offset >= container.offset && node.end <= container.end;
  }
}

class _QuickIdentifierFinder extends GeneralizingAstVisitor<void> {
  _QuickIdentifierFinder(this.name);
  final String name;
  bool isFound = false;

  @override
  void visitNode(AstNode node) {
    if (isFound) return;
    if (node is SimpleIdentifier && node.name == name) {
      isFound = true;
      return;
    }
    super.visitNode(node);
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
      final list = assignments[left.name];
      if (list != null) list.add(node);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Skips known fire-and-forget constructors (e.g. `Future.delayed`,
/// `Timer`, `Timer.periodic`) whose side effects are the intended use.
///
/// Example of **bad** code:
/// ```dart
/// void foo() {
///   MyClass();  // Instance created but not used
/// }
/// ```
///
/// Example of **good** code (not flagged):
/// ```dart
/// void foo() {
///   Future.delayed(Duration(seconds: 1), () => print('done'));
///   Timer(Duration(seconds: 1), () => print('done'));
/// }
/// ```
class AvoidUnusedInstancesRule extends SaropaLintRule {
  AvoidUnusedInstancesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Types whose constructors are intentionally used for side effects
  /// without needing to capture the returned instance.
  static const Set<String> _fireAndForgetTypes = <String>{'Future', 'Timer'};

  static const LintCode _code = LintCode(
    'avoid_unused_instances',
    '[avoid_unused_instances] Object instance created but never assigned to a variable or used in an expression. The constructor runs its side effects (if any) but the resulting object is immediately garbage-collected, wasting memory allocation and usually indicating a missing assignment. {v5}',
    correctionMessage:
        'Assign the instance to a variable for later use, pass it directly as an argument, or remove the creation entirely if the side effects are not needed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExpressionStatement((ExpressionStatement node) {
      final Expression expr = node.expression;
      if (expr is! InstanceCreationExpression) return;

      final String typeName = expr.constructorName.type.name.lexeme;
      if (_fireAndForgetTypes.contains(typeName)) return;

      reporter.atNode(node);
    });
  }
}

/// Warns when a variable is null-checked but not used afterward.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// if (x != null) {
///   print('exists');  // x is not used
/// }
/// ```
class AvoidUnusedAfterNullCheckRule extends SaropaLintRule {
  AvoidUnusedAfterNullCheckRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_unused_after_null_check',
    '[avoid_unused_after_null_check] Variable is null-checked in a condition but never referenced inside the guarded block. The null check implies the variable is needed, so the missing reference likely indicates a logic error where the intended usage was accidentally omitted. {v3}',
    correctionMessage:
        'Reference the variable inside the guarded block where the null check applies, or remove the null check entirely if the variable is genuinely not needed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      final Expression condition = node.expression;

      String? checkedVariable;
      if (condition is BinaryExpression) {
        if (condition.operator.type == TokenType.BANG_EQ) {
          final left = condition.leftOperand;
          final right = condition.rightOperand;
          if (right is NullLiteral && left is SimpleIdentifier) {
            checkedVariable = left.name;
          }
          if (left is NullLiteral && right is SimpleIdentifier) {
            checkedVariable = right.name;
          }
        }
      }

      if (checkedVariable == null) return;

      final bool isUsed = _containsIdentifier(
        node.thenStatement,
        checkedVariable,
      );
      if (!isUsed) {
        reporter.atNode(condition);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// switch (status) {
///   case Status.active: ...
///   default: ...  // May hide unhandled enum values
/// }
/// ```
class FunctionAlwaysReturnsSameValueRule extends SaropaLintRule {
  FunctionAlwaysReturnsSameValueRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'function_always_returns_same_value',
    '[function_always_returns_same_value] Function returns the same value on every code path regardless of input. The function body adds complexity without varying the output, suggesting the logic branches are incomplete or the function can be replaced by a constant. {v5}',
    correctionMessage:
        'Replace the function with a constant or static field if the value is truly fixed, or add the missing branches that return different values based on input.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(node.functionExpression.body, node.name, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, node.name, reporter);
    });
  }

  void _checkFunctionBody(
    FunctionBody body,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
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
      reporter.atToken(nameToken);
    }
  }
}

/// Warns when the same condition appears in nested if statements.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// if (x > 0) {
///   if (x > 0) {  // Same condition
///     ...
///   }
/// }
/// ```
class AvoidUnassignedFieldsRule extends SaropaLintRule {
  AvoidUnassignedFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unassigned_fields',
    '[avoid_unassigned_fields] Field declared without an initializer and no constructor or method assigns it a value. Reading this field returns the default value (null for nullable types), which may cause unexpected NullPointerExceptions or logic errors if the caller expects a meaningful value. {v4}',
    correctionMessage:
        'Add an initializer at the declaration site, assign the field in the constructor, or mark it as late if initialization is deferred to a lifecycle method.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final Set<String> assignedFields = <String>{};
      final Map<String, Token> nullableFields = <String, Token>{};

      // Collect nullable fields without initializers
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final DartType? type = variable.declaredFragment?.element.type;
            if (type != null &&
                type.nullabilitySuffix == NullabilitySuffix.question) {
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
        if (member is ConstructorDeclaration &&
            member.body is BlockFunctionBody) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   late String name;  // Never assigned - will throw at runtime
/// }
/// ```
class AvoidUnassignedLateFieldsRule extends SaropaLintRule {
  AvoidUnassignedLateFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unassigned_late_fields',
    '[avoid_unassigned_late_fields] Late field has no assignment in any constructor, initializer, or lifecycle method. Accessing an unassigned late field throws a LateInitializationError at runtime, crashing the app at a point that the compiler cannot check statically. {v4}',
    correctionMessage:
        'Assign the field in the constructor, an initializer list, or a lifecycle method such as initState(). If initialization is conditional, use a nullable type instead of late.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   late final String name;
///   Foo(this.name);  // late is unnecessary
/// }
/// ```
class AvoidUnnecessaryLateFieldsRule extends SaropaLintRule {
  AvoidUnnecessaryLateFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_late_fields',
    '[avoid_unnecessary_late_fields] Field marked as late but already assigned in the constructor or initializer list. The late keyword is redundant here and misleads readers into thinking initialization is deferred, while also disabling the compile-time guarantee that the field is always initialized. {v5}',
    correctionMessage:
        'Remove the late keyword since the field is already assigned during construction. This restores compile-time initialization checking and clarifies the intent.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final Map<String, FieldDeclaration> lateFields =
          <String, FieldDeclaration>{};

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
              if (param is FieldFormalParameter &&
                  param.name.lexeme == fieldName) {
                assigned = true;
                break;
              }
            }

            // Check initializers
            if (!assigned) {
              for (final ConstructorInitializer init in member.initializers) {
                if (init is ConstructorFieldInitializer &&
                    init.fieldName.name == fieldName) {
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
      for (final MapEntry<String, FieldDeclaration> entry
          in lateFields.entries) {
        if (allConstructorsAssign(entry.key)) {
          reporter.atNode(entry.value, code);
        }
      }
    });
  }
}

/// Warns when a nullable field is always non-null.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class Foo {
///   String? name;  // Always assigned non-null value
///   Foo(String n) : name = n;
/// }
/// ```
class AvoidUnnecessaryNullableFieldsRule extends SaropaLintRule {
  AvoidUnnecessaryNullableFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_nullable_fields',
    '[avoid_unnecessary_nullable_fields] Nullable field is always assigned a non-null value across all constructors and assignment sites. The unnecessary nullable type forces every read site to handle null even though it can never occur, adding redundant null checks and obscuring the actual data flow. {v4}',
    correctionMessage:
        'Change the field type to non-nullable and remove the ? suffix. Add null checks only if a future code path genuinely needs to store null.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final Map<String, Token> nullableFields = <String, Token>{};
      final Set<String> assignedNullFields = <String>{};
      final Set<String> constructorInitializedFields = <String>{};

      // Collect nullable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final DartType? type = variable.declaredFragment?.element.type;
            if (type != null &&
                type.nullabilitySuffix == NullabilitySuffix.question) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidUnnecessaryPatternsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_patterns',
    '[avoid_unnecessary_patterns] Pattern matching syntax used where it does not narrow types or destructure values. The pattern adds syntactic complexity without any type-safety benefit, making the code harder to read compared to a plain variable declaration or assignment. {v5}',
    correctionMessage:
        'Replace the pattern with a simple variable declaration or assignment. Use pattern matching only when it provides destructuring or type narrowing.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      final CaseClause? caseClause = node.caseClause;
      if (caseClause == null) return;

      final GuardedPattern guardedPattern = caseClause.guardedPattern;
      final DartPattern pattern = guardedPattern.pattern;

      // Check if pattern is just a type test on the same type
      if (pattern is DeclaredVariablePattern) {
        final DartType? patternType = pattern.type?.type;
        final DartType? expressionType = node.expression.staticType;

        if (patternType != null && expressionType != null) {
          if (patternType.getDisplayString() ==
              expressionType.getDisplayString()) {
            reporter.atNode(pattern);
          }
        }
      }
    });
  }
}

/// Warns when using default/wildcard case with sealed classes.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// sealed class Shape {}
/// switch (shape) {
///   case Circle(): ...
///   default: ...  // May hide unhandled subclasses
/// }
/// ```
class AvoidUnnecessaryLocalLateRule extends SaropaLintRule {
  AvoidUnnecessaryLocalLateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_local_late',
    '[avoid_unnecessary_local_late] Local variable declared as late but assigned a value on the same line. The late keyword is designed for deferred initialization, so using it on an immediately initialized variable is misleading and disables the compile-time check that ensures the variable is assigned. {v5}',
    correctionMessage:
        'Remove the late keyword and keep the immediate initializer. Use final or var to declare the variable with full compile-time initialization safety.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclarationStatement((
      VariableDeclarationStatement node,
    ) {
      final VariableDeclarationList variables = node.variables;
      if (!variables.isLate) return;

      for (final VariableDeclaration variable in variables.variables) {
        if (variable.initializer != null) {
          // Variable has an initializer, late is unnecessary
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when an overriding method specifies default values that look suspicious.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
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
  MatchBaseClassDefaultValueRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'match_base_class_default_value',
    '[match_base_class_default_value] Overridden method parameter has a different default value than the parent class. Callers using the parent type see the parent default, while callers using the subtype see the override default, creating inconsistent behavior depending on the variable type. {v3}',
    correctionMessage:
        'Match the parent class default value exactly, or remove the default to inherit it. If a different default is intentional, document why the override diverges.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration classNode) {
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
            reporter.atNode(defaultValue);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// Alias: move_variable_closer_to_usage
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
  MoveVariableCloserToUsageRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'move_variable_closer_to_its_usage',
    '[move_variable_closer_to_its_usage] Variable declared far from its first use, with many unrelated statements in between. This forces readers to hold the variable in memory while reading irrelevant code, reducing comprehension and increasing the risk of accidental reuse or shadowing. {v7}',
    correctionMessage:
        'Move the variable declaration to just before its first usage. This narrows the scope, improves readability, and makes the data flow easier to follow.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _minLineDistance = 10;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final Map<String, int> declarationLines = <String, int>{};
      final Map<String, int> firstUsageLines = <String, int>{};
      final Map<String, VariableDeclaration> declarations =
          <String, VariableDeclaration>{};

      // First pass: collect declarations
      for (final Statement statement in node.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable
              in statement.variables.variables) {
            final String name = variable.name.lexeme;
            declarationLines[name] = context.lineInfo
                .getLocation(variable.offset)
                .lineNumber;
            declarations[name] = variable;
          }
        }
      }

      // Second pass: find first usage of each variable
      node.visitChildren(
        _FirstUsageVisitor(
          declarationLines.keys.toSet(),
          firstUsageLines,
          context.lineInfo,
        ),
      );

      // Check distances
      for (final String name in declarationLines.keys) {
        final int? declLineValue = declarationLines[name];
        if (declLineValue == null) continue;
        final int declLine = declLineValue;
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
  _FirstUsageVisitor(this.variableNames, this.firstUsageLines, this.lineInfo);

  final Set<String> variableNames;
  final Map<String, int> firstUsageLines;
  final LineInfo lineInfo;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final String name = node.name;
    if (variableNames.contains(name) && !firstUsageLines.containsKey(name)) {
      // Skip if this is the declaration itself
      final parent = node.parent;
      if (parent is VariableDeclaration && parent.name == node.token) {
        return;
      }
      firstUsageLines[name] = lineInfo.getLocation(node.offset).lineNumber;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when a variable could be moved outside a loop.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: move_variable_outside_iteration
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
  MoveVariableOutsideIterationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'move_variable_outside_iteration',
    '[move_variable_outside_iteration] Variable declared and assigned inside a loop body produces the same value on every iteration. Recreating the same object or computing the same expression repeatedly wastes CPU cycles and puts unnecessary pressure on the garbage collector. {v4}',
    correctionMessage:
        'Move the variable declaration above the loop so it is computed once and reused on each iteration, reducing allocation overhead and improving clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void checkLoopBody(Statement body) {
      if (body is! Block) return;

      for (final Statement statement in body.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable
              in statement.variables.variables) {
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

    context.addForStatement((ForStatement node) {
      checkLoopBody(node.body);
    });

    context.addWhileStatement((WhileStatement node) {
      checkLoopBody(node.body);
    });

    context.addDoStatement((DoStatement node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class UseExistingDestructuringRule extends SaropaLintRule {
  UseExistingDestructuringRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'use_existing_destructuring',
    '[use_existing_destructuring] Property accessed through the original object despite an existing destructured variable that already holds the same value. The redundant access obscures the data flow and ignores the destructuring that was set up to simplify property access. {v5}',
    correctionMessage:
        'Replace the property access with the destructured variable name. This communicates that the value was already extracted and avoids redundant lookups.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
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
  _DestructuredPropertyAccessChecker(
    this.destructuredVars,
    this.reporter,
    this.code,
  );

  final Map<String, Set<String>> destructuredVars;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier) {
      final Set<String>? fields = destructuredVars[target.name];
      if (fields != null && fields.contains(node.propertyName.name)) {
        reporter.atNode(node);
      }
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final Set<String>? fields = destructuredVars[node.prefix.name];
    if (fields != null && fields.contains(node.identifier.name)) {
      reporter.atNode(node);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when a new variable is created that duplicates an existing one.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  UseExistingVariableRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'use_existing_variable',
    '[use_existing_variable] New variable created with the same value as an existing in-scope variable. The duplicate adds an unnecessary name to the scope, increases cognitive load, and risks divergence if one copy is later modified while the other is not. {v4}',
    correctionMessage:
        'Reference the existing variable directly instead of creating a new one. If a different name is needed for clarity, consider renaming the original.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final Map<String, Token> expressionToVariable = <String, Token>{};

      for (final Statement statement in node.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final VariableDeclaration variable
              in statement.variables.variables) {
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
/// Since: v4.13.0 | Rule version: v1
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
class PreferLateFinalRule extends SaropaLintRule {
  PreferLateFinalRule() : super(code: _code);

  /// Code quality improvement - prevents accidental mutation.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_late_final',
    '[prefer_late_final] Late variable is never reassigned after its initial assignment, so it can be declared as late final for stronger immutability guarantees. {v3}',
    correctionMessage:
        'Change late to late final so that any accidental reassignment is caught at compile time, preventing unintended state mutations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Find late non-final fields
      final List<_LateFinalFieldInfo> lateFields = <_LateFinalFieldInfo>[];

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final VariableDeclarationList fields = member.fields;
          if (fields.lateKeyword != null && !fields.isFinal) {
            for (final VariableDeclaration variable in fields.variables) {
              lateFields.add(
                _LateFinalFieldInfo(
                  name: variable.name.lexeme,
                  declaration: variable,
                  field: member,
                ),
              );
            }
          }
        }
      }

      if (lateFields.isEmpty) return;

      // Count assignments to each late field
      // Include inline initializers as the first assignment
      final Map<String, int> assignmentCounts = <String, int>{};
      for (final _LateFinalFieldInfo field in lateFields) {
        // If field has inline initializer, count starts at 1
        final bool hasInitializer = field.declaration.initializer != null;
        assignmentCounts[field.name] = hasInitializer ? 1 : 0;
      }

      // Track which methods assign to which fields, so we can check
      // if those methods are called from multiple sites
      final Map<String, Set<String>> methodFieldAssignments =
          <String, Set<String>>{};

      // Visit all methods to count assignments
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final _LateFinalAssignmentCounterVisitor visitor =
              _LateFinalAssignmentCounterVisitor(assignmentCounts);
          member.body.visitChildren(visitor);

          if (visitor.assignedFields.isNotEmpty) {
            methodFieldAssignments[member.name.lexeme] = visitor.assignedFields;
          }
        }
        if (member is ConstructorDeclaration) {
          if (member.body is BlockFunctionBody) {
            member.body.visitChildren(
              _LateFinalAssignmentCounterVisitor(assignmentCounts),
            );
          }
          // Count initializer list assignments
          for (final ConstructorInitializer initializer
              in member.initializers) {
            if (initializer is ConstructorFieldInitializer) {
              final String fieldName = initializer.fieldName.name;
              if (assignmentCounts.containsKey(fieldName)) {
                assignmentCounts[fieldName] =
                    (assignmentCounts[fieldName] ?? 0) + 1;
              }
            }
          }
        }
      }

      // Adjust counts for methods called from multiple sites.
      // A single assignment in a method called N times means the field
      // is effectively assigned N times at runtime.
      _adjustForMethodCallSites(node, methodFieldAssignments, assignmentCounts);

      // Report fields that are assigned exactly once
      // Skip never-assigned fields (count == 0) - those are bugs, not candidates
      for (final _LateFinalFieldInfo field in lateFields) {
        final int count = assignmentCounts[field.name] ?? 0;
        if (count == 1) {
          reporter.atNode(field.declaration, code);
        }
      }
    });
  }

  /// Counts how many times each assigning method is called within the class.
  /// If a method that assigns to a late field is called from N > 1 sites,
  /// adds (N - 1) to the field's assignment count since the AST visitor
  /// already counted the assignment node once.
  static void _adjustForMethodCallSites(
    ClassDeclaration node,
    Map<String, Set<String>> methodFieldAssignments,
    Map<String, int> assignmentCounts,
  ) {
    if (methodFieldAssignments.isEmpty) return;

    final Map<String, int> methodCallCounts = <String, int>{
      for (final String name in methodFieldAssignments.keys) name: 0,
    };

    final _LateFinalMethodCallCounterVisitor callVisitor =
        _LateFinalMethodCallCounterVisitor(methodCallCounts);

    for (final ClassMember member in node.members) {
      if (member is MethodDeclaration) {
        member.body.visitChildren(callVisitor);
      }
      if (member is ConstructorDeclaration &&
          member.body is BlockFunctionBody) {
        member.body.visitChildren(callVisitor);
      }
    }

    for (final MapEntry<String, Set<String>> entry
        in methodFieldAssignments.entries) {
      final int callCount = methodCallCounts[entry.key] ?? 0;
      if (callCount > 1) {
        for (final String fieldName in entry.value) {
          assignmentCounts[fieldName] =
              (assignmentCounts[fieldName] ?? 0) + (callCount - 1);
        }
      }
    }
  }
}

class _LateFinalFieldInfo {
  const _LateFinalFieldInfo({
    required this.name,
    required this.declaration,
    required this.field,
  });

  final String name;
  final VariableDeclaration declaration;
  final FieldDeclaration field;
}

class _LateFinalAssignmentCounterVisitor extends RecursiveAstVisitor<void> {
  _LateFinalAssignmentCounterVisitor(this.counts);

  final Map<String, int> counts;

  /// Fields that were assigned in the visited scope.
  final Set<String> assignedFields = <String>{};

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression left = node.leftHandSide;
    String? fieldName;

    if (left is SimpleIdentifier) {
      fieldName = left.name;
    } else if (left is PrefixedIdentifier) {
      // this._field or _prefix._field
      if (left.prefix.name == 'this') {
        fieldName = left.identifier.name;
      }
    } else if (left is PropertyAccess) {
      final Expression? target = left.target;
      if (target is ThisExpression) {
        fieldName = left.propertyName.name;
      }
    }

    if (fieldName != null && counts.containsKey(fieldName)) {
      counts[fieldName] = (counts[fieldName] ?? 0) + 1;
      assignedFields.add(fieldName);
    }

    super.visitAssignmentExpression(node);
  }
}

/// Counts calls to specific methods within a class body.
///
/// Used by [PreferLateFinalRule] to detect when a method that assigns
/// to a late field is called from multiple sites, making the field
/// effectively reassigned at runtime.
class _LateFinalMethodCallCounterVisitor extends RecursiveAstVisitor<void> {
  _LateFinalMethodCallCounterVisitor(this.counts);

  final Map<String, int> counts;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (counts.containsKey(methodName)) {
      final Expression? target = node.target;
      // Only count calls on this instance (implicit or explicit this)
      if (target == null || target is ThisExpression) {
        counts[methodName] = (counts[methodName] ?? 0) + 1;
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Returns true if the declaration is `late final` with all variables having
/// inline initializers. Such fields use lazy evaluation and cannot throw
/// [LateInitializationError] — the initializer runs on first access.
bool _allVariablesHaveInitializers(VariableDeclarationList fields) {
  if (!fields.isFinal) return false;
  return fields.variables.every(
    (VariableDeclaration v) => v.initializer != null,
  );
}

/// Warns when late is used for a value that could simply be nullable.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v4
///
/// Using `late` for optional values that might not be initialized is risky.
/// A nullable type with null checks is safer and more explicit.
///
/// Exempts `late final` fields with inline initializers, where `late`
/// provides lazy evaluation rather than deferred assignment.
///
/// **BAD:**
/// ```dart
/// class UserProfile {
///   late String? avatarUrl; // late for nullable is redundant
///   late User user; // Might never be set - crash risk
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserProfile {
///   String? avatarUrl; // Simply nullable
///   User? user; // Null-safe access
///   late final Stream<bool>? stream = _init(); // OK: lazy evaluation
/// }
/// ```
class AvoidLateForNullableRule extends SaropaLintRule {
  AvoidLateForNullableRule() : super(code: _code);

  /// Crash path - accessing before assignment throws LateInitializationError.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_late_for_nullable',
    '[avoid_late_for_nullable] Nullable type declared with late keyword. Since the type already accepts null, the late keyword adds no initialization safety and instead introduces a hidden crash path: accessing the variable before assignment throws LateInitializationError rather than returning null. {v4}',
    correctionMessage:
        'Remove the late keyword and rely on the nullable type (T?) with null checks. The variable will default to null until explicitly assigned, which is safer and more predictable.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      final VariableDeclarationList fields = node.fields;
      if (fields.lateKeyword == null) return;

      // Exempt: late final with inline initializer — late provides lazy
      // evaluation, not deferred assignment. No LateInitializationError risk.
      if (_allVariablesHaveInitializers(fields)) return;

      // Check if type is nullable
      final TypeAnnotation? typeAnnotation = fields.type;
      if (typeAnnotation == null) return;

      // Check outer type nullability via AST question token
      if (isOuterTypeNullable(typeAnnotation)) {
        reporter.atNode(node);
      }
    });

    context.addVariableDeclarationStatement((node) {
      final VariableDeclarationList variables = node.variables;
      if (variables.lateKeyword == null) return;

      // Exempt: late final with inline initializer
      if (_allVariablesHaveInitializers(variables)) return;

      final TypeAnnotation? typeAnnotation = variables.type;
      if (typeAnnotation == null) return;

      // Check outer type nullability via AST question token
      if (isOuterTypeNullable(typeAnnotation)) {
        for (final VariableDeclaration variable in variables.variables) {
          reporter.atNode(variable);
        }
      }
    });
  }
}

// =============================================================================
// prefer_late_lazy_initialization
// =============================================================================

/// Suggests late for expensive lazy initialization.
///
/// Eagerly initializing rarely-used fields wastes memory and startup time.
/// Use late for fields that are only used on certain code paths.
///
/// **Bad:** final heavy = Expensive(); at field level when rarely used.
///
/// **Good:** late final heavy = Expensive(); or initialize in method when needed.
class PreferLateLazyInitializationRule extends SaropaLintRule {
  PreferLateLazyInitializationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_late_lazy_initialization',
    '[prefer_late_lazy_initialization] Field has non-const constructor '
        'initializer. Consider late if this field is rarely used.',
    correctionMessage:
        'Use late for lazy initialization when the field is not always used.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      if (node.fields.isLate) return;
      if (node.fields.isConst) return;
      final TypeAnnotation? type = node.fields.type;
      if (type == null) return;
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? init = variable.initializer;
        if (init is! InstanceCreationExpression) continue;
        if (init.constructorName.type.typeArguments != null) continue;
        reporter.atNode(variable);
        return;
      }
    });
  }
}
