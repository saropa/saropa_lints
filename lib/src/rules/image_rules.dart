import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when Image.network is used inside ListView.builder without caching.
///
/// Images in scrollable lists will be rebuilt on every scroll, causing
/// unnecessary network requests and poor performance.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => Image.network(urls[index]),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => CachedNetworkImage(imageUrl: urls[index]),
/// )
/// ```
class AvoidImageRebuildOnScrollRule extends SaropaLintRule {
  const AvoidImageRebuildOnScrollRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_image_rebuild_on_scroll',
    problemMessage: 'Image.network in ListView.builder will rebuild on scroll.',
    correctionMessage:
        'Use CachedNetworkImage or move image loading outside the builder.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _listBuilders = <String>{
    'ListView',
    'GridView',
    'SliverList',
    'SliverGrid',
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

      // Check for Image.network
      if (typeName != 'Image' || constructorName != 'network') return;

      // Check if inside an itemBuilder callback in a ListView/GridView
      bool insideListBuilder = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is NamedExpression &&
            current.name.label.name == 'itemBuilder') {
          // Found itemBuilder, now check if parent is ListView/GridView
          AstNode? listViewNode = current.parent;
          while (listViewNode != null) {
            if (listViewNode is InstanceCreationExpression) {
              final String listTypeName =
                  listViewNode.constructorName.type.name.lexeme;
              if (_listBuilders.contains(listTypeName)) {
                insideListBuilder = true;
                break;
              }
            }
            listViewNode = listViewNode.parent;
          }
          break;
        }
        current = current.parent;
      }

      if (insideListBuilder) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when CircleAvatar with NetworkImage lacks error handling.
///
/// CircleAvatar's backgroundImage doesn't have a built-in errorBuilder like
/// Image widget. Network failures will leave the avatar blank or broken.
///
/// **BAD:**
/// ```dart
/// CircleAvatar(
///   backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CircleAvatar(
///   backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
///   onBackgroundImageError: (exception, stackTrace) {
///     // Log error or show fallback
///   },
/// )
/// ```
///
/// Or use Image with ClipOval for better error handling:
/// ```dart
/// ClipOval(
///   child: Image.network(
///     'https://example.com/avatar.jpg',
///     errorBuilder: (context, error, stack) => Icon(Icons.person),
///   ),
/// )
/// ```
class RequireAvatarFallbackRule extends SaropaLintRule {
  const RequireAvatarFallbackRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_avatar_fallback',
    problemMessage:
        'CircleAvatar with NetworkImage should have onBackgroundImageError.',
    correctionMessage:
        'Add onBackgroundImageError callback or use Image with ClipOval.',
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
      if (constructorName != 'CircleAvatar') return;

      bool hasNetworkImage = false;
      bool hasErrorHandler = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;

          if (name == 'backgroundImage') {
            // Check if it's a NetworkImage
            if (arg.expression is InstanceCreationExpression) {
              final InstanceCreationExpression imgExpr =
                  arg.expression as InstanceCreationExpression;
              final String? imgTypeName =
                  imgExpr.constructorName.type.element?.name;
              if (imgTypeName == 'NetworkImage') {
                hasNetworkImage = true;
              }
            }
          }

          if (name == 'onBackgroundImageError') {
            hasErrorHandler = true;
          }
        }
      }

      if (hasNetworkImage && !hasErrorHandler) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when video player widgets lack a placeholder.
///
/// Video widgets should show a placeholder while loading to provide
/// visual feedback and prevent layout shifts.
///
/// **BAD:**
/// ```dart
/// VideoPlayer(controller)
/// Chewie(controller: chewieController)
/// ```
///
/// **GOOD:**
/// ```dart
/// Chewie(
///   controller: chewieController,
///   placeholder: Container(
///     color: Colors.black,
///     child: Center(child: CircularProgressIndicator()),
///   ),
/// )
/// ```
class PreferVideoLoadingPlaceholderRule extends SaropaLintRule {
  const PreferVideoLoadingPlaceholderRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_video_loading_placeholder',
    problemMessage: 'Video player should have a loading placeholder.',
    correctionMessage: 'Add placeholder parameter for better UX during load.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Video widgets that support placeholder parameter
  static const Set<String> _videoWidgetsWithPlaceholder = <String>{
    'Chewie',
    'BetterPlayer',
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
      if (!_videoWidgetsWithPlaceholder.contains(constructorName)) return;

      // Check for placeholder parameter
      bool hasPlaceholder = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'placeholder') {
            hasPlaceholder = true;
            break;
          }
        }
      }

      if (!hasPlaceholder) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Image lacks cacheWidth/cacheHeight for memory optimization.
///
/// Images decoded at full resolution consume excessive memory. Use cacheWidth
/// or cacheHeight to decode images at display size, significantly reducing
/// memory usage for large images.
///
/// **BAD:**
/// ```dart
/// Image.network(
///   'https://example.com/large-image.jpg',
///   width: 100,
///   height: 100,
/// ) // Decodes at full resolution, then scales!
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/large-image.jpg',
///   width: 100,
///   height: 100,
///   cacheWidth: 200, // 2x for device pixel ratio
///   cacheHeight: 200,
/// )
/// ```
class PreferImageSizeConstraintsRule extends SaropaLintRule {
  const PreferImageSizeConstraintsRule() : super(code: _code);

  /// Performance optimization.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_image_size_constraints',
    problemMessage:
        'Consider adding cacheWidth/cacheHeight for memory optimization.',
    correctionMessage:
        'Set cacheWidth/cacheHeight to avoid decoding at full resolution.',
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

      if (typeName != 'Image') return;
      // Only check network and asset images
      if (constructorName != 'network' && constructorName != 'asset') return;

      bool hasCacheWidth = false;
      bool hasCacheHeight = false;
      bool hasWidth = false;
      bool hasHeight = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'cacheWidth') hasCacheWidth = true;
          if (paramName == 'cacheHeight') hasCacheHeight = true;
          if (paramName == 'width') hasWidth = true;
          if (paramName == 'height') hasHeight = true;
        }
      }

      // Only warn if display size is constrained but cache size is not
      if ((hasWidth || hasHeight) && !hasCacheWidth && !hasCacheHeight) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}
