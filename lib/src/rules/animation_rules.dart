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
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v4
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_vsync_mixin',
    problemMessage:
        '[require_vsync_mixin] AnimationController is missing a vsync parameter. Without vsync, animations run without frame synchronization, causing visual tearing, wasted CPU cycles, and degraded user experience. This can lead to janky motion and battery drain, especially on mobile devices. Always provide vsync: this and mix in SingleTickerProviderStateMixin to ensure smooth, efficient animations and proper animation controller lifecycle management. {v4}',
    correctionMessage:
        'Add vsync: this and mix in SingleTickerProviderStateMixin to synchronize animation frames with the display refresh rate, preventing unnecessary CPU and memory usage.',
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
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_animation_in_build',
    problemMessage:
        '[avoid_animation_in_build] Creating an AnimationController inside the build() method causes a new controller to be instantiated on every widget rebuild, leading to severe memory leaks, degraded animation performance, and unpredictable UI behavior. Previous controllers are never disposed, which can crash your app or exhaust system resources. AnimationControllers must be long-lived and managed at the widget level, not recreated per frame. This is a critical resource management issue in Flutter. {v2}',
    correctionMessage:
        'Always create AnimationController instances in initState() and store them as fields in your State class. Dispose of them in the dispose() method to release resources and prevent leaks. Audit your codebase for AnimationController usage and refactor any controllers created in build() to follow this pattern. See Flutter documentation for best practices on animation lifecycle management.',
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
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: dispose_animation_controller, animation_controller_dispose, animation_controller_leak, require_animation_disposal
///
/// AnimationController holds native resources (a `Ticker`) that must be
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_animation_controller_dispose',
    problemMessage:
        '[require_animation_controller_dispose] Neglecting to dispose of an AnimationController when a widget is removed from the tree causes memory leaks and can lead to performance degradation, as the controller continues to consume resources and tick animations in the background. This can eventually crash your app or cause unexpected behavior. Always dispose of AnimationControllers to maintain optimal app performance. See https://api.flutter.dev/flutter/animation/AnimationController/dispose.html. {v2}',
    correctionMessage:
        'Call dispose on your AnimationController in the widget’s dispose method to release resources and prevent memory leaks. This is a core Flutter best practice for managing animation lifecycles. See https://api.flutter.dev/flutter/animation/AnimationController/dispose.html for details.',
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
                (typeName == 'AnimationController' ||
                    typeName == 'AnimationController?') &&
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
            RegExp(
              '${RegExp.escape(name)}\\s*[?.]+'
              '\\s*dispose(Safe)?\\s*\\(',
            ).hasMatch(disposeBody);

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
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v3
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hero_tag_uniqueness',
    problemMessage:
        '[require_hero_tag_uniqueness] Using duplicate Hero tags within the same navigation context causes Hero animations to fail, resulting in visual glitches and confusing user experiences. This can break navigation transitions and reduce the perceived quality of your app. Ensure each Hero tag is unique within a given Navigator to maintain smooth and predictable animations. See https://docs.flutter.dev/ui/animations/hero-animations#the-hero-tag. {v3}',
    correctionMessage:
        'Assign unique tags to each Hero widget within the same navigation context to guarantee correct animation behavior and prevent transition errors. Refer to https://docs.flutter.dev/ui/animations/hero-animations#the-hero-tag for best practices.',
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
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_layout_passes',
    problemMessage:
        '[avoid_layout_passes] Using IntrinsicWidth or IntrinsicHeight causes Flutter to perform two layout passes for affected child widgets in the build tree, which significantly hurts performance, especially in complex UIs or lists. This can lead to dropped frames, laggy animations, and poor user experience. Prefer using CrossAxisAlignment.stretch, Expanded, or fixed dimensions to avoid extra layout computation. {v2}',
    correctionMessage:
        'Replace IntrinsicWidth/IntrinsicHeight with CrossAxisAlignment.stretch, Expanded, or fixed dimensions to eliminate the extra layout pass in the build tree.',
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
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_duration',
    problemMessage:
        '[avoid_hardcoded_duration] Hardcoded Duration values make it difficult to maintain consistent timing across the app and can lead to subtle bugs when timings need to be updated globally. This practice reduces maintainability and increases the risk of inconsistent user experiences. Always extract Duration values to named constants for clarity, reusability, and easier updates. {v2}',
    correctionMessage:
        'Extract Duration to a named constant for consistency and maintainability. Test on a low-end device to confirm smooth rendering after the fix.',
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
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_animation_curve',
    problemMessage:
        '[require_animation_curve] Animation uses the default linear curve, which often results in unnatural or robotic motion. Without specifying a curve, transitions may feel abrupt and lack the smoothness users expect. Always wrap with CurvedAnimation or use .animate() with a curve parameter to create more natural, visually appealing animations that enhance user experience. {v2}',
    correctionMessage:
        'Wrap with CurvedAnimation or use .animate() with a curve parameter. Test on a low-end device to confirm smooth rendering after the fix.',
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
      if (!targetSource.endsWith('Tween')) return;

      // Check if the argument is a CurvedAnimation or has curve parameter
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'curve') {
          return; // Has a curve parameter
        }
        final String argSource = arg.toSource();
        if (argSource.endsWith('CurvedAnimation') ||
            argSource.startsWith('CurvedAnimation')) {
          return; // Using CurvedAnimation
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
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_implicit_animations',
    problemMessage:
        '[prefer_implicit_animations] Simple animations such as opacity, size, or color changes are implemented with explicit AnimationController and transition widgets. This adds unnecessary complexity and increases the risk of memory leaks if disposal is missed. Prefer using implicit animation widgets like AnimatedOpacity or AnimatedContainer, which are simpler, auto-dispose, and improve code maintainability and reliability. {v2}',
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
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_staggered_animation_delays',
    problemMessage:
        '[require_staggered_animation_delays] List item animations are not staggered, resulting in all items animating simultaneously. This creates a chaotic and unnatural cascade effect, making it hard for users to follow the UI changes. Use index-based delays (e.g., Interval(index * 0.1, ..)) to stagger animations for a smooth, visually appealing transition. {v2}',
    correctionMessage:
        'Use Interval with index-based delays: Interval(index * 0.1, ..). Test on a low-end device to confirm smooth rendering after the fix.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_tween_sequence',
    problemMessage:
        '[prefer_tween_sequence] Multiple chained animations are implemented without using TweenSequence, which can lead to complex, error-prone code and unpredictable animation timing. TweenSequence simplifies sequential animations, making them easier to manage and ensuring smooth transitions. Use TweenSequence for sequential property changes to improve maintainability and user experience. {v2}',
    correctionMessage:
        'Use TweenSequence for sequential animations. Test on a low-end device to confirm smooth rendering after the fix.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: animation_completion_listener, animation_status_callback, on_animation_complete, prefer_animation_status_listener
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_animation_status_listener',
    problemMessage:
        '[require_animation_status_listener] AnimationController.forward() called without addStatusListener to detect completion. The animation will run but your application cannot respond when it finishes, preventing cleanup, sequencing, or triggering follow-up actions. {v2}',
    correctionMessage:
        'Add controller.addStatusListener and check for AnimationStatus.completed or AnimationStatus.dismissed to execute code when the animation finishes, enabling proper resource management and action sequencing.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: conflicting_animations, duplicate_animation_property, animation_conflict
///
/// Overlapping animations on the same property fight each other,
/// causing jitter and unpredictable behavior. This rule detects nested
/// transition widgets that animate the same property:
/// - `ScaleTransition` → scale
/// - `FadeTransition` → opacity
/// - `SlideTransition` → position
/// - `RotationTransition` → rotation
/// - `SizeTransition` → size (axis-aware: vertical = height, horizontal = width)
///
/// **BAD:** Nested transitions animating the same property
/// ```dart
/// ScaleTransition(
///   scale: _scaleAnimation,
///   child: ScaleTransition(
///     scale: _anotherScaleAnimation,  // Conflicts on 'scale'!
///     child: widget,
///   ),
/// )
/// ```
///
/// **BAD:** SizeTransition with same axis
/// ```dart
/// SizeTransition(
///   sizeFactor: _animation,
///   axis: Axis.vertical,
///   child: SizeTransition(
///     sizeFactor: _anotherAnimation,
///     axis: Axis.vertical,  // Same axis = conflict on height!
///     child: widget,
///   ),
/// )
/// ```
///
/// **GOOD:** Combine into single animation
/// ```dart
/// ScaleTransition(
///   scale: _combinedScaleAnimation,  // Single animation
///   child: widget,
/// )
/// ```
///
/// **GOOD:** SizeTransition on different axes (no conflict)
/// ```dart
/// SizeTransition(
///   sizeFactor: _animation,
///   axis: Axis.vertical,  // Animates HEIGHT
///   child: SizeTransition(
///     sizeFactor: _animation,
///     axis: Axis.horizontal,  // Animates WIDTH - different property!
///     child: widget,
///   ),
/// )
/// ```
///
/// **GOOD:** Different transition types (no conflict)
/// ```dart
/// ScaleTransition(
///   scale: _scaleAnimation,
///   child: FadeTransition(
///     opacity: _fadeAnimation,  // Different property
///     child: widget,
///   ),
/// )
/// ```
class AvoidOverlappingAnimationsRule extends SaropaLintRule {
  const AvoidOverlappingAnimationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresWidgets => true;

  @override
  Set<String>? get requiredPatterns => const <String>{
        'ScaleTransition',
        'FadeTransition',
        'SlideTransition',
        'RotationTransition',
        'SizeTransition',
      };

  static const LintCode _code = LintCode(
    name: 'avoid_overlapping_animations',
    problemMessage:
        '[avoid_overlapping_animations] Multiple animations targeting the same property (e.g., opacity, position, scale) at the same time cause visual jitter, unpredictable results, and confusing UI behavior. Overlapping animations can make transitions hard to follow and degrade user experience, especially for users with cognitive or visual disabilities. {v4}',
    correctionMessage:
        'Refactor your code to combine overlapping animations into a single AnimationController, or animate different properties separately. Audit your widget tree for conflicting animations and document animation best practices for your team.',
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

  /// Gets the effective property being animated, accounting for axis.
  ///
  /// For [SizeTransition], the axis determines whether width or height is
  /// animated - these are different properties and should not conflict.
  static String? _getEffectiveProperty(
    String typeName,
    InstanceCreationExpression node,
  ) {
    if (!_transitionProperties.containsKey(typeName)) return null;

    // SizeTransition needs special handling based on axis
    if (typeName == 'SizeTransition') {
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'axis') {
          final String axisValue = arg.expression.toSource();
          if (axisValue.contains('horizontal')) {
            return 'size_horizontal';
          }
        }
      }
      // Default axis is vertical
      return 'size_vertical';
    }

    return _transitionProperties[typeName];
  }

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
      final String? property = _getEffectiveProperty(typeName, node);
      if (property == null) return;

      // Check if child is same type of transition with same effective property
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression child = arg.expression;
          if (child is InstanceCreationExpression) {
            final String childTypeName = child.constructorName.type.name.lexeme;
            final String? childProperty =
                _getEffectiveProperty(childTypeName, child);
            if (childProperty == property) {
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_animation_rebuild_waste',
    problemMessage:
        '[avoid_animation_rebuild_waste] AnimatedBuilder wraps too much of the widget tree, causing unnecessary rebuilds and wasted CPU cycles. This can degrade animation performance, increase battery usage, and make your app feel sluggish, especially on lower-end devices. {v3}',
    correctionMessage:
        'Move AnimatedBuilder as close as possible to the widgets that actually change during the animation. Avoid wrapping large containers or static content. Audit your widget tree for excessive rebuilds and educate your team on animation performance best practices.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_physics_simulation',
    problemMessage:
        '[prefer_physics_simulation] Drag-release should use physics simulation for natural feel. Abruptly stopping animations on release feels unnatural. Use spring or friction physics for smooth deceleration. {v2}',
    correctionMessage:
        'Use SpringSimulation or FrictionSimulation with animateWith. Test on a low-end device to confirm smooth rendering after the fix.',
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

// =============================================================================
// Ticker Disposal Rules
// =============================================================================

/// Warns when Ticker is created without stop() in dispose.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: ticker_dispose, ticker_stop, ticker_leak
///
/// Ticker objects created directly (not via AnimationController) must be
/// explicitly stopped in dispose(). Failing to stop a Ticker causes memory
/// leaks and can cause "Ticker was not disposed" errors.
///
/// Note: Most Flutter apps use AnimationController which manages its own
/// Ticker internally. This rule targets cases where Ticker is used directly.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late Ticker _ticker;
///
///   @override
///   void initState() {
///     super.initState();
///     _ticker = createTicker((elapsed) {
///       // Frame callback
///     });
///     _ticker.start();
///   }
///   // Missing stop() in dispose - memory leak!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late Ticker _ticker;
///
///   @override
///   void initState() {
///     super.initState();
///     _ticker = createTicker((elapsed) {
///       // Frame callback
///     });
///     _ticker.start();
///   }
///
///   @override
///   void dispose() {
///     _ticker.stop();
///     super.dispose();
///   }
/// }
/// ```
class RequireAnimationTickerDisposalRule extends SaropaLintRule {
  const RequireAnimationTickerDisposalRule() : super(code: _code);

  /// Ticker leaks cause memory issues and error messages.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_animation_ticker_disposal',
    problemMessage:
        '[require_animation_ticker_disposal] If you do not stop your Ticker in dispose(), it will continue running and leak memory, causing slowdowns and error messages. This can degrade performance and lead to crashes in long-running apps. {v2}',
    correctionMessage:
        'Always call _ticker.stop() in dispose() before super.dispose() to safely release resources and prevent memory leaks.',
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

      // Find Ticker fields
      final List<String> tickerFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null &&
              (typeName == 'Ticker' || typeName == 'Ticker?')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              tickerFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (tickerFields.isEmpty) return;

      // Find dispose method and check for stop calls
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Report tickers not stopped in dispose
      for (final String fieldName in tickerFields) {
        final bool isStopped = disposeBody != null &&
            RegExp(
              '${RegExp.escape(fieldName)}\\s*[?.]+'
              '\\s*(stop|dispose)\\s*\\(\\)',
            ).hasMatch(disposeBody);

        if (!isStopped) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable, code);
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
// Spring Animation Preference Rules
// =============================================================================

/// Suggests using SpringSimulation instead of CurvedAnimation for
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// physics-based interactions like drag, fling, and bounce gestures.
///
/// Spring-based animations feel more natural because they model real-world
/// physics. CurvedAnimation uses fixed duration and easing which can feel
/// artificial for interactive gestures.
///
/// **BAD:**
/// ```dart
/// final animation = CurvedAnimation(
///   parent: controller,
///   curve: Curves.bounceOut,
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final spring = SpringDescription(mass: 1, stiffness: 100, damping: 10);
/// controller.animateWith(SpringSimulation(spring, 0, 1, velocity));
/// ```
class PreferSpringAnimationRule extends SaropaLintRule {
  const PreferSpringAnimationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_spring_animation',
    problemMessage:
        '[prefer_spring_animation] CurvedAnimation with a physics-like curve (bounceOut, elasticOut, bounceIn, elasticIn, etc.) is being used where a SpringSimulation would produce smoother, more natural-feeling motion. CurvedAnimation uses a fixed duration that cannot respond to user input velocity, causing disconnects between gesture speed and animation behavior that feel artificial and jarring to users. {v2}',
    correctionMessage:
        'Consider using SpringSimulation with SpringDescription for physics-based animations, especially for gestures like drag, fling, and bounce where animation should respond to input velocity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Curves that mimic physics and are better served by SpringSimulation.
  static const Set<String> _physicsLikeCurves = <String>{
    'bounceOut',
    'bounceIn',
    'bounceInOut',
    'elasticOut',
    'elasticIn',
    'elasticInOut',
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
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'CurvedAnimation') return;

      // Check if the curve argument is a physics-like curve
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'curve') {
          final String curveSource = arg.expression.toSource();
          for (final String physicsCurve in _physicsLikeCurves) {
            if (curveSource.contains(physicsCurve)) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_SuggestSpringSimulationFix()];
}

class _SuggestSpringSimulationFix extends DartFix {
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

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO: consider SpringSimulation for natural physics',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: consider SpringSimulation for natural physics-based motion */ ',
        );
      });
    });
  }
}
