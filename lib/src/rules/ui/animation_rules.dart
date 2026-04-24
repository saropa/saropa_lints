// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Animation lint rules for Flutter applications.
///
/// These rules help identify common animation issues including missing
/// dispose calls, vsync configuration problems, and Hero tag conflicts.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../fixes/animation/prefer_animation_controller_forward_from_zero_fix.dart';
import '../../fixes/animation/prefer_listenable_builder_fix.dart';
import '../../fixes/animation/prefer_single_ticker_provider_state_mixin_fix.dart';
import '../../fixes/animation/remove_redundant_implicit_animation_dispose_fix.dart';
import '../../implicit_animation_dispose_cast_ast.dart';
import '../../saropa_lint_rule.dart';
import '../../target_matcher_utils.dart';

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
  RequireVsyncMixinRule() : super(code: _code);

  /// Missing vsync causes visual glitches and sync issues.
  /// Each occurrence is a bug that should be fixed.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_vsync_mixin',
    '[require_vsync_mixin] AnimationController is missing a vsync parameter. Without vsync, animations run without frame synchronization, causing visual tearing, wasted CPU cycles, and degraded user experience. This can lead to janky motion and battery drain, especially on mobile devices. Always provide vsync: this and mix in SingleTickerProviderStateMixin to ensure smooth, efficient animations and proper animation controller lifecycle management. {v4}',
    correctionMessage:
        'Add vsync: this and mix in SingleTickerProviderStateMixin to synchronize animation frames with the display refresh rate, preventing unnecessary CPU and memory usage.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
  AvoidAnimationInBuildRule() : super(code: _code);

  /// Creating controllers in build() causes resource leaks on every rebuild.
  /// Each occurrence is a memory leak bug.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_animation_in_build',
    '[avoid_animation_in_build] Creating an AnimationController inside the build() method causes a new controller to be instantiated on every widget rebuild, leading to severe memory leaks, degraded animation performance, and unpredictable UI behavior. Previous controllers are never disposed, which can crash your app or exhaust system resources. AnimationControllers must be long-lived and managed at the widget level, not recreated per frame. This is a critical resource management issue in Flutter. {v2}',
    correctionMessage:
        'Always create AnimationController instances in initState() and store them as fields in your State class. Dispose of them in the dispose() method to release resources and prevent leaks. Audit your codebase for AnimationController usage and refactor any controllers created in build() to follow this pattern. See Flutter documentation for best practices on animation lifecycle management.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
      reporter.atNode(node);
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
  RequireAnimationControllerDisposeRule() : super(code: _code);

  /// Undisposed controllers cause memory leaks. Each occurrence leaks memory
  /// and prevents garbage collection. Even 1-2 is serious in production.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_animation_controller_dispose',
    '[require_animation_controller_dispose] Neglecting to dispose of an AnimationController when a widget is removed from the tree causes memory leaks and can lead to performance degradation, as the controller continues to consume resources and tick animations in the background. This can eventually crash your app or cause unexpected behavior. Always dispose of AnimationControllers to maintain optimal app performance. See https://api.flutter.dev/flutter/animation/AnimationController/dispose.html. {v2}',
    correctionMessage:
        'Call dispose on your AnimationController in the widget’s dispose method to release resources and prevent memory leaks. This is a core Flutter best practice for managing animation lifecycles. See https://api.flutter.dev/flutter/animation/AnimationController/dispose.html for details.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find AnimationController fields with initializers
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.body.members) {
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

      // Find dispose method body for isFieldCleanedUp checks
      FunctionBody? disposeMethodBody;
      for (final ClassMember member in node.body.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethodBody = member.body;
          break;
        }
      }

      // Check if controllers are disposed
      for (final String name in controllerNames) {
        final bool isDisposed =
            disposeMethodBody != null &&
            isFieldCleanedUp(name, 'dispose', disposeMethodBody);

        if (!isDisposed) {
          for (final ClassMember member in node.body.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable);
                }
              }
            }
          }
        }
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
  RequireHeroTagUniquenessRule() : super(code: _code);

  /// Duplicate Hero tags cause runtime crashes during navigation.
  /// Each occurrence is a crash waiting to happen.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_hero_tag_uniqueness',
    '[require_hero_tag_uniqueness] Using duplicate Hero tags within the same navigation context causes Hero animations to fail, resulting in visual glitches and confusing user experiences. This can break navigation transitions and reduce the perceived quality of your app. Ensure each Hero tag is unique within a given Navigator to maintain smooth and predictable animations. See https://docs.flutter.dev/ui/animations/hero-animations#the-hero-tag. {v3}',
    correctionMessage:
        'Assign unique tags to each Hero widget within the same navigation context to guarantee correct animation behavior and prevent transition errors. Refer to https://docs.flutter.dev/ui/animations/hero-animations#the-hero-tag for best practices.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Use CompilationUnit visitor to collect all Hero tags first, then report
    context.addCompilationUnit((CompilationUnit unit) {
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
            final list = heroTags[tagString];
            if (list != null) list.add(arg);
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
  AvoidLayoutPassesRule() : super(code: _code);

  /// Double layout passes hurt performance, especially in lists.
  /// A few is okay, but 10+ in hot paths causes noticeable jank.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_layout_passes',
    '[avoid_layout_passes] Using IntrinsicWidth or IntrinsicHeight causes Flutter to perform two layout passes for affected child widgets in the build tree, which significantly hurts performance, especially in complex UIs or lists. This can lead to dropped frames, laggy animations, and poor user experience. Prefer using CrossAxisAlignment.stretch, Expanded, or fixed dimensions to avoid extra layout computation. {v2}',
    correctionMessage:
        'Replace IntrinsicWidth/IntrinsicHeight with CrossAxisAlignment.stretch, Expanded, or fixed dimensions to eliminate the extra layout pass in the build tree.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
  AvoidHardcodedDurationRule() : super(code: _code);

  /// Hardcoded durations affect maintainability, not correctness.
  /// 1000+ is fine in legacy code; enforce on new code only.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_hardcoded_duration',
    '[avoid_hardcoded_duration] Hardcoded Duration values make it difficult to maintain consistent timing across the app and can lead to subtle bugs when timings need to be updated globally. This practice reduces maintainability and increases the risk of inconsistent user experiences. Always extract Duration values to named constants for clarity, reusability, and easier updates. {v2}',
    correctionMessage:
        'Extract Duration to a named constant for consistency and maintainability. Test on a low-end device to confirm smooth rendering after the fix.',
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
        reporter.atNode(node);
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
  RequireAnimationCurveRule() : super(code: _code);

  /// Missing curves affect UX polish, not functionality.
  /// Address when improving animation quality; not urgent.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_animation_curve',
    '[require_animation_curve] Animation uses the default linear curve, which often results in unnatural or robotic motion. Without specifying a curve, transitions may feel abrupt and lack the smoothness users expect. Always wrap with CurvedAnimation or use .animate() with a curve parameter to create more natural, visually appealing animations that enhance user experience. {v2}',
    correctionMessage:
        'Wrap with CurvedAnimation or use .animate() with a curve parameter. Test on a low-end device to confirm smooth rendering after the fix.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
          reporter.atNode(node);
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
  PreferImplicitAnimationsRule() : super(code: _code);

  /// Code simplification suggestion. Explicit animations work fine.
  /// Address during refactoring; not a bug.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_implicit_animations',
    '[prefer_implicit_animations] Simple animations such as opacity, size, or color changes are implemented with explicit AnimationController and transition widgets. This adds unnecessary complexity and increases the risk of memory leaks if disposal is missed. Prefer using implicit animation widgets like AnimatedOpacity or AnimatedContainer, which are simpler, auto-dispose, and improve code maintainability and reliability. {v2}',
    correctionMessage:
        'Implicit animations are simpler and auto-dispose. Use for single-property changes.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track transitions per class to avoid O(n^2) complexity
    final Map<ClassDeclaration, int> transitionCounts =
        <ClassDeclaration, int>{};
    final List<_TransitionNode> pendingReports = <_TransitionNode>[];

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
  RequireStaggeredAnimationDelaysRule() : super(code: _code);

  /// UX polish suggestion. Non-staggered animations work but look less polished.
  /// Address when improving animation quality; not urgent.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_staggered_animation_delays',
    '[require_staggered_animation_delays] List item animations are not staggered, resulting in all items animating simultaneously. This creates a chaotic and unnatural cascade effect, making it hard for users to follow the UI changes. Use index-based delays (e.g., Interval(index * 0.1, ..)) to stagger animations for a smooth, visually appealing transition. {v2}',
    correctionMessage:
        'Use Interval with index-based delays: Interval(index * 0.1, ..). Test on a low-end device to confirm smooth rendering after the fix.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
          final bool hasStagger =
              builderSource.contains('Interval') ||
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
  PreferTweenSequenceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_tween_sequence',
    '[prefer_tween_sequence] Multiple chained animations are implemented without using TweenSequence, which can lead to complex, error-prone code and unpredictable animation timing. TweenSequence simplifies sequential animations, making them easier to manage and ensuring smooth transitions. Use TweenSequence for sequential property changes to improve maintainability and user experience. {v2}',
    correctionMessage:
        'Use TweenSequence for sequential animations. Test on a low-end device to confirm smooth rendering after the fix.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _forwardCallPattern = RegExp(r'\.forward\s*\(\s*\)');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'then') return;

      final Expression? target = node.target;
      if (target is! MethodInvocation) return;
      if (target.methodName.name != 'forward') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression callback = args.arguments.first;
      if (callback is FunctionExpression) {
        final String bodySource = callback.body.toSource();
        if (_forwardCallPattern.hasMatch(bodySource)) {
          reporter.atNode(node);
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
  RequireAnimationStatusListenerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_animation_status_listener',
    '[require_animation_status_listener] AnimationController.forward() called without addStatusListener to detect completion. The animation will run but your application cannot respond when it finishes, preventing cleanup, sequencing, or triggering follow-up actions. {v2}',
    correctionMessage:
        'Add controller.addStatusListener and check for AnimationStatus.completed or AnimationStatus.dismissed to execute code when the animation finishes, enabling proper resource management and action sequencing.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track controllers and their listeners
    final Set<String> controllersWithListener = <String>{};
    final Map<String, MethodInvocation> forwardCalls =
        <String, MethodInvocation>{};

    context.addMethodInvocation((MethodInvocation node) {
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
          final String nodeSource = node.toSource();
          if (!RegExp(r'\brepeat\b').hasMatch(nodeSource)) {
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
  AvoidOverlappingAnimationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

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
    'avoid_overlapping_animations',
    '[avoid_overlapping_animations] Multiple animations targeting the same property (e.g., opacity, position, scale) at the same time cause visual jitter, unpredictable results, and confusing UI behavior. Overlapping animations can make transitions hard to follow and degrade user experience, especially for users with cognitive or visual disabilities. {v4}',
    correctionMessage:
        'Refactor your code to combine overlapping animations into a single AnimationController, or animate different properties separately. Audit your widget tree for conflicting animations and document animation best practices for your team.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      final String? property = _getEffectiveProperty(typeName, node);
      if (property == null) return;

      // Check if child is same type of transition with same effective property
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression child = arg.expression;
          if (child is InstanceCreationExpression) {
            final String childTypeName = child.constructorName.type.name.lexeme;
            final String? childProperty = _getEffectiveProperty(
              childTypeName,
              child,
            );
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
  AvoidAnimationRebuildWasteRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_animation_rebuild_waste',
    '[avoid_animation_rebuild_waste] AnimatedBuilder wraps too much of the widget tree, causing unnecessary rebuilds and wasted CPU cycles. This can degrade animation performance, increase battery usage, and make your app feel sluggish, especially on lower-end devices. {v3}',
    correctionMessage:
        'Move AnimatedBuilder as close as possible to the widgets that actually change during the animation. Avoid wrapping large containers or static content. Audit your widget tree for excessive rebuilds and educate your team on animation performance best practices.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
  PreferPhysicsSimulationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_physics_simulation',
    '[prefer_physics_simulation] Drag-release should use physics simulation for natural feel. Abruptly stopping animations on release feels unnatural. Use spring or friction physics for smooth deceleration. {v2}',
    correctionMessage:
        'Use SpringSimulation or FrictionSimulation with animateWith. Test on a low-end device to confirm smooth rendering after the fix.',
    severity: DiagnosticSeverity.INFO,
  );

  static final List<RegExp> _animateToBackPatterns = <RegExp>[
    RegExp(r'\banimateTo\b'),
    RegExp(r'\banimateBack\b'),
  ];
  static final List<RegExp> _physicsPatterns = <RegExp>[
    RegExp(r'\bSimulation\b'),
    RegExp(r'\banimateWith\b'),
    RegExp(r'\bspring\b'),
    RegExp(r'\bSpring\b'),
    RegExp(r'\bfriction\b'),
    RegExp(r'\bFriction\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      final String name = node.name.label.name;

      if (name != 'onPanEnd' && name != 'onDragEnd') return;

      final Expression callback = node.expression;
      if (callback is! FunctionExpression) return;

      final String bodySource = callback.body.toSource();

      if (!_animateToBackPatterns.any((re) => re.hasMatch(bodySource))) return;

      if (_physicsPatterns.any((re) => re.hasMatch(bodySource))) return;

      reporter.atNode(node);
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
  RequireAnimationTickerDisposalRule() : super(code: _code);

  /// Ticker leaks cause memory issues and error messages.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_animation_ticker_disposal',
    '[require_animation_ticker_disposal] If you do not stop your Ticker in dispose(), it will continue running and leak memory, causing slowdowns and error messages. This can degrade performance and lead to crashes in long-running apps. {v2}',
    correctionMessage:
        'Always call _ticker.stop() in dispose() before super.dispose() to safely release resources and prevent memory leaks.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find Ticker fields
      final List<String> tickerFields = <String>[];
      for (final ClassMember member in node.body.members) {
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
      for (final ClassMember member in node.body.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Report tickers not stopped in dispose (RegExp built once per field)
      final stopRegexByField = <String, RegExp>{
        for (final String f in tickerFields)
          f: RegExp(
            '${RegExp.escape(f)}\\s*[?.]+'
            '\\s*(stop|dispose)\\s*\\(\\)',
          ),
      };
      for (final String fieldName in tickerFields) {
        final re = stopRegexByField[fieldName];
        if (re == null) continue;
        final bool isStopped = disposeBody != null && re.hasMatch(disposeBody);

        if (!isStopped) {
          for (final ClassMember member in node.body.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable);
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
  PreferSpringAnimationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_spring_animation',
    '[prefer_spring_animation] CurvedAnimation with a physics-like curve (bounceOut, elasticOut, bounceIn, elasticIn, etc.) is being used where a SpringSimulation would produce smoother, more natural-feeling motion. CurvedAnimation uses a fixed duration that cannot respond to user input velocity, causing disconnects between gesture speed and animation behavior that feel artificial and jarring to users. {v2}',
    correctionMessage:
        'Consider using SpringSimulation with SpringDescription for physics-based animations, especially for gestures like drag, fling, and bounce where animation should respond to input velocity.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'CurvedAnimation') return;

      // Check if the curve argument is a physics-like curve
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'curve') {
          final String curveSource = arg.expression.toSource();
          for (final String physicsCurve in _physicsLikeCurves) {
            if (curveSource.contains(physicsCurve)) {
              reporter.atNode(node);
              return;
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// avoid_excessive_rebuilds_animation
// =============================================================================

/// Warns when animation builder callbacks contain too many widgets.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Alias: animation_builder_too_large, excessive_animation_rebuilds
///
/// Animation builder callbacks (AnimatedBuilder, ValueListenableBuilder,
/// StreamBuilder, etc.) run on every frame or value change. Placing too
/// many widget constructors inside the builder wastes CPU rebuilding
/// static content that could be passed via the `child` parameter.
///
/// **BAD:**
/// ```dart
/// AnimatedBuilder(
///   animation: _controller,
///   builder: (context, child) {
///     return Column(
///       children: [
///         AppBar(title: Text('Title')),
///         Text('Static'),
///         Icon(Icons.star),
///         Container(color: Colors.blue),
///         Opacity(opacity: _controller.value, child: child),
///       ],
///     );
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// AnimatedBuilder(
///   animation: _controller,
///   child: Column(children: [Text('Static'), Icon(Icons.star)]),
///   builder: (context, child) {
///     return Opacity(opacity: _controller.value, child: child);
///   },
/// )
/// ```
class AvoidExcessiveRebuildsAnimationRule extends SaropaLintRule {
  AvoidExcessiveRebuildsAnimationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_excessive_rebuilds_animation',
    '[avoid_excessive_rebuilds_animation] The builder callback of this '
        'animation widget contains too many widget constructors, causing the '
        'entire subtree to rebuild on every animation frame (typically 60 '
        'times per second). This wastes CPU cycles, increases battery drain, '
        'and degrades animation smoothness. Only widgets that actually change '
        'during the animation should be inside the builder; static content '
        'should be passed via the child parameter or moved outside. {v1}',
    correctionMessage:
        'Extract static widgets outside the builder callback. Use the child '
        'parameter to pass non-animating subtrees through. Only keep widgets '
        'that depend on the animation value inside the builder.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _builderWidgets = <String>{
    'AnimatedBuilder',
    'ValueListenableBuilder',
    'StreamBuilder',
    'FutureBuilder',
    'ListenableBuilder',
  };

  /// Threshold: flag builders with more than this many widget constructors.
  static const int _widgetCountThreshold = 5;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_builderWidgets.contains(typeName)) return;

      // Find the builder named argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'builder') continue;

        final Expression builderExpr = arg.expression;
        if (builderExpr is! FunctionExpression) continue;

        final int count = _countWidgetsInBody(builderExpr.body);
        if (count > _widgetCountThreshold) {
          reporter.atNode(node.constructorName, code);
        }
        return;
      }
    });
  }

  int _countWidgetsInBody(FunctionBody body) {
    final _WidgetCountVisitor visitor = _WidgetCountVisitor();
    body.accept(visitor);
    return visitor.widgetCount;
  }
}

/// Counts widget constructor invocations in a subtree.
///
/// Uses a set of common Flutter widget names rather than a PascalCase
/// heuristic. This avoids counting data classes (User, Config, Duration)
/// which would cause false positives. The set covers the most common
/// layout, styling, and interactive widgets found in builder callbacks.
class _WidgetCountVisitor extends RecursiveAstVisitor<void> {
  int widgetCount = 0;

  static const Set<String> _knownWidgets = <String>{
    'Align',
    'AnimatedOpacity',
    'AppBar',
    'Card',
    'Center',
    'ClipOval',
    'ClipRRect',
    'ColoredBox',
    'Column',
    'Container',
    'DecoratedBox',
    'ElevatedButton',
    'Expanded',
    'Flexible',
    'GestureDetector',
    'Icon',
    'IconButton',
    'Image',
    'InkWell',
    'ListTile',
    'Material',
    'Opacity',
    'Padding',
    'Positioned',
    'Row',
    'Scaffold',
    'SizedBox',
    'Stack',
    'Text',
    'TextButton',
    'Transform',
    'Wrap',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.name.lexeme;
    if (_knownWidgets.contains(typeName)) {
      widgetCount++;
    }
    super.visitInstanceCreationExpression(node);
  }
}

// =============================================================================
// avoid_clip_during_animation
// =============================================================================

/// Warns when a Clip widget is used inside an animated widget.
///
/// Since: v5.1.0 | Rule version: v1
///
/// `ClipRect`, `ClipRRect`, `ClipOval`, and `ClipPath` trigger expensive
/// rasterization on every animation frame. When nested inside an animated
/// widget the GPU must re-clip content 60+ times per second, causing janky
/// animations and dropped frames. Move the clip **outside** the animation
/// scope, or use `BoxDecoration.borderRadius` instead.
///
/// **BAD:**
/// ```dart
/// AnimatedContainer(
///   duration: Duration(milliseconds: 300),
///   child: ClipRRect(
///     borderRadius: BorderRadius.circular(16),
///     child: Image.network(url),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ClipRRect(
///   borderRadius: BorderRadius.circular(16),
///   child: AnimatedContainer(
///     duration: Duration(milliseconds: 300),
///     child: Image.network(url),
///   ),
/// )
/// ```
class AvoidClipDuringAnimationRule extends SaropaLintRule {
  AvoidClipDuringAnimationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresWidgets => true;

  @override
  bool get requiresFlutterImport => true;

  static const LintCode _code = LintCode(
    'avoid_clip_during_animation',
    '[avoid_clip_during_animation] A Clip widget is used inside an animated '
        'widget, causing expensive rasterization on every animation frame. '
        'ClipRRect, ClipOval, and ClipPath force the GPU to re-clip content '
        '60+ times per second during animation, which leads to janky motion '
        'and dropped frames. ClipPath is especially costly because it forces '
        'software rasterization. Move the clip outside the animated scope or '
        'use BoxDecoration.borderRadius for rounded corners. {v1}',
    correctionMessage:
        'Move the Clip widget outside the animated ancestor so clipping '
        'happens once, not on every animation frame.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _clipWidgets = <String>{
    'ClipRect',
    'ClipRRect',
    'ClipOval',
    'ClipPath',
  };

  static const Set<String> _animatedWidgets = <String>{
    'AnimatedContainer',
    'AnimatedOpacity',
    'AnimatedPositioned',
    'AnimatedAlign',
    'AnimatedPadding',
    'AnimatedSize',
    'AnimatedSwitcher',
    'AnimatedCrossFade',
    'AnimatedDefaultTextStyle',
    'AnimatedPhysicalModel',
    'FadeTransition',
    'SlideTransition',
    'ScaleTransition',
    'RotationTransition',
    'SizeTransition',
    'DecoratedBoxTransition',
    'PositionedTransition',
    'RelativePositionedTransition',
    'AnimatedBuilder',
    'TweenAnimationBuilder',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_clipWidgets.contains(typeName)) return;

      // Walk up parents (max 10 levels) looking for an animated ancestor
      AstNode? current = node.parent;
      int depth = 0;
      while (current != null && depth < 10) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (_animatedWidgets.contains(parentType)) {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
        current = current.parent;
        depth++;
      }
    });
  }
}

// =============================================================================
// avoid_multiple_animation_controllers
// =============================================================================

/// Warns when a State class declares three or more AnimationController fields.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Alias: too_many_animation_controllers, complex_animation_state
///
/// Multiple `AnimationController` instances in a single State class indicate
/// overly complex animation logic that is hard to coordinate, test, and
/// maintain. Each controller needs explicit disposal, vsync management,
/// and careful lifecycle handling. Consider using `TweenSequence`,
/// `staggered_animations`, or Rive/Lottie for complex animations.
///
/// Threshold: 3 controllers (2 is a common legitimate pattern).
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> with TickerProviderStateMixin {
///   late final AnimationController _fadeController;
///   late final AnimationController _slideController;
///   late final AnimationController _scaleController; // Too many!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> with SingleTickerProviderStateMixin {
///   late final AnimationController _controller;
///   late final Animation<double> _fadeAnimation;
///   late final Animation<Offset> _slideAnimation;
///   // One controller drives multiple animations via TweenSequence
/// }
/// ```
class AvoidMultipleAnimationControllersRule extends SaropaLintRule {
  AvoidMultipleAnimationControllersRule() : super(code: _code);

  /// Complex animation state is hard to maintain and dispose correctly.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_multiple_animation_controllers',
    '[avoid_multiple_animation_controllers] State class declares 3 or more '
        'AnimationController fields. Multiple controllers are hard to '
        'coordinate, each requiring explicit disposal and vsync management. '
        'Complex multi-controller state increases the risk of lifecycle bugs, '
        'memory leaks from missed disposal, and makes animation timing '
        'difficult to reason about. {v1}',
    correctionMessage:
        'Use a single AnimationController with TweenSequence or '
        'staggered_animations. For complex animations, consider Rive or '
        'Lottie instead of manual controller management.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const int _threshold = 3;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Only check State subclasses
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass != 'State') return;

      int controllerCount = 0;

      for (final ClassMember member in node.body.members) {
        if (member is! FieldDeclaration) continue;
        final TypeAnnotation? type = member.fields.type;

        if (type is NamedType) {
          // Explicit type annotation: AnimationController or AnimationController?
          if (type.name.lexeme == 'AnimationController') {
            controllerCount += member.fields.variables.length;
          }
        } else if (type == null) {
          // Inferred type: check initializer expression
          for (final VariableDeclaration v in member.fields.variables) {
            final Expression? init = v.initializer;
            if (init is InstanceCreationExpression &&
                init.constructorName.type.name.lexeme ==
                    'AnimationController') {
              controllerCount++;
            }
          }
        }
      }

      if (controllerCount >= _threshold) {
        reporter.atToken(node.namePart.typeName);
      }
    });
  }
}

// =============================================================================
// prefer_single_ticker_provider_state_mixin
// =============================================================================

/// Flags `State` subclasses that mix in `TickerProviderStateMixin` but declare
/// exactly one `AnimationController`, recommending the
/// `SingleTickerProviderStateMixin` variant instead.
///
/// `TickerProviderStateMixin` carries per-instance bookkeeping for a list of
/// tickers; `SingleTickerProviderStateMixin` stores a single nullable ticker.
/// When only one controller exists, the plural variant allocates machinery
/// it will never use. The Flutter framework's own documentation recommends
/// the Single variant as the default for single-controller state — it is
/// cheaper and intent-revealing to any reader scanning the class header.
///
/// Forms a staircase with its neighbors (by controller count):
/// - 1 controller + plural mixin → **this rule** (prefer Single)
/// - 2 controllers + plural mixin → correct, no lint
/// - 3+ controllers → [AvoidMultipleAnimationControllersRule]
///
/// Since: v12.4.0 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget>
///     with TickerProviderStateMixin {
///   late final AnimationController _controller; // only one controller
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late final AnimationController _controller;
/// }
/// ```
///
/// **GOOD:** (plural mixin is correct when there are 2+ controllers)
/// ```dart
/// class _MultiState extends State<MultiWidget>
///     with TickerProviderStateMixin {
///   late final AnimationController _fadeController;
///   late final AnimationController _slideController;
/// }
/// ```
class PreferSingleTickerProviderStateMixinRule extends SaropaLintRule {
  PreferSingleTickerProviderStateMixinRule() : super(code: _code);

  /// Idiomatic improvement, not a correctness bug. The plural mixin allocates
  /// a list-of-tickers per instance; the Single variant stores one nullable
  /// ticker. Cheap perf win plus intent-revealing.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Early-exit gate — files without the plural mixin token skip AST
  /// registration entirely.
  @override
  Set<String>? get requiredPatterns => {'TickerProviderStateMixin'};

  static const LintCode _code = LintCode(
    'prefer_single_ticker_provider_state_mixin',
    '[prefer_single_ticker_provider_state_mixin] This State class declares '
        'only one AnimationController but mixes in TickerProviderStateMixin, '
        'which exists for multi-ticker states and allocates a list for the '
        'additional tickers it will never receive here. '
        'SingleTickerProviderStateMixin is the framework default for '
        'single-controller state — cheaper at runtime and intent-revealing to '
        'any reader scanning the class header. {v1}',
    correctionMessage:
        'Replace TickerProviderStateMixin with '
        'SingleTickerProviderStateMixin. Both live in '
        'package:flutter/widgets.dart and expose the same "vsync: this" '
        'protocol, so no other changes are needed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferSingleTickerProviderStateMixinFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Gate 1: must extend State<T>. Mirrors the shape already in use by
      // AvoidMultipleAnimationControllersRule and RequireAnimationControllerDisposeRule.
      // State without type arguments is unresolved Flutter state — skipping
      // avoids firing on generic/abstract scaffolding.
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      final NamedType superclass = extendsClause.superclass;
      if (superclass.name.lexeme != 'State') return;
      if (superclass.typeArguments == null) return;

      // Gate 2: class must declare TickerProviderStateMixin in its own
      // WithClause. We don't resolve mixins up the supertype chain — a
      // subclass that inherits the mixin from a parent State is not this
      // rule's target. Scope stays tight and false positives stay low.
      final WithClause? withClause = node.withClause;
      if (withClause == null) return;

      NamedType? mixinNamedType;
      for (final NamedType mixin in withClause.mixinTypes) {
        if (mixin.name.lexeme == 'TickerProviderStateMixin') {
          mixinNamedType = mixin;
          break;
        }
      }
      if (mixinNamedType == null) return;

      // Gate 3: count AnimationController fields using the same heuristic as
      // AvoidMultipleAnimationControllersRule so the staircase stays
      // consistent. Collections naturally drop out here — `List<AnimationController>`
      // has NamedType lexeme "List", not "AnimationController", and the
      // inferred-type arm only matches direct `AnimationController(...)`
      // constructor calls.
      int controllerCount = 0;
      for (final ClassMember member in node.body.members) {
        if (member is! FieldDeclaration) continue;
        final TypeAnnotation? type = member.fields.type;

        if (type is NamedType) {
          // Explicit annotation: AnimationController or AnimationController?
          // (the nullable `?` lives on a separate token, so the name lexeme
          // is unchanged).
          if (type.name.lexeme == 'AnimationController') {
            controllerCount += member.fields.variables.length;
          }
        } else if (type == null) {
          // Inferred type — only count if the initializer is a direct
          // `AnimationController(...)` constructor. This avoids counting
          // `late final _a = otherController` aliases as new controllers.
          for (final VariableDeclaration v in member.fields.variables) {
            final Expression? init = v.initializer;
            if (init is InstanceCreationExpression &&
                init.constructorName.type.name.lexeme ==
                    'AnimationController') {
              controllerCount++;
            }
          }
        }
      }

      // Exactly one controller is the rule's target. Zero is out of scope
      // (dead-mixin territory, handled separately); two or more means the
      // plural mixin is correct.
      if (controllerCount != 1) return;

      // Report at the mixin token so the squiggle lands on exactly what the
      // user needs to change, and the quick fix rewrites just that token.
      reporter.atNode(mixinNamedType);
    });
  }
}

// =============================================================================
// avoid_implicit_animation_dispose_cast
// =============================================================================

/// Flags `(animation as CurvedAnimation).dispose()` in [ImplicitlyAnimatedWidgetState] subclasses.
///
/// ## Background (Flutter 3.7+)
///
/// Framework PR [flutter/flutter#111849](https://github.com/flutter/flutter/pull/111849) changed
/// **internal** implementation only: the implicit animation field is a [CurvedAnimation], so the
/// engine disposes it without casting. Public API (`animation` still types as [Animation]) is
/// unchanged. Some codebases still contain snippets copied from older framework sources that call
/// `dispose()` on that animation after casting—**the base state already disposes it in
/// `super.dispose()`**, so this is redundant and can cause double-dispose or confusing lifecycle
/// ordering.
///
/// ## When this rule reports
///
/// - The cast target type is exactly `CurvedAnimation` (named type, not heuristic string scan).
/// - The expression is the `animation` **getter** declared on [ImplicitlyAnimatedWidgetState]
///   (resolved via the element model, including `this.animation`).
/// - The cast is the **direct** receiver of `.dispose()` (parentheses around the cast allowed).
/// - The enclosing class **extends** [ImplicitlyAnimatedWidgetState] (any depth up to Flutter’s
///   base, e.g. [AnimatedWidgetBaseState] subclasses).
///
/// ## When this rule does **not** report (false-positive avoidance)
///
/// - `(animation as CurvedAnimation).curve` or any member other than `dispose`.
/// - Casts in classes that do not inherit [ImplicitlyAnimatedWidgetState].
/// - A local or field named `animation` that is **not** the framework getter (resolved element).
///
/// ## Performance
///
/// - [requiredPatterns] includes `as CurvedAnimation` so files without that substring skip the
///   rule before AST callbacks.
/// - [applicableFileTypes] is [FileType.widget] to limit analysis to widget-like paths.
///
/// Since: v9.10.1 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// class _MyState extends ImplicitlyAnimatedWidgetState<MyWidget> {
///   @override
///   void dispose() {
///     (animation as CurvedAnimation).dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends ImplicitlyAnimatedWidgetState<MyWidget> {
///   @override
///   void dispose() {
///     super.dispose();
///   }
/// }
/// ```
///
/// **GOOD:** Cast for APIs on [CurvedAnimation] other than `dispose` is not reported.
/// ```dart
/// final curve = (animation as CurvedAnimation).curve;
/// ```
class AvoidImplicitAnimationDisposeCastRule extends SaropaLintRule {
  AvoidImplicitAnimationDisposeCastRule() : super(code: _code);

  /// Double-dispose / wrong lifecycle ordering on framework-owned animation.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => {'as CurvedAnimation'};

  static const LintCode _code = LintCode(
    'avoid_implicit_animation_dispose_cast',
    '[avoid_implicit_animation_dispose_cast] Calling dispose() on '
        '(animation as CurvedAnimation) in an ImplicitlyAnimatedWidgetState '
        'subclass is redundant and unsafe. The framework owns that CurvedAnimation '
        'and disposes it when super.dispose() runs (Flutter 3.7+, PR #111849). '
        'Remove this call and rely on super.dispose() only. {v1}',
    correctionMessage:
        'Delete the line that casts animation to CurvedAnimation and calls dispose(). '
        'Call super.dispose() (and dispose only your own resources).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveRedundantImplicitAnimationDisposeFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAsExpression((AsExpression node) {
      if (!_isCurvedAnimationNamedType(node.type)) return;
      if (!_isImplicitAnimationGetter(node.expression)) return;
      if (disposeInvocationForCastAsDisposeTarget(node) == null) return;

      final ClassDeclaration? cls = _enclosingClassDeclaration(node);
      if (cls == null) return;
      final ClassElement? classElement = cls.declaredFragment?.element;
      if (classElement == null) return;
      if (!_extendsImplicitlyAnimatedWidgetState(classElement)) return;

      reporter.atNode(node);
    });
  }
}

/// Warns when `AnimatedBuilder` is given a plain `Listenable` (not an
/// `Animation`) and recommends `ListenableBuilder` instead.
///
/// `ListenableBuilder` was added in Flutter 3.13.0 as the semantically
/// precise widget for "rebuild on any `Listenable` change". `AnimatedBuilder`
/// should continue to be used when the source is an `Animation` or
/// `AnimationController` — it is idiomatic there.
///
/// The rule only fires when the analyzer can resolve the `animation:`
/// argument's static type and that type implements `Listenable` but is not
/// a subtype of `Animation`. Unresolved / `dynamic` types are skipped to
/// avoid false positives.
///
/// Since: v12.2.2 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// final counter = ValueNotifier<int>(0);
/// return AnimatedBuilder(
///   animation: counter,
///   builder: (context, _) => Text('${counter.value}'),
/// );
/// ```
///
/// **GOOD:** (ValueNotifier is a Listenable, not an Animation)
/// ```dart
/// return ListenableBuilder(
///   animation: counter,
///   builder: (context, _) => Text('${counter.value}'),
/// );
/// ```
///
/// **GOOD:** (AnimationController is an Animation — keep AnimatedBuilder)
/// ```dart
/// return AnimatedBuilder(
///   animation: _controller,
///   builder: (context, _) => Transform.rotate(angle: _controller.value, child: ...),
/// );
/// ```
class PreferListenableBuilderRule extends SaropaLintRule {
  PreferListenableBuilderRule() : super(code: _code);

  /// Code smell / migration hint — not a correctness bug, so low impact.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Early-exit gate — files that never mention AnimatedBuilder are skipped
  /// before AST callbacks run.
  @override
  Set<String>? get requiredPatterns => {'AnimatedBuilder'};

  static const LintCode _code = LintCode(
    'prefer_listenable_builder',
    '[prefer_listenable_builder] AnimatedBuilder is being passed a plain '
        'Listenable (ValueNotifier, ChangeNotifier, or a custom Listenable) '
        'rather than an Animation. Flutter 3.13+ introduced ListenableBuilder '
        'as the semantically precise widget for this case — using '
        'AnimatedBuilder here obscures intent because the name implies an '
        'Animation source that is not actually present. Prefer '
        'ListenableBuilder when the source is not an Animation; keep '
        'AnimatedBuilder for AnimationController, CurvedAnimation, '
        'Tween.animate(...) results, and other Animation subtypes. {v1}',
    correctionMessage:
        'Rename the constructor from AnimatedBuilder to ListenableBuilder. '
        'The two widgets share the same named parameters (animation, '
        'builder, child), so no argument changes are required. Requires '
        'Flutter 3.13.0 or later.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferListenableBuilderFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // SDK gate: skip projects pinned below Flutter 3.13.0, where
    // ListenableBuilder did not yet exist. Unknown / unparseable constraints
    // default to "assume modern" so we still emit on the common case.
    if (!ProjectContext.flutterSdkAtLeast(context.filePath, 3, 13, 0)) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Filter to AnimatedBuilder instance creations by source token; cheap
      // comparison that avoids resolving the constructor element when it
      // isn't relevant.
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AnimatedBuilder') return;

      // Locate the `animation:` named argument. If it's absent (constructor
      // mis-use), nothing to report — the Dart analyzer will already flag it.
      Expression? animationArg;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'animation') {
          animationArg = arg.expression;
          break;
        }
      }
      if (animationArg == null) return;

      // Need a resolved interface type to make the Animation-vs-Listenable
      // decision reliably. Unresolved / dynamic types are skipped to avoid
      // firing on half-typed code.
      final DartType? argType = animationArg.staticType;
      if (argType is! InterfaceType) return;

      // Animation check must run first — a custom class that extends both
      // Animation and a plain Listenable should be treated as an Animation
      // (AnimatedBuilder is the correct widget for it).
      if (_isAnimationType(argType)) return;

      // Only flag when the argument really is a Listenable — otherwise the
      // user will just get a compile error after the fix is applied.
      if (!_isListenableType(argType)) return;

      reporter.atNode(node.constructorName);
    });
  }
}

/// Flags `someAnimation.value` reads inside `build()` when the read is not
/// wrapped by a listening builder. Reading `.value` directly in `build()`
/// produces a static snapshot — `build()` is not re-invoked on every tick,
/// so the animation appears wired but is visually inert. The typical
/// real-world shape is:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return ScaleTransition(
///     scale: _scaleAnimation,
///     child: widget.child.withOpacity(_opacityAnimation.value), // LINT
///   );
/// }
/// ```
///
/// The fix is to listen: wrap with `FadeTransition`, `ScaleTransition`,
/// `AnimatedBuilder`, or `ListenableBuilder` so the builder re-runs when
/// the animation notifies.
///
/// ### Detection
///
/// - Registry: `addPropertyAccess` and `addPrefixedIdentifier`.
/// - Trigger conditions (all required):
///   1. Property name is `value`.
///   2. Receiver's static type is `Animation<T>` or a subtype
///      (`AnimationController`, `CurvedAnimation`, `ReverseAnimation`,
///      `Tween.animate(...)` result).
///   3. The read is inside a `build(BuildContext ...)` method.
///   4. The read is NOT inside a `builder:` callback of an
///      `AnimatedBuilder`, `ListenableBuilder`, or `ValueListenableBuilder`.
/// - Writes (`controller.value = 0.3`) are skipped — the rule targets reads.
///
/// Since: v12.3.5 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return Opacity(opacity: _opacityAnimation.value, child: widget.child);
/// }
/// ```
///
/// **GOOD:** listening transition widget drives its own RenderObject
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return FadeTransition(opacity: _opacityAnimation, child: widget.child);
/// }
/// ```
///
/// **GOOD:** `AnimatedBuilder` builder re-runs on every tick
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return AnimatedBuilder(
///     animation: _controller,
///     builder: (BuildContext ctx, Widget? child) =>
///         Opacity(opacity: _opacityAnimation.value, child: child),
///     child: widget.child,
///   );
/// }
/// ```
class AvoidInertAnimationValueInBuildRule extends SaropaLintRule {
  AvoidInertAnimationValueInBuildRule() : super(code: _code);

  /// Silent correctness bug — animation appears wired but never runs.
  /// Misleads readers, wastes controller cycles, fails to deliver the
  /// visual feedback the code claims to provide.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Early-exit gate — only widget files that actually access `.value`
  /// somewhere can possibly match. Files without any `.value` token skip
  /// AST registration entirely.
  @override
  Set<String>? get requiredPatterns => {'.value'};

  static const LintCode _code = LintCode(
    'avoid_inert_animation_value_in_build',
    '[avoid_inert_animation_value_in_build] Reading an Animation.value '
        'inside build() outside of a listening builder produces a static '
        'snapshot — the value is captured when build() runs and never '
        'updates as the controller ticks, so the animation is visually '
        'inert. Use FadeTransition (for opacity), ScaleTransition (for '
        'scale), Align / SlideTransition (for offset), or wrap the '
        'subtree in AnimatedBuilder / ListenableBuilder so the read is '
        're-evaluated on every tick. {v1}',
    correctionMessage:
        'Replace the direct .value read with a listening widget: '
        'FadeTransition(opacity: animation, child: ...), '
        'ScaleTransition(scale: animation, child: ...), or '
        'AnimatedBuilder(animation: animation, builder: (ctx, child) => '
        '<widget that uses animation.value>, child: child). The listening '
        'widget rebuilds only its own RenderObject per tick.',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Widgets whose `builder:` callback is re-invoked on every listener
  /// notification — inside these, reading `.value` is safe. Anything else
  /// (plain `ScaleTransition`, `Opacity`, `Transform.scale`, etc.) does
  /// not trigger a rebuild of its children on every tick.
  static const Set<String> _listeningBuilderWidgets = <String>{
    'AnimatedBuilder',
    'ListenableBuilder',
    'ValueListenableBuilder',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'value') return;
      _checkAccess(reporter, node, node.realTarget);
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.identifier.name != 'value') return;
      _checkAccess(reporter, node, node.prefix);
    });
  }

  /// Shared detection path for `PropertyAccess` and `PrefixedIdentifier`
  /// — the only difference is how we reach the receiver expression.
  void _checkAccess(
    SaropaDiagnosticReporter reporter,
    AstNode accessNode,
    Expression? receiver,
  ) {
    if (receiver == null) return;

    // Skip writes: `controller.value = 0.3` is an assignment, not an
    // inert read. Detecting via the parent chain is cheaper than walking
    // up further and never reaching the receiver in most cases.
    if (_isAssignmentTarget(accessNode)) return;

    // Need a resolved type to distinguish `Animation.value` from the many
    // other `.value` properties in the SDK (`TextEditingController`,
    // `ValueNotifier`, custom classes). Unresolved / dynamic is skipped
    // to avoid false positives on half-typed code.
    final DartType? receiverType = receiver.staticType;
    if (receiverType is! InterfaceType) return;
    if (!_isAnimationType(receiverType)) return;

    if (!_isInertReadInBuild(accessNode)) return;

    reporter.atNode(accessNode);
  }

  /// Returns `true` when [node] is the left-hand side of an assignment
  /// (`controller.value = 0.3`, `controller.value += 1`). Those are
  /// writes, not the inert reads this rule targets.
  static bool _isAssignmentTarget(AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is AssignmentExpression) {
      return identical(parent.leftHandSide, node);
    }
    return false;
  }

  /// Walks ancestors of [node] until it either (a) reaches a
  /// `build(BuildContext ...)` method — inert read — or (b) passes through
  /// a listening-builder callback first — safe read — or (c) leaves the
  /// enclosing class/compilation unit — outside the rule's scope.
  ///
  /// Walk order matters: if a listening-builder callback is hit BEFORE
  /// the build() method, the read is safe even though it's textually
  /// inside build(). That matches runtime behavior — the builder runs on
  /// every tick regardless of where it's written.
  static bool _isInertReadInBuild(AstNode node) {
    for (
      AstNode? current = node.parent;
      current != null;
      current = current.parent
    ) {
      // Safe-read short circuit: a listening-builder callback ancestor
      // means the subtree is re-evaluated on every tick, so reads of
      // `.value` inside it are live, not inert.
      if (current is FunctionExpression &&
          _isListeningBuilderCallback(current)) {
        return false;
      }

      if (current is MethodDeclaration) {
        return _isWidgetBuildMethod(current);
      }

      // Leaving the class without hitting a `build` method means the
      // read is in a field initializer, top-level code, or a nested
      // class — v1 conservatively skips those.
      if (current is ClassDeclaration ||
          current is MixinDeclaration ||
          current is ExtensionDeclaration ||
          current is CompilationUnit) {
        return false;
      }
    }
    return false;
  }

  /// Returns `true` for a method named `build` whose parameter list
  /// contains a `BuildContext` parameter. Matches both `StatelessWidget.build`
  /// and `State.build`, and avoids non-Flutter methods that happen to be
  /// named `build` (e.g. builder-pattern DSLs).
  static bool _isWidgetBuildMethod(MethodDeclaration method) {
    if (method.name.lexeme != 'build') return false;
    final FormalParameterList? params = method.parameters;
    if (params == null) return false;

    for (final FormalParameter param in params.parameters) {
      final TypeAnnotation? type = _parameterTypeAnnotation(param);
      if (type is NamedType && type.name.lexeme == 'BuildContext') {
        return true;
      }
    }
    return false;
  }

  /// Unwraps `DefaultFormalParameter` and returns the declared
  /// [TypeAnnotation] of a `SimpleFormalParameter`. Returns `null` for
  /// field/super-formal parameters (their type is inherited from the
  /// field or superclass, which we don't follow in v1).
  static TypeAnnotation? _parameterTypeAnnotation(FormalParameter param) {
    FormalParameter inner = param;
    if (inner is DefaultFormalParameter) {
      inner = inner.parameter;
    }
    if (inner is SimpleFormalParameter) return inner.type;
    return null;
  }

  /// Returns `true` when [fn] is the `builder:` argument of an
  /// `AnimatedBuilder`, `ListenableBuilder`, or `ValueListenableBuilder`
  /// constructor call. Those widgets re-invoke their builder callback on
  /// every listener notification, so `.value` reads inside are live.
  static bool _isListeningBuilderCallback(FunctionExpression fn) {
    final AstNode? namedArg = fn.parent;
    if (namedArg is! NamedExpression) return false;
    if (namedArg.name.label.name != 'builder') return false;

    final AstNode? argList = namedArg.parent;
    if (argList is! ArgumentList) return false;

    final AstNode? creation = argList.parent;
    if (creation is! InstanceCreationExpression) return false;

    final String typeName = creation.constructorName.type.name.lexeme;
    return _listeningBuilderWidgets.contains(typeName);
  }
}

/// Returns `true` when [type] is `Animation<T>` or any subtype of it
/// (`AnimationController`, `CurvedAnimation`, `ReverseAnimation`, the result
/// of `Tween.animate(...)`, etc.).
bool _isAnimationType(InterfaceType type) {
  if (type.element.name == 'Animation') return true;
  for (final InterfaceType sup in type.allSupertypes) {
    if (sup.element.name == 'Animation') return true;
  }
  return false;
}

/// Returns `true` when [type] implements `Listenable` either directly
/// (`type.element.name == 'Listenable'`) or through its supertype chain
/// (`ValueNotifier`, `ChangeNotifier`, custom `Listenable` implementations).
bool _isListenableType(InterfaceType type) {
  if (type.element.name == 'Listenable') return true;
  for (final InterfaceType sup in type.allSupertypes) {
    if (sup.element.name == 'Listenable') return true;
  }
  return false;
}

bool _isCurvedAnimationNamedType(TypeAnnotation typeAnnotation) {
  if (typeAnnotation is! NamedType) return false;
  return typeAnnotation.name.lexeme == 'CurvedAnimation';
}

bool _isImplicitAnimationGetter(Expression expression) {
  final GetterElement? getter = _resolvedAnimationGetter(expression);
  if (getter == null || getter.name != 'animation') return false;
  final Element enclosing = getter.enclosingElement;
  if (enclosing is! ClassElement) return false;
  return enclosing.name == 'ImplicitlyAnimatedWidgetState';
}

GetterElement? _resolvedAnimationGetter(Expression expression) {
  Element? e;
  if (expression is SimpleIdentifier) {
    e = expression.element;
  } else if (expression is PropertyAccess) {
    e = expression.propertyName.element;
  } else {
    return null;
  }
  return e is GetterElement ? e : null;
}

ClassDeclaration? _enclosingClassDeclaration(AstNode node) {
  for (AstNode? current = node; current != null; current = current.parent) {
    if (current is ClassDeclaration) return current;
  }
  return null;
}

bool _extendsImplicitlyAnimatedWidgetState(ClassElement classElement) {
  InterfaceType? type = classElement.thisType;
  final Set<InterfaceType> seen = <InterfaceType>{};
  while (type != null && seen.add(type)) {
    final InterfaceElement element = type.element;
    if (element is ClassElement &&
        element.name == 'ImplicitlyAnimatedWidgetState') {
      return true;
    }
    type = type.superclass;
  }
  return false;
}

// =============================================================================
// prefer_animation_controller_forward_from_zero
// =============================================================================

/// Gesture callbacks that bind press/tap/click-style handlers. When a
/// bare `.forward()` fires from one of these, it can collide with an
/// in-flight reverse from a previous press — the sticky restart this
/// rule targets. Drag/pan handlers are intentionally excluded: they
/// typically drive `value` directly and don't produce the mid-reverse
/// restart scenario.
const Set<String> _pressGestureCallbackNames = <String>{
  'onTap',
  'onTapDown',
  'onTapUp',
  'onDoubleTap',
  'onDoubleTapDown',
  'onLongPress',
  'onLongPressDown',
  'onLongPressStart',
  'onLongPressUp',
  'onPressed',
  'onSecondaryTap',
  'onSecondaryTapDown',
  'onSecondaryTapUp',
  'onSecondaryLongPress',
  'onTertiaryTapDown',
  'onTertiaryTapUp',
};

/// Flags `AnimationController.forward()` (no args) inside a press/tap
/// gesture callback when the controller is wired to auto-reverse on
/// completion (`addStatusListener` → `reverse()` on
/// `AnimationStatus.completed` — the canonical "press-and-bounce"
/// pattern).
///
/// Without `from: 0.0`, a rapid re-press while the controller is still
/// mid-reverse resumes forward from the in-flight value instead of
/// restarting from zero, so the animation plays only the remaining
/// fraction of its duration. The visible effect is a sticky / uneven
/// re-press: the first press animates for the full duration, a fast
/// second press finishes in a fraction of the time. Users feel the UI
/// respond "slippery" on rapid taps without being able to name why.
///
/// Since: v12.3.5 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// class _InkState extends State<InkButton>
///     with SingleTickerProviderStateMixin {
///   late final AnimationController _c;
///
///   @override
///   void initState() {
///     super.initState();
///     _c = AnimationController(vsync: this, ...);
///     _c.addStatusListener((s) {
///       if (s == AnimationStatus.completed) _c.reverse();
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) => InkResponse(
///         onTap: () => _c.forward(), // LINT — sticky on rapid re-press
///         child: ...,
///       );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onTap: () => _c.forward(from: 0.0),
/// ```
///
/// **GOOD:** Equivalent explicit reset before forward.
/// ```dart
/// onTap: () {
///   _c.reset();
///   _c.forward();
/// },
/// ```
class PreferAnimationControllerForwardFromZeroRule extends SaropaLintRule {
  PreferAnimationControllerForwardFromZeroRule() : super(code: _code);

  /// UX correctness bug: rapid re-presses render only part of the
  /// animation, so every second tap looks different from the first.
  /// Not a crash or leak; QA rarely catches it because the regression
  /// is time-correlated. Narrow trigger keeps false positives low.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation', 'ux'};

  /// Class-body scan + descendant visitor per class; cheaper than a
  /// full-file recursive walk but not as cheap as a single visitor
  /// callback.
  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Files that never wire a status listener cannot match — skip entirely.
  /// Single-token prefilter intentionally: `requiredPatterns` uses OR
  /// semantics, so adding a second token would *broaden* the prefilter
  /// (files with only `.forward(` would no longer skip). The status
  /// listener is the strictly-required token, so it alone is the
  /// tightest gate.
  @override
  Set<String>? get requiredPatterns => {'addStatusListener'};

  static const LintCode _code = LintCode(
    'prefer_animation_controller_forward_from_zero',
    '[prefer_animation_controller_forward_from_zero] This '
        'AnimationController is wired to auto-reverse on completion, so '
        'calling forward() with no arguments from a gesture callback '
        'resumes from the in-flight value when the controller is still '
        'mid-reverse. Rapid re-presses play only part of the animation, '
        'which feels sticky and inconsistent to users even though no '
        'error or warning is produced. {v1}',
    correctionMessage:
        'Use forward(from: 0.0) so every press restarts the animation '
        'from the beginning, or call reset() immediately before '
        'forward() for an equivalent explicit restart.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferAnimationControllerForwardFromZeroFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration classNode) {
      // Gate 1: identify controllers in this class that auto-reverse on
      // completion. If none, no forward() call in the class can trip the
      // rule, so we skip the descendant walk entirely.
      final Set<String> autoReverseControllers = _collectAutoReverseControllers(
        classNode,
      );
      if (autoReverseControllers.isEmpty) return;

      // Gate 2: walk descendants to find bare .forward() calls inside
      // gesture callbacks. We scope the visitor to the class body so a
      // status listener in an unrelated class elsewhere in the file
      // cannot bleed into the decision here.
      classNode.visitChildren(
        _ForwardFromZeroVisitor(
          reporter: reporter,
          code: code,
          autoReverseControllers: autoReverseControllers,
        ),
      );
    });
  }
}

/// Scans the class body for `X.addStatusListener(...)` where the listener
/// body reverses `X` on `AnimationStatus.completed`, and returns the set of
/// receiver sources (e.g. `_controller`, `widget.controller`) that match.
///
/// Detection walks the listener's function body as an AST — the earlier
/// `bodySource.contains(...)` approach was flagged by
/// `test/anti_pattern_detection_test.dart` because substring matching on
/// `.toSource()` trips on identifiers embedded in comments or string
/// literals and on lexically similar names. The AST walk (see
/// [_ReverseOnCompletedScanner]) matches only real references to
/// `AnimationStatus.completed` and real `reverse()` invocations whose
/// receiver source equals the listener's receiver — preserving the same
/// "listener on controller A can't flag forward() on controller B" guard
/// without the false-positive surface of a text search.
Set<String> _collectAutoReverseControllers(ClassDeclaration classNode) {
  final Set<String> result = <String>{};
  classNode.visitChildren(_AddStatusListenerVisitor(result));
  return result;
}

class _AddStatusListenerVisitor extends RecursiveAstVisitor<void> {
  _AddStatusListenerVisitor(this.receivers);

  final Set<String> receivers;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'addStatusListener') {
      final Expression? target = node.realTarget;
      if (target != null && node.argumentList.arguments.length == 1) {
        final Expression arg = node.argumentList.arguments.first;
        if (arg is FunctionExpression) {
          final String receiverSource = target.toSource();
          // Walk the listener body once with a scanner that sets two
          // independent flags. Both must fire before the receiver is
          // accepted: (a) AnimationStatus.completed is referenced, and
          // (b) `reverse()` is invoked on the SAME receiver. Matching
          // the receiver rules out the "listener on controller A
          // flagging controller B" false positive; requiring `.completed`
          // keeps us from firing on listeners that reverse on `.dismissed`
          // or some other status (a different mechanism, out of scope).
          final _ReverseOnCompletedScanner scanner = _ReverseOnCompletedScanner(
            receiverSource,
          );
          arg.body.accept(scanner);
          if (scanner.sawCompleted && scanner.sawReverseOnReceiver) {
            receivers.add(receiverSource);
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Visitor that sets two flags when walking a status-listener body:
///
/// - [sawCompleted] — a reference to `AnimationStatus.completed` as a real
///   identifier (not inside a comment or string literal, which text-based
///   searching could not distinguish).
/// - [sawReverseOnReceiver] — a `reverse()` method invocation whose
///   receiver's source text equals [receiverSource], i.e. the same object
///   the outer `addStatusListener` call was attached to.
///
/// We compare receiver text via `Expression.toSource()` equality because
/// the receiver can be any expression shape (`_controller`,
/// `widget.controller`, `this.controller`) and the surrounding code
/// already captured the listener's receiver as its source text. This is
/// not the banned `.toSource().contains(...)` anti-pattern — it is an
/// exact-string equality, which keeps the match tight and readable.
class _ReverseOnCompletedScanner extends RecursiveAstVisitor<void> {
  _ReverseOnCompletedScanner(this.receiverSource);

  final String receiverSource;
  bool sawCompleted = false;
  bool sawReverseOnReceiver = false;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Canonical form: `AnimationStatus.completed` parses as a
    // PrefixedIdentifier when it appears in an equality check such as
    // `status == AnimationStatus.completed`. This is the overwhelmingly
    // common shape in real-world code.
    if (node.prefix.name == 'AnimationStatus' &&
        node.identifier.name == 'completed') {
      sawCompleted = true;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Fallback shape: in some positions (cascaded access, chained member
    // reads) `AnimationStatus.completed` parses as a PropertyAccess
    // instead of a PrefixedIdentifier. Catching both keeps behavior
    // equivalent to the prior substring scan, which was parse-shape-blind.
    final Expression? propertyTarget = node.target;
    if (propertyTarget is SimpleIdentifier &&
        propertyTarget.name == 'AnimationStatus' &&
        node.propertyName.name == 'completed') {
      sawCompleted = true;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Match `X.reverse(...)` where X's source text equals the listener's
    // receiver. Equality (not substring) is the important guard — a
    // substring test would also match `widget.controllerReverse(...)` or
    // an unrelated `reverse` call on a differently-named controller.
    if (node.methodName.name == 'reverse') {
      final Expression? invocationTarget = node.realTarget;
      if (invocationTarget != null &&
          invocationTarget.toSource() == receiverSource) {
        sawReverseOnReceiver = true;
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _ForwardFromZeroVisitor extends RecursiveAstVisitor<void> {
  _ForwardFromZeroVisitor({
    required this.reporter,
    required this.code,
    required this.autoReverseControllers,
  });

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> autoReverseControllers;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (node.methodName.name != 'forward') return;

    // Skip any call that already has arguments. Flutter's signature is
    // `forward({double? from})`, so any present argument means the user
    // has deliberately chosen a starting value — including `from: 0.0`
    // (already correct) and `from: someExpression` (intentional resume).
    if (node.argumentList.arguments.isNotEmpty) return;

    final Expression? target = node.realTarget;
    if (target == null) return;

    // Type gate: only flag calls on AnimationController. Filters out
    // unrelated APIs that happen to expose a `forward()` method (e.g.
    // PageController, custom classes). Skip when the analyzer cannot
    // resolve the type — don't fire on half-typed / unresolved code.
    if (!_isAnimationControllerType(target.staticType)) return;

    // Receiver must match one of the auto-reverse controllers collected
    // from the same class. Prevents flagging forward() on a different
    // controller that just happens to live in the same class.
    final String receiverSource = target.toSource();
    if (!autoReverseControllers.contains(receiverSource)) return;

    // Enclosing context must be a press/tap gesture callback. One-shot
    // entry animations (initState, didChangeDependencies) and drag/pan
    // handlers don't produce the mid-reverse restart scenario.
    if (!_isInPressGestureCallback(node)) return;

    // Don't flag `reset(); forward();` pairs — they are the equivalent
    // of `forward(from: 0.0)` expressed in two steps, and are called
    // out as a valid alternative in the rule's correction message.
    if (_hasPrecedingReset(node, receiverSource)) return;

    reporter.atNode(node, code);
  }
}

/// Returns `true` when [type] is `AnimationController` or a subtype.
/// Uses the element chain rather than a source-text match so subclasses
/// (rare but legal) are still recognized. Returns `false` for
/// unresolved types — the rule deliberately skips half-typed code to
/// avoid firing on in-progress edits.
bool _isAnimationControllerType(DartType? type) {
  if (type is! InterfaceType) return false;
  if (type.element.name == 'AnimationController') return true;
  for (final InterfaceType sup in type.allSupertypes) {
    if (sup.element.name == 'AnimationController') return true;
  }
  return false;
}

/// Walks ancestors looking for any [FunctionExpression] whose parent is
/// a [NamedExpression] using a press-gesture callback name. Stops at
/// the enclosing [ClassDeclaration] — past the class we cannot be
/// inside a widget's gesture callback anymore, so returning `false`
/// there avoids spurious matches from helper functions defined below
/// the class.
bool _isInPressGestureCallback(AstNode start) {
  for (
    AstNode? current = start.parent;
    current != null;
    current = current.parent
  ) {
    if (current is ClassDeclaration) return false;
    if (current is FunctionExpression) {
      final AstNode? parent = current.parent;
      if (parent is NamedExpression &&
          _pressGestureCallbackNames.contains(parent.name.label.name)) {
        return true;
      }
    }
  }
  return false;
}

/// Returns `true` when the statement immediately preceding [forwardCall]
/// in its enclosing [Block] is `<receiver>.reset()`. The reset-then-
/// forward idiom is functionally equivalent to `forward(from: 0.0)` and
/// is the second correct pattern documented in the rule's message, so
/// flagging it would churn valid code.
bool _hasPrecedingReset(MethodInvocation forwardCall, String receiverSource) {
  final Statement? statement = forwardCall.thisOrAncestorOfType<Statement>();
  if (statement == null) return false;
  final AstNode? block = statement.parent;
  if (block is! Block) return false;

  final List<Statement> statements = block.statements;
  final int index = statements.indexOf(statement);
  if (index <= 0) return false;

  final Statement previous = statements[index - 1];
  if (previous is! ExpressionStatement) return false;
  final Expression expr = previous.expression;
  if (expr is! MethodInvocation) return false;
  if (expr.methodName.name != 'reset') return false;

  final Expression? resetTarget = expr.realTarget;
  return resetTarget != null && resetTarget.toSource() == receiverSource;
}
