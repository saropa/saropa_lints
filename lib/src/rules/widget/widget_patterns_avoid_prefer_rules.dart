// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';
import '../../fixes/widget_patterns/comment_out_print_fix.dart';
import '../../fixes/widget_patterns/replace_empty_text_with_sized_box_fix.dart';
import '../../fixes/widget_patterns/replace_font_weight_number_fix.dart';
import '../../fixes/widget_patterns/replace_raw_keyboard_listener_fix.dart';
import '../../fixes/widget_patterns/replace_gesture_with_ink_well_fix.dart';
import '../../fixes/widget_patterns/replace_opacity_with_fade_transition_fix.dart';
import '../../fixes/widget_patterns/replace_text_with_selectable_fix.dart';
import '../../fixes/widget_patterns/remove_material2_fallback_fix.dart';

class AvoidIncorrectImageOpacityRule extends SaropaLintRule {
  AvoidIncorrectImageOpacityRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_incorrect_image_opacity',
    '[avoid_incorrect_image_opacity] Wrapping an Image widget in an Opacity widget is inefficient because it forces the framework to allocate an offscreen buffer, render the image into it, and then composite the buffer with reduced alpha. This extra compositing pass increases GPU memory usage and slows frame rendering, especially on lower-end devices. The Image widget natively supports opacity through its color and colorBlendMode properties, which apply the alpha during the image decode stage without an extra compositing layer. {v6}',
    correctionMessage:
        'Replace Opacity(child: Image(...)) with Image(..., color: color.withOpacity(x), colorBlendMode: BlendMode.modulate) to apply opacity efficiently. This avoids unnecessary compositing and improves rendering performance. See Flutter documentation for details on image opacity handling.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Opacity') return;

      // Find the child argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (_isImageWidget(childExpr)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }

  bool _isImageWidget(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final String typeName = expr.constructorName.type.name.lexeme;
      return typeName == 'Image';
    }
    if (expr is MethodInvocation) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier && target.name == 'Image') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when BuildContext is used in a late field initializer.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Late field initializers run at first access, not during construction,
/// so the context may be invalid or from a different widget lifecycle.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late final theme = Theme.of(context);
///   late final media = MediaQuery.of(context);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   ThemeData? _theme;
///
///   @override
///   void didChangeDependencies() {
///     super.didChangeDependencies();
///     _theme = Theme.of(context);
///   }
/// }
/// ```
class AvoidMissingImageAltRule extends SaropaLintRule {
  AvoidMissingImageAltRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_missing_image_alt',
    '[avoid_missing_image_alt] This Image widget is missing a semanticLabel, which is essential for accessibility. Without a semanticLabel, screen readers cannot describe the image to visually impaired users, making your app less inclusive and potentially non-compliant with accessibility standards. {v4}',
    correctionMessage:
        'Add a descriptive semanticLabel to every Image widget to ensure it is accessible to screen readers. This improves accessibility for users with visual impairments and helps meet accessibility guidelines. Refer to Flutter’s accessibility documentation for best practices on semantic labels.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Image') return;

      _checkForSemanticLabel(node, reporter);
    });

    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Image') return;

      // Check for Image.asset, Image.network, etc.
      final String methodName = node.methodName.name;
      if (const <String>[
        'asset',
        'network',
        'file',
        'memory',
      ].contains(methodName)) {
        _checkForSemanticLabelInMethod(node, reporter);
      }
    });
  }

  void _checkForSemanticLabel(
    InstanceCreationExpression node,
    SaropaDiagnosticReporter reporter,
  ) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) =>
          arg is NamedExpression && arg.name.label.name == 'semanticLabel',
    );

    if (!hasSemanticLabel) {
      reporter.atNode(node);
    }
  }

  void _checkForSemanticLabelInMethod(
    MethodInvocation node,
    SaropaDiagnosticReporter reporter,
  ) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) =>
          arg is NamedExpression && arg.name.label.name == 'semanticLabel',
    );

    if (!hasSemanticLabel) {
      reporter.atNode(node);
    }
  }
}

/// Warns when `mounted` is referenced inside setState callback.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Checking `mounted` inside setState is an anti-pattern because
/// setState should not be called if not mounted.
///
/// Example of **bad** code:
/// ```dart
/// setState(() {
///   if (mounted) {  // Wrong place to check
///     _value = newValue;
///   }
/// });
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (!mounted) return;
/// setState(() {
///   _value = newValue;
/// });
/// ```
class AvoidReturningWidgetsRule extends SaropaLintRule {
  AvoidReturningWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_returning_widgets',
    '[avoid_returning_widgets] Defining methods that return widgets (other than the build method) can make your widget tree harder to read, test, and maintain. This practice hides widget structure in private methods, reducing code clarity and making it more difficult to leverage Flutter’s hot reload and widget inspector tools. {v5}',
    correctionMessage:
        'Refactor methods that return widgets into separate StatelessWidget or StatefulWidget classes. This improves code organization, enables better tooling support, and makes your UI easier to test and maintain. See Flutter documentation for best practices on widget composition.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip build method
      if (node.name.lexeme == 'build') return;

      // Check return type
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType) {
        final String typeName = returnType.name.lexeme;
        if (typeName == 'Widget' || typeName.endsWith('Widget')) {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when shrinkWrap is used in nested scrollable lists.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Using shrinkWrap: true in nested scrollables can cause performance issues
/// as it forces the list to calculate the size of all children.
class AvoidUnnecessaryGestureDetectorRule extends SaropaLintRule {
  AvoidUnnecessaryGestureDetectorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unnecessary_gesture_detector',
    '[avoid_unnecessary_gesture_detector] GestureDetector wraps a child widget but has no gesture callbacks (onTap, onDoubleTap, onLongPress, etc.) defined, making it a redundant wrapper that adds an unnecessary layer to the widget tree and confuses maintainers reading the code. {v6}',
    correctionMessage:
        'Add at least one gesture callback (e.g. onTap, onLongPress) or remove the GestureDetector wrapper entirely to simplify the widget tree.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _gestureCallbacks = <String>{
    'onTap',
    'onTapDown',
    'onTapUp',
    'onTapCancel',
    'onSecondaryTap',
    'onSecondaryTapDown',
    'onSecondaryTapUp',
    'onSecondaryTapCancel',
    'onTertiaryTapDown',
    'onTertiaryTapUp',
    'onTertiaryTapCancel',
    'onDoubleTap',
    'onDoubleTapDown',
    'onDoubleTapCancel',
    'onLongPress',
    'onLongPressStart',
    'onLongPressMoveUpdate',
    'onLongPressUp',
    'onLongPressEnd',
    'onSecondaryLongPress',
    'onSecondaryLongPressStart',
    'onSecondaryLongPressMoveUpdate',
    'onSecondaryLongPressUp',
    'onSecondaryLongPressEnd',
    'onTertiaryLongPress',
    'onTertiaryLongPressStart',
    'onTertiaryLongPressMoveUpdate',
    'onTertiaryLongPressUp',
    'onTertiaryLongPressEnd',
    'onVerticalDragDown',
    'onVerticalDragStart',
    'onVerticalDragUpdate',
    'onVerticalDragEnd',
    'onVerticalDragCancel',
    'onHorizontalDragDown',
    'onHorizontalDragStart',
    'onHorizontalDragUpdate',
    'onHorizontalDragEnd',
    'onHorizontalDragCancel',
    'onForcePressStart',
    'onForcePressPeak',
    'onForcePressUpdate',
    'onForcePressEnd',
    'onPanDown',
    'onPanStart',
    'onPanUpdate',
    'onPanEnd',
    'onPanCancel',
    'onScaleStart',
    'onScaleUpdate',
    'onScaleEnd',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'GestureDetector') return;

      // Check if any gesture callback is defined
      bool hasGestureCallback = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (_gestureCallbacks.contains(paramName)) {
            // Check if it's not null
            final Expression value = arg.expression;
            if (value is! NullLiteral) {
              hasGestureCallback = true;
              break;
            }
          }
        }
      }

      if (!hasGestureCallback) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when setState is called in initState, dispose, or build.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Calling setState during widget lifecycle methods can cause issues.
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   setState(() {});  // Wrong - causes issues
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   // Update state directly in initState, no setState needed
/// }
/// ```
class PreferDefineHeroTagRule extends SaropaLintRule {
  PreferDefineHeroTagRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_define_hero_tag',
    '[prefer_define_hero_tag] Hero widget without an explicit tag defaults to the widget itself, causing conflicts when multiple Hero widgets exist on the same screen. Duplicate tags trigger runtime assertion errors that crash the app during navigation transitions. {v4}',
    correctionMessage:
        'Add a unique tag parameter to the Hero widget, such as a String constant or identifier that distinguishes it from other Hero widgets on the same route.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Hero') return;

      // Check if tag is defined
      final bool hasTag = node.argumentList.arguments.any(
        (Expression arg) =>
            arg is NamedExpression && arg.name.label.name == 'tag',
      );

      if (!hasTag) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when inline callbacks could be extracted to methods.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Long inline callbacks can make code harder to read. Consider extracting
/// them to named methods for better readability and testability.
class PreferExtractingCallbacksRule extends SaropaLintRule {
  PreferExtractingCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_extracting_callbacks',
    '[prefer_extracting_callbacks] Inline callback exceeds a reasonable length, reducing readability and making the build method harder to maintain. Long inline closures obscure widget structure, complicate debugging, and prevent reuse of the callback logic across widgets. {v3}',
    correctionMessage:
        'Extract the callback body into a named method on the widget or state class. This improves readability, enables reuse, and simplifies testing.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpression((FunctionExpression node) {
      // Only check callbacks passed as arguments
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression && parent is! ArgumentList) return;

      // Check callback length
      final FunctionBody body = node.body;
      if (body is BlockFunctionBody) {
        final int lineCount = body.block.statements.length;
        if (lineCount > 5) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when a file contains multiple public widget classes.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Each public widget should generally be in its own file for better
/// organization and maintainability.
class PreferSingleWidgetPerFileRule extends SaropaLintRule {
  PreferSingleWidgetPerFileRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_single_widget_per_file',
    '[prefer_single_widget_per_file] File contains multiple public widget classes, making it harder to locate widgets by filename, increasing merge conflicts in team environments, and complicating code navigation. Each public widget deserves its own file for discoverability and maintainability. {v4}',
    correctionMessage:
        'Move each public widget class to its own file named after the widget (e.g. my_widget.dart). Keep private helper widgets in the same file as the public widget they support.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      final List<ClassDeclaration> publicWidgets = <ClassDeclaration>[];

      for (final CompilationUnitMember member in node.declarations) {
        if (member is ClassDeclaration) {
          // Check if public (not starting with _)
          if (member.name.lexeme.startsWith('_')) continue;

          // Check if extends Widget
          final ExtendsClause? extendsClause = member.extendsClause;
          if (extendsClause != null) {
            final String superclass = extendsClause.superclass.name.lexeme;
            if (superclass.endsWith('Widget') ||
                superclass == 'StatelessWidget' ||
                superclass == 'StatefulWidget') {
              publicWidgets.add(member);
            }
          }
        }
      }

      // Report if more than one public widget
      if (publicWidgets.length > 1) {
        for (int i = 1; i < publicWidgets.length; i++) {
          reporter.atNode(publicWidgets[i], code);
        }
      }
    });
  }
}

/// Warns when a Sliver widget class doesn't have 'Sliver' prefix.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Sliver widgets should be named with 'Sliver' prefix for clarity.
///
/// Example of **bad** code:
/// ```dart
/// class MyList extends SliverChildDelegate {}
/// class CustomGrid extends SliverGridDelegate {}
/// ```
///
/// Example of **good** code:
/// ```dart
/// class SliverMyList extends SliverChildDelegate {}
/// class SliverCustomGrid extends SliverGridDelegate {}
/// ```
class PreferTextRichRule extends SaropaLintRule {
  PreferTextRichRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_text_rich',
    '[prefer_text_rich] RichText widget does not inherit DefaultTextStyle or respect textScaler from the widget tree, causing inconsistent text rendering across the app. Text.rich provides the same TextSpan capabilities while automatically inheriting the ambient text style and scaling settings. {v6}',
    correctionMessage:
        'Replace RichText(text: TextSpan(...)) with Text.rich(TextSpan(...)) to inherit DefaultTextStyle and textScaler from the widget tree automatically.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'RichText') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when using Column inside SingleChildScrollView instead of ListView.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Example of **bad** code:
/// ```dart
/// SingleChildScrollView(
///   child: Column(
///     children: widgets,
///   ),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView(
///   children: widgets,
/// )
/// ```
class PreferWidgetPrivateMembersRule extends SaropaLintRule {
  PreferWidgetPrivateMembersRule() : super(code: _codeField);

  static const LintCode _codeField = LintCode(
    'prefer_widget_private_members',
    '[prefer_widget_private_members] Non-final public field in a widget class breaks the immutability contract of Flutter widgets. Mutable widget fields can cause unpredictable rebuilds, stale state, and hard-to-trace rendering bugs because the framework assumes widgets are immutable after construction. {v6}',
    correctionMessage:
        'Make the field final (preferred) or private with an underscore prefix. Widget fields should be set only via the constructor.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const LintCode _codeMethod = LintCode(
    'prefer_widget_private_members',
    '[prefer_widget_private_members] Public helper method in a widget class exposes internal implementation details to consumers. This increases the public API surface, invites unintended coupling, and makes refactoring harder because external code may depend on methods that are not part of the widget contract. {v6}',
    correctionMessage:
        'Prefix the method name with an underscore to make it private (e.g. _buildHeader), keeping the widget API limited to its constructor parameters.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _widgetBaseClasses = <String>{
    'StatelessWidget',
    'StatefulWidget',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a Widget class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (!_widgetBaseClasses.contains(superclass)) return;

      for (final ClassMember member in node.members) {
        // Check for non-final public fields
        if (member is FieldDeclaration) {
          if (member.isStatic) continue;
          final VariableDeclarationList fields = member.fields;
          if (!fields.isFinal) {
            for (final VariableDeclaration variable in fields.variables) {
              final String name = variable.name.lexeme;
              if (!name.startsWith('_')) {
                reporter.atNode(variable, _codeField);
              }
            }
          }
        }

        // Check for public non-override methods (not build, not createState)
        if (member is MethodDeclaration) {
          if (member.isStatic) continue;
          if (member.isGetter || member.isSetter) continue;

          final String methodName = member.name.lexeme;

          // Skip framework methods
          if (methodName == 'build' ||
              methodName == 'createState' ||
              methodName == 'createElement' ||
              methodName == 'debugFillProperties' ||
              methodName == 'toString') {
            continue;
          }

          // Skip overrides
          bool isOverride = false;
          for (final Annotation annotation in member.metadata) {
            if (annotation.name.name == 'override') {
              isOverride = true;
              break;
            }
          }
          if (isOverride) continue;

          // Warn on public methods
          if (!methodName.startsWith('_')) {
            reporter.atNode(member, _codeMethod);
          }
        }
      }
    });
  }
}

/// Warns when a State class has disposable fields that are not properly disposed.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// StatefulWidget State classes should dispose of controllers, subscriptions,
/// and other disposable resources in their dispose() method to prevent memory leaks.
///
/// **Disposable types checked:**
/// - Controllers: TextEditingController, AnimationController, ScrollController,
///   TabController, PageController, FocusNode, etc.
/// - Streams: StreamSubscription, StreamController
/// - Others: Timer, ChangeNotifier, ValueNotifier
///
/// Example of **bad** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late TextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController();
///   }
///   // Missing dispose() - memory leak!
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late TextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController();
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
/// }
/// ```
class AvoidUncontrolledTextFieldRule extends SaropaLintRule {
  AvoidUncontrolledTextFieldRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_uncontrolled_text_field',
    '[avoid_uncontrolled_text_field] TextField without a TextEditingController loses programmatic access to the input value, making it impossible to pre-fill, clear, validate on demand, or read the text outside of onChanged. This leads to fragile state management and unexpected behavior during form submissions. {v6}',
    correctionMessage:
        'Create a TextEditingController in initState (and dispose it in dispose), then pass it to the TextField via the controller parameter.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextField' && typeName != 'TextFormField') return;

      // Check if controller argument is provided
      final ArgumentList args = node.argumentList;
      bool hasController = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'controller') {
          hasController = true;
          break;
        }
      }

      if (!hasController) {
        reporter.atNode(node);
      }
    });
  }
}

/// Future rule: avoid-hardcoded-asset-paths
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Warns when asset paths are hardcoded as string literals.
///
/// Example of **bad** code:
/// ```dart
/// Image.asset('assets/images/logo.png')
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.asset(Assets.images.logo)  // Using generated assets class
/// ```
class AvoidHardcodedAssetPathsRule extends SaropaLintRule {
  AvoidHardcodedAssetPathsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_hardcoded_asset_paths',
    '[avoid_hardcoded_asset_paths] Hardcoded asset path string is error-prone: typos produce silent runtime failures, path changes require find-and-replace across the codebase, and the compiler cannot verify the asset exists. Centralized asset references enable compile-time safety and single-source-of-truth for all asset paths. {v5}',
    correctionMessage:
        'Define asset paths in a constants class or use a code generator like flutter_gen to produce type-safe asset references (e.g. Assets.images.logo).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for Image.asset, AssetImage, etc.
      final String methodName = node.methodName.name;
      if (methodName != 'asset' && methodName != 'file') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Image' && target.name != 'AssetImage') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is StringLiteral) {
        final String? path = firstArg.stringValue;
        if (path != null &&
            (path.contains('assets/') || path.contains('images/'))) {
          reporter.atNode(firstArg);
        }
      }
    });

    // Also check for AssetImage constructor
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AssetImage') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is StringLiteral) {
        final String? path = firstArg.stringValue;
        if (path != null &&
            (path.contains('assets/') || path.contains('images/'))) {
          reporter.atNode(firstArg);
        }
      }
    });
  }
}

/// Future rule: avoid-print-in-production
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Warns when print() is used outside of debug/test code.
///
/// Example of **bad** code:
/// ```dart
/// void handleError(Object error) {
///   print('Error: $error');  // Use proper logging
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void handleError(Object error) {
///   logger.error('Error: $error');
/// }
/// ```
///
/// **Quick fix available:** Comments out the print statement.
class AvoidPrintInProductionRule extends SaropaLintRule {
  AvoidPrintInProductionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_print_in_production',
    '[avoid_print_in_production] print() call found in production widget code. Print statements bypass structured logging, cannot be filtered by severity, pollute the console in release builds, and may inadvertently leak sensitive data. They also add unnecessary I/O overhead in production. {v5}',
    correctionMessage:
        'Replace with a logging framework (e.g. package:logging, or debugPrint for debug-only output) that supports log levels and can be silenced in release builds.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip test files
    final String path = context.filePath;
    if (path.contains('_test.dart') || path.contains('/test/')) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;

      // Check if it's the top-level print function
      if (node.target == null) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        CommentOutPrintFix(context: context),
  ];
}

/// Future rule: avoid-catching-generic-exception
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when catching Exception or Object too broadly.
///
/// Example of **bad** code:
/// ```dart
/// try {
///   doSomething();
/// } catch (e) {  // Catches everything
///   print(e);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// try {
///   doSomething();
/// } on FormatException catch (e) {
///   // Handle specific exception
/// }
/// ```
class AvoidCatchingGenericExceptionRule extends SaropaLintRule {
  AvoidCatchingGenericExceptionRule() : super(code: _code);

  /// Masks bugs and allows corrupted state to persist.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_catching_generic_exception',
    '[avoid_catching_generic_exception] Catching Exception or Object swallows all errors including programming bugs, assertion failures, and unexpected states that should crash visibly. This masks root causes, making bugs harder to diagnose and allowing the app to continue in a corrupted state. {v4}',
    correctionMessage:
        'Catch specific exception types (e.g. FormatException, HttpException, SocketException) so that unexpected errors propagate and are caught by error reporting.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      final TypeAnnotation? exceptionType = node.exceptionType;

      // Catch without type catches everything
      if (exceptionType == null) {
        reporter.atNode(node);
        return;
      }

      // Check for generic types
      if (exceptionType is NamedType) {
        final String typeName = exceptionType.name.lexeme;
        if (typeName == 'Exception' ||
            typeName == 'Object' ||
            typeName == 'dynamic') {
          reporter.atNode(exceptionType);
        }
      }
    });
  }
}

/// Future rule: avoid-service-locator-overuse
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when GetIt.I or similar service locator calls are scattered throughout.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final service = GetIt.I<MyService>();  // Scattered DI
///     return Text(service.value);
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final MyService service;
///   const MyWidget({required this.service});
///   // Constructor injection
/// }
/// ```
class AvoidServiceLocatorOveruseRule extends SaropaLintRule {
  AvoidServiceLocatorOveruseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_service_locator_overuse',
    '[avoid_service_locator_overuse] Service locator (e.g. GetIt.instance) called directly in a widget hides dependencies, makes the widget untestable without the full service container, and couples the UI layer to a specific DI framework. Constructor injection makes dependencies explicit and enables easy mocking in tests. {v6}',
    correctionMessage:
        'Pass the dependency through the widget constructor or use a DI-aware wrapper (e.g. Provider, Riverpod) so that tests can supply mock implementations without configuring a global container.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Only check build methods
      if (node.name.lexeme != 'build') return;

      // Find GetIt calls in build method
      node.body.accept(
        _ServiceLocatorFinder((MethodInvocation call) {
          reporter.atNode(call);
        }),
      );
    });
  }
}

class _ServiceLocatorFinder extends RecursiveAstVisitor<void> {
  _ServiceLocatorFinder(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for GetIt.I<T>() or GetIt.instance<T>() or locator<T>()
    final Expression? target = node.target;

    if (target is SimpleIdentifier) {
      if (target.name == 'GetIt' ||
          target.name == 'locator' ||
          target.name == 'sl') {
        onFound(node);
      }
    } else if (target is PrefixedIdentifier) {
      if (target.identifier.name == 'I' ||
          target.identifier.name == 'instance') {
        if (target.prefix.name == 'GetIt') {
          onFound(node);
        }
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Future rule: prefer-utc-datetimes
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when DateTime.now() is used where UTC might be more appropriate.
///
/// Example of code that might need UTC:
/// ```dart
/// final timestamp = DateTime.now();  // Consider DateTime.now().toUtc()
/// ```
class PreferUtcDateTimesRule extends SaropaLintRule {
  PreferUtcDateTimesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_utc_datetimes',
    '[prefer_utc_datetimes] Local DateTime values shift meaning when serialized and deserialized across time zones, causing off-by-hours bugs in timestamps, scheduling, and data synchronization. Storing and transmitting dates in UTC eliminates timezone ambiguity and ensures consistent behavior across devices and servers. {v6}',
    correctionMessage:
        'Use DateTime.now().toUtc() or DateTime.utc() for timestamps intended for storage, API transmission, or cross-device synchronization. Convert to local time only for display.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'now') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      // Check if it's being stored or transmitted (in an assignment or json context)
      final AstNode? parent = node.parent;
      if (parent is VariableDeclaration) {
        final String varName = parent.name.lexeme.toLowerCase();
        // Warn for names that suggest storage/transmission
        if (varName.contains('timestamp') ||
            varName.contains('created') ||
            varName.contains('updated') ||
            varName.contains('saved')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Future rule: avoid-regex-in-loop
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when RegExp is created inside a loop.
///
/// Example of **bad** code:
/// ```dart
/// for (final item in items) {
///   final regex = RegExp(r'\d+');  // Created every iteration
///   if (regex.hasMatch(item)) { }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final regex = RegExp(r'\d+');  // Created once
/// for (final item in items) {
///   if (regex.hasMatch(item)) { }
/// }
/// ```
class AvoidRegexInLoopRule extends SaropaLintRule {
  AvoidRegexInLoopRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_regex_in_loop',
    '[avoid_regex_in_loop] RegExp object constructed inside a loop body is re-compiled on every iteration, wasting CPU cycles on repeated pattern parsing. Regex compilation is expensive relative to matching, and this overhead multiplies with large data sets, causing noticeable jank in UI-driven code. {v6}',
    correctionMessage:
        'Declare the RegExp as a static final field or a local variable above the loop so it is compiled once and reused on each iteration.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((ForStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr);
        }),
      );
    });

    context.addWhileStatement((WhileStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr);
        }),
      );
    });

    context.addDoStatement((DoStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr);
        }),
      );
    });
  }
}

class _RegExpCreationFinder extends RecursiveAstVisitor<void> {
  _RegExpCreationFinder(this.onFound);
  final void Function(InstanceCreationExpression) onFound;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'RegExp') {
      onFound(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Future rule: prefer-getter-over-method
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when a method with no parameters just returns a value.
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Example of **bad** code:
/// ```dart
/// String getName() => _name;
/// int getCount() { return _count; }
/// ```
///
/// Example of **good** code:
/// ```dart
/// String get name => _name;
/// int get count => _count;
/// ```
class PreferGetterOverMethodRule extends SaropaLintRule {
  PreferGetterOverMethodRule() : super(code: _code);

  /// Stylistic preference only. No performance or correctness benefit.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  String get exampleBad => 'String getName() => _name;';

  @override
  String get exampleGood => 'String get name => _name;';

  static const LintCode _code = LintCode(
    'prefer_getter_over_method',
    '[prefer_getter_over_method] Using a getter instead of a zero-parameter method is a Dart API style preference. Both produce identical compiled code with no performance difference. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Convert to a getter (e.g. String get name => _name;). Reserve methods for operations that have side effects or accept parameters.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip getters, setters, operators
      if (node.isGetter || node.isSetter || node.isOperator) return;

      // Skip methods with parameters
      final FormalParameterList? params = node.parameters;
      if (params == null) return;
      if (params.parameters.isNotEmpty) return;

      // Skip async methods
      if (node.body.isAsynchronous) return;

      // Skip void return type
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'void') return;

      // Check if body is a simple expression return
      final FunctionBody body = node.body;
      if (body is ExpressionFunctionBody) {
        // Simple expression body - likely should be a getter
        final String name = node.name.lexeme;
        // Skip methods starting with common action prefixes
        if (!name.startsWith('get') &&
            !name.startsWith('fetch') &&
            !name.startsWith('load') &&
            !name.startsWith('create') &&
            !name.startsWith('build') &&
            !name.startsWith('compute') &&
            !name.startsWith('calculate')) {
          return;
        }
        reporter.atToken(node.name, code);
      } else if (body is BlockFunctionBody) {
        // Check if it's a single return statement
        final Block block = body.block;
        if (block.statements.length == 1) {
          final Statement stmt = block.statements.first;
          if (stmt is ReturnStatement && stmt.expression != null) {
            final String name = node.name.lexeme;
            if (name.startsWith('get') && name.length > 3) {
              reporter.atToken(node.name, code);
            }
          }
        }
      }
    });
  }
}

/// Future rule: avoid-unused-parameters-in-callbacks
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when callback parameters are declared but not used.
///
/// Example of **bad** code:
/// ```dart
/// onTap: (value) {
///   print('tapped');
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// onTap: (_) {
///   print('tapped');
/// }
/// ```
class AvoidUnusedCallbackParametersRule extends SaropaLintRule {
  AvoidUnusedCallbackParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unused_callback_parameters',
    '[avoid_unused_callback_parameters] Callback parameter is declared but never referenced in the closure body, adding visual noise and misleading readers into thinking the value is needed. Unused parameters also trigger analyzer warnings and obscure the actual data flow of the callback. {v4}',
    correctionMessage:
        'Replace the unused parameter name with an underscore (_) or double underscore (__) to signal that the value is intentionally ignored.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpression((FunctionExpression node) {
      final NodeList<FormalParameter>? parameters = node.parameters?.parameters;
      if (parameters == null || parameters.isEmpty) return;

      // Get all identifiers used in the body
      final Set<String> usedIdentifiers = <String>{};
      node.body.visitChildren(_IdentifierCollector(usedIdentifiers));

      for (final FormalParameter param in parameters) {
        final String? name = param.name?.lexeme;
        if (name == null || name.startsWith('_')) continue;

        if (!usedIdentifiers.contains(name)) {
          final token = param.name;
          if (token != null) reporter.atToken(token, code);
        }
      }
    });
  }
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  _IdentifierCollector(this.identifiers);
  final Set<String> identifiers;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Future rule: prefer-const-widgets-in-lists
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Warns when widget literals in lists could be const.
///
/// Example of **bad** code:
/// ```dart
/// children: [
///   SizedBox(height: 8),
///   Divider(),
/// ]
/// ```
///
/// Example of **good** code:
/// ```dart
/// children: const [
///   SizedBox(height: 8),
///   Divider(),
/// ]
/// ```
class AvoidTextScaleFactorRule extends SaropaLintRule {
  AvoidTextScaleFactorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_text_scale_factor',
    '[avoid_text_scale_factor] textScaleFactor is deprecated since Flutter 3.16. It applies a linear multiplier that cannot express non-linear text scaling used by accessibility settings on modern platforms. The replacement textScaler API supports both linear and non-linear scaling, ensuring correct rendering for users with accessibility needs. {v4}',
    correctionMessage:
        'Replace textScaleFactor with textScaler: TextScaler.linear(factor), or use MediaQuery.textScalerOf(context) to read the ambient scaler.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check for textScaleFactorOf method calls
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'textScaleFactorOf') {
        reporter.atNode(node.methodName, code);
      }
    });

    // Check for .textScaleFactor property access
    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name == 'textScaleFactor') {
        reporter.atNode(node.propertyName, code);
      }
    });
  }
}

/// Future rule: prefer-widget-state-mixin
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when State class doesn't use WidgetStateMixin for better state management.
///
/// Example of **bad** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   bool _isHovered = false;
///   bool _isPressed = false;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with WidgetStateMixin<MyWidget> {
///   // Use WidgetState for hover, pressed, etc.
/// }
/// ```
class AvoidImageWithoutCacheRule extends SaropaLintRule {
  AvoidImageWithoutCacheRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_image_without_cache',
    '[avoid_image_without_cache] Image.network without cacheWidth or cacheHeight decodes the full-resolution image into memory, even when displayed at a smaller size. A 4000x3000 photo decoded at full resolution consumes ~48 MB of GPU memory, causing excessive memory usage and potential out-of-memory crashes on low-end devices. {v6}',
    correctionMessage:
        'Add cacheWidth and/or cacheHeight matching the display size (in logical pixels multiplied by devicePixelRatio) so Flutter decodes a smaller image into memory.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      if (typeName == 'Image' && constructorName == 'network') {
        // Check for cacheWidth/cacheHeight
        bool hasCacheWidth = false;
        bool hasCacheHeight = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            if (name == 'cacheWidth') hasCacheWidth = true;
            if (name == 'cacheHeight') hasCacheHeight = true;
          }
        }

        if (!hasCacheWidth && !hasCacheHeight) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: prefer-split-widget-const
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when large widget trees should be split into const widgets.
///
/// Example of **bad** code:
/// ```dart
/// Column(
///   children: [
///     Text('Title'),
///     Text('Subtitle'),
///     Icon(Icons.star),
///   ],
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// const _TitleSection();
/// // or extract to const widget
/// ```
class PreferSplitWidgetConstRule extends SaropaLintRule {
  PreferSplitWidgetConstRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_split_widget_const',
    '[prefer_split_widget_const] Large widget subtree with all-const children is rebuilt on every parent setState, even though its output never changes. Extracting it into a separate const widget class allows Flutter to skip rebuilding the entire subtree, reducing frame build times and improving scroll performance. {v6}',
    correctionMessage:
        'Extract the static subtree into its own StatelessWidget class with a const constructor, then instantiate it with const in the parent build method.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check common container widgets
      if (typeName == 'Column' || typeName == 'Row' || typeName == 'Stack') {
        // Count nested widgets
        int widgetCount = 0;
        node.visitChildren(_WidgetCounter((int count) => widgetCount = count));

        // If more than 5 nested widgets, suggest splitting
        if (widgetCount > 5) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

class _WidgetCounter extends RecursiveAstVisitor<void> {
  _WidgetCounter(this.onCount);
  final void Function(int) onCount;
  int _count = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _count++;
    onCount(_count);
    super.visitInstanceCreationExpression(node);
  }
}

/// Future rule: avoid-navigator-push-without-route-name
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when Navigator.push is used without a route name.
///
/// Example of **bad** code:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => NextPage()),
/// );
/// ```
///
/// Example of **good** code:
/// ```dart
/// Navigator.pushNamed(context, '/next');
/// // or use go_router/auto_route
/// ```
class AvoidNavigatorPushWithoutRouteNameRule extends SaropaLintRule {
  AvoidNavigatorPushWithoutRouteNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_navigator_push_without_route_name',
    '[avoid_navigator_push_without_route_name] Anonymous Navigator.push with inline MaterialPageRoute scatters route definitions throughout the codebase, making it impossible to see all routes in one place, complicating deep linking, and preventing analytics from tracking navigation paths by name. {v4}',
    correctionMessage:
        'Use Navigator.pushNamed with routes defined in a central route table, or adopt a declarative routing package (e.g. go_router) for type-safe navigation.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'Navigator') {
        final String methodName = node.methodName.name;
        if (methodName == 'push' ||
            methodName == 'pushReplacement' ||
            methodName == 'pushAndRemoveUntil') {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-duplicate-keys-in-widget-list
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when widgets in a list have duplicate keys.
///
/// Example of **bad** code:
/// ```dart
/// [
///   Container(key: Key('item')),
///   Container(key: Key('item')),  // Duplicate key
/// ]
/// ```
///
/// Example of **good** code:
/// ```dart
/// [
///   Container(key: Key('item1')),
///   Container(key: Key('item2')),
/// ]
/// ```
class AvoidDuplicateWidgetKeysRule extends SaropaLintRule {
  AvoidDuplicateWidgetKeysRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_duplicate_widget_keys',
    '[avoid_duplicate_widget_keys] Multiple widgets in a list share the same Key value. Flutter uses keys to match old widgets with new widgets during reconciliation. Duplicate keys cause the framework to reuse the wrong element, leading to stale state, broken animations, and incorrect widget ordering after list mutations. {v4}',
    correctionMessage:
        'Assign a unique key to each widget in the list, using ValueKey with a stable identifier (e.g. item.id) rather than the list index.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
      final Map<String, List<AstNode>> keyValues = <String, List<AstNode>>{};

      for (final CollectionElement element in node.elements) {
        if (element is InstanceCreationExpression) {
          // Find key argument
          for (final Expression arg in element.argumentList.arguments) {
            if (arg is NamedExpression && arg.name.label.name == 'key') {
              final String? keyString = _extractKeyString(arg.expression);
              if (keyString != null) {
                keyValues.putIfAbsent(keyString, () => <AstNode>[]).add(arg);
              }
            }
          }
        }
      }

      // Report duplicates
      for (final List<AstNode> nodes in keyValues.values) {
        if (nodes.length > 1) {
          for (final AstNode keyNode in nodes) {
            reporter.atNode(keyNode);
          }
        }
      }
    });
  }

  String? _extractKeyString(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final NodeList<Expression> args = expr.argumentList.arguments;
      if (args.isNotEmpty) {
        final first = args.first;
        if (first is StringLiteral) return first.stringValue;
      }
    } else if (expr is MethodInvocation && expr.methodName.name == 'ValueKey') {
      final NodeList<Expression> args = expr.argumentList.arguments;
      if (args.isNotEmpty) {
        final first = args.first;
        if (first is StringLiteral) return first.stringValue;
      }
    }
    return null;
  }
}

/// Prefer letting Scaffold consume safe area instead of wrapping body in SafeArea.
///
/// **prefer_safe_area_consumer** — Warns when `SafeArea` is used as the direct
/// body of a `Scaffold` that already has an `AppBar` or `BottomNavigationBar`.
/// In that case Scaffold insets the body below the AppBar and above the bottom
/// bar, so a full SafeArea doubles the top/bottom inset and wastes vertical space.
///
/// **Exceptions:** Does not report when:
/// - The Scaffold has no `appBar` and no `bottomNavigationBar` (body extends
///   under system UI; SafeArea is appropriate).
/// - SafeArea has an explicit `top: false` (only bottom/left/right insets;
///   no redundant top inset with AppBar).
///
/// Since: v1.1.19 | Updated: v4.13.0 | Rule version: v4
///
/// **Bad:**
/// ```dart
/// Scaffold(
///   body: SafeArea(
///     child: ListView(...),
///   ),
/// )
/// ```
///
/// **Good:**
/// ```dart
/// Scaffold(
///   body: ListView(...),
/// )
/// ```
///
/// **Good (bottom-only inset):**
/// ```dart
/// Scaffold(
///   appBar: AppBar(...),
///   body: SafeArea(top: false, child: WebView(...)),
/// )
/// ```
class PreferSafeAreaConsumerRule extends SaropaLintRule {
  PreferSafeAreaConsumerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_safe_area_consumer',
    '[prefer_safe_area_consumer] SafeArea placed directly inside a Scaffold body is often redundant because Scaffold already insets its body below the AppBar and above the BottomNavigationBar. Doubling up on safe area handling wastes vertical space and can push content further from the edges than intended. {v4}',
    correctionMessage:
        'Remove SafeArea if the Scaffold has appBar or bottomNavigationBar that already consume safe area insets. Use SafeArea only when the Scaffold body extends behind system UI.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Scaffold') {
        if (!_scaffoldHasAppBarOrBottomNav(node)) return;
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'body') {
            final bodyExpr = arg.expression;
            if (bodyExpr is InstanceCreationExpression &&
                bodyExpr.constructorName.type.name.lexeme == 'SafeArea') {
              if (_safeAreaHasTopFalse(bodyExpr)) continue;
              reporter.atNode(bodyExpr.constructorName, code);
            }
          }
        }
      }
    });
  }

  /// True when this Scaffold has appBar or bottomNavigationBar (so body
  /// is already inset and SafeArea is redundant).
  static bool _scaffoldHasAppBarOrBottomNav(
    InstanceCreationExpression scaffold,
  ) {
    for (final Expression arg in scaffold.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'appBar' || name == 'bottomNavigationBar') {
          if (arg.expression is! NullLiteral) return true;
        }
      }
    }
    return false;
  }

  /// True when this SafeArea has an explicit `top: false` (no redundant top
  /// inset with Scaffold appBar).
  static bool _safeAreaHasTopFalse(InstanceCreationExpression safeArea) {
    for (final Expression arg in safeArea.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'top') {
        final expr = arg.expression;
        return expr is BooleanLiteral && !expr.value;
      }
    }
    return false;
  }
}

/// Future rule: avoid-unrestricted-text-field-length
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when TextField doesn't have maxLength set.
///
/// Example of **bad** code:
/// ```dart
/// TextField(controller: _controller)
/// ```
///
/// Example of **good** code:
/// ```dart
/// TextField(
///   controller: _controller,
///   maxLength: 500,
/// )
/// ```
class AvoidUnrestrictedTextFieldLengthRule extends SaropaLintRule {
  AvoidUnrestrictedTextFieldLengthRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unrestricted_text_field_length',
    '[avoid_unrestricted_text_field_length] TextField without maxLength allows unbounded input, enabling users to paste megabytes of text that can freeze the UI, exhaust memory, and create oversized payloads for backend APIs. Setting maxLength protects against denial-of-service scenarios and enforces data integrity constraints. {v6}',
    correctionMessage:
        'Add the maxLength parameter with a reasonable limit (e.g. maxLength: 500) and optionally set maxLengthEnforcement to control truncation behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'TextField' || typeName == 'TextFormField') {
        bool hasMaxLength = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'maxLength') {
            hasMaxLength = true;
            break;
          }
        }

        if (!hasMaxLength) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: prefer-scaffold-messenger-maybeof
///
/// Since: v1.1.19 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when ScaffoldMessenger.of is used instead of maybeOf.
///
/// Example of **bad** code:
/// ```dart
/// ScaffoldMessenger.of(context).showSnackBar(...);
/// ```
///
/// Example of **good** code:
/// ```dart
/// ScaffoldMessenger.maybeOf(context)?.showSnackBar(...);
/// ```
class PreferScaffoldMessengerMaybeOfRule extends SaropaLintRule {
  PreferScaffoldMessengerMaybeOfRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_scaffold_messenger_maybeof',
    '[prefer_scaffold_messenger_maybeof] ScaffoldMessenger.of throws a FlutterError if no ScaffoldMessenger ancestor exists, crashing the app in contexts like dialogs, overlays, or tests without a Scaffold. Using maybeOf returns null instead, allowing graceful fallback when the messenger is unavailable. {v4}',
    correctionMessage:
        'Replace ScaffoldMessenger.of(context) with ScaffoldMessenger.maybeOf(context) and handle the null case, or verify the context has a Scaffold ancestor before calling .of.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier &&
          target.name == 'ScaffoldMessenger' &&
          node.methodName.name == 'of') {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Future rule: avoid-form-without-key
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when Form widget doesn't have a GlobalKey.
///
/// Example of **bad** code:
/// ```dart
/// Form(
///   child: Column(...),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Form(
///   key: _formKey,
///   child: Column(...),
/// )
/// ```
class AvoidFormWithoutKeyRule extends SaropaLintRule {
  AvoidFormWithoutKeyRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_form_without_key',
    '[avoid_form_without_key] Form widget without a GlobalKey<FormState> makes it impossible to call validate(), save(), or reset() on the form state programmatically. Without a key, you cannot trigger field validation on submit, retrieve form values, or reset the form to its initial state. {v4}',
    correctionMessage:
        'Create a GlobalKey<FormState> field (e.g. final _formKey = GlobalKey<FormState>()) and pass it to the Form widget via the key parameter.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Form') {
        bool hasKey = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'key') {
            hasKey = true;
            break;
          }
        }

        if (!hasKey) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-listview-without-item-extent
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when ListView doesn't specify itemExtent for better performance.
///
/// Example of **bad** code:
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(...),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView.builder(
///   itemExtent: 72.0,
///   itemBuilder: (context, index) => ListTile(...),
/// )
/// ```
class AvoidMediaQueryInBuildRule extends SaropaLintRule {
  AvoidMediaQueryInBuildRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_mediaquery_in_build',
    '[avoid_mediaquery_in_build] MediaQuery.of(context) subscribes to all MediaQueryData changes (size, padding, orientation, brightness, text scaling), causing unnecessary rebuilds when only one property is needed. Specific accessors like sizeOf or paddingOf subscribe to only the relevant property, significantly reducing rebuild frequency. {v6}',
    correctionMessage:
        'Replace MediaQuery.of(context).size with MediaQuery.sizeOf(context), .padding with MediaQuery.paddingOf(context), etc. These targeted methods were added in Flutter 3.10.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier &&
          target.name == 'MediaQuery' &&
          node.methodName.name == 'of') {
        reporter.atNode(node);
      }
    });
  }
}

/// Future rule: prefer-sliver-list-delegate
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when SliverList uses children instead of delegate for large lists.
///
/// Example of **bad** code:
/// ```dart
/// SliverList(
///   delegate: SliverChildListDelegate([...100 items...]),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// SliverList(
///   delegate: SliverChildBuilderDelegate(
///     (context, index) => Item(items[index]),
///     childCount: items.length,
///   ),
/// )
/// ```
class PreferCachedNetworkImageRule extends SaropaLintRule {
  PreferCachedNetworkImageRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_cached_network_image',
    '[prefer_cached_network_image] Image.network re-downloads images every time the widget rebuilds or the user navigates back to the screen, wasting bandwidth and causing visible loading flicker. CachedNetworkImage persists images to disk, loads them instantly on subsequent visits, and supports placeholder and error widgets out of the box. {v4}',
    correctionMessage:
        'Replace Image.network(url) with CachedNetworkImage(imageUrl: url) from the cached_network_image package, and add placeholder/errorWidget parameters for loading feedback.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      if (typeName == 'Image' && constructorName == 'network') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Future rule: avoid-gesture-detector-in-scrollview
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when GestureDetector is used around a scrollable widget.
///
/// Example of **bad** code:
/// ```dart
/// GestureDetector(
///   onTap: () {},
///   child: ListView(...),  // Conflicts with scroll gestures
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView(
///   children: [
///     GestureDetector(onTap: () {}, child: ListItem()),
///   ],
/// )
/// ```
class AvoidStatefulWidgetInListRule extends SaropaLintRule {
  AvoidStatefulWidgetInListRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_stateful_widget_in_list',
    '[avoid_stateful_widget_in_list] StatefulWidget created inside a ListView.builder callback loses its State when scrolled off-screen and recreated, causing input fields to reset, animations to restart, and expanded/collapsed states to revert. The framework cannot preserve State for widgets without stable keys in a lazily-built list. {v6}',
    correctionMessage:
        'Add a ValueKey with a stable identifier (e.g. item.id) to the StatefulWidget, or lift mutable state out of the list item into a parent state manager.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // This would need type resolution to check if widget extends StatefulWidget
    // For now, we'll check for common patterns
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'builder') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'ListView' && target.name != 'GridView') return;

      // Check itemBuilder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'itemBuilder') {
          // Check if builder creates widgets without keys
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            final FunctionBody body = builderExpr.body;
            if (body is ExpressionFunctionBody) {
              final Expression expr = body.expression;
              if (expr is InstanceCreationExpression) {
                // Check if key is provided
                bool hasKey = false;
                for (final Expression argExpr in expr.argumentList.arguments) {
                  if (argExpr is NamedExpression &&
                      argExpr.name.label.name == 'key') {
                    hasKey = true;
                    break;
                  }
                }
                if (!hasKey) {
                  // Warn for any widget without key in list builder
                  reporter.atNode(expr.constructorName, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Future rule: prefer-opacity-over-color-alpha
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// Warns when Color.withAlpha/withOpacity is used instead of Opacity widget.
///
/// Example of **bad** code:
/// ```dart
/// Container(
///   color: Colors.red.withOpacity(0.5),
///   child: ExpensiveWidget(),  // Still fully rendered
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Opacity(
///   opacity: 0.5,
///   child: Container(
///     color: Colors.red,
///     child: ExpensiveWidget(),
///   ),
/// )
/// // Or better, use AnimatedOpacity for animations
/// ```
class AvoidEmptyTextWidgetsRule extends SaropaLintRule {
  AvoidEmptyTextWidgetsRule() : super(code: _code);

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceEmptyTextWithSizedBoxFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'avoid_empty_text_widgets',
    "[avoid_empty_text_widgets] Text widget with an empty string ('') still occupies space based on the inherited text style's line height, creating invisible layout artifacts. It also participates in accessibility announcements, confusing screen readers with blank text nodes that convey no information. {v2}",
    correctionMessage:
        'Replace Text(\'\') with SizedBox.shrink() for a zero-size placeholder, or remove the widget entirely if conditional display is intended.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Text') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // First argument should be the text string
      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) return; // Skip if no positional arg

      // Check for empty string literal
      if (firstArg is SimpleStringLiteral && firstArg.value.isEmpty) {
        reporter.atNode(node);
      } else if (firstArg is StringInterpolation &&
          firstArg.elements.length == 1) {
        final firstElement = firstArg.elements.first;
        if (firstElement is InterpolationString && firstElement.value.isEmpty) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when FontWeight is specified using numeric w-values instead of named constants.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// While FontWeight supports w100-w900 numeric values, using named constants
/// like FontWeight.normal or FontWeight.bold is more readable.
///
/// Example of **bad** code:
/// ```dart
/// TextStyle(fontWeight: FontWeight.w400)
/// TextStyle(fontWeight: FontWeight.w700)
/// ```
///
/// Example of **good** code:
/// ```dart
/// TextStyle(fontWeight: FontWeight.normal)  // w400
/// TextStyle(fontWeight: FontWeight.bold)    // w700
/// ```
class AvoidFontWeightAsNumberRule extends SaropaLintRule {
  AvoidFontWeightAsNumberRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_font_weight_as_number',
    '[avoid_font_weight_as_number] Numeric FontWeight values like w400 or w700 are less readable and harder to maintain than their named equivalents. Named constants (normal, bold) convey semantic intent, reduce lookup effort during code review, and align with design system terminology used by designers. {v2}',
    correctionMessage:
        'Replace numeric FontWeight values with named constants: w100=thin, w200=extraLight, w300=light, w400=normal, w500=medium, w600=semiBold, w700=bold, w800=extraBold, w900=black.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Mapping of numeric values to named constants
  static const Map<String, String> _weightMapping = <String, String>{
    'w400': 'normal',
    'w700': 'bold',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'FontWeight') return;

      final String identifier = node.identifier.name;
      if (_weightMapping.containsKey(identifier)) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceFontWeightNumberFix(context: context),
  ];
}

/// Warns when Container is used only for whitespace/spacing.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// SizedBox is more efficient than Container when you only need to add
/// spacing. Container has additional overhead from decoration handling.
///
/// Example of **bad** code:
/// ```dart
/// Container(width: 16)
/// Container(height: 8)
/// Container(width: 10, height: 10)
/// ```
///
/// Example of **good** code:
/// ```dart
/// SizedBox(width: 16)
/// SizedBox(height: 8)
/// SizedBox.square(dimension: 10)
/// ```
class AvoidMultipleMaterialAppsRule extends SaropaLintRule {
  AvoidMultipleMaterialAppsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_multiple_material_apps',
    '[avoid_multiple_material_apps] Multiple MaterialApp (or CupertinoApp) widgets in the tree create separate Navigator stacks, separate Theme contexts, and independent Locale/MediaQuery scopes. This breaks navigation (pushNamed cannot reach routes in the other app), causes theme inconsistencies, and doubles memory usage for shared resources. {v2}',
    correctionMessage:
        'Keep a single MaterialApp at the root. For sub-navigators, use Navigator widgets or a nested Router instead of adding another MaterialApp.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _appWidgets = <String>{
    'MaterialApp',
    'CupertinoApp',
    'WidgetsApp',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_appWidgets.contains(typeName)) return;

      // Check if any parent is also an App widget
      if (_hasAppAncestor(node)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _hasAppAncestor(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (_appWidgets.contains(typeName)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when deprecated RawKeyboardListener is used.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// RawKeyboardListener is deprecated. Use KeyboardListener or Focus widget
/// with onKeyEvent instead.
///
/// Example of **bad** code:
/// ```dart
/// RawKeyboardListener(
///   focusNode: _focusNode,
///   onKey: (event) { },
///   child: child,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// KeyboardListener(
///   focusNode: _focusNode,
///   onKeyEvent: (event) { },
///   child: child,
/// )
/// ```
class AvoidRawKeyboardListenerRule extends SaropaLintRule {
  AvoidRawKeyboardListenerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceRawKeyboardListenerFix(context: context),
  ];

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_raw_keyboard_listener',
    '[avoid_raw_keyboard_listener] RawKeyboardListener is deprecated since Flutter 3.18. It uses the legacy RawKeyEvent system that does not correctly handle key mapping across platforms, missing modifier keys and producing inconsistent key codes. The replacement KeyboardListener uses the modern KeyEvent system with proper platform key mapping. {v4}',
    correctionMessage:
        'Replace RawKeyboardListener with KeyboardListener (or Focus with onKeyEvent) which uses the modern HardwareKeyboard / KeyEvent API for correct cross-platform input handling.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'RawKeyboardListener') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when ImageRepeat is used on Image widgets.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// ImageRepeat is rarely needed and often indicates a design issue.
/// Consider using a pattern image or tiled background instead.
///
/// Example of **bad** code:
/// ```dart
/// Image.asset(
///   'image.png',
///   repeat: ImageRepeat.repeat,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.asset('image.png')
/// ```
class AvoidImageRepeatRule extends SaropaLintRule {
  AvoidImageRepeatRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_image_repeat',
    '[avoid_image_repeat] ImageRepeat tiles the image across the available space, which is rarely the intended behavior for photos or icons and usually signals a misconfigured decoration. Tiled images consume additional GPU memory for the repeated texture and can produce visual artifacts at tile boundaries on different screen densities. {v4}',
    correctionMessage:
        'Remove the repeat parameter (defaults to ImageRepeat.noRepeat), or if tiling is intentional, use a dedicated pattern asset designed for seamless repetition.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name == 'ImageRepeat' &&
          node.identifier.name != 'noRepeat') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Icon widget has explicit size override.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v2
///
/// Instead of overriding icon size on individual Icon widgets,
/// use IconTheme to set consistent sizing.
///
/// Example of **bad** code:
/// ```dart
/// Icon(Icons.home, size: 24)
/// ```
///
/// Example of **good** code:
/// ```dart
/// IconTheme(
///   data: IconThemeData(size: 24),
///   child: Icon(Icons.home),
/// )
/// ```
class AvoidIconSizeOverrideRule extends SaropaLintRule {
  AvoidIconSizeOverrideRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_icon_size_override',
    '[avoid_icon_size_override] Setting icon size directly on individual Icon widgets scatters sizing values throughout the codebase, causing inconsistencies when the design system changes. IconTheme provides a single point of control for icon sizing within a subtree, keeping all icons consistent and easier to update. {v2}',
    correctionMessage:
        'Remove the size parameter from the Icon widget and wrap the relevant subtree with IconTheme(data: IconThemeData(size: 24), child: ...) for centralized sizing.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Icon') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'size') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }
}

/// Warns when GestureDetector is used with only onTap.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// For simple tap interactions with Material design feedback,
/// InkWell provides better UX with ripple effects.
///
/// Example of **bad** code:
/// ```dart
/// GestureDetector(
///   onTap: () { },
///   child: MyWidget(),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// InkWell(
///   onTap: () { },
///   child: MyWidget(),
/// )
/// ```
class PreferInkwellOverGestureRule extends SaropaLintRule {
  PreferInkwellOverGestureRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceGestureWithInkWellFix(context: context),
  ];

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_inkwell_over_gesture',
    '[prefer_inkwell_over_gesture] GestureDetector with onTap provides no visual feedback when tapped, leaving users unsure whether their tap registered. InkWell produces the Material Design ripple effect that confirms interaction, improving perceived responsiveness and matching platform conventions users expect. {v4}',
    correctionMessage:
        'Replace GestureDetector(onTap: ...) with InkWell(onTap: ...) to get built-in ripple feedback. Ensure a Material ancestor exists in the tree for the ripple to render.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _simpleGestures = <String>{
    'onTap',
    'onTapDown',
    'onTapUp',
    'onTapCancel',
    'onDoubleTap',
    'onLongPress',
  };

  static const Set<String> _complexGestures = <String>{
    'onPanStart',
    'onPanUpdate',
    'onPanEnd',
    'onScaleStart',
    'onScaleUpdate',
    'onScaleEnd',
    'onHorizontalDragStart',
    'onHorizontalDragUpdate',
    'onVerticalDragStart',
    'onVerticalDragUpdate',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GestureDetector') return;

      bool hasSimple = false;
      bool hasComplex = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (_simpleGestures.contains(name)) hasSimple = true;
          if (_complexGestures.contains(name)) hasComplex = true;
        }
      }

      if (hasSimple && !hasComplex) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when FittedBox contains a Text widget.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// FittedBox scales its child to fit, which can cause text to become
/// unreadable or distorted. Use maxLines and overflow instead.
///
/// Example of **bad** code:
/// ```dart
/// FittedBox(child: Text('Long text'))
/// ```
///
/// Example of **good** code:
/// ```dart
/// Text('Long text', maxLines: 2, overflow: TextOverflow.ellipsis)
/// ```
class AvoidFittedBoxForTextRule extends SaropaLintRule {
  AvoidFittedBoxForTextRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_fitted_box_for_text',
    '[avoid_fitted_box_for_text] FittedBox scales Text widgets uniformly, shrinking the entire text to fit the container. This ignores the user accessibility text scaling preference, can render text unreadably small on narrow screens, and defeats the purpose of responsive text layout. Use text-specific overflow handling instead. {v3}',
    correctionMessage:
        'Remove FittedBox and use maxLines with TextOverflow.ellipsis to handle long text, or use AutoSizeText for controlled text scaling that respects minimum font sizes.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'FittedBox') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          if (_isTextWidget(arg.expression)) {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
      }
    });
  }

  bool _isTextWidget(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final String name = expr.constructorName.type.name.lexeme;
      return name == 'Text' || name == 'RichText' || name == 'SelectableText';
    }
    return false;
  }
}

/// Warns when ListView is used with many children instead of ListView.builder.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: require_list_view_builder
///
/// ListView with children list builds all items at once.
/// Use ListView.builder for lazy loading with large lists.
///
/// Example of **bad** code:
/// ```dart
/// ListView(children: List.generate(100, (i) => ListTile()))
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView.builder(itemCount: 100, itemBuilder: (ctx, i) => ListTile())
/// ```
class AvoidOpacityAnimationRule extends SaropaLintRule {
  AvoidOpacityAnimationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceOpacityWithFadeTransitionFix(context: context),
  ];

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_opacity_animation',
    '[avoid_opacity_animation] Animating the Opacity widget via setState triggers a full rebuild of the child subtree on every frame, which is expensive for complex children. FadeTransition applies opacity changes directly on the compositing layer without rebuilding, achieving the same visual effect with significantly less CPU and GPU overhead. {v3}',
    correctionMessage:
        'Replace the Opacity widget with FadeTransition(opacity: animation, child: ...) driven by an AnimationController, so opacity changes happen at the compositing layer.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Opacity') return;

      if (_isInsideAnimationBuilder(node)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _isInsideAnimationBuilder(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 10) {
      if (current is InstanceCreationExpression) {
        final String name = current.constructorName.type.name.lexeme;
        if (name == 'AnimatedBuilder' || name == 'TweenAnimationBuilder') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when SizedBox.expand() is used.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// SizedBox.expand() fills all available space which can cause layout issues.
///
/// Example of **bad** code:
/// ```dart
/// SizedBox.expand(child: MyWidget())
/// ```
///
/// Example of **good** code:
/// ```dart
/// SizedBox(width: double.infinity, height: 200, child: MyWidget())
/// ```
class PreferSelectableTextRule extends SaropaLintRule {
  PreferSelectableTextRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceTextWithSelectableFix(context: context),
  ];

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_selectable_text',
    '[prefer_selectable_text] Long-form text displayed with the Text widget cannot be selected or copied by users, frustrating those who need to copy error messages, addresses, phone numbers, or reference codes. SelectableText enables native text selection with copy support at no additional performance cost. {v3}',
    correctionMessage:
        'Replace Text with SelectableText for content users may want to copy (errors, IDs, addresses, etc.). Use SelectableText.rich for styled spans.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _minLength = 100;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Text') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) return;

      if (firstArg is SimpleStringLiteral &&
          firstArg.value.length >= _minLength) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Row/Column uses SizedBox for spacing instead of spacing param.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Flutter 3.10+ introduced spacing parameter for Row, Column, Wrap, and Flex.
///
/// Example of **bad** code:
/// ```dart
/// Column(children: [Text('A'), SizedBox(height: 8), Text('B')])
/// ```
///
/// Example of **good** code:
/// ```dart
/// Column(spacing: 8, children: [Text('A'), Text('B')])
/// ```
class AvoidMaterial2FallbackRule extends SaropaLintRule {
  AvoidMaterial2FallbackRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveMaterial2FallbackFix(context: context),
  ];

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_material2_fallback',
    '[avoid_material2_fallback] Explicitly setting useMaterial3: false forces the app back to the deprecated Material 2 design system, which will receive no new component updates or accessibility improvements. Material 2 components may also be removed in future Flutter releases, creating a migration burden. {v3}',
    correctionMessage:
        'Remove useMaterial3: false (M3 is the default since Flutter 3.16) or set it to true. Migrate M2-specific theming to M3 ColorScheme and typography.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'ThemeData') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'useMaterial3') {
            final Expression valueExpr = arg.expression;
            if (valueExpr is BooleanLiteral && !valueExpr.value) {
              reporter.atNode(arg);
            }
          }
        }
      }
    });
  }
}

/// Warns when using OverlayEntry instead of the declarative OverlayPortal.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// OverlayPortal (Flutter 3.10+) provides a declarative API for overlays
/// that integrates better with the widget tree and InheritedWidgets.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// late OverlayEntry _overlayEntry;
///
/// void showOverlay() {
///   _overlayEntry = OverlayEntry(
///     builder: (context) => MyOverlayWidget(),
///   );
///   Overlay.of(context).insert(_overlayEntry);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// final _controller = OverlayPortalController();
///
/// OverlayPortal(
///   controller: _controller,
///   overlayChildBuilder: (context) => MyOverlayWidget(),
///   child: MyWidget(),
/// )
/// ```
class PreferOverlayPortalRule extends SaropaLintRule {
  PreferOverlayPortalRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_overlay_portal',
    '[prefer_overlay_portal] Consider using OverlayPortal instead of OverlayEntry. {v4}',
    correctionMessage:
        'OverlayPortal provides a declarative API that integrates '
        'with InheritedWidgets (Flutter 3.10+).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'OverlayEntry') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when using third-party carousel packages instead of CarouselView.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// CarouselView (Flutter 3.24+) is a built-in Material 3 carousel widget
/// that provides standard carousel behavior without external dependencies.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// import 'package:carousel_slider/carousel_slider.dart';
///
/// CarouselSlider(
///   items: items,
///   options: CarouselOptions(),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// CarouselView(
///   itemExtent: 300,
///   children: items,
/// )
/// ```
class PreferCarouselViewRule extends SaropaLintRule {
  PreferCarouselViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_carousel_view',
    '[prefer_carousel_view] Third-party carousel package adds dependency maintenance overhead, increases app size, and may not follow Material 3 design guidelines. The built-in CarouselView widget (Flutter 3.24+) provides standard M3 carousel behavior with accessibility support, animation curves, and theme integration out of the box. {v3}',
    correctionMessage:
        'Replace the third-party carousel with CarouselView(children: items) from the Flutter framework. It supports item extent, shrink extent, and standard scroll physics.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Known third-party carousel packages and their main widgets
  static const Set<String> _carouselWidgets = <String>{
    'CarouselSlider',
    'PagedCarousel',
    'Carousel',
    'FlutterCarousel',
  };

  static const Set<String> _carouselPackages = <String>{
    'carousel_slider',
    'flutter_carousel_slider',
    'flutter_carousel_widget',
    'card_swiper',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check for carousel widget constructors
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (_carouselWidgets.contains(typeName)) {
        reporter.atNode(node.constructorName, code);
      }
    });

    // Check for carousel package imports
    context.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      for (final String pkg in _carouselPackages) {
        if (uri.startsWith('package:$pkg/')) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when using showSearch/SearchDelegate instead of SearchAnchor.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// SearchAnchor (Flutter 3.10+) is the Material 3 search component that
/// provides a modern, declarative search UI pattern.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// IconButton(
///   icon: Icon(Icons.search),
///   onPressed: () {
///     showSearch(
///       context: context,
///       delegate: MySearchDelegate(),
///     );
///   },
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// SearchAnchor(
///   builder: (context, controller) {
///     return IconButton(
///       icon: Icon(Icons.search),
///       onPressed: () => controller.openView(),
///     );
///   },
///   suggestionsBuilder: (context, controller) {
///     return [/* suggestions */];
///   },
/// )
/// ```
class PreferSearchAnchorRule extends SaropaLintRule {
  PreferSearchAnchorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_search_anchor',
    '[prefer_search_anchor] showSearch with SearchDelegate uses an imperative API that bypasses the widget tree, cannot access InheritedWidgets from the parent context, and follows Material 2 patterns. SearchAnchor (Flutter 3.10+) provides a declarative, widget-based search with full M3 styling and theme integration. {v4}',
    correctionMessage:
        'Replace showSearch/SearchDelegate with SearchAnchor and SearchAnchor.bar, which integrate into the widget tree and support suggestionsBuilder for async search results.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check for showSearch() calls
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'showSearch') {
        reporter.atNode(node);
      }
    });

    // Check for SearchDelegate subclasses
    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'SearchDelegate') {
          reporter.atNode(extendsClause);
        }
      }
    });
  }
}

/// Warns when using GestureDetector for tap-outside-to-dismiss patterns.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// TapRegion (Flutter 3.10+) provides a cleaner API for detecting taps
/// outside a widget, commonly used for dismissing popups, dropdowns, etc.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Stack(
///   children: [
///     GestureDetector(
///       onTap: () => Navigator.pop(context),
///       child: Container(color: Colors.black54),
///     ),
///     Center(child: MyPopup()),
///   ],
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// TapRegion(
///   onTapOutside: (_) => Navigator.pop(context),
///   child: MyPopup(),
/// )
/// ```
class PreferTapRegionForDismissRule extends SaropaLintRule {
  PreferTapRegionForDismissRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_tap_region_for_dismiss',
    '[prefer_tap_region_for_dismiss] Manual tap-outside detection using GestureDetector or Focus requires tracking tap locations and comparing against widget bounds, which is error-prone and breaks with nested interactive elements. TapRegion (Flutter 3.10+) handles this pattern correctly out of the box, including group regions for linked elements. {v4}',
    correctionMessage:
        'Wrap the dismissible content with TapRegion(onTapOutside: (_) => dismiss()) for reliable tap-outside detection. Use TapRegion.groupId to link multiple regions.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GestureDetector') return;

      // Check if this looks like a dismiss pattern
      bool hasOnTap = false;
      bool hasDismissPattern = false;

      bool looksLikeBarrier = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;

          // Look for onTap callback
          if (argName == 'onTap') {
            hasOnTap = true;

            // Check if the callback contains dismiss-like calls
            final Expression callback = arg.expression;
            final String callbackSource = callback.toSource().toLowerCase();
            if (callbackSource.contains('pop') ||
                callbackSource.contains('dismiss') ||
                callbackSource.contains('close') ||
                callbackSource.contains('hide')) {
              hasDismissPattern = true;
            }
          }

          // Check for barrier-like child (transparent/semi-transparent container)
          if (argName == 'child') {
            final Expression childExpr = arg.expression;
            if (childExpr is InstanceCreationExpression) {
              final String childName =
                  childExpr.constructorName.type.name.lexeme;
              // Container/ColoredBox with color often indicates barrier
              if (childName == 'Container' || childName == 'ColoredBox') {
                for (final Expression childArg
                    in childExpr.argumentList.arguments) {
                  if (childArg is NamedExpression &&
                      childArg.name.label.name == 'color') {
                    // Has a color, likely a barrier
                    looksLikeBarrier = true;
                  }
                }
              }
            }
          }
        }
      }

      // Report if it's onTap with dismiss pattern, or onTap with barrier-like child
      if (hasOnTap && (hasDismissPattern || looksLikeBarrier)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Text widgets with dynamic content lack overflow handling.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// Text displaying dynamic content (variables, user input) can overflow
/// unexpectedly. Adding `overflow` or `maxLines` ensures graceful handling.
///
/// Only flags Text widgets that:
/// - Use variable interpolation or non-literal strings
/// - Are inside Expanded, Flexible, or constrained containers
///
/// **BAD:**
/// ```dart
/// Text(userName) // Dynamic content may overflow
/// Text('$firstName $lastName') // Interpolated string
/// Expanded(child: Text(description)) // Constrained width
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(userName, overflow: TextOverflow.ellipsis, maxLines: 1)
/// Text('OK') // Static short text is fine
/// Text('Submit', maxLines: 1) // Has maxLines
/// ```
class AvoidGestureWithoutBehaviorRule extends SaropaLintRule {
  AvoidGestureWithoutBehaviorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_gesture_without_behavior',
    '[avoid_gesture_without_behavior] GestureDetector without explicit HitTestBehavior defaults to deferToChild, which only detects taps on painted pixels of the child. Empty areas within the GestureDetector bounds are ignored, causing missed taps that confuse users. Specifying the behavior makes the tap target boundaries explicit and predictable. {v5}',
    correctionMessage:
        'Add behavior: HitTestBehavior.opaque to detect taps on the full bounding box, or .translucent to detect taps while allowing pass-through to widgets behind.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GestureDetector') return;

      // Check if behavior is specified
      bool hasBehavior = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'behavior') {
          hasBehavior = true;
          break;
        }
      }

      if (!hasBehavior) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons don't prevent double-tap submissions.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v4
///
/// Double-tapping a submit button can cause duplicate API calls,
/// payments, or other unintended side effects.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () => submitForm(),
///   child: Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: isSubmitting ? null : () => submitForm(),
///   child: isSubmitting ? CircularProgressIndicator() : Text('Submit'),
/// )
/// ```
class AvoidDoubleTapSubmitRule extends SaropaLintRule {
  AvoidDoubleTapSubmitRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_double_tap_submit',
    '[avoid_double_tap_submit] Submit button without double-tap protection can fire the onPressed callback multiple times before the first submission completes. This causes duplicate API requests, duplicate database entries, double charges in payment flows, and race conditions that corrupt application state. {v4}',
    correctionMessage:
        'Set onPressed to null (disabling the button) while the async operation is in progress, or use a debounce/throttle mechanism to ignore rapid successive taps.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
  };

  static const Set<String> _submitKeywords = <String>{
    'submit',
    'save',
    'send',
    'pay',
    'purchase',
    'confirm',
    'order',
    'checkout',
    'register',
    'signup',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_buttonWidgets.contains(typeName)) return;

      String? childText;
      Expression? onPressedExpr;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'child') {
            childText = arg.expression.toSource().toLowerCase();
          }
          if (argName == 'onPressed') {
            onPressedExpr = arg.expression;
          }
        }
      }

      // Check if this looks like a submit button
      if (childText == null) return;
      final text = childText;
      bool isSubmitButton = _submitKeywords.any(
        (String keyword) => text.contains(keyword),
      );
      if (!isSubmitButton) return;

      // Check if onPressed has any conditional logic
      if (onPressedExpr == null) return;
      final String onPressedSource = onPressedExpr.toSource();

      // If it's a simple function without null check, warn
      if (!onPressedSource.contains('?') &&
          !onPressedSource.contains('null') &&
          !onPressedSource.contains('isLoading') &&
          !onPressedSource.contains('isSubmitting') &&
          !onPressedSource.contains('_loading') &&
          !onPressedSource.contains('_submitting')) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons on web don't have mouse cursor configured.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v6
///
/// On web platforms, buttons should show appropriate cursors to
/// indicate interactivity.
///
/// **BAD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   child: Text('Click me'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   mouseCursor: SystemMouseCursors.click,
///   child: Text('Click me'),
/// )
/// ```
class PreferCursorForButtonsRule extends SaropaLintRule {
  PreferCursorForButtonsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_cursor_for_buttons',
    '[prefer_cursor_for_buttons] Interactive widget on web/desktop without a pointer cursor leaves the default arrow cursor, giving users no visual indication that the element is clickable. This violates web platform conventions and reduces discoverability of interactive elements, especially for GestureDetector-based custom buttons. {v6}',
    correctionMessage:
        'Add mouseCursor: SystemMouseCursors.click to GestureDetector or InkWell widgets that act as buttons. Built-in Material buttons handle this automatically.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'InkWell',
    'GestureDetector',
    'InkResponse',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_interactiveWidgets.contains(typeName)) return;

      bool hasOnTap = false;
      bool hasMouseCursor = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onTap' || argName == 'onPressed') {
            hasOnTap = true;
          }
          if (argName == 'mouseCursor') {
            hasMouseCursor = true;
          }
        }
      }

      if (hasOnTap && !hasMouseCursor) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when interactive widgets don't handle hover state.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v6
///
/// On web and desktop, hover states provide important visual feedback.
///
/// **BAD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   child: MyButton(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   onHover: (hovering) => setState(() => _isHovered = hovering),
///   child: MyButton(isHovered: _isHovered),
/// )
/// ```
class AvoidHardcodedTextStylesRule extends SaropaLintRule {
  AvoidHardcodedTextStylesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_hardcoded_text_styles',
    '[avoid_hardcoded_text_styles] Inline TextStyle with hardcoded fontSize, fontWeight, and color values creates scattered styling that drifts from the design system over time. Every hardcoded style must be updated individually when the design changes, and inconsistencies between screens become difficult to detect during code review. {v5}',
    correctionMessage:
        'Use Theme.of(context).textTheme (e.g. bodyMedium, titleLarge) for standard styles and .copyWith() for minor overrides. Define custom styles in a centralized theme extension.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextStyle') return;

      // Check if this TextStyle is used inline in a Text widget style argument
      final AstNode? parent = node.parent;
      if (parent is NamedExpression && parent.name.label.name == 'style') {
        final AstNode? grandparent = parent.parent?.parent;
        if (grandparent is InstanceCreationExpression) {
          final String parentType =
              grandparent.constructorName.type.name.lexeme;
          if (parentType == 'Text' ||
              parentType == 'RichText' ||
              parentType == 'DefaultTextStyle') {
            // Check for hardcoded values
            bool hasHardcodedValues = false;
            for (final Expression arg in node.argumentList.arguments) {
              if (arg is NamedExpression) {
                final String argName = arg.name.label.name;
                if (argName == 'fontSize' || argName == 'fontWeight') {
                  // Check if value is a literal
                  if (arg.expression is IntegerLiteral ||
                      arg.expression is DoubleLiteral) {
                    hasHardcodedValues = true;
                    break;
                  }
                }
              }
            }

            if (hasHardcodedValues) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when PageStorageKey is not used for scroll position preservation.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
///
/// Without PageStorageKey, scroll positions are lost when navigating
/// between screens.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(),
///   itemCount: 100,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   key: PageStorageKey('my_list'),
///   itemBuilder: (context, index) => ListTile(),
///   itemCount: 100,
/// )
/// ```
class PreferAssetImageForLocalRule extends SaropaLintRule {
  PreferAssetImageForLocalRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_asset_image_for_local',
    '[prefer_asset_image_for_local] FileImage reads from the device filesystem at runtime and is intended for user-generated content, not bundled assets. Using FileImage for assets bypasses Flutter asset resolution (density variants, locale fallbacks), is not supported on web, and fails if the file path does not exist on the target device. {v3}',
    correctionMessage:
        'Replace FileImage with AssetImage or use Image.asset() to load bundled assets through the Flutter asset pipeline with proper resolution-aware variant selection.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'FileImage') return;

      // Check if the file path looks like an asset path
      if (node.argumentList.arguments.isNotEmpty) {
        final String argSource = node.argumentList.arguments.first.toSource();
        if (argSource.contains('assets/') || argSource.contains('asset')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Warns when background images don't use BoxFit.cover.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v3
///
/// BoxFit.cover ensures the image fills the container without distortion.
///
/// **BAD:**
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     image: DecorationImage(image: AssetImage('bg.png')),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     image: DecorationImage(
///       image: AssetImage('bg.png'),
///       fit: BoxFit.cover,
///     ),
///   ),
/// )
/// ```
class PreferFitCoverForBackgroundRule extends SaropaLintRule {
  PreferFitCoverForBackgroundRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_fit_cover_for_background',
    '[prefer_fit_cover_for_background] Background DecorationImage without BoxFit.cover may show letterboxing, stretching, or empty space around the image on different screen aspect ratios. BoxFit.cover ensures the image fills the entire container while maintaining its aspect ratio, which is the standard behavior for background images. {v3}',
    correctionMessage:
        'Add fit: BoxFit.cover to DecorationImage so the image fills the container on all screen sizes without distortion. Crop alignment defaults to center.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'DecorationImage') return;

      bool hasFit = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'fit') {
          hasFit = true;
          break;
        }
      }

      if (!hasFit) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons with conditional onPressed don't customize disabled style.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
///
/// While Flutter buttons have default disabled styling, custom styles
/// provide better UX consistency across your app's design system.
///
/// Note: This rule suggests customization, not requirement. The default
/// disabled styling is functional but may not match your design.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: canSubmit ? submit : null,
///   child: Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: canSubmit ? submit : null,
///   style: ElevatedButton.styleFrom(
///     disabledBackgroundColor: Colors.grey.shade300,
///   ),
///   child: Text('Submit'),
/// )
/// ```
class AvoidGestureConflictRule extends SaropaLintRule {
  AvoidGestureConflictRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_gesture_conflict',
    '[avoid_gesture_conflict] Nested GestureDetector widgets compete in the gesture arena, causing unpredictable behavior where the inner detector wins some gestures and the outer wins others depending on timing. This leads to missed taps, swallowed swipes, and inconsistent interaction behavior that is difficult to debug. {v6}',
    correctionMessage:
        'Consolidate gesture handling into a single GestureDetector, or use RawGestureDetector with a custom gesture factory to coordinate nested gesture recognition explicitly.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GestureDetector' && typeName != 'InkWell') return;

      // Check if inside another GestureDetector
      AstNode? current = node.parent;
      int depth = 0;
      while (current != null && depth < 20) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'GestureDetector' || parentType == 'InkWell') {
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

/// Warns when large images are loaded without size constraints.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
///
/// Loading large images without constraints wastes memory.
///
/// **BAD:**
/// ```dart
/// Image.asset('large_photo.png') // Could be 4000x3000 pixels!
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.asset(
///   'large_photo.png',
///   width: 300,
///   height: 200,
///   cacheWidth: 300,
/// )
/// ```
class AvoidLargeImagesInMemoryRule extends SaropaLintRule {
  AvoidLargeImagesInMemoryRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_large_images_in_memory',
    '[avoid_large_images_in_memory] Image loaded without size constraints decodes at full resolution into GPU memory regardless of display size. A single uncompressed 4K image can consume 30-50 MB of memory, and lists of such images quickly exhaust available memory, causing OOM crashes on mobile devices. {v5}',
    correctionMessage:
        'Add width/height to constrain display size and cacheWidth/cacheHeight to limit decode resolution. Set cacheWidth to displayWidth * devicePixelRatio.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      // Check Image.asset and Image.network
      if (typeName != 'Image') return;
      if (constructorName != 'asset' && constructorName != 'network') return;

      bool hasWidth = false;
      bool hasHeight = false;
      bool hasCacheWidth = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'width') hasWidth = true;
          if (argName == 'height') hasHeight = true;
          if (argName == 'cacheWidth' || argName == 'cacheHeight') {
            hasCacheWidth = true;
          }
        }
      }

      // Warn if no size constraints at all
      if (!hasWidth && !hasHeight && !hasCacheWidth) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when LayoutBuilder is used inside a scrollable widget.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v6
///
/// LayoutBuilder in a scrollable can cause performance issues as
/// it rebuilds on every scroll.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [
///     LayoutBuilder(builder: (context, constraints) => ...),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) => ListView(
///     children: [...],
///   ),
/// )
/// ```
class PreferActionsAndShortcutsRule extends SaropaLintRule {
  PreferActionsAndShortcutsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_actions_and_shortcuts',
    '[prefer_actions_and_shortcuts] RawKeyboardListener requires manual key code matching and does not integrate with the Flutter intent system, making keyboard shortcuts invisible to accessibility tools and impossible to discover via keyboard shortcut overlays. The Actions/Shortcuts system provides composable, discoverable, and testable keyboard handling. {v6}',
    correctionMessage:
        'Replace with Shortcuts(shortcuts: {key: intent}, child: Actions(actions: {Intent: CallbackAction(...)}, child: ...)) for declarative keyboard handling.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'RawKeyboardListener' || typeName == 'KeyboardListener') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when GestureDetector doesn't handle long press for context menus.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v3
///
/// Long press is a common pattern for showing context menus on mobile.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => selectItem(),
///   child: ListTile(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   onTap: () => selectItem(),
///   onLongPress: () => showContextMenu(),
///   child: ListTile(...),
/// )
/// ```
class AvoidFindChildInBuildRule extends SaropaLintRule {
  AvoidFindChildInBuildRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_find_child_in_build',
    '[avoid_find_child_in_build] Creating findChildIndexCallback as a new closure inside the build method allocates a new function object on every rebuild. Since SliverChildBuilderDelegate uses this callback to optimize child reordering, a new instance defeats the identity check and forces unnecessary child lookups on every frame. {v4}',
    correctionMessage:
        'Extract findChildIndexCallback to a final field, a static method, or a top-level function so the same instance is reused across rebuilds.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'ListView' && typeName != 'GridView') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'findChildIndexCallback') {
          // Check if it's a lambda defined inline
          if (arg.expression is FunctionExpression) {
            // Check if we're in a build method
            AstNode? current = node.parent;
            while (current != null) {
              if (current is MethodDeclaration &&
                  current.name.lexeme == 'build') {
                reporter.atNode(arg);
                return;
              }
              current = current.parent;
            }
          }
        }
      }
    });
  }
}

/// Warns when Column/Row is used inside SingleChildScrollView without constraints.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v4
///
/// Without proper constraints, Column/Row may have unbounded height/width.
///
/// **BAD:**
/// ```dart
/// SingleChildScrollView(
///   child: Column(
///     children: [Expanded(child: Container())], // Expanded won't work!
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// SingleChildScrollView(
///   child: ConstrainedBox(
///     constraints: BoxConstraints(minHeight: viewportHeight),
///     child: Column(children: [...]),
///   ),
/// )
/// ```
class AvoidNullableWidgetMethodsRule extends SaropaLintRule {
  AvoidNullableWidgetMethodsRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_nullable_widget_methods',
    '[avoid_nullable_widget_methods] A method returning Widget? forces every call site to handle the null case, which clutters the widget tree with null checks and ternary expressions. Nullable widget returns also break composability because parent widgets expecting a non-null child cannot directly use the result. Returning a placeholder widget such as SizedBox.shrink() for empty states keeps the return type non-nullable and makes the widget tree consistent and predictable. {v2}',
    correctionMessage:
        'Return SizedBox.shrink() instead of null for empty states, or move the null check to the call site using conditional rendering (e.g. if (show) widget else SizedBox.shrink()).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip build method
      if (node.name.lexeme == 'build') return;

      // Check return type
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType) {
        final String typeName = returnType.name.lexeme;

        // Check if it's a Widget type
        if (typeName == 'Widget' || typeName.endsWith('Widget')) {
          // Check if it's nullable (has ? suffix)
          if (returnType.question != null) {
            reporter.atToken(node.name, code);
          }
        }
      }
    });

    // Also check function declarations (top-level functions)
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType) {
        final String typeName = returnType.name.lexeme;

        if (typeName == 'Widget' || typeName.endsWith('Widget')) {
          if (returnType.question != null) {
            reporter.atToken(node.name, code);
          }
        }
      }
    });
  }
}

/// Warns when OverflowBox is used without a comment explaining why.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// OverflowBox allows children to overflow parent bounds, which can cause
/// visual glitches. Require a comment explaining why overflow is intentional.
///
/// **BAD:**
/// ```dart
/// OverflowBox(
///   maxWidth: 300,
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // OverflowBox needed: menu must extend beyond AppBar bounds
/// OverflowBox(
///   maxWidth: 300,
///   child: MyWidget(),
/// )
/// ```
class AvoidNavigationInBuildRule extends SaropaLintRule {
  AvoidNavigationInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_navigation_in_build',
    '[avoid_navigation_in_build] Navigation in build() triggers during '
        'rebuild, causing infinite navigation loops or flickering screens. {v2}',
    correctionMessage:
        'Use WidgetsBinding.instance.addPostFrameCallback or move to callback.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _navigationMethods = <String>{
    'push',
    'pushNamed',
    'pushReplacement',
    'pushReplacementNamed',
    'pushAndRemoveUntil',
    'pushNamedAndRemoveUntil',
    'pop',
    'popAndPushNamed',
    'popUntil',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for Navigator.method or context.navigatorMethod via extensions
      final methodName = node.methodName.name;
      if (!_navigationMethods.contains(methodName)) return;

      final target = node.target;
      if (target == null) return;

      final targetSource = target.toSource();
      // Exact match to avoid FP on NavigatorHelper, CustomNavigator, etc.
      if (targetSource != 'Navigator' &&
          !targetSource.startsWith('Navigator.')) {
        return;
      }

      // Walk up to find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;
      bool inCallback = false;

      while (current != null) {
        if (current is FunctionExpression) {
          inCallback = true;
        }
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) return;
      if (enclosingMethod.name.lexeme != 'build') return;

      // If inside a callback in build, that's usually OK
      if (inCallback) return;

      // Check if in State<T> class or StatelessWidget
      final parent = enclosingMethod.parent;
      if (parent is! ClassDeclaration) return;

      reporter.atNode(node.methodName, code);
    });
  }
}

// =============================================================================
// Part 4: Additional Missing Parameter Rules
// =============================================================================

/// Warns when TextFormField is used without a Form ancestor.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: text_form_field_without_form, orphan_text_form_field
///
/// TextFormField features like validation only work inside a Form widget.
/// For standalone text input, use TextField instead.
///
/// **BAD:**
/// ```dart
/// Column(
///   children: [
///     TextFormField(  // validation won't work!
///       validator: (v) => v!.isEmpty ? 'Required' : null,
///     ),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Form(
///   child: TextFormField(
///     validator: (v) => v!.isEmpty ? 'Required' : null,
///   ),
/// )
/// // Or use TextField if no form validation needed
/// ```
///
/// **Note:** This rule uses heuristic detection since Form widgets may be
/// defined in parent files.
class AvoidLateWithoutGuaranteeRule extends SaropaLintRule {
  AvoidLateWithoutGuaranteeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_late_without_guarantee',
    '[avoid_late_without_guarantee] late field throws a LateInitializationError at runtime if accessed before assignment, and Dart provides no compile-time guarantee that initialization has occurred. This creates a hidden crash risk that is difficult to catch in testing and may only surface in specific user flows or edge cases. {v2}',
    correctionMessage:
        'Use a nullable type with null checks for fields that may not be initialized, or ensure initialization in the constructor or initState where the framework guarantees execution order.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      // Check for late keyword
      if (node.fields.lateKeyword == null) return;

      // Skip if it's late final with an initializer
      if (node.fields.isFinal) {
        for (final variable in node.fields.variables) {
          if (variable.initializer != null) return;
        }
      }

      // Check if in State<T> class
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'State') return;

      // Check if initialized in initState
      String? initStateBody;
      for (final member in parent.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'initState') {
          initStateBody = member.body.toSource();
          break;
        }
      }

      // Check each late variable
      for (final variable in node.fields.variables) {
        final varName = variable.name.lexeme;

        // If no initState or field not assigned in initState, warn
        if (initStateBody == null ||
            !initStateBody.contains('$varName =') &&
                !initStateBody.contains('$varName=')) {
          reporter.atNode(variable);
        }
      }
    });
  }
}

// =============================================================================
// Part 8: Cross-File Rules (Configuration Reminders)
// Note: Full validation requires reading native config files. These rules
// serve as reminders when package APIs are used.
// =============================================================================

/// Reminder to add NSPhotoLibraryUsageDescription for image_picker on iOS.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: ios_photo_permission, image_picker_plist
///
/// image_picker requires Info.plist entries on iOS.
///
/// **Required in ios/Runner/Info.plist:**
/// ```xml
/// <key>NSPhotoLibraryUsageDescription</key>
/// <string>App needs photo library access</string>
/// <key>NSCameraUsageDescription</key>
/// <string>App needs camera access</string>
/// ```
class AvoidStaticRouteConfigRule extends SaropaLintRule {
  AvoidStaticRouteConfigRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_static_route_config',
    '[avoid_static_route_config] Static router configuration prevents '
        'hot reload. Route changes require full restart. {v2}',
    correctionMessage:
        'Use a top-level final variable or a getter for the router instead.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _routerTypes = <String>{
    'GoRouter',
    'MaterialApp',
    'CupertinoApp',
    'AutoRouter',
    'AppRouter',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      // Check if static
      if (!node.isStatic) return;

      // Check if final
      if (node.fields.keyword?.keyword != Keyword.FINAL) return;

      // Check the type
      final TypeAnnotation? type = node.fields.type;
      if (type != null) {
        final String typeStr = type.toSource();
        for (final String routerType in _routerTypes) {
          if (typeStr.contains(routerType)) {
            reporter.atNode(node);
            return;
          }
        }
      }

      // Also check initializer for router creation
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer is InstanceCreationExpression) {
          final String typeName = initializer.constructorName.type.name.lexeme;
          if (_routerTypes.contains(typeName)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// Widget & Layout Best Practices (from v4.1.7)
// =============================================================================

/// Warns when complex positioning uses nested widgets instead of CustomSingleChildLayout.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
///
/// For complex single-child positioning logic, CustomSingleChildLayout is more
/// efficient than nested Positioned/Align/Transform widgets.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Stack(children: [
///     Positioned(
///       top: calculateTop(),
///       left: calculateLeft(),
///       child: Transform.rotate(
///         angle: calculateAngle(),
///         child: Align(
///           alignment: calculateAlignment(),
///           child: MyWidget(),
///         ),
///       ),
///     ),
///   ]);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return CustomSingleChildLayout(
///     delegate: MyLayoutDelegate(),
///     child: MyWidget(),
///   );
/// }
/// ```
class PreferFeatureFolderStructureRule extends SaropaLintRule {
  PreferFeatureFolderStructureRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_feature_folder_structure',
    '[prefer_feature_folder_structure] File in type-based folder. Prefer feature-based organization. Group files by feature (/auth, /profile) instead of type (/bloc, /ui) to improve scalability. {v3}',
    correctionMessage:
        'Group related files by feature (e.g. features/auth/login_bloc.dart, features/auth/login_screen.dart) so all code for a feature is co-located and can be modified, tested, and deleted as a unit.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _typeBasedFolderPattern = RegExp(
    r'/(blocs?|cubits?|providers?|models?|widgets?|screens?|pages?|views?)/',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check the file path
    final String filePath = context.filePath;

    if (_typeBasedFolderPattern.hasMatch(filePath)) {
      // Report on the compilation unit (file level)
      context.addCompilationUnit((CompilationUnit node) {
        // Only report once per file, on the first declaration
        if (node.declarations.isNotEmpty) {
          reporter.atNode(node.declarations.first, code);
        }
      });
    }
  }
}

/// Allowlisted bool parameter names used in Flutter SDK where bool is idiomatic.
const Set<String> _widgetBoolParamAllowlist = <String>{
  'enabled',
  'disabled',
  'autofocus',
  'obscureText',
  'readOnly',
  'expands',
  'autocorrect',
  'enableSuggestions',
  'selected',
  'checked',
  'dense',
  'wrapped',
  'visible',
  'value',
};

/// Warns when a widget constructor has named bool parameters (except allowlisted).
///
/// Prefer enums or widget decomposition for clearer call sites.
///
/// **Bad:**
/// ```dart
/// class UserCard extends StatelessWidget {
///   const UserCard({super.key, required this.isLoading, required this.showAvatar});
///   final bool isLoading;
///   final bool showAvatar;
///   ...
/// }
/// ```
///
/// **Good:**
/// ```dart
/// enum UserCardState { loading, loaded }
/// class UserCard extends StatelessWidget {
///   const UserCard({super.key, required this.state});
///   final UserCardState state;
///   ...
/// }
/// ```
class AvoidBoolInWidgetConstructorsRule extends SaropaLintRule {
  AvoidBoolInWidgetConstructorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_bool_in_widget_constructors',
    '[avoid_bool_in_widget_constructors] Widget constructor has a named bool parameter. Prefer an enum or widget decomposition for clearer call sites.',
    correctionMessage:
        'Replace with an enum, sealed class, or separate widgets so call sites are self-documenting.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;
      if (!_isWidgetClass(classDecl)) return;
      final FormalParameterList params = node.parameters;
      for (final FormalParameter p in params.parameters) {
        final FormalParameter inner = p is DefaultFormalParameter
            ? p.parameter
            : p;
        if (inner is! SimpleFormalParameter) continue;
        if (!inner.isNamed) continue;
        final String? name = inner.name?.lexeme;
        if (name == null || _widgetBoolParamAllowlist.contains(name)) continue;
        final TypeAnnotation? type = inner.type;
        if (type is! NamedType) continue;
        if (type.name.lexeme != 'bool') continue;
        reporter.atNode(inner);
      }
    });
  }

  bool _isWidgetClass(ClassDeclaration node) {
    final ExtendsClause? ext = node.extendsClause;
    if (ext != null) {
      final String sup = ext.superclass.name.lexeme;
      if (sup == 'StatelessWidget' ||
          sup == 'StatefulWidget' ||
          sup == 'Widget' ||
          sup == 'InheritedWidget' ||
          sup == 'InheritedNotifier' ||
          sup == 'InheritedModel' ||
          sup == 'RenderObjectWidget' ||
          sup.endsWith('Widget') ||
          sup == 'State') {
        return true;
      }
    }
    return false;
  }
}

/// Container constructor args that justify its use (layout/paint). Key and child are excluded.
const Set<String> _containerJustifyingArgNames = <String>{
  'alignment',
  'clipBehavior',
  'color',
  'constraints',
  'decoration',
  'foregroundDecoration',
  'height',
  'margin',
  'padding',
  'transform',
  'transformAlignment',
  'width',
};

/// Warns when a Container has only a child (or key + child), adding no value.
///
/// A Container with only `child` (and optionally `key`) is redundant; use the
/// child directly. Use Padding, ColoredBox, SizedBox, or Align when you need
/// those behaviors.
///
/// Since: v6.0.8 | Rule version: v1
///
/// **Bad:**
/// ```dart
/// Container(child: Text('Hello'));
/// ```
///
/// **Good:**
/// ```dart
/// Text('Hello');
/// Container(padding: EdgeInsets.all(8), child: Text('Hello'));
/// ```
class AvoidUnnecessaryContainersRule extends SaropaLintRule {
  AvoidUnnecessaryContainersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => const <String>{'Container('};

  static const LintCode _code = LintCode(
    'avoid_unnecessary_containers',
    '[avoid_unnecessary_containers] Container adds no value when it only has a child (and optionally a key). It adds an extra layer to the widget tree with no benefit. Remove the Container and use the child directly, or use Padding, ColoredBox, SizedBox, or Align when you need those behaviors.',
    correctionMessage:
        'Remove the unnecessary Container and use the child directly. If you need padding, color, or alignment, use Padding, ColoredBox, or Align instead.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final DartType? type = node.staticType;
      if (type is! InterfaceType) return;
      if (type.element.name != 'Container') return;
      final String? uri = type.element.library.uri.toString();
      if (uri == null || !uri.contains('flutter')) return;

      final Set<String> namedArgNames = <String>{};
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          namedArgNames.add(arg.name.label.name);
        }
      }

      if (namedArgNames.any(_containerJustifyingArgNames.contains)) return;

      reporter.atNode(node);
    });
  }
}

/// Warns when a non-const collection literal is passed to an @immutable constructor.
///
/// Use const on the literal to avoid allocating on every rebuild.
///
/// Since: v6.0.8 | Rule version: v1
///
/// **Bad:**
/// ```dart
/// BoxDecoration(boxShadow: [BoxShadow(color: Colors.black)]);
/// ```
///
/// **Good:**
/// ```dart
/// BoxDecoration(boxShadow: const [BoxShadow(color: Colors.black)]);
/// ```
class PreferConstLiteralsToCreateImmutablesRule extends SaropaLintRule {
  PreferConstLiteralsToCreateImmutablesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_const_literals_to_create_immutables',
    '[prefer_const_literals_to_create_immutables] Non-const collection literal passed to an immutable class. Add const to avoid allocating on every rebuild.',
    correctionMessage: 'Add the const keyword before the collection literal.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final DartType? type = node.staticType;
      if (type is! InterfaceType) return;
      if (!_isImmutableType(type)) return;

      for (final Expression arg in node.argumentList.arguments) {
        final Expression expr = arg is NamedExpression ? arg.expression : arg;
        if (expr is ListLiteral &&
            expr.constKeyword == null &&
            _allElementsConst(expr.elements)) {
          reporter.atNode(expr);
        } else if (expr is SetOrMapLiteral &&
            expr.constKeyword == null &&
            _allElementsConst(expr.elements)) {
          reporter.atNode(expr);
        }
      }
    });
  }

  static bool _isImmutableType(InterfaceType type) {
    for (InterfaceType? t = type; t != null; t = t.superclass) {
      if (t.element.name == 'Widget' ||
          t.element.name == 'StatelessWidget' ||
          t.element.name == 'StatefulWidget') {
        return true;
      }
    }
    return false;
  }

  static bool _allElementsConst(NodeList<CollectionElement> elements) {
    for (final CollectionElement e in elements) {
      if (e is SpreadElement || e is IfElement || e is ForElement) {
        return false;
      }
      if (e is Expression && !_isConstExpression(e)) {
        return false;
      }
      if (e is MapLiteralEntry) {
        if (!_isConstExpression(e.key) || !_isConstExpression(e.value)) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _isConstExpression(Expression e) {
    if (e is Literal) {
      return true;
    }
    if (e is InstanceCreationExpression && e.isConst) {
      return true;
    }
    return false;
  }
}
