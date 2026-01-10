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
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class AvoidIconButtonsWithoutTooltipRule extends SaropaLintRule {
  const AvoidIconButtonsWithoutTooltipRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_icon_buttons_without_tooltip',
    problemMessage:
        'IconButton lacks a tooltip. Screen readers cannot announce its purpose.',
    correctionMessage:
        "Add tooltip: 'Description of action' to describe what the button does.",
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
class AvoidSmallTouchTargetsRule extends SaropaLintRule {
  const AvoidSmallTouchTargetsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireExcludeSemanticsJustificationRule extends SaropaLintRule {
  const RequireExcludeSemanticsJustificationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_exclude_semantics_justification',
    problemMessage:
        'ExcludeSemantics should have a comment explaining why content is excluded.',
    correctionMessage:
        'Add a comment above ExcludeSemantics explaining the rationale.',
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
class AvoidColorOnlyIndicatorsRule extends SaropaLintRule {
  const AvoidColorOnlyIndicatorsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_color_only_indicators',
    problemMessage:
        'Avoid using color alone to convey information. Add icons or text.',
    correctionMessage:
        'Add an icon, text label, or pattern alongside the color indicator.',
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
class AvoidGestureOnlyInteractionsRule extends SaropaLintRule {
  const AvoidGestureOnlyInteractionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_only_interactions',
    problemMessage:
        'GestureDetector should have keyboard accessibility alternatives.',
    correctionMessage:
        'Wrap with Focus and handle keyboard events, or use a Button widget.',
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
class RequireSemanticsLabelRule extends SaropaLintRule {
  const RequireSemanticsLabelRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_semantics_label',
    problemMessage:
        'Interactive Semantics widget lacks a label. Screen readers cannot describe it.',
    correctionMessage:
        "Add label: 'Description' to describe the interactive element's purpose.",
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidMergedSemanticsHidingInfoRule extends SaropaLintRule {
  const AvoidMergedSemanticsHidingInfoRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_merged_semantics_hiding_info',
    problemMessage:
        'MergeSemantics contains interactive widgets. Buttons/inputs may become inaccessible.',
    correctionMessage:
        'Move interactive widgets outside MergeSemantics, or wrap only related text content.',
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireLiveRegionRule extends SaropaLintRule {
  const RequireLiveRegionRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireHeadingSemanticsRule extends SaropaLintRule {
  const RequireHeadingSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidImageButtonsWithoutTooltipRule extends SaropaLintRule {
  const AvoidImageButtonsWithoutTooltipRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

/// Warns when textScaleFactor is set to 1.0, ignoring user accessibility settings.
///
/// Users with visual impairments rely on system text scaling to make text
/// readable. Hardcoding textScaleFactor: 1.0 overrides their preferences.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   textScaleFactor: 1.0, // Ignores accessibility settings!
/// )
/// MediaQuery(
///   data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
///   child: child,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text('Hello') // Respects system text scale
/// // Or if you need to limit scaling:
/// Text(
///   'Hello',
///   textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.5),
/// )
/// ```
class AvoidTextScaleFactorIgnoreRule extends SaropaLintRule {
  const AvoidTextScaleFactorIgnoreRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_text_scale_factor_ignore',
    problemMessage:
        'Setting textScaleFactor to 1.0 ignores user accessibility settings.',
    correctionMessage:
        'Remove textScaleFactor or use clamp() to limit scaling range.',
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
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'textScaleFactor') {
            // Check if value is 1.0
            final Expression value = arg.expression;
            if (value is DoubleLiteral && value.value == 1.0) {
              reporter.atNode(arg, code);
            } else if (value is IntegerLiteral && value.value == 1) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });

    // Also check for copyWith(textScaleFactor: 1.0)
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'copyWith') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'textScaleFactor') {
            final Expression value = arg.expression;
            if (value is DoubleLiteral && value.value == 1.0) {
              reporter.atNode(arg, code);
            } else if (value is IntegerLiteral && value.value == 1) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Image widget lacks a semanticLabel for screen readers.
///
/// Images without semanticLabel are invisible to screen readers, making
/// content inaccessible to users with visual impairments. Use
/// excludeFromSemantics: true only for purely decorative images.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/photo.jpg')
/// Image.asset('assets/icon.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/photo.jpg',
///   semanticLabel: 'Profile photo of user',
/// )
/// // For decorative images:
/// Image.asset(
///   'assets/decoration.png',
///   excludeFromSemantics: true,
/// )
/// ```
class RequireImageSemanticsRule extends SaropaLintRule {
  const RequireImageSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_image_semantics',
    problemMessage:
        'Image lacks semanticLabel. Screen readers cannot describe this image.',
    correctionMessage:
        "Add semanticLabel: 'description' or excludeFromSemantics: true for decorative images.",
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
      if (constructorName != 'Image') return;

      bool hasSemanticLabel = false;
      bool isExcludedFromSemantics = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'semanticLabel') {
            hasSemanticLabel = true;
          }
          if (name == 'excludeFromSemantics') {
            if (arg.expression is BooleanLiteral) {
              isExcludedFromSemantics =
                  (arg.expression as BooleanLiteral).value;
            }
          }
        }
      }

      if (!hasSemanticLabel && !isExcludedFromSemantics) {
        reporter.atNode(node.constructorName, code);
      }
    });

    // Also check Image.network, Image.asset, Image.file, Image.memory
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (target is! SimpleIdentifier || target.name != 'Image') return;
      if (!<String>{'network', 'asset', 'file', 'memory'}
          .contains(methodName)) {
        return;
      }

      bool hasSemanticLabel = false;
      bool isExcludedFromSemantics = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'semanticLabel') {
            hasSemanticLabel = true;
          }
          if (name == 'excludeFromSemantics') {
            if (arg.expression is BooleanLiteral) {
              isExcludedFromSemantics =
                  (arg.expression as BooleanLiteral).value;
            }
          }
        }
      }

      if (!hasSemanticLabel && !isExcludedFromSemantics) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when interactive elements have excludeFromSemantics but also have tap handlers.
///
/// Elements with tap handlers that are excluded from semantics are completely
/// inaccessible to screen reader users. This is a critical accessibility bug.
///
/// **BAD:**
/// ```dart
/// Semantics(
///   excludeFromSemantics: true,
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: Icon(Icons.add),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   button: true,
///   label: 'Add item',
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: Icon(Icons.add),
///   ),
/// )
/// ```
class AvoidHiddenInteractiveRule extends SaropaLintRule {
  const AvoidHiddenInteractiveRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_hidden_interactive',
    problemMessage:
        'Interactive element with excludeFromSemantics is inaccessible to screen readers.',
    correctionMessage:
        'Remove excludeFromSemantics or provide Semantics wrapper with label.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'GestureDetector',
    'InkWell',
    'InkResponse',
    'IconButton',
    'TextButton',
    'ElevatedButton',
    'OutlinedButton',
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

      // Check for ExcludeSemantics wrapping interactive widgets
      if (constructorName == 'ExcludeSemantics') {
        // Check if child contains interactive widget
        bool hasInteractiveChild = false;
        node.visitChildren(
          _InteractiveChildVisitor((String name) {
            if (_interactiveWidgets.contains(name)) {
              hasInteractiveChild = true;
            }
          }),
        );

        if (hasInteractiveChild) {
          reporter.atNode(node.constructorName, code);
        }
      }

      // Check for Semantics(excludeSemantics: true) with interactive child
      if (constructorName == 'Semantics') {
        bool hasExcludeSemantics = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression &&
              arg.name.label.name == 'excludeSemantics') {
            if (arg.expression is BooleanLiteral) {
              hasExcludeSemantics = (arg.expression as BooleanLiteral).value;
            }
          }
        }

        if (hasExcludeSemantics) {
          bool hasInteractiveChild = false;
          node.visitChildren(
            _InteractiveChildVisitor((String name) {
              if (_interactiveWidgets.contains(name)) {
                hasInteractiveChild = true;
              }
            }),
          );

          if (hasInteractiveChild) {
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

class _InteractiveChildVisitor extends RecursiveAstVisitor<void> {
  _InteractiveChildVisitor(this.onFound);

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

/// Warns when text uses fixed pixel sizes that don't scale with system settings.
///
/// Text should scale with system font size settings for users with visual
/// impairments. Avoid fixed pixel sizes and let text scale naturally.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(fontSize: 14), // Fixed size - won't scale!
/// )
/// Text(
///   'Hello',
///   textScaleFactor: 1.0, // Forces no scaling!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: Theme.of(context).textTheme.bodyMedium, // Scales with system
/// )
/// // Or use relative sizing:
/// Text(
///   'Hello',
///   style: TextStyle(fontSize: 14 * MediaQuery.textScaleFactorOf(context)),
/// )
/// ```
class PreferScalableTextRule extends SaropaLintRule {
  const PreferScalableTextRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_scalable_text',
    problemMessage:
        'Fixed font size does not scale with user accessibility settings.',
    correctionMessage:
        'Use Theme.textTheme or consider MediaQuery.textScaleFactorOf for scaling.',
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

      // Check for fontSize argument with literal value
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'fontSize') {
          final Expression valueExpr = arg.expression;

          // Report if it's a literal number
          if (valueExpr is IntegerLiteral || valueExpr is DoubleLiteral) {
            reporter.atNode(arg, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when custom tap targets lack Semantics with button: true.
///
/// GestureDetector and InkWell on non-button widgets are invisible to
/// screen readers unless wrapped with Semantics indicating they're buttons.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => doSomething(),
///   child: Container(
///     child: Icon(Icons.add),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   button: true,
///   label: 'Add item',
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: Container(
///       child: Icon(Icons.add),
///     ),
///   ),
/// )
/// // Or use IconButton which has built-in semantics:
/// IconButton(
///   onPressed: () => doSomething(),
///   icon: Icon(Icons.add),
///   tooltip: 'Add item',
/// )
/// ```
class RequireButtonSemanticsRule extends SaropaLintRule {
  const RequireButtonSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_button_semantics',
    problemMessage:
        'Custom tap target needs Semantics with button: true for accessibility.',
    correctionMessage:
        'Wrap with Semantics(button: true, label: "...") or use IconButton/TextButton.',
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

      // Check if has onTap
      bool hasOnTap = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'onTap' || name == 'onPressed' || name == 'onLongPress') {
            hasOnTap = true;
            break;
          }
        }
      }

      if (!hasOnTap) return;

      // Check if wrapped in Semantics
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'Semantics') {
            // Check for button: true
            for (final Expression arg in current.argumentList.arguments) {
              if (arg is NamedExpression && arg.name.label.name == 'button') {
                return; // Has Semantics with button property
              }
            }
          }
        }
        // Stop at method boundaries
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when custom widgets lack explicit Semantics wrapper.
///
/// Custom widgets that display meaningful content need Semantics to be
/// accessible. Screen readers can't understand custom-painted or composed
/// widgets without explicit semantic information.
///
/// **BAD:**
/// ```dart
/// class StarRating extends StatelessWidget {
///   Widget build(context) {
///     return Row(
///       children: List.generate(5, (i) => Icon(
///         i < rating ? Icons.star : Icons.star_border,
///       )),
///     ); // Screen reader sees nothing useful
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class StarRating extends StatelessWidget {
///   Widget build(context) {
///     return Semantics(
///       label: '$rating out of 5 stars',
///       child: Row(
///         children: List.generate(5, (i) => Icon(
///           i < rating ? Icons.star : Icons.star_border,
///         )),
///       ),
///     );
///   }
/// }
/// ```
class PreferExplicitSemanticsRule extends SaropaLintRule {
  const PreferExplicitSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_semantics',
    problemMessage:
        'Custom widget may need explicit Semantics for screen reader access.',
    correctionMessage:
        'Consider adding Semantics(label: "...") to describe the widget purpose.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends StatelessWidget or StatefulWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String? superName = extendsClause.superclass.element?.name;
      if (superName != 'StatelessWidget' && superName != 'StatefulWidget') {
        return;
      }

      // Check if widget name suggests visual/custom content
      final String className = node.name.lexeme;
      final List<String> visualPatterns = <String>[
        'Rating',
        'Chart',
        'Graph',
        'Progress',
        'Avatar',
        'Badge',
        'Indicator',
        'Status',
        'Custom',
        'Canvas',
        'Painter',
      ];

      bool needsSemantics = false;
      for (final String pattern in visualPatterns) {
        if (className.contains(pattern)) {
          needsSemantics = true;
          break;
        }
      }

      if (!needsSemantics) return;

      // Check if build method has Semantics
      final String classSource = node.toSource();
      if (!classSource.contains('Semantics')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when MouseRegion or Listener is used without tap alternative.
///
/// Hover-only interactions are inaccessible on touch devices and for
/// screen reader users. Always provide tap or button alternatives.
///
/// **BAD:**
/// ```dart
/// MouseRegion(
///   onEnter: (_) => showTooltip(),
///   onExit: (_) => hideTooltip(),
///   child: Icon(Icons.info),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   onTap: () => showTooltip(), // Touch alternative
///   child: MouseRegion(
///     onEnter: (_) => showTooltip(),
///     onExit: (_) => hideTooltip(),
///     child: Icon(Icons.info),
///   ),
/// )
/// // Or use Tooltip which handles both:
/// Tooltip(
///   message: 'Information',
///   child: Icon(Icons.info),
/// )
/// ```
class AvoidHoverOnlyRule extends SaropaLintRule {
  const AvoidHoverOnlyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_hover_only',
    problemMessage: 'Hover-only interaction is inaccessible on touch devices.',
    correctionMessage:
        'Add GestureDetector with onTap or use widgets like Tooltip that handle both.',
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
      if (typeName != 'MouseRegion' && typeName != 'Listener') return;

      // Check if has hover callbacks
      bool hasHover = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'onEnter' || name == 'onExit' || name == 'onHover') {
            hasHover = true;
            break;
          }
        }
      }

      if (!hasHover) return;

      // Check if wrapped in GestureDetector or similar
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'GestureDetector' ||
              parentType == 'InkWell' ||
              parentType == 'Tooltip' ||
              parentType == 'IconButton' ||
              parentType == 'TextButton') {
            return; // Has tap alternative
          }
        }
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      // Also check if child contains tap widgets
      final String nodeSource = node.toSource();
      if (nodeSource.contains('GestureDetector') ||
          nodeSource.contains('InkWell') ||
          nodeSource.contains('onTap') ||
          nodeSource.contains('onPressed')) {
        return;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when error states don't have non-color indicators.
///
/// Errors must be identifiable without color. Users with color blindness
/// cannot distinguish red from other colors. Add icons, text labels,
/// and positional cues alongside color changes.
///
/// **BAD:**
/// ```dart
/// Container(
///   color: hasError ? Colors.red : Colors.grey,
///   child: Text('Email'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(
///   children: [
///     if (hasError) Icon(Icons.error, color: Colors.red),
///     Text(
///       'Email',
///       style: TextStyle(color: hasError ? Colors.red : null),
///     ),
///     if (hasError) Text(' - Required field'),
///   ],
/// )
/// ```
class RequireErrorIdentificationRule extends SaropaLintRule {
  const RequireErrorIdentificationRule() : super(code: _code);

  /// Accessibility issue affecting colorblind users.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_error_identification',
    problemMessage:
        'Error state uses only color. Add icon, text label, or other non-color indicator.',
    correctionMessage:
        'Add an error icon (Icons.error) or text message alongside color change.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConditionalExpression((ConditionalExpression node) {
      // Check for pattern: condition ? Colors.red/error : something
      final String conditionSource = node.condition.toSource().toLowerCase();
      final String thenSource = node.thenExpression.toSource().toLowerCase();
      final String elseSource = node.elseExpression.toSource().toLowerCase();

      // Check if this is an error-related condition
      if (!conditionSource.contains('error') &&
          !conditionSource.contains('invalid') &&
          !conditionSource.contains('haserror') &&
          !conditionSource.contains('iserror') &&
          !conditionSource.contains('isvalid')) {
        return;
      }

      // Check if using error colors
      if (!thenSource.contains('red') &&
          !thenSource.contains('error') &&
          !elseSource.contains('red') &&
          !elseSource.contains('error')) {
        return;
      }

      // Check if this is in a color-only context (no icon nearby)
      // Look for Icon, errorText, or helperText in surrounding context
      AstNode? current = node.parent;
      int depth = 0;
      bool hasNonColorIndicator = false;

      while (current != null && depth < 10) {
        final String source = current.toSource();
        if (source.contains('Icon(') ||
            source.contains('Icons.error') ||
            source.contains('Icons.warning') ||
            source.contains('errorText') ||
            source.contains('helperText') ||
            source.contains('decoration:') && source.contains('error')) {
          hasNonColorIndicator = true;
          break;
        }
        current = current.parent;
        depth++;
      }

      if (!hasNonColorIndicator) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when text may have insufficient contrast ratio.
///
/// Text must have 4.5:1 contrast ratio against background (3:1 for large text).
/// This rule flags potential issues when light colors are used on light
/// backgrounds or dark colors on dark backgrounds.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(color: Colors.grey[300]), // Light gray on white
/// )
/// Container(
///   color: Colors.black,
///   child: Text('Hello', style: TextStyle(color: Colors.grey[700])),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(color: Colors.grey[700]), // Darker gray on white
/// )
/// Container(
///   color: Colors.black,
///   child: Text('Hello', style: TextStyle(color: Colors.white)),
/// )
/// ```
class RequireMinimumContrastRule extends SaropaLintRule {
  const RequireMinimumContrastRule() : super(code: _code);

  /// Accessibility issue affecting users with low vision.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_minimum_contrast',
    problemMessage:
        'Text color may have insufficient contrast. WCAG requires 4.5:1 ratio.',
    correctionMessage:
        'Use darker text on light backgrounds or lighter text on dark backgrounds.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Light colors that may have contrast issues on white/light backgrounds
  static const Set<String> _lightColors = <String>{
    'grey[100]',
    'grey[200]',
    'grey[300]',
    'grey[400]',
    'grey.shade100',
    'grey.shade200',
    'grey.shade300',
    'grey.shade400',
    'white',
    'white10',
    'white12',
    'white24',
    'white30',
    'white38',
    'white54',
    'yellow[100]',
    'yellow[200]',
    'yellow.shade100',
    'yellow.shade200',
    'amber[100]',
    'amber[200]',
    'lime[100]',
    'lime[200]',
    'cyan[100]',
    'cyan[200]',
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

      if (typeName != 'TextStyle') return;

      // Check for color argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'color') {
          final String colorSource = arg.expression.toSource();

          // Check if it's a light color
          for (final String lightColor in _lightColors) {
            if (colorSource.contains(lightColor)) {
              // Check if there's an explicit dark background nearby
              if (!_hasDarkBackgroundContext(node)) {
                reporter.atNode(arg, code);
              }
              return;
            }
          }
        }
      }
    });
  }

  bool _hasDarkBackgroundContext(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 8) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'Container' || typeName == 'DecoratedBox') {
          final String source = current.toSource();
          // Check for dark background colors
          if (source.contains('black') ||
              source.contains('grey[800]') ||
              source.contains('grey[900]') ||
              source.contains('grey.shade800') ||
              source.contains('grey.shade900')) {
            return true;
          }
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when CircleAvatar lacks a semanticLabel for accessibility.
///
/// Screen readers need a description to announce what the avatar represents.
/// Without semanticLabel, the avatar is invisible to blind users.
///
/// **BAD:**
/// ```dart
/// CircleAvatar(
///   backgroundImage: NetworkImage(user.photoUrl),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CircleAvatar(
///   backgroundImage: NetworkImage(user.photoUrl),
///   semanticLabel: 'Profile photo of ${user.name}',
/// )
/// ```
class RequireAvatarAltTextRule extends SaropaLintRule {
  const RequireAvatarAltTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_avatar_alt_text',
    problemMessage:
        'CircleAvatar lacks semanticLabel. Screen readers cannot describe it.',
    correctionMessage:
        'Add semanticLabel: "Description of avatar" for accessibility.',
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
      if (typeName != 'CircleAvatar') return;

      // Check for semanticLabel argument
      bool hasSemanticLabel = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'semanticLabel') {
          hasSemanticLabel = true;
          break;
        }
      }

      if (!hasSemanticLabel) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Badge widget lacks accessibility semantics.
///
/// Badges convey important information (like notification counts) that
/// screen reader users need to hear. Without proper semantics, this
/// information is hidden from blind users.
///
/// **BAD:**
/// ```dart
/// Badge(
///   label: Text('5'),
///   child: Icon(Icons.mail),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   label: '5 unread messages',
///   child: Badge(
///     label: Text('5'),
///     child: Icon(Icons.mail),
///   ),
/// )
/// ```
class RequireBadgeSemanticsRule extends SaropaLintRule {
  const RequireBadgeSemanticsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_badge_semantics',
    problemMessage:
        'Badge lacks accessibility semantics. Screen readers cannot announce it.',
    correctionMessage:
        'Wrap Badge in Semantics widget with descriptive label.',
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
      if (typeName != 'Badge') return;

      // Check if wrapped in Semantics widget
      if (!_hasSemanticAncestor(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _hasSemanticAncestor(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 5) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'Semantics') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when Badge displays count greater than 99 without truncation.
///
/// Large numbers in badges are hard to read and look unprofessional.
/// The convention is to show "99+" for counts above 99.
///
/// **BAD:**
/// ```dart
/// Badge(
///   label: Text('150'),
///   child: Icon(Icons.mail),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Badge(
///   label: Text(count > 99 ? '99+' : '$count'),
///   child: Icon(Icons.mail),
/// )
/// ```
class RequireBadgeCountLimitRule extends SaropaLintRule {
  const RequireBadgeCountLimitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_badge_count_limit',
    problemMessage:
        'Badge count exceeds 99. Use "99+" pattern for large numbers.',
    correctionMessage:
        'Replace with: Text(count > 99 ? "99+" : "\$count")',
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
      if (typeName != 'Badge') return;

      // Check label argument for literal number > 99
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'label') {
          final Expression labelExpr = arg.expression;

          // Check if it's a Text widget with a literal number
          if (labelExpr is InstanceCreationExpression) {
            final String labelTypeName =
                labelExpr.constructorName.type.name.lexeme;
            if (labelTypeName == 'Text' &&
                labelExpr.argumentList.arguments.isNotEmpty) {
              final Expression textArg =
                  labelExpr.argumentList.arguments.first;
              if (textArg is SimpleStringLiteral) {
                final int? number = int.tryParse(textArg.value);
                if (number != null && number > 99) {
                  reporter.atNode(arg, code);
                }
              }
            }
          }
        }
      }
    });
  }
}
