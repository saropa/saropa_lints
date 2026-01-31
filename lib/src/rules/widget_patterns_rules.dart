// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

class AvoidIncorrectImageOpacityRule extends SaropaLintRule {
  const AvoidIncorrectImageOpacityRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_incorrect_image_opacity',
    problemMessage:
        '[avoid_incorrect_image_opacity] Wrapping an Image widget in an Opacity widget is inefficient and can cause performance issues, as it requires the image to be composited offscreen. Instead, use the Image widget’s color and colorBlendMode properties to achieve opacity effects directly, which is more performant and recommended by Flutter best practices.',
    correctionMessage:
        'Replace Opacity(child: Image(...)) with Image(..., color: color.withOpacity(x), colorBlendMode: BlendMode.modulate) to apply opacity efficiently. This avoids unnecessary compositing and improves rendering performance. See Flutter documentation for details on image opacity handling.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Opacity') return;

      // Find the child argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (_isImageWidget(childExpr)) {
            reporter.atNode(node, code);
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
  const AvoidMissingImageAltRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_missing_image_alt',
    problemMessage:
        '[avoid_missing_image_alt] This Image widget is missing a semanticLabel, which is essential for accessibility. Without a semanticLabel, screen readers cannot describe the image to visually impaired users, making your app less inclusive and potentially non-compliant with accessibility standards.',
    correctionMessage:
        'Add a descriptive semanticLabel to every Image widget to ensure it is accessible to screen readers. This improves accessibility for users with visual impairments and helps meet accessibility guidelines. Refer to Flutter’s accessibility documentation for best practices on semantic labels.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Image') return;

      _checkForSemanticLabel(node, reporter);
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Image') return;

      // Check for Image.asset, Image.network, etc.
      final String methodName = node.methodName.name;
      if (<String>['asset', 'network', 'file', 'memory'].contains(methodName)) {
        _checkForSemanticLabelInMethod(node, reporter);
      }
    });
  }

  void _checkForSemanticLabel(
      InstanceCreationExpression node, SaropaDiagnosticReporter reporter) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) =>
          arg is NamedExpression && arg.name.label.name == 'semanticLabel',
    );

    if (!hasSemanticLabel) {
      reporter.atNode(node, code);
    }
  }

  void _checkForSemanticLabelInMethod(
      MethodInvocation node, SaropaDiagnosticReporter reporter) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) =>
          arg is NamedExpression && arg.name.label.name == 'semanticLabel',
    );

    if (!hasSemanticLabel) {
      reporter.atNode(node, code);
    }
  }
}

/// Warns when `mounted` is referenced inside setState callback.
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
  const AvoidReturningWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_returning_widgets',
    problemMessage:
        '[avoid_returning_widgets] Defining methods that return widgets (other than the build method) can make your widget tree harder to read, test, and maintain. This practice hides widget structure in private methods, reducing code clarity and making it more difficult to leverage Flutter’s hot reload and widget inspector tools.',
    correctionMessage:
        'Refactor methods that return widgets into separate StatelessWidget or StatefulWidget classes. This improves code organization, enables better tooling support, and makes your UI easier to test and maintain. See Flutter documentation for best practices on widget composition.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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
/// Using shrinkWrap: true in nested scrollables can cause performance issues
/// as it forces the list to calculate the size of all children.

class AvoidUnnecessaryGestureDetectorRule extends SaropaLintRule {
  const AvoidUnnecessaryGestureDetectorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_gesture_detector',
    problemMessage:
        '[avoid_unnecessary_gesture_detector] GestureDetector wraps a child widget but has no gesture callbacks (onTap, onDoubleTap, onLongPress, etc.) defined, making it a redundant wrapper that adds an unnecessary layer to the widget tree and confuses maintainers reading the code.',
    correctionMessage:
        'Add at least one gesture callback (e.g. onTap, onLongPress) or remove the GestureDetector wrapper entirely to simplify the widget tree.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const PreferDefineHeroTagRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_define_hero_tag',
    problemMessage:
        '[prefer_define_hero_tag] Hero widget without an explicit tag defaults to the widget itself, causing conflicts when multiple Hero widgets exist on the same screen. Duplicate tags trigger runtime assertion errors that crash the app during navigation transitions.',
    correctionMessage:
        'Add a unique tag parameter to the Hero widget, such as a String constant or identifier that distinguishes it from other Hero widgets on the same route.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Hero') return;

      // Check if tag is defined
      final bool hasTag = node.argumentList.arguments.any(
        (Expression arg) =>
            arg is NamedExpression && arg.name.label.name == 'tag',
      );

      if (!hasTag) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when inline callbacks could be extracted to methods.
///
/// Long inline callbacks can make code harder to read. Consider extracting
/// them to named methods for better readability and testability.

class PreferExtractingCallbacksRule extends SaropaLintRule {
  const PreferExtractingCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_extracting_callbacks',
    problemMessage:
        '[prefer_extracting_callbacks] Inline callback exceeds a reasonable length, reducing readability and making the build method harder to maintain. Long inline closures obscure widget structure, complicate debugging, and prevent reuse of the callback logic across widgets.',
    correctionMessage:
        'Extract the callback body into a named method on the widget or state class. This improves readability, enables reuse, and simplifies testing.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Only check callbacks passed as arguments
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression && parent is! ArgumentList) return;

      // Check callback length
      final FunctionBody body = node.body;
      if (body is BlockFunctionBody) {
        final int lineCount = body.block.statements.length;
        if (lineCount > 5) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a file contains multiple public widget classes.
///
/// Each public widget should generally be in its own file for better
/// organization and maintainability.

class PreferSingleWidgetPerFileRule extends SaropaLintRule {
  const PreferSingleWidgetPerFileRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_single_widget_per_file',
    problemMessage:
        '[prefer_single_widget_per_file] File contains multiple public widget classes, making it harder to locate widgets by filename, increasing merge conflicts in team environments, and complicating code navigation. Each public widget deserves its own file for discoverability and maintainability.',
    correctionMessage:
        'Move each public widget class to its own file named after the widget (e.g. my_widget.dart). Keep private helper widgets in the same file as the public widget they support.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
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
  const PreferTextRichRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_text_rich',
    problemMessage:
        '[prefer_text_rich] RichText widget does not inherit DefaultTextStyle or respect textScaler from the widget tree, causing inconsistent text rendering across the app. Text.rich provides the same TextSpan capabilities while automatically inheriting the ambient text style and scaling settings.',
    correctionMessage:
        'Replace RichText(text: TextSpan(...)) with Text.rich(TextSpan(...)) to inherit DefaultTextStyle and textScaler from the widget tree automatically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'RichText') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when using Column inside SingleChildScrollView instead of ListView.
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
  const PreferWidgetPrivateMembersRule() : super(code: _codeField);

  static const LintCode _codeField = LintCode(
    name: 'prefer_widget_private_members',
    problemMessage:
        '[prefer_widget_private_members] Non-final public field in a widget class breaks the immutability contract of Flutter widgets. Mutable widget fields can cause unpredictable rebuilds, stale state, and hard-to-trace rendering bugs because the framework assumes widgets are immutable after construction.',
    correctionMessage:
        'Make the field final (preferred) or private with an underscore prefix. Widget fields should be set only via the constructor.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const LintCode _codeMethod = LintCode(
    name: 'prefer_widget_private_members',
    problemMessage:
        '[prefer_widget_private_members] Public helper method in a widget class exposes internal implementation details to consumers. This increases the public API surface, invites unintended coupling, and makes refactoring harder because external code may depend on methods that are not part of the widget contract.',
    correctionMessage:
        'Prefix the method name with an underscore to make it private (e.g. _buildHeader), keeping the widget API limited to its constructor parameters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _widgetBaseClasses = <String>{
    'StatelessWidget',
    'StatefulWidget',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
  const AvoidUncontrolledTextFieldRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_uncontrolled_text_field',
    problemMessage:
        '[avoid_uncontrolled_text_field] TextField without a TextEditingController loses programmatic access to the input value, making it impossible to pre-fill, clear, validate on demand, or read the text outside of onChanged. This leads to fragile state management and unexpected behavior during form submissions.',
    correctionMessage:
        'Create a TextEditingController in initState (and dispose it in dispose), then pass it to the TextField via the controller parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

/// Future rule: avoid-hardcoded-asset-paths
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
  const AvoidHardcodedAssetPathsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_asset_paths',
    problemMessage:
        '[avoid_hardcoded_asset_paths] Hardcoded asset path string is error-prone: typos produce silent runtime failures, path changes require find-and-replace across the codebase, and the compiler cannot verify the asset exists. Centralized asset references enable compile-time safety and single-source-of-truth for all asset paths.',
    correctionMessage:
        'Define asset paths in a constants class or use a code generator like flutter_gen to produce type-safe asset references (e.g. Assets.images.logo).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
          reporter.atNode(firstArg, code);
        }
      }
    });

    // Also check for AssetImage constructor
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AssetImage') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is StringLiteral) {
        final String? path = firstArg.stringValue;
        if (path != null &&
            (path.contains('assets/') || path.contains('images/'))) {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }
}

/// Future rule: avoid-print-in-production
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
  const AvoidPrintInProductionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_print_in_production',
    problemMessage:
        '[avoid_print_in_production] print() call found in production widget code. Print statements bypass structured logging, cannot be filtered by severity, pollute the console in release builds, and may inadvertently leak sensitive data. They also add unnecessary I/O overhead in production.',
    correctionMessage:
        'Replace with a logging framework (e.g. package:logging, or debugPrint for debug-only output) that supports log levels and can be silenced in release builds.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Skip test files
    final String path = resolver.path;
    if (path.contains('_test.dart') || path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;

      // Check if it's the top-level print function
      if (node.target == null) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutPrintFix()];
}

class _CommentOutPrintFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;
      if (node.target != null) return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the statement containing this invocation
      final AstNode? statement = _findContainingStatement(node);
      if (statement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out print statement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Comment out the statement to preserve developer intent history
        final String originalCode = statement.toSource();
        builder.addSimpleReplacement(
          SourceRange(statement.offset, statement.length),
          '// $originalCode',
        );
      });
    });
  }

  AstNode? _findContainingStatement(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is ExpressionStatement) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }
}

/// Future rule: avoid-catching-generic-exception
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
  const AvoidCatchingGenericExceptionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_catching_generic_exception',
    problemMessage:
        '[avoid_catching_generic_exception] Catching Exception or Object swallows all errors including programming bugs, assertion failures, and unexpected states that should crash visibly. This masks root causes, making bugs harder to diagnose and allowing the app to continue in a corrupted state.',
    correctionMessage:
        'Catch specific exception types (e.g. FormatException, HttpException, SocketException) so that unexpected errors propagate and are caught by error reporting.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final TypeAnnotation? exceptionType = node.exceptionType;

      // Catch without type catches everything
      if (exceptionType == null) {
        reporter.atNode(node, code);
        return;
      }

      // Check for generic types
      if (exceptionType is NamedType) {
        final String typeName = exceptionType.name.lexeme;
        if (typeName == 'Exception' ||
            typeName == 'Object' ||
            typeName == 'dynamic') {
          reporter.atNode(exceptionType, code);
        }
      }
    });
  }
}

/// Future rule: avoid-service-locator-overuse
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
  const AvoidServiceLocatorOveruseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_service_locator_overuse',
    problemMessage:
        '[avoid_service_locator_overuse] Service locator (e.g. GetIt.instance) called directly in a widget hides dependencies, makes the widget untestable without the full service container, and couples the UI layer to a specific DI framework. Constructor injection makes dependencies explicit and enables easy mocking in tests.',
    correctionMessage:
        'Pass the dependency through the widget constructor or use a DI-aware wrapper (e.g. Provider, Riverpod) so that tests can supply mock implementations without configuring a global container.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check build methods
      if (node.name.lexeme != 'build') return;

      // Find GetIt calls in build method
      node.body.accept(
        _ServiceLocatorFinder((MethodInvocation call) {
          reporter.atNode(call, code);
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
/// Warns when DateTime.now() is used where UTC might be more appropriate.
///
/// Example of code that might need UTC:
/// ```dart
/// final timestamp = DateTime.now();  // Consider DateTime.now().toUtc()
/// ```

class PreferUtcDateTimesRule extends SaropaLintRule {
  const PreferUtcDateTimesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_utc_datetimes',
    problemMessage:
        '[prefer_utc_datetimes] Local DateTime values shift meaning when serialized and deserialized across time zones, causing off-by-hours bugs in timestamps, scheduling, and data synchronization. Storing and transmitting dates in UTC eliminates timezone ambiguity and ensures consistent behavior across devices and servers.',
    correctionMessage:
        'Use DateTime.now().toUtc() or DateTime.utc() for timestamps intended for storage, API transmission, or cross-device synchronization. Convert to local time only for display.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Future rule: avoid-regex-in-loop
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
  const AvoidRegexInLoopRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_regex_in_loop',
    problemMessage:
        '[avoid_regex_in_loop] RegExp object constructed inside a loop body is re-compiled on every iteration, wasting CPU cycles on repeated pattern parsing. Regex compilation is expensive relative to matching, and this overhead multiplies with large data sets, causing noticeable jank in UI-driven code.',
    correctionMessage:
        'Declare the RegExp as a static final field or a local variable above the loop so it is compiled once and reused on each iteration.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr, code);
        }),
      );
    });

    context.registry.addWhileStatement((WhileStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr, code);
        }),
      );
    });

    context.registry.addDoStatement((DoStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr, code);
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
/// Warns when a method with no parameters just returns a value.
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
  const PreferGetterOverMethodRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_getter_over_method',
    problemMessage:
        '[prefer_getter_over_method] Zero-argument method that returns a value without side effects reads more naturally as a getter. Methods imply computation or side effects, while getters signal a simple property access. Using a getter clarifies intent and aligns with the Dart style guide convention.',
    correctionMessage:
        'Convert to a getter (e.g. String get name => _name;). Reserve methods for operations that have side effects or accept parameters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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
  const AvoidUnusedCallbackParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unused_callback_parameters',
    problemMessage:
        '[avoid_unused_callback_parameters] Callback parameter is declared but never referenced in the closure body, adding visual noise and misleading readers into thinking the value is needed. Unused parameters also trigger analyzer warnings and obscure the actual data flow of the callback.',
    correctionMessage:
        'Replace the unused parameter name with an underscore (_) or double underscore (__) to signal that the value is intentionally ignored.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      final NodeList<FormalParameter>? parameters = node.parameters?.parameters;
      if (parameters == null || parameters.isEmpty) return;

      // Get all identifiers used in the body
      final Set<String> usedIdentifiers = <String>{};
      node.body.visitChildren(_IdentifierCollector(usedIdentifiers));

      for (final FormalParameter param in parameters) {
        final String? name = param.name?.lexeme;
        if (name == null || name.startsWith('_')) continue;

        if (!usedIdentifiers.contains(name)) {
          reporter.atToken(param.name!, code);
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

class PreferSemanticWidgetNamesRule extends SaropaLintRule {
  const PreferSemanticWidgetNamesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_semantic_widget_names',
    problemMessage:
        '[prefer_semantic_widget_names] Generic Container widget used where a more specific widget communicates intent. Container combines padding, decoration, alignment, and sizing in one opaque widget, making it unclear which feature is actually needed. Specific widgets like SizedBox, DecoratedBox, Padding, or Align are more readable and more efficient.',
    correctionMessage:
        'Replace Container with the specific widget that matches the intended use: SizedBox for sizing, Padding for padding, DecoratedBox for decoration, or Align for alignment.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Container') {
        // Check what properties are used
        final Set<String> usedProps = <String>{};
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            usedProps.add(arg.name.label.name);
          }
        }

        // Suggest alternatives based on usage
        if (usedProps.length == 1) {
          if (usedProps.contains('decoration')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('width') ||
              usedProps.contains('height')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('padding')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('alignment')) {
            reporter.atNode(node.constructorName, code);
          }
        } else if (usedProps.length == 2 &&
            usedProps.contains('width') &&
            usedProps.contains('height')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-text-scale-factor
/// Warns when using deprecated textScaleFactor instead of textScaler.
///
/// Example of **bad** code:
/// ```dart
/// MediaQuery.textScaleFactorOf(context);
/// MediaQuery.of(context).textScaleFactor;
/// ```
///
/// Example of **good** code:
/// ```dart
/// MediaQuery.textScalerOf(context);
/// MediaQuery.of(context).textScaler;
/// ```

class AvoidTextScaleFactorRule extends SaropaLintRule {
  const AvoidTextScaleFactorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_text_scale_factor',
    problemMessage:
        '[avoid_text_scale_factor] textScaleFactor is deprecated since Flutter 3.16. It applies a linear multiplier that cannot express non-linear text scaling used by accessibility settings on modern platforms. The replacement textScaler API supports both linear and non-linear scaling, ensuring correct rendering for users with accessibility needs.',
    correctionMessage:
        'Replace textScaleFactor with textScaler: TextScaler.linear(factor), or use MediaQuery.textScalerOf(context) to read the ambient scaler.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for textScaleFactorOf method calls
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'textScaleFactorOf') {
        reporter.atNode(node.methodName, code);
      }
    });

    // Check for .textScaleFactor property access
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name == 'textScaleFactor') {
        reporter.atNode(node.propertyName, code);
      }
    });
  }
}

/// Future rule: prefer-widget-state-mixin
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
  const AvoidImageWithoutCacheRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_image_without_cache',
    problemMessage:
        '[avoid_image_without_cache] Image.network without cacheWidth or cacheHeight decodes the full-resolution image into memory, even when displayed at a smaller size. A 4000x3000 photo decoded at full resolution consumes ~48 MB of GPU memory, causing excessive memory usage and potential out-of-memory crashes on low-end devices.',
    correctionMessage:
        'Add cacheWidth and/or cacheHeight matching the display size (in logical pixels multiplied by devicePixelRatio) so Flutter decodes a smaller image into memory.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const PreferSplitWidgetConstRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_split_widget_const',
    problemMessage:
        '[prefer_split_widget_const] Large widget subtree with all-const children is rebuilt on every parent setState, even though its output never changes. Extracting it into a separate const widget class allows Flutter to skip rebuilding the entire subtree, reducing frame build times and improving scroll performance.',
    correctionMessage:
        'Extract the static subtree into its own StatelessWidget class with a const constructor, then instantiate it with const in the parent build method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const AvoidNavigatorPushWithoutRouteNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_navigator_push_without_route_name',
    problemMessage:
        '[avoid_navigator_push_without_route_name] Anonymous Navigator.push with inline MaterialPageRoute scatters route definitions throughout the codebase, making it impossible to see all routes in one place, complicating deep linking, and preventing analytics from tracking navigation paths by name.',
    correctionMessage:
        'Use Navigator.pushNamed with routes defined in a central route table, or adopt a declarative routing package (e.g. go_router) for type-safe navigation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const AvoidDuplicateWidgetKeysRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_widget_keys',
    problemMessage:
        '[avoid_duplicate_widget_keys] Multiple widgets in a list share the same Key value. Flutter uses keys to match old widgets with new widgets during reconciliation. Duplicate keys cause the framework to reuse the wrong element, leading to stale state, broken animations, and incorrect widget ordering after list mutations.',
    correctionMessage:
        'Assign a unique key to each widget in the list, using ValueKey with a stable identifier (e.g. item.id) rather than the list index.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
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
            reporter.atNode(keyNode, code);
          }
        }
      }
    });
  }

  String? _extractKeyString(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final NodeList<Expression> args = expr.argumentList.arguments;
      if (args.isNotEmpty && args.first is StringLiteral) {
        return (args.first as StringLiteral).stringValue;
      }
    } else if (expr is MethodInvocation && expr.methodName.name == 'ValueKey') {
      final NodeList<Expression> args = expr.argumentList.arguments;
      if (args.isNotEmpty && args.first is StringLiteral) {
        return (args.first as StringLiteral).stringValue;
      }
    }
    return null;
  }
}

/// Future rule: prefer-safe-area-consumer
/// Warns when SafeArea is used without considering when it's unnecessary.
///
/// Example of **bad** code:
/// ```dart
/// Scaffold(
///   body: SafeArea(  // Scaffold already handles safe area
///     child: ListView(...),
///   ),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Scaffold(
///   body: ListView(...),  // Scaffold handles safe area via appBar, bottomNavigationBar
/// )
/// ```

class PreferSafeAreaConsumerRule extends SaropaLintRule {
  const PreferSafeAreaConsumerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_safe_area_consumer',
    problemMessage:
        '[prefer_safe_area_consumer] SafeArea placed directly inside a Scaffold body is often redundant because Scaffold already insets its body below the AppBar and above the BottomNavigationBar. Doubling up on safe area handling wastes vertical space and can push content further from the edges than intended.',
    correctionMessage:
        'Remove SafeArea if the Scaffold has appBar or bottomNavigationBar that already consume safe area insets. Use SafeArea only when the Scaffold body extends behind system UI.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Scaffold') {
        // Check body argument
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'body') {
            if (arg.expression is InstanceCreationExpression) {
              final InstanceCreationExpression bodyExpr =
                  arg.expression as InstanceCreationExpression;
              if (bodyExpr.constructorName.type.name.lexeme == 'SafeArea') {
                reporter.atNode(bodyExpr.constructorName, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Future rule: avoid-unrestricted-text-field-length
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
  const AvoidUnrestrictedTextFieldLengthRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unrestricted_text_field_length',
    problemMessage:
        '[avoid_unrestricted_text_field_length] TextField without maxLength allows unbounded input, enabling users to paste megabytes of text that can freeze the UI, exhaust memory, and create oversized payloads for backend APIs. Setting maxLength protects against denial-of-service scenarios and enforces data integrity constraints.',
    correctionMessage:
        'Add the maxLength parameter with a reasonable limit (e.g. maxLength: 500) and optionally set maxLengthEnforcement to control truncation behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const PreferScaffoldMessengerMaybeOfRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_scaffold_messenger_maybeof',
    problemMessage:
        '[prefer_scaffold_messenger_maybeof] ScaffoldMessenger.of throws a FlutterError if no ScaffoldMessenger ancestor exists, crashing the app in contexts like dialogs, overlays, or tests without a Scaffold. Using maybeOf returns null instead, allowing graceful fallback when the messenger is unavailable.',
    correctionMessage:
        'Replace ScaffoldMessenger.of(context) with ScaffoldMessenger.maybeOf(context) and handle the null case, or verify the context has a Scaffold ancestor before calling .of.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const AvoidFormWithoutKeyRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_form_without_key',
    problemMessage:
        '[avoid_form_without_key] Form widget without a GlobalKey<FormState> makes it impossible to call validate(), save(), or reset() on the form state programmatically. Without a key, you cannot trigger field validation on submit, retrieve form values, or reset the form to its initial state.',
    correctionMessage:
        'Create a GlobalKey<FormState> field (e.g. final _formKey = GlobalKey<FormState>()) and pass it to the Form widget via the key parameter.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const AvoidMediaQueryInBuildRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_mediaquery_in_build',
    problemMessage:
        '[avoid_mediaquery_in_build] MediaQuery.of(context) subscribes to all MediaQueryData changes (size, padding, orientation, brightness, text scaling), causing unnecessary rebuilds when only one property is needed. Specific accessors like sizeOf or paddingOf subscribe to only the relevant property, significantly reducing rebuild frequency.',
    correctionMessage:
        'Replace MediaQuery.of(context).size with MediaQuery.sizeOf(context), .padding with MediaQuery.paddingOf(context), etc. These targeted methods were added in Flutter 3.10.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier &&
          target.name == 'MediaQuery' &&
          node.methodName.name == 'of') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Future rule: prefer-sliver-list-delegate
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
  const PreferCachedNetworkImageRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_cached_network_image',
    problemMessage:
        '[prefer_cached_network_image] Image.network re-downloads images every time the widget rebuilds or the user navigates back to the screen, wasting bandwidth and causing visible loading flicker. CachedNetworkImage persists images to disk, loads them instantly on subsequent visits, and supports placeholder and error widgets out of the box.',
    correctionMessage:
        'Replace Image.network(url) with CachedNetworkImage(imageUrl: url) from the cached_network_image package, and add placeholder/errorWidget parameters for loading feedback.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      if (typeName == 'Image' && constructorName == 'network') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Future rule: avoid-gesture-detector-in-scrollview
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
  const AvoidStatefulWidgetInListRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_stateful_widget_in_list',
    problemMessage:
        '[avoid_stateful_widget_in_list] StatefulWidget created inside a ListView.builder callback loses its State when scrolled off-screen and recreated, causing input fields to reset, animations to restart, and expanded/collapsed states to revert. The framework cannot preserve State for widgets without stable keys in a lazily-built list.',
    correctionMessage:
        'Add a ValueKey with a stable identifier (e.g. item.id) to the StatefulWidget, or lift mutable state out of the list item into a parent state manager.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This would need type resolution to check if widget extends StatefulWidget
    // For now, we'll check for common patterns
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const AvoidEmptyTextWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_empty_text_widgets',
    problemMessage:
        "[avoid_empty_text_widgets] Text widget with an empty string ('') still occupies space based on the inherited text style's line height, creating invisible layout artifacts. It also participates in accessibility announcements, confusing screen readers with blank text nodes that convey no information.",
    correctionMessage:
        'Replace Text(\'\') with SizedBox.shrink() for a zero-size placeholder, or remove the widget entirely if conditional display is intended.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Text') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // First argument should be the text string
      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) return; // Skip if no positional arg

      // Check for empty string literal
      if (firstArg is SimpleStringLiteral && firstArg.value.isEmpty) {
        reporter.atNode(node, code);
      } else if (firstArg is StringInterpolation &&
          firstArg.elements.length == 1 &&
          firstArg.elements.first is InterpolationString) {
        final InterpolationString str =
            firstArg.elements.first as InterpolationString;
        if (str.value.isEmpty) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceEmptyTextWithSizedBoxFix()];
}

class _ReplaceEmptyTextWithSizedBoxFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Text') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with SizedBox.shrink()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'const SizedBox.shrink()',
        );
      });
    });
  }
}

/// Warns when FontWeight is specified using numeric w-values instead of named constants.
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
  const AvoidFontWeightAsNumberRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_font_weight_as_number',
    problemMessage:
        '[avoid_font_weight_as_number] Numeric FontWeight values like w400 or w700 are less readable and harder to maintain than their named equivalents. Named constants (normal, bold) convey semantic intent, reduce lookup effort during code review, and align with design system terminology used by designers.',
    correctionMessage:
        'Replace numeric FontWeight values with named constants: w100=thin, w200=extraLight, w300=light, w400=normal, w500=medium, w600=semiBold, w700=bold, w800=extraBold, w900=black.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Mapping of numeric values to named constants
  static const Map<String, String> _weightMapping = <String, String>{
    'w400': 'normal',
    'w700': 'bold',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'FontWeight') return;

      final String identifier = node.identifier.name;
      if (_weightMapping.containsKey(identifier)) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceFontWeightNumberFix()];
}

class _ReplaceFontWeightNumberFix extends DartFix {
  static const Map<String, String> _weightMapping = <String, String>{
    'w400': 'normal',
    'w700': 'bold',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.prefix.name != 'FontWeight') return;

      final String identifier = node.identifier.name;
      final String? replacement = _weightMapping[identifier];
      if (replacement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with FontWeight.$replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'FontWeight.$replacement',
        );
      });
    });
  }
}

/// Warns when Container is used only for whitespace/spacing.
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
  const AvoidMultipleMaterialAppsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_multiple_material_apps',
    problemMessage:
        '[avoid_multiple_material_apps] Multiple MaterialApp (or CupertinoApp) widgets in the tree create separate Navigator stacks, separate Theme contexts, and independent Locale/MediaQuery scopes. This breaks navigation (pushNamed cannot reach routes in the other app), causes theme inconsistencies, and doubles memory usage for shared resources.',
    correctionMessage:
        'Keep a single MaterialApp at the root. For sub-navigators, use Navigator widgets or a nested Router instead of adding another MaterialApp.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _appWidgets = <String>{
    'MaterialApp',
    'CupertinoApp',
    'WidgetsApp',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const AvoidRawKeyboardListenerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_raw_keyboard_listener',
    problemMessage:
        '[avoid_raw_keyboard_listener] RawKeyboardListener is deprecated since Flutter 3.18. It uses the legacy RawKeyEvent system that does not correctly handle key mapping across platforms, missing modifier keys and producing inconsistent key codes. The replacement KeyboardListener uses the modern KeyEvent system with proper platform key mapping.',
    correctionMessage:
        'Replace RawKeyboardListener with KeyboardListener (or Focus with onKeyEvent) which uses the modern HardwareKeyboard / KeyEvent API for correct cross-platform input handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'RawKeyboardListener') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceRawKeyboardListenerFix()];
}

class _ReplaceRawKeyboardListenerFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'RawKeyboardListener') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with KeyboardListener',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'KeyboardListener',
        );
      });
    });
  }
}

/// Warns when ImageRepeat is used on Image widgets.
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
  const AvoidImageRepeatRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_image_repeat',
    problemMessage:
        '[avoid_image_repeat] ImageRepeat tiles the image across the available space, which is rarely the intended behavior for photos or icons and usually signals a misconfigured decoration. Tiled images consume additional GPU memory for the repeated texture and can produce visual artifacts at tile boundaries on different screen densities.',
    correctionMessage:
        'Remove the repeat parameter (defaults to ImageRepeat.noRepeat), or if tiling is intentional, use a dedicated pattern asset designed for seamless repetition.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name == 'ImageRepeat' &&
          node.identifier.name != 'noRepeat') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Icon widget has explicit size override.
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
  const AvoidIconSizeOverrideRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_icon_size_override',
    problemMessage:
        '[avoid_icon_size_override] Setting icon size directly on individual Icon widgets scatters sizing values throughout the codebase, causing inconsistencies when the design system changes. IconTheme provides a single point of control for icon sizing within a subtree, keeping all icons consistent and easier to update.',
    correctionMessage:
        'Remove the size parameter from the Icon widget and wrap the relevant subtree with IconTheme(data: IconThemeData(size: 24), child: ...) for centralized sizing.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Icon') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'size') {
          reporter.atNode(arg, code);
          return;
        }
      }
    });
  }
}

/// Warns when GestureDetector is used with only onTap.
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
  const PreferInkwellOverGestureRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_inkwell_over_gesture',
    problemMessage:
        '[prefer_inkwell_over_gesture] GestureDetector with onTap provides no visual feedback when tapped, leaving users unsure whether their tap registered. InkWell produces the Material Design ripple effect that confirms interaction, improving perceived responsiveness and matching platform conventions users expect.',
    correctionMessage:
        'Replace GestureDetector(onTap: ...) with InkWell(onTap: ...) to get built-in ripple feedback. Ensure a Material ancestor exists in the tree for the ripple to render.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceGestureWithInkWellFix()];
}

class _ReplaceGestureWithInkWellFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GestureDetector') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with InkWell',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'InkWell',
        );
      });
    });
  }
}

/// Warns when FittedBox contains a Text widget.
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
  const AvoidFittedBoxForTextRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_fitted_box_for_text',
    problemMessage:
        '[avoid_fitted_box_for_text] FittedBox scales Text widgets uniformly, shrinking the entire text to fit the container. This ignores the user accessibility text scaling preference, can render text unreadably small on narrow screens, and defeats the purpose of responsive text layout. Use text-specific overflow handling instead.',
    correctionMessage:
        'Remove FittedBox and use maxLines with TextOverflow.ellipsis to handle long text, or use AutoSizeText for controlled text scaling that respects minimum font sizes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const AvoidOpacityAnimationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_opacity_animation',
    problemMessage:
        '[avoid_opacity_animation] Animating the Opacity widget via setState triggers a full rebuild of the child subtree on every frame, which is expensive for complex children. FadeTransition applies opacity changes directly on the compositing layer without rebuilding, achieving the same visual effect with significantly less CPU and GPU overhead.',
    correctionMessage:
        'Replace the Opacity widget with FadeTransition(opacity: animation, child: ...) driven by an AnimationController, so opacity changes happen at the compositing layer.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceOpacityWithFadeTransitionFix()];
}

class _ReplaceOpacityWithFadeTransitionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with FadeTransition',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'FadeTransition',
        );
      });
    });
  }
}

/// Warns when SizedBox.expand() is used.
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
  const PreferSelectableTextRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_selectable_text',
    problemMessage:
        '[prefer_selectable_text] Long-form text displayed with the Text widget cannot be selected or copied by users, frustrating those who need to copy error messages, addresses, phone numbers, or reference codes. SelectableText enables native text selection with copy support at no additional performance cost.',
    correctionMessage:
        'Replace Text with SelectableText for content users may want to copy (errors, IDs, addresses, etc.). Use SelectableText.rich for styled spans.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _minLength = 100;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceTextWithSelectableFix()];
}

class _ReplaceTextWithSelectableFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with SelectableText',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'SelectableText',
        );
      });
    });
  }
}

/// Warns when Row/Column uses SizedBox for spacing instead of spacing param.
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
  const AvoidMaterial2FallbackRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_material2_fallback',
    problemMessage:
        '[avoid_material2_fallback] Explicitly setting useMaterial3: false forces the app back to the deprecated Material 2 design system, which will receive no new component updates or accessibility improvements. Material 2 components may also be removed in future Flutter releases, creating a migration burden.',
    correctionMessage:
        'Remove useMaterial3: false (M3 is the default since Flutter 3.16) or set it to true. Migrate M2-specific theming to M3 ColorScheme and typography.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'ThemeData') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'useMaterial3') {
            final Expression valueExpr = arg.expression;
            if (valueExpr is BooleanLiteral && !valueExpr.value) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RemoveMaterial2FallbackFix()];
}

class _RemoveMaterial2FallbackFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.name.label.name != 'useMaterial3') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Remove useMaterial3: false',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find and remove the argument including trailing comma if present
        int startOffset = node.offset;
        int endOffset = node.end;

        // Check for trailing comma
        final AstNode? parent = node.parent;
        if (parent is ArgumentList) {
          final int index = parent.arguments.indexOf(node);
          if (index >= 0) {
            // Check if there's a comma after this argument
            final String source =
                resolver.source.contents.data.substring(endOffset);
            final Match? commaMatch = RegExp(r'^\s*,').firstMatch(source);
            if (commaMatch != null) {
              endOffset += commaMatch.end;
            }
          }
        }

        builder.addDeletion(SourceRange(startOffset, endOffset - startOffset));
      });
    });
  }
}

/// Warns when using OverlayEntry instead of the declarative OverlayPortal.
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
  const PreferOverlayPortalRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_overlay_portal',
    problemMessage:
        '[prefer_overlay_portal] Consider using OverlayPortal instead of OverlayEntry.',
    correctionMessage:
        'OverlayPortal provides a declarative API that integrates '
        'with InheritedWidgets (Flutter 3.10+).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'OverlayEntry') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when using third-party carousel packages instead of CarouselView.
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
  const PreferCarouselViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_carousel_view',
    problemMessage:
        '[prefer_carousel_view] Third-party carousel package adds dependency maintenance overhead, increases app size, and may not follow Material 3 design guidelines. The built-in CarouselView widget (Flutter 3.24+) provides standard M3 carousel behavior with accessibility support, animation curves, and theme integration out of the box.',
    correctionMessage:
        'Replace the third-party carousel with CarouselView(children: items) from the Flutter framework. It supports item extent, shrink extent, and standard scroll physics.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for carousel widget constructors
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (_carouselWidgets.contains(typeName)) {
        reporter.atNode(node.constructorName, code);
      }
    });

    // Check for carousel package imports
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      for (final String pkg in _carouselPackages) {
        if (uri.startsWith('package:$pkg/')) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when using showSearch/SearchDelegate instead of SearchAnchor.
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
  const PreferSearchAnchorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_search_anchor',
    problemMessage:
        '[prefer_search_anchor] showSearch with SearchDelegate uses an imperative API that bypasses the widget tree, cannot access InheritedWidgets from the parent context, and follows Material 2 patterns. SearchAnchor (Flutter 3.10+) provides a declarative, widget-based search with full M3 styling and theme integration.',
    correctionMessage:
        'Replace showSearch/SearchDelegate with SearchAnchor and SearchAnchor.bar, which integrate into the widget tree and support suggestionsBuilder for async search results.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for showSearch() calls
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'showSearch') {
        reporter.atNode(node, code);
      }
    });

    // Check for SearchDelegate subclasses
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'SearchDelegate') {
          reporter.atNode(extendsClause, code);
        }
      }
    });
  }
}

/// Warns when using GestureDetector for tap-outside-to-dismiss patterns.
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
  const PreferTapRegionForDismissRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_tap_region_for_dismiss',
    problemMessage:
        '[prefer_tap_region_for_dismiss] Manual tap-outside detection using GestureDetector or Focus requires tracking tap locations and comparing against widget bounds, which is error-prone and breaks with nested interactive elements. TapRegion (Flutter 3.10+) handles this pattern correctly out of the box, including group regions for linked elements.',
    correctionMessage:
        'Wrap the dismissible content with TapRegion(onTapOutside: (_) => dismiss()) for reliable tap-outside detection. Use TapRegion.groupId to link multiple regions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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

class RequireTextOverflowHandlingRule extends SaropaLintRule {
  const RequireTextOverflowHandlingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_text_overflow_handling',
    problemMessage:
        '[require_text_overflow_handling] Text with dynamic content should have overflow handling to prevent layout issues.',
    correctionMessage:
        'Add overflow: TextOverflow.ellipsis and/or maxLines: 1 parameter.',
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
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'Text') return;

      // Check for overflow handling
      bool hasOverflow = false;
      bool hasMaxLines = false;
      bool hasSoftWrap = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'overflow') hasOverflow = true;
          if (argName == 'maxLines') hasMaxLines = true;
          if (argName == 'softWrap') hasSoftWrap = true;
        }
      }

      // Already has overflow handling
      if (hasOverflow || hasMaxLines || hasSoftWrap) return;

      // Check if text content is dynamic (not a simple string literal)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;

      // Skip if it's a short static string (likely a label/button text)
      if (firstArg is SimpleStringLiteral) {
        final String value = firstArg.value;
        // Skip short strings (e.g., buttons, labels) - unlikely to overflow
        if (value.length <= 30 && !value.contains('\n')) return;
      }

      // Skip simple string literals without interpolation
      if (firstArg is SimpleStringLiteral) return;

      // Flag dynamic content: variables, interpolations, method calls
      if (firstArg is StringInterpolation ||
          firstArg is SimpleIdentifier ||
          firstArg is PrefixedIdentifier ||
          firstArg is MethodInvocation ||
          firstArg is PropertyAccess ||
          firstArg is IndexExpression ||
          firstArg is ConditionalExpression ||
          firstArg is BinaryExpression) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTextOverflowFix()];
}

class _AddTextOverflowFix extends DartFix {
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
      if (node.constructorName.type.name.lexeme != 'Text') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add overflow: TextOverflow.ellipsis, maxLines: 1',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find position before closing parenthesis
        final int insertOffset = node.argumentList.rightParenthesis.offset;
        final String comma = node.argumentList.arguments.isEmpty ? '' : ', ';
        builder.addSimpleInsertion(
          insertOffset,
          '${comma}overflow: TextOverflow.ellipsis, maxLines: 1',
        );
      });
    });
  }
}

/// Requires Image.network to have an errorBuilder for handling load failures.
///
/// Alias: require_image_error_fallback
///
/// Network images can fail to load due to connectivity issues, invalid URLs, or server errors. Without an errorBuilder, users see broken image icons, blank spaces, or cryptic UI. This leads to poor user experience, missed content, and increased support burden. It can also mask backend or CDN issues during development and testing.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.png')
/// // No errorBuilder provided - user sees broken image icon or blank space
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image),
/// )
/// // User sees a fallback icon or message when image fails to load
/// ```
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
/// )
/// ```

class RequireImageErrorBuilderRule extends SaropaLintRule {
  const RequireImageErrorBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_image_error_builder',
    problemMessage:
        '[require_image_error_builder] Network image should have an errorBuilder.',
    correctionMessage:
        'Add errorBuilder to handle image loading failures gracefully.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      // Check for Image.network
      if (typeName != 'Image') return;
      if (constructorName != 'network') return;

      bool hasErrorBuilder = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'errorBuilder') {
          hasErrorBuilder = true;
          break;
        }
      }

      if (!hasErrorBuilder) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Requires network images to specify width and height for layout stability.
///
/// Network images without dimensions cause layout shifts (CLS) when they load,
/// leading to poor user experience. Specifying dimensions reserves space
/// before the image loads.
///
/// Only applies to:
/// - `Image.network()`
/// - `CachedNetworkImage()`
///
/// Does NOT flag:
/// - `Image.asset()` - dimensions are typically known at build time
/// - Images with `fit` parameter - usually sized by parent container
/// - Images inside `SizedBox`, `Container` with dimensions
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.png')
/// CachedNetworkImage(imageUrl: url)
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   width: 200,
///   height: 150,
/// )
/// SizedBox(
///   width: 200,
///   height: 150,
///   child: Image.network(url, fit: BoxFit.cover),
/// )
/// ```

class RequireImageDimensionsRule extends SaropaLintRule {
  const RequireImageDimensionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_image_dimensions',
    problemMessage:
        '[require_image_dimensions] Network image should specify width and height to prevent layout shifts.',
    correctionMessage:
        'Add width and height, or wrap in SizedBox with dimensions.',
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
      final String? constructorName = node.constructorName.name?.name;

      // Only check network images
      bool isNetworkImage = false;
      if (typeName == 'Image' && constructorName == 'network') {
        isNetworkImage = true;
      }
      if (typeName == 'CachedNetworkImage') {
        isNetworkImage = true;
      }

      if (!isNetworkImage) return;

      bool hasWidth = false;
      bool hasHeight = false;
      bool hasFit = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'width') hasWidth = true;
          if (argName == 'height') hasHeight = true;
          if (argName == 'fit') hasFit = true;
        }
      }

      // Allow if BoxFit is specified (usually means parent provides dimensions)
      if (hasFit) return;

      // Allow if has at least one dimension (aspect ratio can determine other)
      if (hasWidth || hasHeight) return;

      // Check if parent is a sizing widget (SizedBox, Container with size)
      if (_hasParentWithDimensions(node)) return;

      reporter.atNode(node.constructorName, code);
    });
  }

  /// Checks if an ancestor provides dimensions (SizedBox, Container, etc.)
  bool _hasParentWithDimensions(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;
    const int maxDepth = 5; // Don't look too far up

    while (current != null && depth < maxDepth) {
      if (current is InstanceCreationExpression) {
        final String parentType = current.constructorName.type.name.lexeme;

        // SizedBox, Container, ConstrainedBox typically provide dimensions
        if (parentType == 'SizedBox' ||
            parentType == 'Container' ||
            parentType == 'ConstrainedBox' ||
            parentType == 'AspectRatio') {
          // Check if the parent has width/height
          for (final Expression arg in current.argumentList.arguments) {
            if (arg is NamedExpression) {
              final String argName = arg.name.label.name;
              if (argName == 'width' ||
                  argName == 'height' ||
                  argName == 'constraints' ||
                  argName == 'aspectRatio') {
                return true;
              }
            }
          }
        }

        // Expanded/Flexible in Row/Column will provide constraints
        if (parentType == 'Expanded' || parentType == 'Flexible') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Requires network images to have a placeholder or loadingBuilder.
///
/// Without a placeholder, users see nothing while images load,
/// leading to poor perceived performance.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   loadingBuilder: (context, child, progress) =>
///       progress == null ? child : CircularProgressIndicator(),
/// )
/// // Or with CachedNetworkImage:
/// CachedNetworkImage(
///   imageUrl: url,
///   placeholder: (context, url) => CircularProgressIndicator(),
/// )
/// ```

class RequirePlaceholderForNetworkRule extends SaropaLintRule {
  const RequirePlaceholderForNetworkRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_placeholder_for_network',
    problemMessage:
        '[require_placeholder_for_network] Network image should have a placeholder or loadingBuilder.',
    correctionMessage:
        'Add loadingBuilder or placeholder to show feedback during loading.',
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
      final String? constructorName = node.constructorName.name?.name;

      // Check for Image.network
      bool isNetworkImage = false;
      if (typeName == 'Image' && constructorName == 'network') {
        isNetworkImage = true;
      }
      if (typeName == 'CachedNetworkImage') {
        isNetworkImage = true;
      }

      if (!isNetworkImage) return;

      bool hasPlaceholder = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'loadingBuilder' ||
              argName == 'placeholder' ||
              argName == 'progressIndicatorBuilder') {
            hasPlaceholder = true;
            break;
          }
        }
      }

      if (!hasPlaceholder) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Requires ScrollController fields to be disposed in State classes.
///
/// ScrollController allocates native resources and listeners that must be
/// released by calling dispose(). Failing to do so causes memory leaks.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _scrollController = ScrollController();
///   // Missing dispose - MEMORY LEAK!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _scrollController = ScrollController();
///
///   @override
///   void dispose() {
///     _scrollController.dispose();
///     super.dispose();
///   }
/// }
/// ```

class PreferTextThemeRule extends SaropaLintRule {
  const PreferTextThemeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_text_theme',
    problemMessage:
        '[prefer_text_theme] Consider using Theme.textTheme instead of hardcoded TextStyle.',
    correctionMessage:
        'Use Theme.of(context).textTheme.* for consistent typography.',
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
      if (typeName != 'TextStyle') return;

      // Check if inside a Text widget's style argument
      AstNode? current = node.parent;
      while (current != null) {
        if (current is NamedExpression && current.name.label.name == 'style') {
          // Check if parent is Text widget
          final AstNode? namedParent = current.parent;
          if (namedParent is ArgumentList) {
            final AstNode? argListParent = namedParent.parent;
            if (argListParent is InstanceCreationExpression) {
              final String parentType =
                  argListParent.constructorName.type.name.lexeme;
              if (parentType == 'Text' || parentType == 'RichText') {
                reporter.atNode(node, code);
                return;
              }
            }
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when scrollable widgets are nested without NestedScrollView.
///
/// Nested scrollables (ListView inside ListView) cause gestures to be
/// ambiguous and can lead to poor scroll performance and UX issues.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [
///     ListView.builder(...), // Nested scrollable!
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// NestedScrollView(
///   headerSliverBuilder: (context, innerBoxIsScrolled) => [
///     SliverAppBar(...),
///   ],
///   body: ListView.builder(...),
/// )
/// // Or use shrinkWrap + NeverScrollableScrollPhysics for inner list
/// ```

class AvoidGestureWithoutBehaviorRule extends SaropaLintRule {
  const AvoidGestureWithoutBehaviorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_without_behavior',
    problemMessage:
        '[avoid_gesture_without_behavior] GestureDetector should specify HitTestBehavior.',
    correctionMessage:
        'Add behavior: HitTestBehavior.opaque (or translucent/deferToChild).',
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
  const AvoidDoubleTapSubmitRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_double_tap_submit',
    problemMessage:
        '[avoid_double_tap_submit] Button may allow double-tap submissions.',
    correctionMessage:
        'Disable the button during submission or use a debounce mechanism.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
      bool isSubmitButton = _submitKeywords.any(
        (String keyword) => childText!.contains(keyword),
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
  const PreferCursorForButtonsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_cursor_for_buttons',
    problemMessage:
        '[prefer_cursor_for_buttons] Interactive widget should specify mouse cursor for web.',
    correctionMessage:
        'Add mouseCursor: SystemMouseCursors.click (or similar).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'InkWell',
    'GestureDetector',
    'InkResponse',
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

class RequireHoverStatesRule extends SaropaLintRule {
  const RequireHoverStatesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_hover_states',
    problemMessage:
        '[require_hover_states] Interactive widget should handle hover state for web/desktop.',
    correctionMessage: 'Add onHover callback for visual feedback.',
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
      // Only check InkWell and MouseRegion
      if (typeName != 'InkWell' && typeName != 'GestureDetector') return;

      bool hasOnTap = false;
      bool hasHoverHandling = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onTap' || argName == 'onPressed') {
            hasOnTap = true;
          }
          if (argName == 'onHover' ||
              argName == 'hoverColor' ||
              argName == 'highlightColor') {
            hasHoverHandling = true;
          }
        }
      }

      if (hasOnTap && !hasHoverHandling) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons don't have a loading state for async operations.
///
/// Users should see visual feedback when an async operation is in progress.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     await api.submit(data);
///   },
///   child: Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: isLoading ? null : () async {
///     setState(() => isLoading = true);
///     await api.submit(data);
///     setState(() => isLoading = false);
///   },
///   child: isLoading ? CircularProgressIndicator() : Text('Submit'),
/// )
/// ```

class RequireButtonLoadingStateRule extends SaropaLintRule {
  const RequireButtonLoadingStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_button_loading_state',
    problemMessage:
        '[require_button_loading_state] Async button should show loading state.',
    correctionMessage:
        'Disable button and show loading indicator during async operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
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
      if (!_buttonWidgets.contains(typeName)) return;

      Expression? onPressedExpr;
      Expression? childExpr;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onPressed') {
            onPressedExpr = arg.expression;
          }
          if (argName == 'child') {
            childExpr = arg.expression;
          }
        }
      }

      if (onPressedExpr == null) return;
      final String onPressedSource = onPressedExpr.toSource();

      // Check if the callback is async
      bool isAsync = onPressedSource.contains('async') ||
          onPressedSource.contains('await');

      if (!isAsync) return;

      // Check if there's loading state handling
      bool hasLoadingState = onPressedSource.contains('isLoading') ||
          onPressedSource.contains('_loading') ||
          onPressedSource.contains('loading') ||
          onPressedSource.contains('isSubmitting') ||
          onPressedSource.contains('_submitting');

      // Check if child shows loading indicator
      String childSource = childExpr?.toSource() ?? '';
      bool hasLoadingIndicator =
          childSource.contains('CircularProgressIndicator') ||
              childSource.contains('Loading') ||
              childSource.contains('isLoading') ||
              childSource.contains('?');

      if (!hasLoadingState && !hasLoadingIndicator) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when hardcoded TextStyle values are used instead of theme.
///
/// Hardcoded text styles make it difficult to maintain consistent
/// typography across the app.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: Theme.of(context).textTheme.bodyLarge,
/// )
/// ```

class AvoidHardcodedTextStylesRule extends SaropaLintRule {
  const AvoidHardcodedTextStylesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_text_styles',
    problemMessage:
        '[avoid_hardcoded_text_styles] Avoid inline TextStyle with hardcoded values.',
    correctionMessage:
        'Use Theme.of(context).textTheme or define styles in a central location.',
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

class RequireRefreshIndicatorRule extends SaropaLintRule {
  const RequireRefreshIndicatorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_refresh_indicator',
    problemMessage:
        '[require_refresh_indicator] List showing remote data should have RefreshIndicator for pull-to-refresh.',
    correctionMessage:
        'Wrap with RefreshIndicator(onRefresh: () => fetch(), child: ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Words suggesting remote/fetchable data
  static const Set<String> _remoteDataIndicators = <String>{
    'posts',
    'items',
    'messages',
    'notifications',
    'feeds',
    'articles',
    'users',
    'comments',
    'data',
    'results',
    'list',
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
      final String? constructorName = node.constructorName.name?.name;

      // Only check ListView.builder which typically shows dynamic content
      if (typeName != 'ListView' || constructorName != 'builder') return;

      // Check if already wrapped in RefreshIndicator
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'RefreshIndicator') {
            return; // Already has RefreshIndicator
          }
        }
        current = current.parent;
      }

      // Only warn if the source suggests remote data
      final String nodeSource = node.toSource().toLowerCase();
      final bool suggestsRemoteData = _remoteDataIndicators.any(
        (indicator) => nodeSource.contains(indicator),
      );

      if (suggestsRemoteData) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when scrollable widgets don't specify scroll physics.
///
/// Explicit scroll physics ensures consistent behavior across platforms.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   physics: const BouncingScrollPhysics(),
///   itemBuilder: (context, index) => ListTile(),
/// )
/// ```

class RequireDefaultTextStyleRule extends SaropaLintRule {
  const RequireDefaultTextStyleRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_default_text_style',
    problemMessage:
        '[require_default_text_style] Multiple Text widgets with same style - use DefaultTextStyle.',
    correctionMessage: 'Wrap with DefaultTextStyle to share common styles.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      // Count Text widgets with explicit styles in this list
      int textWithStyleCount = 0;
      String? firstStyleSource;

      for (final CollectionElement element in node.elements) {
        if (element is InstanceCreationExpression) {
          final String typeName = element.constructorName.type.name.lexeme;
          if (typeName == 'Text') {
            for (final Expression arg in element.argumentList.arguments) {
              if (arg is NamedExpression && arg.name.label.name == 'style') {
                final String styleSource = arg.expression.toSource();
                if (firstStyleSource == null) {
                  firstStyleSource = styleSource;
                  textWithStyleCount++;
                } else if (styleSource == firstStyleSource) {
                  textWithStyleCount++;
                }
              }
            }
          }
        }
      }

      // If 3+ Text widgets have the same style, suggest DefaultTextStyle
      if (textWithStyleCount >= 3) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Row/Column with overflow could use Wrap instead.
///
/// Wrap automatically moves overflowing children to the next line.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [Chip(...), Chip(...), Chip(...), Chip(...)], // May overflow
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Wrap(
///   spacing: 8,
///   children: [Chip(...), Chip(...), Chip(...), Chip(...)],
/// )
/// ```

class PreferAssetImageForLocalRule extends SaropaLintRule {
  const PreferAssetImageForLocalRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_asset_image_for_local',
    problemMessage:
        '[prefer_asset_image_for_local] Use AssetImage for bundled assets, not FileImage.',
    correctionMessage: 'Replace FileImage with AssetImage or Image.asset().',
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
  const PreferFitCoverForBackgroundRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_fit_cover_for_background',
    problemMessage:
        '[prefer_fit_cover_for_background] Background images should use BoxFit.cover.',
    correctionMessage: 'Add fit: BoxFit.cover to DecorationImage.',
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

class RequireDisabledStateRule extends SaropaLintRule {
  const RequireDisabledStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_disabled_state',
    problemMessage:
        '[require_disabled_state] Consider customizing disabled style for design consistency.',
    correctionMessage:
        'Add style with disabledBackgroundColor/disabledForegroundColor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
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
      if (!_buttonWidgets.contains(typeName)) return;

      bool hasConditionalOnPressed = false;
      bool hasStyleHandling = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;

          if (argName == 'onPressed') {
            final String source = arg.expression.toSource();
            // Check for conditional pattern: condition ? fn : null
            if (source.contains('?') && source.contains('null')) {
              hasConditionalOnPressed = true;
            }
          }

          if (argName == 'style') {
            hasStyleHandling = true;
          }
        }
      }

      if (hasConditionalOnPressed && !hasStyleHandling) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Draggable doesn't have feedback widget.
///
/// Feedback provides visual indication during drag operations.
///
/// **BAD:**
/// ```dart
/// Draggable(
///   data: item,
///   child: ItemWidget(item),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Draggable(
///   data: item,
///   feedback: Material(child: ItemWidget(item)),
///   child: ItemWidget(item),
/// )
/// ```

class RequireDragFeedbackRule extends SaropaLintRule {
  const RequireDragFeedbackRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_drag_feedback',
    problemMessage:
        '[require_drag_feedback] Draggable should have feedback widget.',
    correctionMessage: 'Add feedback: Widget to show during drag.',
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
      if (typeName != 'Draggable' && typeName != 'LongPressDraggable') return;

      bool hasFeedback = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'feedback') {
          hasFeedback = true;
          break;
        }
      }

      if (!hasFeedback) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when GestureDetector widgets are nested, causing gesture conflicts.
///
/// Nested GestureDetectors can cause unexpected behavior as gestures
/// compete with each other.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: handleOuterTap,
///   child: GestureDetector(
///     onTap: handleInnerTap, // Conflicts with outer!
///     child: Content(),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   onTap: handleTap,
///   child: Content(),
/// )
/// ```

class AvoidGestureConflictRule extends SaropaLintRule {
  const AvoidGestureConflictRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_conflict',
    problemMessage:
        '[avoid_gesture_conflict] Nested GestureDetector widgets may cause gesture conflicts.',
    correctionMessage: 'Consolidate gesture handling or use behavior property.',
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
  const AvoidLargeImagesInMemoryRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_large_images_in_memory',
    problemMessage:
        '[avoid_large_images_in_memory] Image should specify size constraints to save memory.',
    correctionMessage:
        'Add width/height and cacheWidth/cacheHeight parameters.',
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
  const PreferActionsAndShortcutsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_actions_and_shortcuts',
    problemMessage:
        '[prefer_actions_and_shortcuts] Use Actions/Shortcuts system instead of RawKeyboardListener.',
    correctionMessage: 'Replace with Shortcuts and Actions widgets.',
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
      if (typeName == 'RawKeyboardListener' || typeName == 'KeyboardListener') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when GestureDetector doesn't handle long press for context menus.
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

class RequireLongPressCallbackRule extends SaropaLintRule {
  const RequireLongPressCallbackRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_long_press_callback',
    problemMessage:
        '[require_long_press_callback] Consider adding onLongPress for context menu.',
    correctionMessage: 'Add onLongPress callback for additional actions.',
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
      if (typeName != 'GestureDetector' && typeName != 'InkWell') return;

      bool hasOnTap = false;
      bool hasOnLongPress = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onTap') hasOnTap = true;
          if (argName == 'onLongPress') hasOnLongPress = true;
        }
      }

      // Only suggest if has onTap but no onLongPress, and is on a list item
      if (hasOnTap && !hasOnLongPress) {
        // Check if child is a list-like item
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'child') {
            final String childSource = arg.expression.toSource();
            if (childSource.contains('ListTile') ||
                childSource.contains('Card') ||
                childSource.contains('Item')) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when findChildIndexCallback is called in build method.
///
/// Creating a new callback in build causes unnecessary rebuilds.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   findChildIndexCallback: (key) => items.indexWhere(...),
///   itemBuilder: ...,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Define callback outside build or use memoization
/// final _findChildIndex = (Key key) => ...;
///
/// ListView.builder(
///   findChildIndexCallback: _findChildIndex,
///   itemBuilder: ...,
/// )
/// ```

class AvoidFindChildInBuildRule extends SaropaLintRule {
  const AvoidFindChildInBuildRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_find_child_in_build',
    problemMessage:
        '[avoid_find_child_in_build] findChildIndexCallback should not be created in build.',
    correctionMessage: 'Extract callback to a field or use memoization.',
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
                reporter.atNode(arg, code);
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

class RequireErrorWidgetRule extends SaropaLintRule {
  const RequireErrorWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_error_widget',
    problemMessage:
        '[require_error_widget] FutureBuilder/StreamBuilder must handle error state to prevent silent failures, blank screens, or cryptic UI. Without error handling, users may see no feedback when data fails to load, leading to confusion, poor UX, and support burden. This can also mask backend or network issues during development.',
    correctionMessage:
        'Add error handling: if (snapshot.hasError) show a user-friendly error message or fallback UI. Log errors for diagnostics and provide actionable feedback to users. Audit all async builders for error handling coverage.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'FutureBuilder' && typeName != 'StreamBuilder') return;

      // Find the builder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();

          // Check if it handles errors
          if (!builderSource.contains('hasError') &&
              !builderSource.contains('.error')) {
            reporter.atNode(node.constructorName, code);
          }
          return;
        }
      }
    });
  }
}

/// Warns when AppBar is used inside CustomScrollView instead of SliverAppBar.
///
/// SliverAppBar enables collapsing/expanding behavior in scroll views.
///
/// **BAD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverToBoxAdapter(child: AppBar(title: Text('Title'))),
///     SliverList(...),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverAppBar(title: Text('Title'), floating: true),
///     SliverList(...),
///   ],
/// )
/// ```

class RequireFormValidationRule extends SaropaLintRule {
  const RequireFormValidationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_form_validation',
    problemMessage:
        '[require_form_validation] TextFormField in Form should have a validator.',
    correctionMessage: 'Add validator: (value) => ... to validate input.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextFormField') return;

      // Check if inside a Form
      bool insideForm = false;
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'Form') {
            insideForm = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!insideForm) return;

      // Check if has validator
      bool hasValidator = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'validator') {
          hasValidator = true;
          break;
        }
      }

      if (!hasValidator) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when ListView/GridView uses `shrinkWrap: true` inside a scrollable.
///
/// Using `shrinkWrap: true` forces the list to calculate the size of all
/// children at once, which defeats lazy loading and causes O(n) layout cost.
/// This is particularly problematic for large lists.
///
/// **BAD:**
/// ```dart
/// ListView(
///   shrinkWrap: true,
///   children: items.map((item) => ListTile(title: Text(item))).toList(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, index) => ListTile(title: Text(items[index])),
/// )
/// ```
///
/// **Also OK (for small fixed lists):**
/// ```dart
/// ListView(
///   children: [
///     ListTile(title: Text('Item 1')),
///     ListTile(title: Text('Item 2')),
///   ],
/// )
/// ```

class RequireThemeColorFromSchemeRule extends SaropaLintRule {
  const RequireThemeColorFromSchemeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_theme_color_from_scheme',
    problemMessage:
        '[require_theme_color_from_scheme] Hardcoded color breaks theming. Use Theme.of(context).colorScheme.',
    correctionMessage:
        'Replace with colorScheme.primary, .secondary, .surface, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for Color(0x...) hardcoded colors
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Color') return;

      // Skip if in theme definition file
      final String filePath = resolver.source.fullName.toLowerCase();
      if (filePath.contains('theme') || filePath.contains('color')) return;

      // Check for hex literal
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is IntegerLiteral) {
          reporter.atNode(node, code);
        }
      }
    });

    // Check for Colors.* constants
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Colors') return;

      // Skip Colors.transparent - commonly used and valid
      if (node.identifier.name == 'transparent') return;

      // Skip if in theme definition
      final String filePath = resolver.source.fullName.toLowerCase();
      if (filePath.contains('theme') || filePath.contains('color')) return;

      // Common colors that should come from theme
      final Set<String> semanticColors = <String>{
        'blue',
        'red',
        'green',
        'orange',
        'purple',
        'grey',
        'black',
        'white',
      };

      final String colorName = node.identifier.name.toLowerCase();
      if (semanticColors.any((String c) => colorName.startsWith(c))) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when ColorScheme is created manually instead of using fromSeed.
///
/// ColorScheme.fromSeed generates a harmonious, accessible color palette
/// from a single seed color. Manual ColorScheme is error-prone and often
/// has accessibility issues.
///
/// **BAD:**
/// ```dart
/// ColorScheme(
///   primary: Color(0xFF6750A4),
///   onPrimary: Colors.white,
///   secondary: Color(0xFF625B71),
///   // 15+ more colors to define manually...
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ColorScheme.fromSeed(
///   seedColor: Color(0xFF6750A4),
///   brightness: Brightness.light,
/// )
/// ```

class PreferColorSchemeFromSeedRule extends SaropaLintRule {
  const PreferColorSchemeFromSeedRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_color_scheme_from_seed',
    problemMessage:
        '[prefer_color_scheme_from_seed] Manual ColorScheme is error-prone. Use ColorScheme.fromSeed.',
    correctionMessage:
        'ColorScheme.fromSeed(seedColor: yourPrimary) generates accessible palettes.',
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
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      // Only flag default constructor, not fromSeed/fromSwatch
      if (constructorName != 'ColorScheme') return;
      if (namedConstructor != null) return; // fromSeed, light, dark, etc.

      // Check if it has many color arguments (indicating manual definition)
      int colorArgs = 0;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name.startsWith('on') ||
              name == 'primary' ||
              name == 'secondary' ||
              name == 'tertiary' ||
              name == 'surface' ||
              name == 'error' ||
              name == 'background' ||
              name == 'outline') {
            colorArgs++;
          }
        }
      }

      // If defining 4+ colors manually, suggest fromSeed
      if (colorArgs >= 4) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when multiple adjacent Text widgets could use Text.rich or RichText.
///
/// Multiple Text widgets in a Row or Wrap for styled text is inefficient.
/// Use Text.rich with TextSpan children for mixed styling.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [
///     Text('Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
///     Text('world', style: TextStyle(color: Colors.blue)),
///     Text('!', style: TextStyle(fontSize: 20)),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text.rich(
///   TextSpan(
///     children: [
///       TextSpan(text: 'Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
///       TextSpan(text: 'world', style: TextStyle(color: Colors.blue)),
///       TextSpan(text: '!', style: TextStyle(fontSize: 20)),
///     ],
///   ),
/// )
/// ```

class PreferRichTextForComplexRule extends SaropaLintRule {
  const PreferRichTextForComplexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_rich_text_for_complex',
    problemMessage:
        '[prefer_rich_text_for_complex] Multiple Text widgets in row could be combined with Text.rich.',
    correctionMessage:
        'Use Text.rich with TextSpan children for better performance and line wrapping.',
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
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'Row' && typeName != 'Wrap') return;

      // Find children argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression childrenExpr = arg.expression;
          if (childrenExpr is ListLiteral) {
            int textWidgetCount = 0;

            for (final CollectionElement element in childrenExpr.elements) {
              if (element is Expression) {
                if (element is InstanceCreationExpression) {
                  final String? childType =
                      element.constructorName.type.element?.name;
                  if (childType == 'Text') {
                    textWidgetCount++;
                  }
                }
              }
            }

            // If 3+ adjacent Text widgets, suggest Text.rich
            if (textWidgetCount >= 3) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when ThemeMode is hardcoded instead of using system default.
///
/// Using ThemeMode.light or ThemeMode.dark ignores user's OS preference.
/// Default to ThemeMode.system to respect user settings, with option to override.
///
/// **BAD:**
/// ```dart
/// MaterialApp(
///   themeMode: ThemeMode.light, // Ignores user's dark mode preference
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialApp(
///   themeMode: ThemeMode.system, // Respects OS setting
/// )
/// // Or let user choose with setting stored:
/// MaterialApp(
///   themeMode: userThemePreference ?? ThemeMode.system,
/// )
/// ```

class PreferSystemThemeDefaultRule extends SaropaLintRule {
  const PreferSystemThemeDefaultRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_system_theme_default',
    problemMessage:
        '[prefer_system_theme_default] Hardcoded ThemeMode ignores user\'s OS dark mode preference.',
    correctionMessage:
        'Use ThemeMode.system as default to respect user settings.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      // Only check ThemeMode.light or ThemeMode.dark
      if (node.prefix.name != 'ThemeMode') return;
      if (node.identifier.name != 'light' && node.identifier.name != 'dark') {
        return;
      }

      // Single traversal: find themeMode arg and check for conditionals
      AstNode? current = node.parent;
      bool foundThemeModeArg = false;

      while (current != null) {
        // Skip if inside conditional (user preference logic)
        if (current is ConditionalExpression ||
            current is IfStatement ||
            current is SwitchStatement ||
            current is SwitchExpression) {
          return;
        }

        // Check if directly in themeMode: argument
        if (current is NamedExpression &&
            current.name.label.name == 'themeMode') {
          foundThemeModeArg = true;
          break;
        }

        // Stop at widget boundary
        if (current is InstanceCreationExpression) break;

        current = current.parent;
      }

      if (foundThemeModeArg) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when AbsorbPointer is used (often IgnorePointer is more appropriate).
///
/// AbsorbPointer blocks ALL touch events including scrolling. IgnorePointer
/// allows events to pass through to widgets behind. AbsorbPointer is rarely
/// the correct choice.
///
/// **BAD:**
/// ```dart
/// AbsorbPointer(
///   absorbing: isLoading,
///   child: Form(...), // Blocks scrolling in parent ListView too!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// IgnorePointer(
///   ignoring: isLoading,
///   child: Form(...), // Events pass through to parent
/// )
/// // Or use AbsorbPointer only when you specifically need to block events:
/// AbsorbPointer(
///   absorbing: true,
///   // ignore: avoid_absorb_pointer_misuse
///   child: OverlayBlocker(),
/// )
/// ```

class AvoidBrightnessCheckForThemeRule extends SaropaLintRule {
  const AvoidBrightnessCheckForThemeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_brightness_check_for_theme',
    problemMessage:
        '[avoid_brightness_check_for_theme] Avoid checking brightness manually. Use colorScheme instead.',
    correctionMessage:
        'Replace brightness checks with colorScheme.onSurface, colorScheme.surface, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Detect Theme.of(context).brightness pattern
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'brightness') return;

      final Expression? target = node.target;
      if (target is! MethodInvocation) return;
      if (target.methodName.name != 'of') return;

      final Expression? methodTarget = target.target;
      if (methodTarget is SimpleIdentifier && methodTarget.name == 'Theme') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Scaffold body doesn't handle safe areas.
///
/// Notches, home indicators, and rounded corners clip content. Scaffold
/// body should use SafeArea or handle MediaQuery.padding appropriately.
///
/// **BAD:**
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [...], // May be clipped by notch!
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(
///   body: SafeArea(
///     child: Column(
///       children: [...],
///     ),
///   ),
/// )
/// // Or handle manually:
/// Scaffold(
///   body: Padding(
///     padding: MediaQuery.of(context).padding,
///     child: Column(...),
///   ),
/// )
/// ```

class RequireSafeAreaHandlingRule extends SaropaLintRule {
  const RequireSafeAreaHandlingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_safe_area_handling',
    problemMessage:
        '[require_safe_area_handling] Scaffold body should handle safe areas for notches and home indicators.',
    correctionMessage:
        'Wrap body content with SafeArea or use MediaQuery.padding.',
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
      if (typeName != 'Scaffold') return;

      // Check Scaffold arguments
      bool hasAppBar = false;
      bool hasBottomNav = false;
      NamedExpression? bodyArg;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'appBar') hasAppBar = true;
          if (name == 'bottomNavigationBar') hasBottomNav = true;
          if (name == 'body') bodyArg = arg;
        }
      }

      // Skip if no body or if Scaffold has appBar+bottomNav (handles safe areas)
      if (bodyArg == null) return;
      if (hasAppBar && hasBottomNav) return;

      // Skip if body is a simple variable reference
      if (bodyArg.expression is SimpleIdentifier) return;

      // Check if body widget handles safe areas
      final Expression bodyExpr = bodyArg.expression;
      if (bodyExpr is InstanceCreationExpression) {
        final String bodyType = bodyExpr.constructorName.type.name.lexeme;

        // These widgets handle safe areas internally or via slivers
        const Set<String> safeWidgets = <String>{
          'SafeArea',
          'SliverSafeArea',
          'CustomScrollView',
          'NestedScrollView',
        };
        if (safeWidgets.contains(bodyType)) return;

        // Check if body wraps with SafeArea
        for (final Expression bodyChildArg in bodyExpr.argumentList.arguments) {
          if (bodyChildArg is NamedExpression &&
              bodyChildArg.name.label.name == 'child') {
            final Expression childExpr = bodyChildArg.expression;
            if (childExpr is InstanceCreationExpression) {
              final String childType =
                  childExpr.constructorName.type.name.lexeme;
              if (safeWidgets.contains(childType)) return;
            }
          }
        }
      }

      reporter.atNode(bodyArg.name, code);
    });
  }
}

/// Warns when Material widgets are used that have Cupertino equivalents.
///
/// Material widgets look foreign on iOS. Use Cupertino equivalents or
/// adaptive widgets for native iOS feel.
///
/// **BAD:**
/// ```dart
/// // Using Material AlertDialog on iOS
/// showDialog(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: Text('Confirm'),
///     actions: [...],
///   ),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Platform-adaptive approach
/// showDialog(
///   context: context,
///   builder: (context) => Platform.isIOS
///     ? CupertinoAlertDialog(title: Text('Confirm'), actions: [...])
///     : AlertDialog(title: Text('Confirm'), actions: [...]),
/// );
/// // Or use adaptive widgets
/// showAdaptiveDialog(...);
/// ```

class PreferCupertinoForIosFeelRule extends SaropaLintRule {
  const PreferCupertinoForIosFeelRule() : super(code: _code);

  /// Design preference for native iOS feel.
  /// App works but may feel less native to iOS users.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_cupertino_for_ios_feel',
    problemMessage:
        '[prefer_cupertino_for_ios_feel] Material widget has Cupertino equivalent for native iOS feel.',
    correctionMessage:
        'Consider using Cupertino version or adaptive widget on iOS.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Map<String, String> _materialToCupertino = <String, String>{
    'AlertDialog': 'CupertinoAlertDialog',
    'CircularProgressIndicator': 'CupertinoActivityIndicator',
    'Switch': 'CupertinoSwitch',
    'Slider': 'CupertinoSlider',
    'TextField': 'CupertinoTextField',
    'DatePicker': 'CupertinoDatePicker',
    'TimePicker': 'CupertinoTimerPicker',
    'BottomNavigationBar': 'CupertinoTabBar',
    'TabBar': 'CupertinoSlidingSegmentedControl',
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

      if (_materialToCupertino.containsKey(typeName)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// cspell:ignore myapp
/// Warns when web apps don't use path URL strategy.
///
/// Hash URLs (/#/page) look ugly and hurt SEO. Use PathUrlStrategy for
/// clean URLs in production web apps.
///
/// **BAD:**
/// ```dart
/// // URLs like: myapp.com/#/home, myapp.com/#/settings
/// void main() {
///   runApp(MyApp()); // Uses hash URLs by default
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // URLs like: myapp.com/home, myapp.com/settings
/// void main() {
///   usePathUrlStrategy(); // Call before runApp
///   runApp(MyApp());
/// }
/// ```

class PreferUrlStrategyForWebRule extends SaropaLintRule {
  const PreferUrlStrategyForWebRule() : super(code: _code);

  /// Hash URLs hurt SEO and look unprofessional.
  /// App works but may rank lower in search results.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_url_strategy_for_web',
    problemMessage:
        '[prefer_url_strategy_for_web] Web app should use path URL strategy for clean URLs and SEO.',
    correctionMessage:
        'Call usePathUrlStrategy() before runApp() for clean URLs.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;

    // Only check web-related files or main.dart
    if (!path.endsWith('main.dart') &&
        !path.contains('/web/') &&
        !path.contains(r'\web\')) {
      return;
    }

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final String mainSource = node.toSource();

      // Check if has runApp but no URL strategy
      if (mainSource.contains('runApp') &&
          !mainSource.contains('usePathUrlStrategy') &&
          !mainSource.contains('setPathUrlStrategy') &&
          !mainSource.contains('UrlStrategy')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when desktop apps don't set window size constraints.
///
/// Desktop apps need minimum window size to prevent unusable layouts.
/// Set constraints in main() or platform runner.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(MyDesktopApp()); // No size constraints - can resize to 1x1!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await windowManager.ensureInitialized();
///   await windowManager.setMinimumSize(Size(800, 600));
///   runApp(MyDesktopApp());
/// }
/// ```

class RequireWindowSizeConstraintsRule extends SaropaLintRule {
  const RequireWindowSizeConstraintsRule() : super(code: _code);

  /// Window can resize to unusable dimensions without constraints.
  /// Users may accidentally make window too small to use.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_window_size_constraints',
    problemMessage:
        '[require_window_size_constraints] Desktop app should set minimum window size constraints.',
    correctionMessage: 'Use window_manager or similar to set setMinimumSize().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;

    // Only check main.dart in desktop contexts
    if (!path.endsWith('main.dart')) return;

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final String mainSource = node.toSource();

      // Check if has runApp but no window size setup
      if (mainSource.contains('runApp')) {
        final bool hasWindowSetup = mainSource.contains('setMinimumSize') ||
            mainSource.contains('setWindowMinSize') ||
            mainSource.contains('windowManager') ||
            mainSource.contains('window_size') ||
            mainSource.contains('bitsdojo');

        // Only warn if file mentions desktop platforms
        if (!hasWindowSetup &&
            (mainSource.contains('windows') ||
                mainSource.contains('macos') ||
                mainSource.contains('linux') ||
                mainSource.contains('Platform.isWindows') ||
                mainSource.contains('Platform.isMacOS') ||
                mainSource.contains('Platform.isLinux'))) {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when desktop apps lack keyboard shortcuts.
///
/// Desktop users expect Ctrl+S, Ctrl+Z, etc. Implement Shortcuts and
/// Actions for standard keyboard interactions.
///
/// **BAD:**
/// ```dart
/// class MyDesktopApp extends StatelessWidget {
///   Widget build(context) {
///     return MaterialApp(
///       home: MyHomePage(), // No keyboard shortcuts
///     );
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyDesktopApp extends StatelessWidget {
///   Widget build(context) {
///     return Shortcuts(
///       shortcuts: {
///         LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
///           SaveIntent(),
///       },
///       child: Actions(
///         actions: {SaveIntent: SaveAction()},
///         child: MaterialApp(home: MyHomePage()),
///       ),
///     );
///   }
/// }
/// ```

class PreferKeyboardShortcutsRule extends SaropaLintRule {
  const PreferKeyboardShortcutsRule() : super(code: _code);

  /// Desktop users expect keyboard shortcuts for efficiency.
  /// App works but power users may find it less productive.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_keyboard_shortcuts',
    problemMessage:
        '[prefer_keyboard_shortcuts] Desktop app should implement keyboard shortcuts for common actions.',
    correctionMessage:
        'Add Shortcuts and Actions widgets for Ctrl+S, Ctrl+Z, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String path = resolver.source.fullName;

    // Only check files that might be desktop entry points
    if (!path.endsWith('main.dart') && !path.contains('app.dart')) return;

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends StatelessWidget/StatefulWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String? superName = extendsClause.superclass.element?.name;
      if (superName != 'StatelessWidget' && superName != 'StatefulWidget') {
        return;
      }

      // Check if class name suggests it's the main app
      final String className = node.name.lexeme;
      if (!className.contains('App') && !className.contains('Main')) return;

      // Check if build method has Shortcuts
      final String classSource = node.toSource();
      if (classSource.contains('MaterialApp') ||
          classSource.contains('CupertinoApp')) {
        if (!classSource.contains('Shortcuts') &&
            !classSource.contains('CallbackShortcuts')) {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when methods return nullable Widget? types.
///
/// Methods returning `Widget?` are often better implemented as:
/// - Returning an empty SizedBox or Container when nothing should render
/// - Using conditional rendering in the parent widget
/// - Extracting to a separate widget class
///
/// Nullable widget methods can lead to null checks scattered throughout
/// the widget tree and make the rendering logic harder to follow.
///
/// **BAD:**
/// ```dart
/// Widget? _buildOptionalHeader() {
///   if (!showHeader) return null;
///   return Text('Header');
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       if (_buildOptionalHeader() != null) _buildOptionalHeader()!,
///       // or
///       _buildOptionalHeader() ?? SizedBox.shrink(),
///     ],
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget _buildHeader() {
///   if (!showHeader) return const SizedBox.shrink();
///   return Text('Header');
/// }
///
/// // Or use conditional rendering directly:
/// @override
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       if (showHeader) const Text('Header'),
///     ],
///   );
/// }
/// ```

class AvoidNullableWidgetMethodsRule extends SaropaLintRule {
  const AvoidNullableWidgetMethodsRule() : super(code: _code);

  /// Style/consistency issue. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_nullable_widget_methods',
    problemMessage:
        '[avoid_nullable_widget_methods] Avoid methods that return nullable Widget? types.',
    correctionMessage:
        'Return SizedBox.shrink() instead of null, or use conditional '
        'rendering in the parent widget.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
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

class PreferActionButtonTooltipRule extends SaropaLintRule {
  const PreferActionButtonTooltipRule() : super(code: _code);

  /// Accessibility improvement.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_action_button_tooltip',
    problemMessage:
        '[prefer_action_button_tooltip] IconButton should have a tooltip for accessibility.',
    correctionMessage: 'Add tooltip parameter to describe the button action.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Buttons that should have tooltips
  static const Set<String> _buttonTypes = <String>{
    'IconButton',
    'FloatingActionButton',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_buttonTypes.contains(typeName)) return;

      final ArgumentList args = node.argumentList;

      bool hasTooltip = false;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'tooltip') {
          hasTooltip = true;
          break;
        }
      }

      if (!hasTooltip) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when void Function() is used instead of VoidCallback typedef.
///
/// Using VoidCallback typedef is cleaner and more conventional in Flutter.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final void Function() onPressed;
/// void doSomething(void Function() callback) {}
/// ```
///
/// #### GOOD:
/// ```dart
/// final VoidCallback onPressed;
/// void doSomething(VoidCallback callback) {}
/// ```

class PreferVoidCallbackRule extends SaropaLintRule {
  const PreferVoidCallbackRule() : super(code: _code);

  /// Style improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Alias: prefer_void_callback_type
  static const LintCode _code = LintCode(
    name: 'prefer_void_callback',
    problemMessage:
        '[prefer_void_callback] Use VoidCallback instead of void Function().',
    correctionMessage: 'Replace with VoidCallback typedef.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addGenericFunctionType((GenericFunctionType node) {
      // Check for void Function()
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      // Return type should be void
      final String returnTypeName = returnType.toSource();
      if (returnTypeName != 'void') return;

      // Should have no parameters
      final FormalParameterList? params = node.parameters;
      if (params == null || params.parameters.isNotEmpty) return;

      // Should have no type parameters
      if (node.typeParameters != null) return;

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceWithVoidCallbackFix()];
}

class _ReplaceWithVoidCallbackFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addGenericFunctionType((GenericFunctionType node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with VoidCallback',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'VoidCallback',
        );
      });
    });
  }
}

/// Warns when InheritedWidget doesn't override updateShouldNotify.
///
/// Without updateShouldNotify, dependent widgets rebuild on every
/// ancestor rebuild, even when the inherited data hasn't changed.
///
/// **BAD:**
/// ```dart
/// class MyInherited extends InheritedWidget {
///   final String data;
///   const MyInherited({required this.data, required Widget child})
///       : super(child: child);
///   // Missing updateShouldNotify!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyInherited extends InheritedWidget {
///   final String data;
///   const MyInherited({required this.data, required Widget child})
///       : super(child: child);
///
///   @override
///   bool updateShouldNotify(MyInherited oldWidget) {
///     return data != oldWidget.data;
///   }
/// }
/// ```

class RequireOrientationHandlingRule extends SaropaLintRule {
  const RequireOrientationHandlingRule() : super(code: _code);

  /// UX issue - broken layouts in certain orientations.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_orientation_handling',
    problemMessage:
        '[require_orientation_handling] MaterialApp without orientation handling. May break in landscape.',
    correctionMessage:
        'Use SystemChrome.setPreferredOrientations or OrientationBuilder.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'MaterialApp' && typeName != 'CupertinoApp') {
        return;
      }

      // Check the file for orientation handling
      final unit = node.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) {
        return;
      }

      final fileSource = unit.toSource();

      // Check for orientation handling patterns
      if (fileSource.contains('setPreferredOrientations') ||
          fileSource.contains('OrientationBuilder') ||
          fileSource.contains('MediaQuery') &&
              fileSource.contains('orientation')) {
        return;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when kIsWeb is used without considering renderer type.
///
/// Flutter web has different renderers (HTML, CanvasKit, Skia) with
/// different capabilities. Code assuming one renderer may fail on others.
///
/// **BAD:**
/// ```dart
/// if (kIsWeb) {
///   // Assumes HTML renderer capabilities
///   html.window.localStorage['key'] = value;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (kIsWeb) {
///   // Check renderer if using renderer-specific features
///   if (isCanvasKit) {
///     // CanvasKit-specific code
///   } else {
///     // HTML renderer code
///   }
/// }
/// ```
///
/// **Note:** This is an INFO-level reminder. Not all web code is
/// renderer-dependent.

class RequireWebRendererAwarenessRule extends SaropaLintRule {
  const RequireWebRendererAwarenessRule() : super(code: _code);

  /// Platform compatibility issue.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_web_renderer_awareness',
    problemMessage:
        '[require_web_renderer_awareness] kIsWeb check without renderer consideration. Behavior may vary.',
    correctionMessage:
        'Consider if code depends on HTML vs CanvasKit renderer.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((node) {
      // Check if condition uses kIsWeb
      final conditionSource = node.expression.toSource();
      if (!conditionSource.contains('kIsWeb')) {
        return;
      }

      // Check if body uses renderer-specific APIs
      final bodySource = node.thenStatement.toSource().toLowerCase();

      // cspell:ignore sessionstorage
      // HTML-specific patterns
      final htmlPatterns = [
        'html.',
        'dart:html',
        'window.',
        'document.',
        'localstorage',
        'sessionstorage',
      ];

      final usesHtmlApis = htmlPatterns.any((p) => bodySource.contains(p));

      if (!usesHtmlApis) {
        return;
      }

      // Check if there's renderer awareness
      final blockSource = node.toSource().toLowerCase();
      if (blockSource.contains('canvaskit') ||
          blockSource.contains('renderer') ||
          blockSource.contains('skwasm')) {
        return;
      }

      reporter.atNode(node.expression, code);
    });
  }
}

// =============================================================================
// Part 3: Widget Lifecycle Rules
// =============================================================================

/// Warns when dispose() method doesn't call super.dispose().
///
/// Alias: missing_super_dispose, super_dispose_required
///
/// In `State<T>` subclasses, dispose() must call super.dispose() to ensure
/// proper cleanup of framework resources.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void dispose() {
///     // Missing super.dispose()!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void dispose() {
///     // Clean up resources
///     super.dispose();
///   }
/// }
/// ```

class AvoidNavigationInBuildRule extends SaropaLintRule {
  const AvoidNavigationInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_navigation_in_build',
    problemMessage:
        '[avoid_navigation_in_build] Navigation in build() triggers during '
        'rebuild, causing infinite navigation loops or flickering screens.',
    correctionMessage:
        'Use WidgetsBinding.instance.addPostFrameCallback or move to callback.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Navigator.method or context.navigatorMethod via extensions
      final methodName = node.methodName.name;
      if (!_navigationMethods.contains(methodName)) return;

      final target = node.target;
      if (target == null) return;

      final targetSource = target.toSource();
      if (!targetSource.contains('Navigator')) return;

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

class RequireTextFormFieldInFormRule extends SaropaLintRule {
  const RequireTextFormFieldInFormRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_text_form_field_in_form',
    problemMessage:
        '[require_text_form_field_in_form] TextFormField should be inside a Form widget for validation to work.',
    correctionMessage:
        'Wrap with Form widget or use TextField if no validation needed.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextFormField') return;

      // Check if the TextFormField has a validator parameter (indicates form usage)
      bool hasValidator = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'validator') {
          hasValidator = true;
          break;
        }
      }

      if (!hasValidator) return; // No validator = probably OK to not have Form

      // Walk up looking for Form constructor
      AstNode? current = node.parent;
      bool foundForm = false;
      int depth = 0;
      const maxDepth = 50; // Reasonable widget tree depth

      while (current != null && depth < maxDepth) {
        if (current is InstanceCreationExpression) {
          final parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'Form') {
            foundForm = true;
            break;
          }
        }
        current = current.parent;
        depth++;
      }

      if (!foundForm) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when WebView is used without navigationDelegate.
///
/// Alias: webview_missing_navigation_delegate, insecure_webview
///
/// WebView without navigationDelegate can navigate to any URL, which is
/// a security risk. Always validate navigation requests.
///
/// **BAD:**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
///   // No navigation control - can go anywhere!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
///   navigationDelegate: (request) {
///     if (request.url.startsWith('https://trusted.com')) {
///       return NavigationDecision.navigate;
///     }
///     return NavigationDecision.prevent;
///   },
/// )
/// ```

class RequireWebViewNavigationDelegateRule extends SaropaLintRule {
  const RequireWebViewNavigationDelegateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_webview_navigation_delegate',
    problemMessage:
        '[require_webview_navigation_delegate] Without navigation delegate, '
        'WebView can navigate to malicious or phishing sites.',
    correctionMessage:
        'Add navigationDelegate to validate URLs before navigation.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _webViewTypes = <String>{
    'WebView',
    'WebViewWidget',
    'InAppWebView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_webViewTypes.contains(typeName)) return;

      // Check for navigationDelegate or onNavigationRequest parameter
      bool hasNavigationControl = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final paramName = arg.name.label.name;
          if (paramName == 'navigationDelegate' ||
              paramName == 'onNavigationRequest' ||
              paramName == 'shouldOverrideUrlLoading') {
            hasNavigationControl = true;
            break;
          }
        }
      }

      if (!hasNavigationControl) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// Part 5: Additional API Pattern Rules
// =============================================================================

/// Warns when nested scrollables don't have NeverScrollableScrollPhysics.
///
/// Alias: nested_scroll_physics, scroll_conflict
///
/// When one scrollable is inside another, the inner one should usually
/// have NeverScrollableScrollPhysics to prevent gesture conflicts.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [
///     ListView(  // Gesture conflict!
///       shrinkWrap: true,
///       children: [...],
///     ),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView(
///   children: [
///     ListView(
///       shrinkWrap: true,
///       physics: NeverScrollableScrollPhysics(),
///       children: [...],
///     ),
///   ],
/// )
/// ```

class RequireAnimatedBuilderChildRule extends SaropaLintRule {
  const RequireAnimatedBuilderChildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_animated_builder_child',
    problemMessage:
        '[require_animated_builder_child] AnimatedBuilder should use child parameter for static widgets.',
    correctionMessage:
        'Move static widgets to child parameter to avoid rebuilds.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AnimatedBuilder') return;

      // Check if child parameter is present
      bool hasChild = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          hasChild = true;
          break;
        }
      }

      if (!hasChild) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when `throw e` is used instead of `rethrow`.
///
/// Alias: use_rethrow
///
/// `throw e` loses the original stack trace. Use `rethrow` to preserve it.
///
/// **BAD:**
/// ```dart
/// try {
///   await api.call();
/// } catch (e) {
///   log(e);
///   throw e;  // Loses stack trace!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await api.call();
/// } catch (e) {
///   log(e);
///   rethrow;  // Preserves stack trace
/// }
/// ```

class RequireRethrowPreserveStackRule extends SaropaLintRule {
  const RequireRethrowPreserveStackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_rethrow_preserve_stack',
    problemMessage:
        '[require_rethrow_preserve_stack] throw e loses stack trace. Use rethrow instead.',
    correctionMessage: 'Replace "throw e" with "rethrow".',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((ThrowExpression node) {
      final thrown = node.expression;
      if (thrown is! SimpleIdentifier) return;

      // Check if we're in a catch clause
      AstNode? current = node.parent;
      CatchClause? catchClause;

      while (current != null) {
        if (current is CatchClause) {
          catchClause = current;
          break;
        }
        current = current.parent;
      }

      if (catchClause == null) return;

      // Check if throwing the caught exception
      final exceptionParam = catchClause.exceptionParameter?.name.lexeme;
      if (exceptionParam == null) return;

      if (thrown.name == exceptionParam) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when http:// URLs are used in network calls.
///
/// Alias: insecure_http, require_https
///
/// HTTP is insecure. Always use HTTPS for network requests.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(Uri.parse('http://api.example.com/data'));
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(Uri.parse('https://api.example.com/data'));
/// ```

class RequireHttpsOverHttpRule extends SaropaLintRule {
  const RequireHttpsOverHttpRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_https_over_http',
    problemMessage:
        '[require_https_over_http] HTTP transmits data in plain text. '
        'Attackers can intercept credentials, tokens, and user data.',
    correctionMessage: 'Replace http:// with https://.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final value = node.value;
      if (value.startsWith('http://') &&
          !value.startsWith('http://localhost') &&
          !value.startsWith('http://127.0.0.1') &&
          !value.startsWith('http://10.') &&
          !value.startsWith('http://192.168.')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when ws:// URLs are used for WebSocket connections.
///
/// Alias: insecure_websocket, require_wss
///
/// ws:// is insecure. Always use wss:// for WebSocket connections.
///
/// **BAD:**
/// ```dart
/// final channel = WebSocketChannel.connect(Uri.parse('ws://api.example.com'));
/// ```
///
/// **GOOD:**
/// ```dart
/// final channel = WebSocketChannel.connect(Uri.parse('wss://api.example.com'));
/// ```

class RequireWssOverWsRule extends SaropaLintRule {
  const RequireWssOverWsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_wss_over_ws',
    problemMessage:
        '[require_wss_over_ws] ws:// transmits data unencrypted. Attackers '
        'can intercept, read, and modify WebSocket messages in transit.',
    correctionMessage: 'Replace ws:// with wss://.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final value = node.value;
      if (value.startsWith('ws://') &&
          !value.startsWith('ws://localhost') &&
          !value.startsWith('ws://127.0.0.1') &&
          !value.startsWith('ws://10.') &&
          !value.startsWith('ws://192.168.')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when `late` is used without guaranteed initialization.
///
/// Alias: unsafe_late, late_init_risk
///
/// `late` fields throw LateInitializationError if accessed before init.
/// Only use late when you can guarantee initialization before access.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   late String _data;  // May be accessed before init!
///
///   void fetchData() async {
///     _data = await api.getData();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   String? _data;  // Null-safe alternative
///
///   // Or use late only with guaranteed init in initState:
///   late final AnimationController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = AnimationController(vsync: this);  // Always runs
///   }
/// }
/// ```

class AvoidLateWithoutGuaranteeRule extends SaropaLintRule {
  const AvoidLateWithoutGuaranteeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_late_without_guarantee',
    problemMessage:
        '[avoid_late_without_guarantee] late field may cause LateInitializationError if accessed before init.',
    correctionMessage:
        'Consider using nullable type or ensure init in initState/constructor.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
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
          reporter.atNode(variable, code);
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

class RequireImagePickerPermissionIosRule extends SaropaLintRule {
  const RequireImagePickerPermissionIosRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_image_picker_permission_ios',
    problemMessage:
        '[require_image_picker_permission_ios] Missing Info.plist entries cause '
        'app rejection by App Store or instant crash when accessing photos.',
    correctionMessage:
        'Add NSPhotoLibraryUsageDescription and NSCameraUsageDescription to Info.plist.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only report once per file using image_picker
    bool reported = false;

    context.registry.addImportDirective((ImportDirective node) {
      if (reported) return;

      final uri = node.uri.stringValue ?? '';
      if (uri.contains('image_picker')) {
        reporter.atNode(node, code);
        reported = true;
      }
    });
  }
}

/// Reminder to add camera permission for image_picker on Android.
///
/// Alias: android_camera_permission, image_picker_manifest
///
/// Camera access requires AndroidManifest.xml entry.
///
/// **Required in android/app/src/main/AndroidManifest.xml:**
/// ```xml
/// <uses-permission android:name="android.permission.CAMERA"/>
/// ```

class RequireImagePickerPermissionAndroidRule extends SaropaLintRule {
  const RequireImagePickerPermissionAndroidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_image_picker_permission_android',
    problemMessage:
        '[require_image_picker_permission_android] Missing CAMERA permission '
        'causes SecurityException crash when user tries to take a photo.',
    correctionMessage:
        'Add <uses-permission android:name="android.permission.CAMERA"/> to manifest.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'pickImage') return;

      // Check for ImageSource.camera
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'source') {
          if (arg.expression.toSource() == 'ImageSource.camera') {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Reminder to add manifest entry for runtime permissions.
///
/// Alias: android_manifest_permission, permission_handler_manifest
///
/// Runtime permissions require manifest declaration on Android.
///
/// **Example for AndroidManifest.xml:**
/// ```xml
/// <uses-permission android:name="android.permission.CAMERA"/>
/// <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
/// ```

class RequirePermissionManifestAndroidRule extends SaropaLintRule {
  const RequirePermissionManifestAndroidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_permission_manifest_android',
    problemMessage:
        '[require_permission_manifest_android] Runtime permission request without '
        'manifest entry always fails. Feature silently stops working.',
    correctionMessage:
        'Add <uses-permission android:name="android.permission.XXX"/> to manifest.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool reported = false;

    context.registry.addImportDirective((ImportDirective node) {
      if (reported) return;

      final uri = node.uri.stringValue ?? '';
      if (uri.contains('permission_handler')) {
        reporter.atNode(node, code);
        reported = true;
      }
    });
  }
}

/// Reminder to add Info.plist entries for iOS permissions.
///
/// Alias: ios_plist_permission, permission_handler_plist
///
/// iOS permissions require Info.plist usage description strings.
///
/// **Example for ios/Runner/Info.plist:**
/// ```xml
/// <key>NSCameraUsageDescription</key>
/// <string>Camera access for photo capture</string>
/// ```

class RequirePermissionPlistIosRule extends SaropaLintRule {
  const RequirePermissionPlistIosRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_permission_plist_ios',
    problemMessage:
        '[require_permission_plist_ios] iOS requires usage descriptions in '
        'Info.plist. App crashes or gets rejected from App Store without them.',
    correctionMessage:
        'Add NSxxxUsageDescription key to Info.plist for each permission.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'request') return;

      final target = node.target;
      if (target == null) return;

      final targetSource = target.toSource();
      if (targetSource.contains('Permission.')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Reminder to add queries element for url_launcher on Android 11+.
///
/// Alias: android_queries_element, url_launcher_manifest
///
/// Android 11+ requires queries element in manifest for URL handling.
///
/// **Required in android/app/src/main/AndroidManifest.xml:**
/// ```xml
/// <queries>
///   <intent>
///     <action android:name="android.intent.action.VIEW"/>
///     <data android:scheme="https"/>
///   </intent>
/// </queries>
/// ```

class RequireUrlLauncherQueriesAndroidRule extends SaropaLintRule {
  const RequireUrlLauncherQueriesAndroidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_url_launcher_queries_android',
    problemMessage:
        '[require_url_launcher_queries_android] Without <queries> in manifest, '
        'canLaunchUrl returns false on Android 11+ even for installed apps.',
    correctionMessage:
        'Add <queries> element with intent filters to AndroidManifest.xml.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool reported = false;

    context.registry.addImportDirective((ImportDirective node) {
      if (reported) return;

      final uri = node.uri.stringValue ?? '';
      if (uri.contains('url_launcher')) {
        reporter.atNode(node, code);
        reported = true;
      }
    });
  }
}

/// Reminder to add LSApplicationQueriesSchemes for iOS url_launcher.
///
/// Alias: ios_url_schemes, url_launcher_plist
///
/// iOS requires declared URL schemes in Info.plist for canLaunchUrl.
///
/// **Required in ios/Runner/Info.plist:**
/// ```xml
/// <key>LSApplicationQueriesSchemes</key>
/// <array>
///   <string>https</string>
///   <string>tel</string>
///   <string>mailto</string>
/// </array>
/// ```

class RequireUrlLauncherSchemesIosRule extends SaropaLintRule {
  const RequireUrlLauncherSchemesIosRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_url_launcher_schemes_ios',
    problemMessage:
        '[require_url_launcher_schemes_ios] Without LSApplicationQueriesSchemes, '
        'canLaunchUrl returns false on iOS even for available URL schemes.',
    correctionMessage:
        'Add URL schemes to LSApplicationQueriesSchemes array in Info.plist.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'canLaunchUrl' &&
          node.methodName.name != 'canLaunch') {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when Stack children are not Positioned widgets.
///
/// Alias: stack_positioned, positioned_in_stack
///
/// Stack children without Positioned are placed at the top-left by default.
/// For overlay layouts, use Positioned to control child placement.
///
/// **BAD:**
/// ```dart
/// Stack(
///   children: [
///     Container(color: Colors.blue),
///     Text('Overlay'), // Not positioned!
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(
///   children: [
///     Container(color: Colors.blue),
///     Positioned(
///       top: 10,
///       right: 10,
///       child: Text('Overlay'),
///     ),
///   ],
/// )
/// ```

class AvoidStaticRouteConfigRule extends SaropaLintRule {
  const AvoidStaticRouteConfigRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_static_route_config',
    problemMessage:
        '[avoid_static_route_config] Static router configuration prevents '
        'hot reload. Route changes require full restart.',
    correctionMessage:
        'Use a top-level final variable or a getter for the router instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
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
            reporter.atNode(node, code);
            return;
          }
        }
      }

      // Also check initializer for router creation
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer is InstanceCreationExpression) {
          final String typeName = initializer.constructorName.type.name2.lexeme;
          if (_routerTypes.contains(typeName)) {
            reporter.atNode(node, code);
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

class RequireLocaleForTextRule extends SaropaLintRule {
  const RequireLocaleForTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_locale_for_text',
    problemMessage:
        '[require_locale_for_text] Text formatting without explicit locale may vary by device.',
    correctionMessage:
        'Provide explicit locale parameter for consistent formatting across devices.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name2.lexeme;

      // Check for NumberFormat, DateFormat
      if (constructorName != 'NumberFormat' &&
          constructorName != 'DateFormat') {
        return;
      }

      // Check if locale is provided
      final String argsSource = node.argumentList.toSource();
      if (!argsSource.contains('locale:') &&
          !argsSource.contains("'en") &&
          !argsSource.contains('"en')) {
        reporter.atNode(node, code);
      }
    });

    // Also check for static constructors like DateFormat.yMd()
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      if (target.name != 'NumberFormat' && target.name != 'DateFormat') return;

      // Check if locale is provided in the arguments
      final String argsSource = node.argumentList.toSource();
      if (argsSource == '()' || // No arguments
          (!argsSource.contains('locale:') &&
              !argsSource.contains("'en") &&
              !argsSource.contains('"en'))) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when destructive dialogs can be dismissed by tapping barrier.
///
/// `[HEURISTIC]` - Detects showDialog without explicit barrierDismissible for destructive actions.
///
/// Destructive confirmations shouldn't dismiss on barrier tap.
/// Users might accidentally dismiss important dialogs.
///
/// **BAD:**
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: Text('Delete account?'),
///     content: Text('This cannot be undone.'),
///     actions: [
///       TextButton(onPressed: deleteAccount, child: Text('Delete')),
///     ],
///   ),
/// ); // barrierDismissible defaults to true!
/// ```
///
/// **GOOD:**
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false, // Explicit for destructive action
///   builder: (context) => AlertDialog(
///     title: Text('Delete account?'),
///     // ...
///   ),
/// );
/// ```

class RequireDialogBarrierConsiderationRule extends SaropaLintRule {
  const RequireDialogBarrierConsiderationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_dialog_barrier_consideration',
    problemMessage:
        '[require_dialog_barrier_consideration] Destructive dialog without explicit barrierDismissible.',
    correctionMessage:
        'Set barrierDismissible: false for destructive confirmation dialogs.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _destructivePattern = RegExp(
    r'\b(delete|remove|destroy|cancel|discard|erase|clear|reset|logout|signout|unsubscribe)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'showDialog') return;

      final String argsSource = node.argumentList.toSource();

      // Check if barrierDismissible is set
      if (argsSource.contains('barrierDismissible')) return;

      // Check if dialog content contains destructive keywords
      if (_destructivePattern.hasMatch(argsSource)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when folder structure doesn't follow feature-based organization.
///
/// `[HEURISTIC]` - Checks file path patterns.
///
/// Group files by feature (/auth, /profile) instead of type (/bloc, /ui)
/// for better scalability.
///
/// **BAD:**
/// ```
/// lib/
///   bloc/
///     user_bloc.dart
///     order_bloc.dart
///   ui/
///     user_screen.dart
///     order_screen.dart
///   models/
///     user.dart
///     order.dart
/// ```
///
/// **GOOD:**
/// ```
/// lib/
///   features/
///     user/
///       user_bloc.dart
///       user_screen.dart
///       user_model.dart
///     order/
///       order_bloc.dart
///       order_screen.dart
///       order_model.dart
/// ```

class PreferFeatureFolderStructureRule extends SaropaLintRule {
  const PreferFeatureFolderStructureRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_feature_folder_structure',
    problemMessage:
        '[prefer_feature_folder_structure] File in type-based folder. Consider feature-based organization.',
    correctionMessage:
        'Group files by feature (features/auth/) instead of type (blocs/, models/).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _typeBasedFolderPattern = RegExp(
    r'/(blocs?|cubits?|providers?|models?|widgets?|screens?|pages?|views?)/',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check the file path
    final String filePath = resolver.source.fullName;

    if (_typeBasedFolderPattern.hasMatch(filePath)) {
      // Report on the compilation unit (file level)
      context.registry.addCompilationUnit((CompilationUnit node) {
        // Only report once per file, on the first declaration
        if (node.declarations.isNotEmpty) {
          reporter.atNode(node.declarations.first, code);
        }
      });
    }
  }
}
