import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when Image.network is used inside ListView.builder without caching.
///
/// Alias: cache_list_images, image_in_listview, use_cached_network_image
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
/// Alias: avatar_error_handler, circle_avatar_fallback, network_avatar_error
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
/// Alias: video_placeholder, video_loading_indicator, video_loader
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
/// Alias: image_memory_optimization, cache_image_size, decode_image_size
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

/// Warns when Image.network is used without an errorBuilder callback.
///
/// Alias: image_error_handler, network_image_fallback, image_error_callback
///
/// Network images can fail to load due to connectivity issues, invalid URLs,
/// or server errors. Without error handling, the widget will show nothing
/// or throw an exception.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.jpg')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.jpg',
///   errorBuilder: (context, error, stackTrace) {
///     return Icon(Icons.error);
///   },
/// )
/// ```
class RequireImageErrorFallbackRule extends SaropaLintRule {
  const RequireImageErrorFallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_image_error_fallback',
    problemMessage: 'Image.network should have an errorBuilder for failed loads.',
    correctionMessage: 'Add errorBuilder callback to handle network failures.',
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

      if (typeName != 'Image' || constructorName != 'network') return;

      bool hasErrorBuilder = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'errorBuilder') {
          hasErrorBuilder = true;
          break;
        }
      }

      if (!hasErrorBuilder) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Image.network is used without a loadingBuilder callback.
///
/// Alias: image_loading_indicator, image_progress, network_image_loader
///
/// Network images take time to download. Without a loading indicator,
/// users see an empty space which creates a poor user experience.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.jpg')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.jpg',
///   loadingBuilder: (context, child, loadingProgress) {
///     if (loadingProgress == null) return child;
///     return CircularProgressIndicator(
///       value: loadingProgress.expectedTotalBytes != null
///           ? loadingProgress.cumulativeBytesLoaded /
///               loadingProgress.expectedTotalBytes!
///           : null,
///     );
///   },
/// )
/// ```
class RequireImageLoadingPlaceholderRule extends SaropaLintRule {
  const RequireImageLoadingPlaceholderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_image_loading_placeholder',
    problemMessage: 'Image.network should have a loadingBuilder for UX feedback.',
    correctionMessage: 'Add loadingBuilder to show progress while loading.',
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

      if (typeName != 'Image' || constructorName != 'network') return;

      bool hasLoadingBuilder = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'loadingBuilder') {
          hasLoadingBuilder = true;
          break;
        }
      }

      if (!hasLoadingBuilder) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when VideoPlayer is used without checking isInitialized.
///
/// Alias: video_initialized_check, video_controller_ready, video_loading_state
///
/// VideoPlayerController requires initialization before use. Using VideoPlayer
/// without checking controller.value.isInitialized will show a blank widget
/// or cause errors.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return VideoPlayer(_controller);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return _controller.value.isInitialized
///       ? AspectRatio(
///           aspectRatio: _controller.value.aspectRatio,
///           child: VideoPlayer(_controller),
///         )
///       : Center(child: CircularProgressIndicator());
/// }
/// ```
class RequireMediaLoadingStateRule extends SaropaLintRule {
  const RequireMediaLoadingStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_media_loading_state',
    problemMessage: 'VideoPlayer should check isInitialized before displaying.',
    correctionMessage:
        'Wrap VideoPlayer in a conditional checking controller.value.isInitialized.',
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
      if (typeName != 'VideoPlayer') return;

      // Check if inside a conditional expression checking isInitialized
      AstNode? current = node.parent;
      bool hasInitializedCheck = false;

      while (current != null) {
        // Check for ternary expression with isInitialized
        if (current is ConditionalExpression) {
          final String conditionSource = current.condition.toSource();
          if (conditionSource.contains('isInitialized')) {
            hasInitializedCheck = true;
            break;
          }
        }
        // Check for if statement with isInitialized
        if (current is IfStatement) {
          final String conditionSource = current.expression.toSource();
          if (conditionSource.contains('isInitialized')) {
            hasInitializedCheck = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!hasInitializedCheck) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when PDF viewer is used without a loading indicator.
///
/// Alias: pdf_loading_state, pdf_viewer_progress, pdf_loader
///
/// PDF loading can be slow, especially for large documents or over network.
/// Users should see progress feedback during load.
///
/// **BAD:**
/// ```dart
/// PdfViewer.openFile(filePath)
/// PDFView(filePath: filePath)
/// SfPdfViewer.file(file)
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(
///   children: [
///     PdfViewer.openFile(filePath),
///     if (isLoading) CircularProgressIndicator(),
///   ],
/// )
/// ```
///
/// Or with onDocumentLoaded callback:
/// ```dart
/// PdfViewer.openFile(
///   filePath,
///   onDocumentLoaded: (document) {
///     setState(() => isLoading = false);
///   },
/// )
/// ```
class RequirePdfLoadingIndicatorRule extends SaropaLintRule {
  const RequirePdfLoadingIndicatorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_pdf_loading_indicator',
    problemMessage: 'PDF viewer should provide loading feedback.',
    correctionMessage:
        'Add loading state handling or use onDocumentLoaded callback.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Common PDF viewer widgets
  static const Set<String> _pdfViewers = <String>{
    'PdfViewer',
    'PDFView',
    'SfPdfViewer',
    'PdfViewerController',
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
      if (!_pdfViewers.contains(typeName)) return;

      bool hasLoadingCallback = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          // Check for common loading-related callbacks
          if (name == 'onDocumentLoaded' ||
              name == 'onPageChanged' ||
              name == 'onRender' ||
              name == 'onViewCreated') {
            hasLoadingCallback = true;
            break;
          }
        }
      }

      if (!hasLoadingCallback) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Clipboard.setData is used without user feedback.
///
/// Alias: clipboard_snackbar, copy_feedback, clipboard_toast
///
/// Clipboard operations should provide user feedback (SnackBar, Toast, etc.)
/// to confirm the action was successful. Without feedback, users won't know
/// if the copy succeeded.
///
/// **BAD:**
/// ```dart
/// onPressed: () async {
///   await Clipboard.setData(ClipboardData(text: 'copied'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onPressed: () async {
///   await Clipboard.setData(ClipboardData(text: 'copied'));
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text('Copied to clipboard')),
///   );
/// }
/// ```
class PreferClipboardFeedbackRule extends SaropaLintRule {
  const PreferClipboardFeedbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_clipboard_feedback',
    problemMessage: 'Clipboard.setData should provide user feedback.',
    correctionMessage: 'Add SnackBar or Toast to confirm clipboard operation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Clipboard.setData
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource != 'Clipboard') return;
      if (node.methodName.name != 'setData') return;

      // Check if there's a SnackBar/Toast in the same block or function
      AstNode? current = node.parent;
      FunctionBody? enclosingBody;

      while (current != null) {
        if (current is FunctionBody) {
          enclosingBody = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBody == null) return;

      final String bodySource = enclosingBody.toSource();
      final bool hasFeedback = bodySource.contains('showSnackBar') ||
          bodySource.contains('ScaffoldMessenger') ||
          bodySource.contains('Toast') ||
          bodySource.contains('Fluttertoast') ||
          bodySource.contains('showToast') ||
          bodySource.contains('showMessage');

      if (!hasFeedback) {
        reporter.atNode(node, code);
      }
    });
  }
}
