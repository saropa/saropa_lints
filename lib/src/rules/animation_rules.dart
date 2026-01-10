// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Animation lint rules for Flutter applications.
///
/// These rules help identify common animation issues including missing
/// dispose calls, vsync configuration problems, and Hero tag conflicts.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when AnimationController is created without vsync.
///
/// Alias: animation_controller_vsync, missing_vsync, no_vsync_parameter
///
/// AnimationController requires a TickerProvider (vsync) to function
/// correctly. Without it, animations may not sync with frame rendering
/// and can cause visual glitches.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late final _controller = AnimationController(
///     duration: Duration(seconds: 1),
///   ); // Missing vsync!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late final _controller = AnimationController(
///     duration: Duration(seconds: 1),
///     vsync: this,
///   );
/// }
/// ```
class RequireVsyncMixinRule extends SaropaLintRule {
  const RequireVsyncMixinRule() : super(code: _code);

  /// Missing vsync causes visual glitches and sync issues.
  /// Each occurrence is a bug that should be fixed.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_vsync_mixin',
    problemMessage: 'AnimationController created without vsync parameter.',
    correctionMessage:
        'Add vsync: this and use SingleTickerProviderStateMixin or TickerProviderStateMixin.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'AnimationController') return;

      bool hasVsync = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'vsync') {
          hasVsync = true;
          break;
        }
      }

      if (!hasVsync) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddVsyncFix()];
}

class _AddVsyncFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add vsync: this',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final ArgumentList args = node.argumentList;
        if (args.arguments.isEmpty) {
          builder.addSimpleInsertion(
            args.leftParenthesis.end,
            'vsync: this',
          );
        } else {
          builder.addSimpleInsertion(
            args.arguments.last.end,
            ', vsync: this',
          );
        }
      });
    });
  }
}

/// Warns when AnimationController is created inside build() method.
///
/// Alias: no_animation_controller_in_build, animation_controller_in_build_method
///
/// Creating AnimationController in build() creates a new controller on
/// every rebuild, wasting resources and causing animation issues.
/// Controllers should be created in initState() or as late final fields.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final controller = AnimationController(...);
///   return AnimatedWidget(animation: controller);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final AnimationController _controller;
///
/// @override
/// void initState() {
///   super.initState();
///   _controller = AnimationController(...);
/// }
/// ```
class AvoidAnimationInBuildRule extends SaropaLintRule {
  const AvoidAnimationInBuildRule() : super(code: _code);

  /// Creating controllers in build() causes resource leaks on every rebuild.
  /// Each occurrence is a memory leak bug.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_animation_in_build',
    problemMessage:
        'AnimationController created in build() is recreated on every rebuild.',
    correctionMessage:
        'Create AnimationController in initState() or as a late final field.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_AnimationControllerVisitor(reporter, code));
    });
  }
}

class _AnimationControllerVisitor extends RecursiveAstVisitor<void> {
  _AnimationControllerVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? typeName = node.constructorName.type.element?.name;
    if (typeName == 'AnimationController') {
      reporter.atNode(node, code);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when AnimationController is not disposed.
///
/// Alias: dispose_animation_controller, animation_controller_dispose, animation_controller_leak, require_animation_disposal
///
/// AnimationController holds native resources (a [Ticker]) that must be
/// explicitly released. Failing to dispose causes memory leaks and prevents
/// the widget from being garbage collected, as the Ticker maintains a
/// reference back to the State object.
///
/// ## Detection
///
/// This rule detects AnimationController fields in State classes by:
/// - Explicit type annotation containing `AnimationController`
/// - Instance creation expressions (`AnimationController(...)`)
///
/// ## Valid Disposal Patterns
///
/// The rule recognizes these disposal methods:
/// - `_controller.dispose()` - standard disposal
/// - `_controller?.dispose()` - null-safe disposal
/// - `_controller..dispose()` - cascade disposal
/// - `_controller.disposeSafe()` - safe disposal extension method
/// - `_controller?.disposeSafe()` - null-safe extension disposal
/// - `_controller..disposeSafe()` - cascade extension disposal
///
/// ## Excluded Types
///
/// Collections containing AnimationControllers are **not** flagged by this
/// rule, as they require loop-based disposal patterns:
/// - `List<AnimationController>` / `List<IconAnimationController>`
/// - `Set<AnimationController>`
/// - `Map<..., AnimationController>`
/// - `Iterable<AnimationController>`
///
/// For collections, dispose in a loop:
/// ```dart
/// for (final controller in _controllers) {
///   controller.dispose();
/// }
/// ```
///
/// ## Examples
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late final _controller = AnimationController(
///     vsync: this,
///     duration: Duration(seconds: 1),
///   );
///   // Missing dispose - memory leak!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late final _controller = AnimationController(
///     vsync: this,
///     duration: Duration(seconds: 1),
///   );
///
///   @override
///   void dispose() {
///     _controller.dispose(); // or _controller.disposeSafe()
///     super.dispose();
///   }
/// }
/// ```
class RequireAnimationControllerDisposeRule extends SaropaLintRule {
  const RequireAnimationControllerDisposeRule() : super(code: _code);

  /// Undisposed controllers cause memory leaks. Each occurrence leaks memory
  /// and prevents garbage collection. Even 1-2 is serious in production.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_animation_controller_dispose',
    problemMessage:
        'AnimationController is not disposed. This causes memory leaks.',
    correctionMessage:
        'Add _controller.dispose() in dispose() method before super.dispose().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find AnimationController fields with initializers
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            final String? typeName = member.fields.type?.toSource();
            if (typeName != null &&
                typeName.contains('AnimationController') &&
                !typeName.startsWith('List<') &&
                !typeName.startsWith('Set<') &&
                !typeName.startsWith('Map<') &&
                !typeName.startsWith('Iterable<')) {
              controllerNames.add(variable.name.lexeme);
              continue;
            }

            if (initializer is InstanceCreationExpression) {
              final String initType =
                  initializer.constructorName.type.name.lexeme;
              if (initType == 'AnimationController') {
                controllerNames.add(variable.name.lexeme);
              }
            }
          }
        }
      }

      if (controllerNames.isEmpty) return;

      // Find dispose method
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if controllers are disposed
      for (final String name in controllerNames) {
        final bool isDisposed = disposeBody != null &&
            (disposeBody.contains('$name.dispose(') ||
                disposeBody.contains('$name?.dispose(') ||
                disposeBody.contains('$name..dispose(') ||
                disposeBody.contains('$name.disposeSafe(') ||
                disposeBody.contains('$name?.disposeSafe(') ||
                disposeBody.contains('$name..disposeSafe('));

        if (!isDisposed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddAnimationControllerDisposeFix()];
}

class _AddAnimationControllerDisposeFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String fieldName = node.name.lexeme;

      // Find the containing class
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }
      if (current is! ClassDeclaration) return;

      final ClassDeclaration classNode = current;

      // Find existing dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod != null) {
        // Insert dispose() call before super.dispose()
        final String bodySource = disposeMethod.body.toSource();
        final int superDisposeIndex = bodySource.indexOf('super.dispose()');

        if (superDisposeIndex != -1) {
          final int bodyOffset = disposeMethod.body.offset;
          final int insertOffset = bodyOffset + superDisposeIndex;

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Add $fieldName.dispose()',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleInsertion(
              insertOffset,
              '$fieldName.dispose();\n    ',
            );
          });
        }
      } else {
        // Create new dispose method
        int insertOffset = classNode.rightBracket.offset;

        for (final ClassMember member in classNode.members) {
          if (member is FieldDeclaration || member is ConstructorDeclaration) {
            insertOffset = member.end;
          }
        }

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add dispose() method with $fieldName.dispose()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            insertOffset,
            '\n\n  @override\n  void dispose() {\n    $fieldName.dispose();\n    super.dispose();\n  }',
          );
        });
      }
    });
  }
}

/// Warns when duplicate Hero tags are found in the same file.
///
/// Alias: unique_hero_tag, duplicate_hero_tag, hero_tag_conflict
///
/// Hero widgets with the same tag cause "Multiple heroes" errors when
/// both are on screen during a navigation transition. Each Hero must
/// have a unique tag within the visible widget tree.
///
/// **BAD:**
/// ```dart
/// Hero(tag: 'profile', child: avatar1),
/// Hero(tag: 'profile', child: avatar2), // Same tag!
/// ```
///
/// **GOOD:**
/// ```dart
/// Hero(tag: 'profile-1', child: avatar1),
/// Hero(tag: 'profile-2', child: avatar2),
/// // Or use unique identifiers:
/// Hero(tag: 'profile-${user.id}', child: avatar),
/// ```
class RequireHeroTagUniquenessRule extends SaropaLintRule {
  const RequireHeroTagUniquenessRule() : super(code: _code);

  /// Duplicate Hero tags cause runtime crashes during navigation.
  /// Each occurrence is a crash waiting to happen.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_hero_tag_uniqueness',
    problemMessage:
        'Duplicate Hero tag found. This causes "Multiple heroes" error.',
    correctionMessage:
        'Use unique tags for each Hero widget, e.g., include IDs or indices.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Use CompilationUnit visitor to collect all Hero tags first, then report
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Map<String, List<AstNode>> heroTags = <String, List<AstNode>>{};

      unit.visitChildren(_HeroTagCollector(heroTags));

      // Report duplicates
      for (final MapEntry<String, List<AstNode>> entry in heroTags.entries) {
        if (entry.value.length > 1) {
          // Report all occurrences after the first
          for (int i = 1; i < entry.value.length; i++) {
            reporter.atNode(entry.value[i], code);
          }
        }
      }
    });
  }
}

class _HeroTagCollector extends RecursiveAstVisitor<void> {
  _HeroTagCollector(this.heroTags);

  final Map<String, List<AstNode>> heroTags;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? constructorName = node.constructorName.type.element?.name;
    if (constructorName == 'Hero') {
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'tag') {
          final Expression tagValue = arg.expression;

          if (tagValue is SimpleStringLiteral) {
            final String tagString = tagValue.value;
            heroTags.putIfAbsent(tagString, () => <AstNode>[]);
            heroTags[tagString]!.add(arg);
          }
          // Skip interpolations - can't reliably detect duplicates
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when IntrinsicWidth or IntrinsicHeight is used.
///
/// Alias: no_intrinsic_width, no_intrinsic_height, avoid_intrinsic_dimensions
///
/// IntrinsicWidth and IntrinsicHeight cause two layout passes, which
/// doubles the layout cost for their subtree. This can significantly
/// impact performance, especially in lists or frequently rebuilt widgets.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => IntrinsicHeight(
///     child: Row(...), // Two layout passes for every item!
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => Row(
///     crossAxisAlignment: CrossAxisAlignment.stretch,
///     children: [...],
///   ),
/// )
/// ```
class AvoidLayoutPassesRule extends SaropaLintRule {
  const AvoidLayoutPassesRule() : super(code: _code);

  /// Double layout passes hurt performance, especially in lists.
  /// A few is okay, but 10+ in hot paths causes noticeable jank.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_layout_passes',
    problemMessage:
        'IntrinsicWidth/Height causes two layout passes. This hurts performance.',
    correctionMessage:
        'Use CrossAxisAlignment.stretch, Expanded, or fixed dimensions instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'IntrinsicWidth' &&
          constructorName != 'IntrinsicHeight') {
        return;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when Duration uses hardcoded literal values instead of constants.
///
/// Alias: no_magic_duration, duration_constant, extract_duration
///
/// Hardcoded duration values make it difficult to maintain consistent
/// timing across the app. Define duration constants for reusability.
///
/// **BAD:**
/// ```dart
/// AnimationController(
///   duration: Duration(milliseconds: 300),
///   vsync: this,
/// );
/// Future.delayed(Duration(seconds: 2));
/// ```
///
/// **GOOD:**
/// ```dart
/// static const kAnimationDuration = Duration(milliseconds: 300);
///
/// AnimationController(
///   duration: kAnimationDuration,
///   vsync: this,
/// );
/// Future.delayed(kDelayDuration);
/// ```
class AvoidHardcodedDurationRule extends SaropaLintRule {
  const AvoidHardcodedDurationRule() : super(code: _code);

  /// Hardcoded durations affect maintainability, not correctness.
  /// 1000+ is fine in legacy code; enforce on new code only.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_duration',
    problemMessage:
        'Avoid hardcoded Duration values. Use named constants instead.',
    correctionMessage:
        'Extract Duration to a named constant for consistency and maintainability.',
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

      // Check if this is a const declaration (allowed)
      AstNode? current = node.parent;
      while (current != null) {
        if (current is VariableDeclaration) {
          final VariableDeclarationList? varList =
              current.parent as VariableDeclarationList?;
          if (varList != null && varList.isConst) {
            return; // This is a const declaration, allowed
          }
        }
        if (current is FieldDeclaration && current.isStatic) {
          return; // Static field declaration, likely a constant
        }
        current = current.parent;
      }

      // Check if arguments contain literal values
      bool hasLiteralArgs = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final Expression value = arg.expression;
          if (value is IntegerLiteral || value is DoubleLiteral) {
            hasLiteralArgs = true;
            break;
          }
        } else if (arg is IntegerLiteral || arg is DoubleLiteral) {
          hasLiteralArgs = true;
          break;
        }
      }

      if (hasLiteralArgs) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when animations don't specify a curve.
///
/// Alias: animation_curve, prefer_easing, missing_animation_curve
///
/// Linear animations (default) feel robotic and unnatural. Using curves
/// like easeInOut, bounceIn, or elasticOut creates more natural motion
/// that matches platform conventions.
///
/// **BAD:**
/// ```dart
/// AnimationController(
///   duration: Duration(milliseconds: 300),
///   vsync: this,
/// ); // Uses linear curve by default
///
/// Tween<double>(begin: 0, end: 1).animate(_controller);
/// ```
///
/// **GOOD:**
/// ```dart
/// CurvedAnimation(
///   parent: _controller,
///   curve: Curves.easeInOut,
/// );
///
/// Tween<double>(begin: 0, end: 1).animate(
///   CurvedAnimation(parent: _controller, curve: Curves.easeOut),
/// );
/// ```
class RequireAnimationCurveRule extends SaropaLintRule {
  const RequireAnimationCurveRule() : super(code: _code);

  /// Missing curves affect UX polish, not functionality.
  /// Address when improving animation quality; not urgent.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_animation_curve',
    problemMessage:
        'Animation uses default linear curve. Specify a curve for natural motion.',
    correctionMessage:
        'Wrap with CurvedAnimation or use .animate() with a curve parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Tween.animate() without curve
      if (node.methodName.name != 'animate') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check if target is a Tween
      final String targetSource = target.toSource();
      if (!targetSource.contains('Tween')) return;

      // Check if the argument is a CurvedAnimation or has curve
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        if (argSource.contains('CurvedAnimation') ||
            argSource.contains('curve:') ||
            argSource.contains('Curve')) {
          return; // Has a curve
        }
      }

      // If argument is just a controller reference without curve
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is SimpleIdentifier || firstArg is PrefixedIdentifier) {
          // Direct controller reference without CurvedAnimation
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when explicit AnimationController is used for simple transitions.
///
/// Alias: use_animated_widgets, prefer_animated_opacity, implicit_vs_explicit_animation
///
/// For simple animations (opacity, size, color), use implicit animations
/// like AnimatedOpacity, AnimatedContainer, etc. They're simpler and
/// handle disposal automatically.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late AnimationController _controller;
///   late Animation<double> _opacity;
///
///   @override
///   void initState() {
///     _controller = AnimationController(duration: Duration(ms: 300), vsync: this);
///     _opacity = Tween<double>(begin: 0, end: 1).animate(_controller);
///   }
///
///   Widget build(context) => FadeTransition(opacity: _opacity, child: child);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// AnimatedOpacity(
///   opacity: _isVisible ? 1.0 : 0.0,
///   duration: Duration(milliseconds: 300),
///   child: child,
/// )
/// ```
class PreferImplicitAnimationsRule extends SaropaLintRule {
  const PreferImplicitAnimationsRule() : super(code: _code);

  /// Code simplification suggestion. Explicit animations work fine.
  /// Address during refactoring; not a bug.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_implicit_animations',
    problemMessage:
        'Simple animation could use AnimatedOpacity, AnimatedContainer, etc.',
    correctionMessage:
        'Implicit animations are simpler and auto-dispose. Use for single-property changes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Transition widgets that have implicit equivalents
  static const Map<String, String> _transitionToImplicit = <String, String>{
    'FadeTransition': 'AnimatedOpacity',
    'SizeTransition': 'AnimatedSize',
    'ScaleTransition': 'AnimatedScale',
    'RotationTransition': 'AnimatedRotation',
    'SlideTransition': 'AnimatedSlide',
    'DecoratedBoxTransition': 'AnimatedContainer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track transitions per class to avoid O(n^2) complexity
    final Map<ClassDeclaration, int> transitionCounts =
        <ClassDeclaration, int>{};
    final List<_TransitionNode> pendingReports = <_TransitionNode>[];

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName == null) return;

      if (!_transitionToImplicit.containsKey(typeName)) return;

      // Find parent class
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }

      if (current is ClassDeclaration) {
        transitionCounts[current] = (transitionCounts[current] ?? 0) + 1;
        pendingReports.add(_TransitionNode(current, node));
      }
    });

    // Report only single-transition classes after all nodes are visited
    context.addPostRunCallback(() {
      for (final _TransitionNode item in pendingReports) {
        if (transitionCounts[item.classDecl] == 1) {
          reporter.atNode(item.node.constructorName, code);
        }
      }
    });
  }
}

class _TransitionNode {
  _TransitionNode(this.classDecl, this.node);
  final ClassDeclaration classDecl;
  final InstanceCreationExpression node;
}

/// Warns when list item animations don't use staggered delays.
///
/// Alias: stagger_list_animations, list_animation_delay, cascade_animation
///
/// Animating all list items at once looks jarring. Stagger animations
/// with Interval or increasing delays for a smoother cascade effect.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     return FadeTransition(
///       opacity: _animation, // Same animation for all items
///       child: ListTile(...),
///     );
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     final delay = index * 0.1;
///     final animation = CurvedAnimation(
///       parent: _controller,
///       curve: Interval(delay, delay + 0.3, curve: Curves.easeOut),
///     );
///     return FadeTransition(opacity: animation, child: ListTile(...));
///   },
/// )
/// ```
class RequireStaggeredAnimationDelaysRule extends SaropaLintRule {
  const RequireStaggeredAnimationDelaysRule() : super(code: _code);

  /// UX polish suggestion. Non-staggered animations work but look less polished.
  /// Address when improving animation quality; not urgent.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_staggered_animation_delays',
    problemMessage:
        'List item animations should be staggered for smooth cascade effect.',
    correctionMessage:
        'Use Interval with index-based delays: Interval(index * 0.1, ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _transitionWidgets = <String>{
    'FadeTransition',
    'SlideTransition',
    'ScaleTransition',
    'SizeTransition',
    'RotationTransition',
    'AnimatedBuilder',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'ListView' && typeName != 'GridView') return;

      // Check for itemBuilder
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'itemBuilder') {
          final String builderSource = arg.expression.toSource();

          // Check if builder contains transition widgets
          bool hasTransition = false;
          for (final String transition in _transitionWidgets) {
            if (builderSource.contains(transition)) {
              hasTransition = true;
              break;
            }
          }

          if (!hasTransition) return;

          // Check if using staggered animations
          final bool hasStagger = builderSource.contains('Interval') ||
              builderSource.contains('index *') ||
              builderSource.contains('index*') ||
              builderSource.contains('delay') ||
              builderSource.contains('stagger');

          if (!hasStagger) {
            reporter.atNode(arg.name, code);
          }
        }
      }
    });
  }
}

/// Warns when multiple chained animations could use TweenSequence.
///
/// Alias: chain_animations, sequential_animations, use_tween_sequence
///
/// Multiple sequential animations are harder to manage and can drift.
/// TweenSequence provides a single timeline with precise control.
///
/// **BAD:**
/// ```dart
/// _controller1.forward().then((_) {
///   _controller2.forward().then((_) {
///     _controller3.forward();
///   });
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// TweenSequence([
///   TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
///   TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 1),
///   TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0), weight: 1),
/// ]).animate(_controller);
/// ```
class PreferTweenSequenceRule extends SaropaLintRule {
  const PreferTweenSequenceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_tween_sequence',
    problemMessage: 'Multiple chained animations should use TweenSequence.',
    correctionMessage: 'Use TweenSequence for sequential animations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'then') return;

      // Check if called on .forward()
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;
      if (target.methodName.name != 'forward') return;

      // Check if the callback also calls forward
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression callback = args.arguments.first;
      if (callback is FunctionExpression) {
        final String bodySource = callback.body.toSource();
        if (bodySource.contains('.forward()')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when one-shot animation lacks StatusListener for cleanup.
///
/// Alias: animation_completion_listener, animation_status_callback, on_animation_complete
///
/// Animations that run once need to know when they complete for cleanup
/// or state updates. Use StatusListener to handle completion.
///
/// **BAD:**
/// ```dart
/// _controller.forward();
/// // How do we know when it's done?
/// ```
///
/// **GOOD:**
/// ```dart
/// _controller.addStatusListener((status) {
///   if (status == AnimationStatus.completed) {
///     setState(() => _showContent = true);
///   }
/// });
/// _controller.forward();
/// ```
class RequireAnimationStatusListenerRule extends SaropaLintRule {
  const RequireAnimationStatusListenerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_animation_status_listener',
    problemMessage:
        'One-shot animation should have StatusListener for completion.',
    correctionMessage: 'Add addStatusListener to handle animation completion.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track controllers and their listeners
    final Set<String> controllersWithListener = <String>{};
    final Map<String, MethodInvocation> forwardCalls =
        <String, MethodInvocation>{};

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'addStatusListener') {
        final Expression? target = node.target;
        if (target != null) {
          controllersWithListener.add(target.toSource());
        }
      }

      if (methodName == 'forward') {
        final Expression? target = node.target;
        if (target != null) {
          // Skip if using repeat (continuous animation)
          final String source = node.toSource();
          if (!source.contains('repeat')) {
            forwardCalls[target.toSource()] = node;
          }
        }
      }
    });

    context.addPostRunCallback(() {
      for (final MapEntry<String, MethodInvocation> entry
          in forwardCalls.entries) {
        if (!controllersWithListener.contains(entry.key)) {
          reporter.atNode(entry.value, code);
        }
      }
    });
  }
}

/// Warns when multiple animations target the same property.
///
/// Alias: conflicting_animations, duplicate_animation_property, animation_conflict
///
/// Overlapping animations on the same property fight each other,
/// causing jitter and unpredictable behavior.
///
/// **BAD:**
/// ```dart
/// ScaleTransition(
///   scale: _scaleAnimation,
///   child: ScaleTransition(
///     scale: _anotherScaleAnimation,  // Conflicts!
///     child: widget,
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ScaleTransition(
///   scale: _combinedScaleAnimation,  // Single animation
///   child: widget,
/// )
/// ```
class AvoidOverlappingAnimationsRule extends SaropaLintRule {
  const AvoidOverlappingAnimationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_overlapping_animations',
    problemMessage: 'Multiple animations on same property cause conflicts.',
    correctionMessage:
        'Combine into single animation or use different properties.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Map transition types to the property they animate
  static const Map<String, String> _transitionProperties = <String, String>{
    'ScaleTransition': 'scale',
    'FadeTransition': 'opacity',
    'SlideTransition': 'position',
    'RotationTransition': 'rotation',
    'SizeTransition': 'size',
  };

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
      if (!_transitionProperties.containsKey(typeName)) return;

      final String property = _transitionProperties[typeName]!;

      // Check if child is same type of transition
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression child = arg.expression;
          if (child is InstanceCreationExpression) {
            final String childTypeName = child.constructorName.type.name.lexeme;
            if (_transitionProperties[childTypeName] == property) {
              reporter.atNode(child.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when AnimatedBuilder wraps too much of the widget tree.
///
/// Alias: animated_builder_scope, minimize_animation_rebuild, animation_rebuild_scope
///
/// AnimatedBuilder rebuilds its entire child on every frame. Wrapping
/// large widget trees causes excessive rebuilds and poor performance.
///
/// **BAD:**
/// ```dart
/// AnimatedBuilder(
///   animation: _controller,
///   builder: (context, child) => Scaffold(
///     appBar: AppBar(...),
///     body: Column(
///       children: [
///         Transform.scale(scale: _controller.value, child: widget),
///         // Many other widgets that don't animate
///       ],
///     ),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(
///   appBar: AppBar(...),
///   body: Column(
///     children: [
///       AnimatedBuilder(
///         animation: _controller,
///         builder: (context, child) =>
///           Transform.scale(scale: _controller.value, child: child),
///         child: widget,  // Static child passed through
///       ),
///     ],
///   ),
/// )
/// ```
class AvoidAnimationRebuildWasteRule extends SaropaLintRule {
  const AvoidAnimationRebuildWasteRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_animation_rebuild_waste',
    problemMessage: 'AnimatedBuilder wraps too much of the widget tree.',
    correctionMessage: 'Move AnimatedBuilder closer to animated widgets only.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Large container widgets that shouldn't be inside AnimatedBuilder
  static const Set<String> _largeContainers = <String>{
    'Scaffold',
    'MaterialApp',
    'CupertinoApp',
    'Navigator',
    'TabBarView',
    'PageView',
  };

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
      if (typeName != 'AnimatedBuilder') return;

      // Check builder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();

          // Check if builder contains large containers
          for (final String container in _largeContainers) {
            if (builderSource.contains('$container(')) {
              reporter.atNode(node.constructorName, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when drag-release interaction doesn't use physics simulation.
///
/// Alias: spring_animation, natural_animation, use_spring_simulation
///
/// Abruptly stopping animations on release feels unnatural. Use spring
/// or friction physics for smooth deceleration.
///
/// **BAD:**
/// ```dart
/// onPanEnd: (details) {
///   _controller.animateTo(0.0);  // Abrupt stop
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onPanEnd: (details) {
///   final simulation = SpringSimulation(
///     SpringDescription.withDampingRatio(mass: 1, stiffness: 100),
///     _controller.value,
///     0.0,
///     details.velocity.pixelsPerSecond.dx,
///   );
///   _controller.animateWith(simulation);
/// }
/// ```
class PreferPhysicsSimulationRule extends SaropaLintRule {
  const PreferPhysicsSimulationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_physics_simulation',
    problemMessage:
        'Drag-release should use physics simulation for natural feel.',
    correctionMessage:
        'Use SpringSimulation or FrictionSimulation with animateWith.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      final String name = node.name.label.name;

      if (name != 'onPanEnd' && name != 'onDragEnd') return;

      final Expression callback = node.expression;
      if (callback is! FunctionExpression) return;

      final String bodySource = callback.body.toSource();

      // Check if using animateTo/animateBack without physics
      if (bodySource.contains('animateTo') ||
          bodySource.contains('animateBack')) {
        // OK if using physics simulation
        if (bodySource.contains('Simulation') ||
            bodySource.contains('animateWith') ||
            bodySource.contains('spring') ||
            bodySource.contains('Spring') ||
            bodySource.contains('friction') ||
            bodySource.contains('Friction')) {
          return;
        }

        reporter.atNode(node, code);
      }
    });
  }
}
