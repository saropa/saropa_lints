// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

class RequireTextOverflowHandlingRule extends SaropaLintRule {
  RequireTextOverflowHandlingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_text_overflow_handling',
    '[require_text_overflow_handling] Text displaying dynamic content (user input, API data, translations) without overflow handling can break layouts when the text is longer than expected. Unbounded text pushes sibling widgets off-screen, triggers RenderFlex overflow errors in Row/Column contexts, and creates inconsistent UI across locales with varying text lengths. {v3}',
    correctionMessage:
        'Add overflow: TextOverflow.ellipsis and maxLines to limit visible lines, or wrap in Expanded/Flexible within Row/Column to constrain the available width.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
}

/// Requires Image.network to have an errorBuilder for handling load failures.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
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
  RequireImageErrorBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_image_error_builder',
    '[require_image_error_builder] Network image without errorBuilder shows a broken image icon or blank space when the URL is invalid, the server is down, or the network is unavailable. This creates a poor user experience with no indication of what went wrong and no way to retry loading the image. {v3}',
    correctionMessage:
        'Add errorBuilder: (context, error, stackTrace) => FallbackWidget() to display a placeholder icon, error message, or retry button when image loading fails.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Requires network images to specify width and height for layout stability.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
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
  RequireImageDimensionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'require_image_dimensions',
    '[require_image_dimensions] Network image without explicit dimensions causes layout shifts (CLS) when the image loads, as the widget expands from zero to the image size. This pushes surrounding content around, creates a jarring user experience, and negatively impacts web Core Web Vitals scores. {v2}',
    correctionMessage:
        'Set width and height on the Image widget matching the expected aspect ratio, or wrap it in a SizedBox/AspectRatio with fixed dimensions to reserve space before the image loads.',
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
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
  RequirePlaceholderForNetworkRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_placeholder_for_network',
    '[require_placeholder_for_network] Network image without a placeholder or loadingBuilder shows blank space while the image downloads, giving users no indication that content is loading. On slow connections this blank period can last several seconds, making the UI appear broken or unresponsive. {v4}',
    correctionMessage:
        'Add loadingBuilder to show a progress indicator during download, or use a placeholder image (e.g. a low-res thumbnail or shimmer effect) to indicate loading state.',
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
        reporter.atNode(node);
      }
    });
  }
}

/// Requires ScrollController fields to be disposed in State classes.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
class RequireHoverStatesRule extends SaropaLintRule {
  RequireHoverStatesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_hover_states',
    '[require_hover_states] Interactive widget on web/desktop without hover feedback feels unresponsive to mouse users. Hover states are a fundamental interaction pattern on these platforms, signaling clickability and providing visual confirmation that the cursor is over the target. Missing hover states make the app feel like a mobile port rather than a native desktop experience. {v6}',
    correctionMessage:
        'Add onHover callback to change visual state (e.g. elevation, background color, or border) when the mouse enters the widget. Material widgets like ElevatedButton handle this automatically.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
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
  RequireButtonLoadingStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_button_loading_state',
    '[require_button_loading_state] Button triggering an async operation without a loading state indicator leaves users unsure whether their tap was registered. They may tap again (causing duplicate requests), navigate away (abandoning the operation), or assume the app is frozen. A loading state provides essential feedback for async interactions. {v5}',
    correctionMessage:
        'Show a CircularProgressIndicator and set onPressed to null while the async operation runs. Restore the button when the operation completes or fails.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
      bool isAsync =
          onPressedSource.contains('async') ||
          onPressedSource.contains('await');

      if (!isAsync) return;

      // Check if there's loading state handling
      bool hasLoadingState =
          onPressedSource.contains('isLoading') ||
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
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
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
class RequireRefreshIndicatorRule extends SaropaLintRule {
  RequireRefreshIndicatorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_refresh_indicator',
    '[require_refresh_indicator] List displaying remote data without pull-to-refresh forces users to navigate away and back to see updated content. This common UX pattern is expected on both platforms, and its absence makes the app feel unresponsive when data becomes stale. Users have no self-service way to recover from a failed initial load. {v5}',
    correctionMessage:
        'Wrap the scrollable list with RefreshIndicator(onRefresh: () async => fetchData(), child: listView) to enable pull-to-refresh for data refresh.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
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
  RequireDefaultTextStyleRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_default_text_style',
    '[require_default_text_style] Multiple sibling Text widgets repeat the same TextStyle, creating redundant style objects and making future style changes error-prone since each instance must be updated independently. DefaultTextStyle applies a shared style to all descendant Text widgets automatically, keeping the code DRY and consistent. {v5}',
    correctionMessage:
        'Wrap the parent widget with DefaultTextStyle(style: sharedStyle, child: ...) and remove individual style parameters from child Text widgets that use the common style.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Row/Column with overflow could use Wrap instead.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v3
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
class RequireDisabledStateRule extends SaropaLintRule {
  RequireDisabledStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_disabled_state',
    '[require_disabled_state] Button without custom disabled styling uses the framework default gray appearance, which may not match your app design system or provide sufficient contrast. Customizing the disabled state ensures visual consistency, communicates the disabled status clearly, and maintains your brand identity across all button states. {v5}',
    correctionMessage:
        'Add a ButtonStyle with disabledBackgroundColor and disabledForegroundColor via styleFrom or the theme, ensuring disabled buttons match your design system.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_buttonWidgets.contains(typeName)) return;

      bool hasConditionalOnPressed = false;
      bool hasStyleHandling = false;
      final questionMarkPattern = RegExp(r'\?');
      final nullWordPattern = RegExp(r'\bnull\b');

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;

          if (argName == 'onPressed') {
            final String exprSource = arg.expression.toSource();
            if (questionMarkPattern.hasMatch(exprSource) &&
                nullWordPattern.hasMatch(exprSource)) {
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
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v4
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
  RequireDragFeedbackRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_drag_feedback',
    '[require_drag_feedback] Draggable without a feedback widget shows no visual representation of the dragged item under the user finger/cursor. The original child disappears (replaced by childWhenDragging or nothing) while the drag area appears empty, making it impossible for the user to see what they are dragging or where to drop it. {v4}',
    correctionMessage:
        'Add a feedback parameter with a widget representing the dragged item (e.g. a semi-transparent copy of the child or a Material-elevated card).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v6
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
class RequireLongPressCallbackRule extends SaropaLintRule {
  RequireLongPressCallbackRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'require_long_press_callback',
    '[require_long_press_callback] Interactive list item without onLongPress misses a standard mobile interaction pattern for secondary actions. Users expect long-press to reveal context menus, selection mode, or additional options. Omitting this leaves no discoverable path to bulk actions like delete, share, or move. {v3}',
    correctionMessage:
        'Add onLongPress callback to show a context menu (showMenu), enter selection mode, or trigger a bottom sheet with secondary actions for the item.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v4
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
class RequireErrorWidgetRule extends SaropaLintRule {
  RequireErrorWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_error_widget',
    '[require_error_widget] FutureBuilder/StreamBuilder must handle error state to prevent silent failures, blank screens, or cryptic UI. Without error handling, users may see no feedback when data fails to load, leading to confusion, poor UX, and support burden. This can also mask backend or network issues during development. {v4}',
    correctionMessage:
        'Add error handling: if (snapshot.hasError) show a user-friendly error message or fallback UI. Log errors for diagnostics and provide actionable feedback to users. Audit all async builders for error handling coverage.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v3
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
  RequireFormValidationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'require_form_validation',
    '[require_form_validation] TextFormField inside a Form without a validator function bypasses the form validation pipeline entirely. Calling formKey.currentState.validate() will always return true for this field, allowing invalid or empty input to reach the backend, causing data integrity issues and poor user feedback. {v3}',
    correctionMessage:
        'Add a validator parameter (e.g. validator: (value) => value?.isEmpty ?? true ? \"Required field\" : null) to participate in Form.validate() calls.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v4
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
  RequireThemeColorFromSchemeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_theme_color_from_scheme',
    '[require_theme_color_from_scheme] Hardcoded Color value (e.g. Colors.blue, Color(0xFF...)) does not adapt to light/dark theme, high-contrast mode, or dynamic color (Material You). This breaks theming consistency and accessibility, as the color may become unreadable against the themed background in alternate modes. {v4}',
    correctionMessage:
        'Replace with Theme.of(context).colorScheme.primary, .secondary, .surface, .onSurface, etc. to use theme-aware colors that adapt to light/dark mode automatically.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check for Color(0x...) hardcoded colors
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Color') return;

      // Skip if in theme definition file
      final String filePath = context.filePath.toLowerCase();
      if (filePath.contains('theme') || filePath.contains('color')) return;

      // Check for hex literal
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is IntegerLiteral) {
          reporter.atNode(node);
        }
      }
    });

    // Check for Colors.* constants
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Colors') return;

      // Skip Colors.transparent - commonly used and valid
      if (node.identifier.name == 'transparent') return;

      // Skip if in theme definition
      final String filePath = context.filePath.toLowerCase();
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when ColorScheme is created manually instead of using fromSeed.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v4
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
class RequireSafeAreaHandlingRule extends SaropaLintRule {
  RequireSafeAreaHandlingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'require_safe_area_handling',
    '[require_safe_area_handling] Scaffold body without safe area handling allows content to render behind device notches, camera cutouts, rounded corners, and home indicators. On modern devices with non-rectangular displays, this causes text and interactive elements to be obscured or unreachable. {v2}',
    correctionMessage:
        'Wrap the Scaffold body with SafeArea, or use MediaQuery.paddingOf(context) to manually inset content away from system UI intrusions.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
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
class RequireWindowSizeConstraintsRule extends SaropaLintRule {
  RequireWindowSizeConstraintsRule() : super(code: _code);

  /// Window can resize to unusable dimensions without constraints.
  /// Users may accidentally make window too small to use.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_window_size_constraints',
    '[require_window_size_constraints] Desktop app without minimum window size allows users to resize the window below the minimum layout dimensions, causing text overflow, clipped buttons, and broken layouts. Setting a minimum size prevents the window from reaching dimensions where the UI cannot function properly. {v2}',
    correctionMessage:
        'Use the window_manager package to call setMinimumSize(Size(minWidth, minHeight)) during app initialization, based on your minimum supported layout dimensions.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String path = context.filePath;

    // Only check main.dart in desktop contexts
    if (!path.endsWith('main.dart')) return;

    context.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final String mainSource = node.toSource();

      // Check if has runApp but no window size setup
      if (mainSource.contains('runApp')) {
        final bool hasWindowSetup =
            mainSource.contains('setMinimumSize') ||
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
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
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
class RequireOrientationHandlingRule extends SaropaLintRule {
  RequireOrientationHandlingRule() : super(code: _code);

  /// UX issue - broken layouts in certain orientations.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_orientation_handling',
    '[require_orientation_handling] MaterialApp without orientation handling. May break in landscape. This widget pattern increases complexity and makes the widget tree harder to maintain and debug. {v3}',
    correctionMessage:
        'Call SystemChrome.setPreferredOrientations in main() to lock orientation, or use OrientationBuilder/LayoutBuilder to provide responsive layouts for both portrait and landscape.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
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

// =============================================================================
// Part 3: Widget Lifecycle Rules
// =============================================================================

/// Warns when dispose() method doesn't call super.dispose().
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
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
class RequireTextFormFieldInFormRule extends SaropaLintRule {
  RequireTextFormFieldInFormRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_text_form_field_in_form',
    '[require_text_form_field_in_form] TextFormField outside a Form ancestor cannot participate in form-level validation. Calling formKey.currentState.validate() will not reach this field, and its validator callback will never execute. The field behaves identically to a plain TextField but misleads readers into thinking validation is wired up. {v2}',
    correctionMessage:
        'Wrap the TextFormField and its siblings in a Form widget with a GlobalKey<FormState>, or replace it with TextField if form-level validation is not needed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v3
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
  RequireWebViewNavigationDelegateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_webview_navigation_delegate',
    '[require_webview_navigation_delegate] Without navigation delegate, '
        'WebView can navigate to malicious or phishing sites. {v3}',
    correctionMessage:
        'Add navigationDelegate to validate URLs before navigation.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _webViewTypes = <String>{
    'WebView',
    'WebViewWidget',
    'InAppWebView',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
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
  RequireAnimatedBuilderChildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_animated_builder_child',
    '[require_animated_builder_child] AnimatedBuilder without a child parameter rebuilds the entire subtree on every animation frame. Static widgets that do not depend on the animation value are needlessly reconstructed 60 times per second, wasting CPU cycles and causing jank in complex widget trees. {v2}',
    correctionMessage:
        'Move static widgets to the child parameter of AnimatedBuilder. The child is built once and passed to the builder callback, avoiding reconstruction on each frame.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireRethrowPreserveStackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_rethrow_preserve_stack',
    '[require_rethrow_preserve_stack] Using \"throw e\" in a catch block creates a new stack trace starting from the throw site, discarding the original stack trace that shows where the error actually occurred. This makes debugging significantly harder because the error origin is lost. The rethrow keyword preserves the original stack trace. {v2}',
    correctionMessage:
        'Replace \"throw e\" with \"rethrow\" to preserve the original stack trace. If you need to wrap the error, throw a new exception with the original as the cause.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addThrowExpression((ThrowExpression node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when http:// URLs are used in network calls.
///
/// Since: v4.13.0 | Rule version: v1
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
  RequireHttpsOverHttpRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_https_over_http',
    '[require_https_over_http] HTTP transmits data in plain text. '
        'Attackers can intercept credentials, tokens, and user data. {v1}',
    correctionMessage: 'Replace http:// with https://.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final value = node.value;
      if (value.startsWith('http://') &&
          !value.startsWith('http://localhost') &&
          !value.startsWith('http://127.0.0.1') &&
          !value.startsWith('http://10.') &&
          !value.startsWith('http://192.168.')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when ws:// URLs are used for WebSocket connections.
///
/// Since: v4.13.0 | Rule version: v1
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
  RequireWssOverWsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_wss_over_ws',
    '[require_wss_over_ws] ws:// transmits data unencrypted. Attackers '
        'can intercept, read, and modify WebSocket messages in transit. {v1}',
    correctionMessage: 'Replace ws:// with wss://.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final value = node.value;
      if (value.startsWith('ws://') &&
          !value.startsWith('ws://localhost') &&
          !value.startsWith('ws://127.0.0.1') &&
          !value.startsWith('ws://10.') &&
          !value.startsWith('ws://192.168.')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when `late` is used without guaranteed initialization.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
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
class RequireImagePickerPermissionIosRule extends SaropaLintRule {
  RequireImagePickerPermissionIosRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_image_picker_permission_ios',
    '[require_image_picker_permission_ios] Missing Info.plist entries cause '
        'app rejection by App Store or instant crash when accessing photos. {v3}',
    correctionMessage:
        'Add NSPhotoLibraryUsageDescription and NSCameraUsageDescription to Info.plist.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only report once per file using image_picker
    bool reported = false;

    context.addImportDirective((ImportDirective node) {
      if (reported) return;

      final uri = node.uri.stringValue ?? '';
      if (uri.contains('image_picker')) {
        reporter.atNode(node);
        reported = true;
      }
    });
  }
}

/// Reminder to add camera permission for image_picker on Android.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v3
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
  RequireImagePickerPermissionAndroidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_image_picker_permission_android',
    '[require_image_picker_permission_android] Missing CAMERA permission '
        'causes SecurityException crash when user tries to take a photo. {v3}',
    correctionMessage:
        'Add <uses-permission android:name="android.permission.CAMERA"/> to manifest.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'pickImage') return;

      // Check for ImageSource.camera
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'source') {
          if (arg.expression.toSource() == 'ImageSource.camera') {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Reminder to add manifest entry for runtime permissions.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v3
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
  RequirePermissionManifestAndroidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_permission_manifest_android',
    '[require_permission_manifest_android] Runtime permission request without '
        'manifest entry always fails. Feature silently stops working. {v3}',
    correctionMessage:
        'Add <uses-permission android:name="android.permission.XXX"/> to manifest.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool reported = false;

    context.addImportDirective((ImportDirective node) {
      if (reported) return;

      final uri = node.uri.stringValue ?? '';
      if (uri.contains('permission_handler')) {
        reporter.atNode(node);
        reported = true;
      }
    });
  }
}

/// Reminder to add Info.plist entries for iOS permissions.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v3
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
  RequirePermissionPlistIosRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_permission_plist_ios',
    '[require_permission_plist_ios] iOS requires usage descriptions in '
        'Info.plist. App crashes or gets rejected from App Store without them. {v3}',
    correctionMessage:
        'Add NSxxxUsageDescription key to Info.plist for each permission.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'request') return;

      final target = node.target;
      if (target == null) return;

      if (!RegExp(r'Permission\.').hasMatch(target.toSource())) return;
      reporter.atNode(node);
    });
  }
}

/// Reminder to add queries element for url_launcher on Android 11+.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v3
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
  RequireUrlLauncherQueriesAndroidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_url_launcher_queries_android',
    '[require_url_launcher_queries_android] Without <queries> in manifest, '
        'canLaunchUrl returns false on Android 11+ even for installed apps. {v3}',
    correctionMessage:
        'Add <queries> element with intent filters to AndroidManifest.xml.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool reported = false;

    context.addImportDirective((ImportDirective node) {
      if (reported) return;

      final uri = node.uri.stringValue ?? '';
      if (uri.contains('url_launcher')) {
        reporter.atNode(node);
        reported = true;
      }
    });
  }
}

/// Reminder to add LSApplicationQueriesSchemes for iOS url_launcher.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v3
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
  RequireUrlLauncherSchemesIosRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_url_launcher_schemes_ios',
    '[require_url_launcher_schemes_ios] Without LSApplicationQueriesSchemes, '
        'canLaunchUrl returns false on iOS even for available URL schemes. {v3}',
    correctionMessage:
        'Add URL schemes to LSApplicationQueriesSchemes array in Info.plist.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'canLaunchUrl' &&
          node.methodName.name != 'canLaunch') {
        return;
      }

      reporter.atNode(node);
    });
  }
}

/// Warns when Stack children are not Positioned widgets.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
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
class RequireLocaleForTextRule extends SaropaLintRule {
  RequireLocaleForTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_locale_for_text',
    '[require_locale_for_text] Text formatting methods (toUpperCase, toLowerCase, number formatting) without an explicit locale use the device default, producing different results across regions. For example, Turkish locale uppercases \"i\" to \"I\" (with a dot), breaking string comparisons and identifiers unexpectedly. {v2}',
    correctionMessage:
        'Pass an explicit locale parameter to text formatting calls, or use toUpperCase() only on ASCII-known strings. Use intl package for locale-aware number and date formatting.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;

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
        reporter.atNode(node);
      }
    });

    // Also check for static constructors like DateFormat.yMd()
    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      if (target.name != 'NumberFormat' && target.name != 'DateFormat') return;

      // Check if locale is provided in the arguments
      final String argsSource = node.argumentList.toSource();
      if (argsSource == '()' || // No arguments
          (!argsSource.contains('locale:') &&
              !argsSource.contains("'en") &&
              !argsSource.contains('"en'))) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when destructive dialogs can be dismissed by tapping barrier.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
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
  RequireDialogBarrierConsiderationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_dialog_barrier_consideration',
    '[require_dialog_barrier_consideration] Destructive confirmation dialog (delete, remove, logout) defaults to barrierDismissible: true, allowing users to accidentally dismiss the dialog by tapping outside. This can silently skip the confirmation step, or worse, leave the user unsure whether the action was confirmed or canceled. {v2}',
    correctionMessage:
        'Set barrierDismissible: false on destructive confirmation dialogs so users must explicitly tap a button to confirm or cancel the action.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _destructivePattern = RegExp(
    r'\b(delete|remove|destroy|cancel|discard|erase|clear|reset|logout|signout|unsubscribe)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'showDialog') return;

      final String argsSource = node.argumentList.toSource();

      // Check if barrierDismissible is set
      if (argsSource.contains('barrierDismissible')) return;

      // Check if dialog content contains destructive keywords
      if (_destructivePattern.hasMatch(argsSource)) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_overlay_portal_layout_builder
// =============================================================================

/// Suggests OverlayPortal.overlayChildLayoutBuilder for unconstrained overlays.
///
/// Flutter 3.38+ OverlayPortal.overlayChildLayoutBuilder helps with overlay layout.
///
/// **Bad:** Overlay.insert without layout builder for overlay children.
///
/// **Good:** Use OverlayPortal.overlayChildLayoutBuilder when building overlay content.
class PreferOverlayPortalLayoutBuilderRule extends SaropaLintRule {
  PreferOverlayPortalLayoutBuilderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_overlay_portal_layout_builder',
    '[prefer_overlay_portal_layout_builder] Consider OverlayPortal.overlayChildLayoutBuilder '
        'for unconstrained overlay layout (Flutter 3.38+).',
    correctionMessage:
        'Use OverlayPortal.overlayChildLayoutBuilder for overlay child layout.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'insert') return;
      final Expression? target = node.realTarget;
      if (target == null) return;
      final String src = target.toSource();
      if (RegExp(r'Overlay\.of\b').hasMatch(src) || src.startsWith('Overlay')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when folder structure doesn't follow feature-based organization.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v3
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
