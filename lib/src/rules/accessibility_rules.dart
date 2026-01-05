// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Accessibility lint rules for Flutter applications.
///
/// These rules help ensure your app is usable by people with disabilities,
/// including those using screen readers, switch controls, or other
/// assistive technologies.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when IconButton is used without a tooltip for accessibility.
///
/// IconButtons without tooltips are not accessible to screen readers.
/// The tooltip provides the accessible label that screen readers announce.
///
/// **BAD:**
/// ```dart
/// IconButton(
///   icon: Icon(Icons.add),
///   onPressed: () {},
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// IconButton(
///   icon: Icon(Icons.add),
///   onPressed: () {},
///   tooltip: 'Add item',
/// )
/// ```
class AvoidIconButtonsWithoutTooltipRule extends DartLintRule {
  const AvoidIconButtonsWithoutTooltipRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_icon_buttons_without_tooltip',
    problemMessage: 'IconButton should have a tooltip for accessibility.',
    correctionMessage: 'Add a tooltip parameter describing the button action.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'IconButton') return;

      final bool hasTooltip = node.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'tooltip';
        }
        return false;
      });

      if (!hasTooltip) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when touch targets are potentially too small for accessibility.
///
/// WCAG 2.1 recommends touch targets be at least 44x44 CSS pixels.
/// Material Design recommends 48x48 dp minimum.
///
/// This rule checks for explicit small sizes on interactive widgets.
///
/// **BAD:**
/// ```dart
/// SizedBox(
///   width: 24,
///   height: 24,
///   child: IconButton(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// SizedBox(
///   width: 48,
///   height: 48,
///   child: IconButton(...),
/// )
/// ```
class AvoidSmallTouchTargetsRule extends DartLintRule {
  const AvoidSmallTouchTargetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_small_touch_targets',
    problemMessage:
        'Touch target may be too small. Minimum recommended size is 48x48.',
    correctionMessage:
        'Increase the size to at least 48x48 for better accessibility.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const double _minTouchTarget = 44.0;

  static const Set<String> _interactiveWidgets = <String>{
    'IconButton',
    'TextButton',
    'ElevatedButton',
    'OutlinedButton',
    'GestureDetector',
    'InkWell',
    'InkResponse',
    'Checkbox',
    'Radio',
    'Switch',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'SizedBox' && constructorName != 'Container') {
        return;
      }

      // Check if it contains an interactive widget
      final bool hasInteractiveChild = _containsInteractiveWidget(node);
      if (!hasInteractiveChild) return;

      // Check width and height
      double? width;
      double? height;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width' || name == 'height') {
            final double? value = _extractNumericValue(arg.expression);
            if (name == 'width') {
              width = value;
            } else {
              height = value;
            }
          }
        }
      }

      if ((width != null && width < _minTouchTarget) ||
          (height != null && height < _minTouchTarget)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _containsInteractiveWidget(InstanceCreationExpression node) {
    bool found = false;
    node.visitChildren(
      _InteractiveWidgetVisitor((String name) {
        if (_interactiveWidgets.contains(name)) {
          found = true;
        }
      }),
    );
    return found;
  }

  double? _extractNumericValue(Expression expr) {
    if (expr is IntegerLiteral) {
      return expr.value?.toDouble();
    } else if (expr is DoubleLiteral) {
      return expr.value;
    }
    return null;
  }
}

class _InteractiveWidgetVisitor extends RecursiveAstVisitor<void> {
  _InteractiveWidgetVisitor(this.onFound);

  final void Function(String) onFound;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = node.constructorName.type.element?.name;
    if (name != null) {
      onFound(name);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when ExcludeSemantics is used without a comment explaining why.
///
/// ExcludeSemantics removes content from the accessibility tree.
/// This should be intentional and documented.
///
/// **BAD:**
/// ```dart
/// ExcludeSemantics(
///   child: DecorativeImage(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Decorative image, no semantic meaning
/// ExcludeSemantics(
///   child: DecorativeImage(),
/// )
/// ```
class RequireExcludeSemanticsJustificationRule extends DartLintRule {
  const RequireExcludeSemanticsJustificationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_exclude_semantics_justification',
    problemMessage:
        'ExcludeSemantics should have a comment explaining why content is excluded.',
    correctionMessage:
        'Add a comment above ExcludeSemantics explaining the rationale.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'ExcludeSemantics') return;

      // Check for preceding comment
      final AstNode? parent = node.parent;
      if (parent == null) {
        reporter.atNode(node.constructorName, code);
        return;
      }

      // Look for comments in the compilation unit
      final CompilationUnit? unit =
          node.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) {
        reporter.atNode(node.constructorName, code);
        return;
      }

      final int nodeOffset = node.offset;
      bool hasComment = false;

      // Check if there's a comment within 200 characters before this node
      for (final Token? token in _getPrecedingTokens(node)) {
        if (token == null) break;
        if (nodeOffset - token.offset > 200) break;

        Token? comment = token.precedingComments;
        while (comment != null) {
          if (nodeOffset - comment.offset < 200) {
            hasComment = true;
            break;
          }
          comment = comment.next;
        }
        if (hasComment) break;
      }

      if (!hasComment) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  Iterable<Token?> _getPrecedingTokens(AstNode node) sync* {
    Token? token = node.beginToken.previous;
    for (int i = 0; i < 5 && token != null; i++) {
      yield token;
      token = token.previous;
    }
  }
}

/// Warns when using color alone to convey information.
///
/// Users with color blindness may not be able to distinguish colors.
/// Always provide an additional indicator (icon, text, pattern).
///
/// This rule checks for color-only status indicators.
///
/// **BAD:**
/// ```dart
/// Container(
///   color: isError ? Colors.red : Colors.green,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(
///   children: [
///     Icon(isError ? Icons.error : Icons.check),
///     Container(color: isError ? Colors.red : Colors.green),
///   ],
/// )
/// ```
class AvoidColorOnlyIndicatorsRule extends DartLintRule {
  const AvoidColorOnlyIndicatorsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_color_only_indicators',
    problemMessage:
        'Avoid using color alone to convey information. Add icons or text.',
    correctionMessage:
        'Add an icon, text label, or pattern alongside the color indicator.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Container') return;

      // Check if color is set conditionally
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'color') {
          if (arg.expression is ConditionalExpression) {
            // Check if Container only has color (simple status indicator)
            final bool hasOnlyColorAndChild =
                node.argumentList.arguments.whereType<NamedExpression>().every(
                      (NamedExpression na) =>
                          na.name.label.name == 'color' ||
                          na.name.label.name == 'child' ||
                          na.name.label.name == 'key' ||
                          na.name.label.name == 'width' ||
                          na.name.label.name == 'height',
                    );

            if (hasOnlyColorAndChild) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when GestureDetector is used without keyboard accessibility.
///
/// Touch gestures like tap, long press, etc. need keyboard equivalents
/// for users who cannot use touch input.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => doSomething(),
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Focus(
///   onKeyEvent: (node, event) {
///     if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
///       doSomething();
///       return KeyEventResult.handled;
///     }
///     return KeyEventResult.ignored;
///   },
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: MyWidget(),
///   ),
/// )
/// ```
class AvoidGestureOnlyInteractionsRule extends DartLintRule {
  const AvoidGestureOnlyInteractionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_only_interactions',
    problemMessage:
        'GestureDetector should have keyboard accessibility alternatives.',
    correctionMessage:
        'Wrap with Focus and handle keyboard events, or use a Button widget.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'GestureDetector') return;

      // Check if inside a Focus, FocusableActionDetector, or Shortcuts widget
      AstNode? current = node.parent;
      bool hasKeyboardSupport = false;

      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Focus' ||
              parentName == 'FocusableActionDetector' ||
              parentName == 'Shortcuts' ||
              parentName == 'Actions') {
            hasKeyboardSupport = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!hasKeyboardSupport) {
        // Check if GestureDetector has interactive callbacks
        final bool hasInteractiveCallback =
            node.argumentList.arguments.any((Expression arg) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            return name == 'onTap' ||
                name == 'onDoubleTap' ||
                name == 'onLongPress';
          }
          return false;
        });

        if (hasInteractiveCallback) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Warns when Semantics widget is missing the label property.
///
/// Interactive elements need semantic labels for screen readers.
///
/// **BAD:**
/// ```dart
/// Semantics(
///   button: true,
///   child: MyCustomButton(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   button: true,
///   label: 'Submit form',
///   child: MyCustomButton(),
/// )
/// ```
class RequireSemanticsLabelRule extends DartLintRule {
  const RequireSemanticsLabelRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_semantics_label',
    problemMessage:
        'Interactive Semantics widget should have a label for screen readers.',
    correctionMessage: 'Add a label parameter describing the element.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _interactiveProperties = <String>{
    'button',
    'link',
    'slider',
    'textField',
    'toggled',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Semantics') return;

      bool hasLabel = false;
      bool isInteractive = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'label') {
            hasLabel = true;
          }
          if (_interactiveProperties.contains(name)) {
            // Check if the value is true
            if (arg.expression is BooleanLiteral) {
              final BooleanLiteral boolLit = arg.expression as BooleanLiteral;
              if (boolLit.value) {
                isInteractive = true;
              }
            }
          }
        }
      }

      if (isInteractive && !hasLabel) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when MergeSemantics might hide important information.
///
/// MergeSemantics combines all descendant semantics into one node.
/// This can hide important information from screen reader users.
///
/// **BAD:**
/// ```dart
/// MergeSemantics(
///   child: Column(
///     children: [
///       Text('Price:'),
///       Text('\$99.99'),
///       ElevatedButton(onPressed: () {}, child: Text('Buy')),
///     ],
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Column(
///   children: [
///     MergeSemantics(
///       child: Row(children: [Text('Price:'), Text('\$99.99')]),
///     ),
///     ElevatedButton(onPressed: () {}, child: Text('Buy')),
///   ],
/// )
/// ```
class AvoidMergedSemanticsHidingInfoRule extends DartLintRule {
  const AvoidMergedSemanticsHidingInfoRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_merged_semantics_hiding_info',
    problemMessage:
        'MergeSemantics may hide important information from assistive technologies.',
    correctionMessage:
        'Review if all merged content should be announced together.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'IconButton',
    'FloatingActionButton',
    'TextField',
    'TextFormField',
    'Checkbox',
    'Radio',
    'Switch',
    'Slider',
    'DropdownButton',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'MergeSemantics') return;

      // Check if it contains interactive widgets
      int interactiveCount = 0;
      node.visitChildren(
        _InteractiveCountVisitor((String name) {
          if (_interactiveWidgets.contains(name)) {
            interactiveCount++;
          }
        }),
      );

      // If MergeSemantics contains interactive widgets, warn
      if (interactiveCount > 0) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

class _InteractiveCountVisitor extends RecursiveAstVisitor<void> {
  _InteractiveCountVisitor(this.onFound);

  final void Function(String) onFound;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = node.constructorName.type.element?.name;
    if (name != null) {
      onFound(name);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when dynamic content doesn't use live region semantics.
///
/// Screen readers need to be notified when content changes dynamically.
/// Use Semantics with liveRegion: true for important updates.
///
/// **BAD:**
/// ```dart
/// Text(errorMessage) // Error message that changes dynamically
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   liveRegion: true,
///   child: Text(errorMessage),
/// )
/// ```
class RequireLiveRegionRule extends DartLintRule {
  const RequireLiveRegionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_live_region',
    problemMessage:
        'Dynamic content that changes should use Semantics with liveRegion.',
    correctionMessage:
        'Wrap with Semantics(liveRegion: true) to announce changes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _dynamicIndicators = <String>{
    'error',
    'warning',
    'alert',
    'notification',
    'message',
    'status',
    'loading',
    'progress',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Text') return;

      // Check if the text content suggests dynamic content
      final Expression? textArg = node.argumentList.arguments.firstOrNull;
      if (textArg == null) return;

      String? variableName;
      if (textArg is SimpleIdentifier) {
        variableName = textArg.name.toLowerCase();
      } else if (textArg is PrefixedIdentifier) {
        variableName = textArg.identifier.name.toLowerCase();
      }

      if (variableName == null) return;

      final bool suggestsDynamic = _dynamicIndicators.any(
        (String indicator) => variableName!.contains(indicator),
      );

      if (!suggestsDynamic) return;

      // Check if already wrapped in Semantics with liveRegion
      AstNode? current = node.parent;
      bool hasLiveRegion = false;

      while (current != null && !hasLiveRegion) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Semantics') {
            hasLiveRegion =
                current.argumentList.arguments.any((Expression arg) {
              if (arg is NamedExpression &&
                  arg.name.label.name == 'liveRegion') {
                if (arg.expression is BooleanLiteral) {
                  return (arg.expression as BooleanLiteral).value;
                }
              }
              return false;
            });
            break;
          }
        }
        current = current.parent;
      }

      if (!hasLiveRegion) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when section headers don't have heading semantics.
///
/// Screen reader users rely on heading semantics to navigate content.
/// Use Semantics with header: true for section titles.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Settings',
///   style: Theme.of(context).textTheme.headlineMedium,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   header: true,
///   child: Text(
///     'Settings',
///     style: Theme.of(context).textTheme.headlineMedium,
///   ),
/// )
/// ```
class RequireHeadingSemanticsRule extends DartLintRule {
  const RequireHeadingSemanticsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_heading_semantics',
    problemMessage: 'Section headers should have Semantics with header: true.',
    correctionMessage:
        'Wrap with Semantics(header: true) for screen reader navigation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _headingStyles = <String>{
    'displayLarge',
    'displayMedium',
    'displaySmall',
    'headlineLarge',
    'headlineMedium',
    'headlineSmall',
    'titleLarge',
    'titleMedium',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Text') return;

      // Check if using a heading text style
      bool usesHeadingStyle = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'style') {
          final String styleSource = arg.expression.toSource();
          usesHeadingStyle = _headingStyles.any(
            (String style) => styleSource.contains(style),
          );
          break;
        }
      }

      if (!usesHeadingStyle) return;

      // Check if wrapped in Semantics with header: true
      AstNode? current = node.parent;
      bool hasHeaderSemantics = false;

      while (current != null && !hasHeaderSemantics) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Semantics') {
            hasHeaderSemantics = current.argumentList.arguments.any((
              Expression arg,
            ) {
              if (arg is NamedExpression && arg.name.label.name == 'header') {
                if (arg.expression is BooleanLiteral) {
                  return (arg.expression as BooleanLiteral).value;
                }
              }
              return false;
            });
            break;
          }
        }
        current = current.parent;
      }

      if (!hasHeaderSemantics) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when image-based buttons lack tooltips.
///
/// Buttons that only show an image or icon need text descriptions
/// for screen reader users.
///
/// **BAD:**
/// ```dart
/// InkWell(
///   onTap: () {},
///   child: Image.asset('assets/logo.png'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Tooltip(
///   message: 'Go to home',
///   child: InkWell(
///     onTap: () {},
///     child: Image.asset('assets/logo.png'),
///   ),
/// )
/// ```
class AvoidImageButtonsWithoutTooltipRule extends DartLintRule {
  const AvoidImageButtonsWithoutTooltipRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_image_buttons_without_tooltip',
    problemMessage:
        'Image-based interactive elements need a Tooltip or semanticLabel.',
    correctionMessage:
        'Wrap with Tooltip or add Semantics to describe the action.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _tapWidgets = <String>{
    'InkWell',
    'InkResponse',
    'GestureDetector',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (!_tapWidgets.contains(constructorName)) return;

      // Check if has onTap
      final bool hasOnTap = node.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'onTap';
        }
        return false;
      });

      if (!hasOnTap) return;

      // Check if child is an image
      bool hasImageChild = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          if (arg.expression is InstanceCreationExpression) {
            final InstanceCreationExpression child =
                arg.expression as InstanceCreationExpression;
            final String? childName = child.constructorName.type.element?.name;
            if (childName == 'Image' ||
                childName == 'Icon' ||
                childName == 'SvgPicture') {
              hasImageChild = true;
            }
          }
        }
      }

      if (!hasImageChild) return;

      // Check if wrapped in Tooltip or Semantics
      AstNode? current = node.parent;
      bool hasAccessibility = false;

      while (current != null && !hasAccessibility) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Tooltip' || parentName == 'Semantics') {
            hasAccessibility = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!hasAccessibility) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}
