// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when Image.network is used inside ListView.builder without caching.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_image_rebuild_on_scroll',
    problemMessage:
        '[avoid_image_rebuild_on_scroll] Image.network in ListView.builder will rebuild on scroll. Images in scrollable lists will be rebuilt on every scroll, causing unnecessary network requests and poor performance. {v2}',
    correctionMessage:
        'Use CachedNetworkImage or move image loading outside the builder. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v3
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_avatar_fallback',
    problemMessage:
        '[require_avatar_fallback] CircleAvatar with NetworkImage fails silently when image load fails. Users will see a broken or blank avatar with no indication of the error, leading to confusion, poor UX, and missed identity cues. This can also mask backend or connectivity issues during development. {v3}',
    correctionMessage:
        'Add onBackgroundImageError callback or use Image with ClipOval and provide a fallback asset or initials. Audit all avatar usage for error handling and add tests for image failure scenarios. Document fallback logic for maintainability.',
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
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_video_loading_placeholder',
    problemMessage:
        '[prefer_video_loading_placeholder] Video player must have a loading placeholder. Video widgets should show a placeholder while loading to provide visual feedback and prevent layout shifts. {v2}',
    correctionMessage:
        'Add placeholder parameter to improve UX during load. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v3
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_image_size_constraints',
    problemMessage:
        '[prefer_image_size_constraints] Missing cacheWidth/cacheHeight decodes full resolution into memory. Images decoded at full resolution consume excessive memory. Use cacheWidth or cacheHeight to decode images at display size, significantly reducing memory usage for large images. {v3}',
    correctionMessage:
        'Set cacheWidth/cacheHeight to avoid decoding at full resolution. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

  @override
  List<Fix> getFixes() => <Fix>[_PreferImageSizeConstraintsFix()];
}

class _PreferImageSizeConstraintsFix extends DartFix {
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
        message: 'Add cacheWidth and cacheHeight',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList;
        builder.addSimpleInsertion(
          args.arguments.last.end,
          ', cacheWidth: 200, cacheHeight: 200',
        );
      });
    });
  }
}

/// Warns when Image.network is used without an errorBuilder callback.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_image_error_fallback',
    problemMessage:
        '[require_image_error_fallback] Image.network used without an errorBuilder callback. When the network request fails due to connectivity issues, 404 errors, or server timeouts, Flutter displays a broken image icon placeholder. Users see an ugly, unexplained error state instead of a meaningful fallback such as a retry button or alternative content that maintains the visual layout. {v2}',
    correctionMessage:
        'Add an errorBuilder callback to Image.network that returns a fallback widget, such as an error icon with retry functionality or a placeholder image, when the network request fails.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_image_loading_placeholder',
    problemMessage:
        '[require_image_loading_placeholder] Image.network without loadingBuilder shows blank space during load. Network images take time to download. Without a loading indicator, users see an empty space which creates a poor user experience. {v4}',
    correctionMessage:
        'Add loadingBuilder to show progress while loading. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_media_loading_state',
    problemMessage:
        '[require_media_loading_state] VideoPlayer displayed without checking isInitialized shows a black rectangle or crashes. The video player needs time to load the video before the build method can render it properly. {v4}',
    correctionMessage:
        'Wrap VideoPlayer in a conditional checking controller.value.isInitialized. This prevents errors and ensures the video is ready before display.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_pdf_loading_indicator',
    problemMessage:
        '[require_pdf_loading_indicator] PDF viewer should provide loading feedback. PDF loading can be slow, especially for large documents or over network. Users should see progress feedback during load. {v2}',
    correctionMessage:
        'Add loading state handling or use onDocumentLoaded callback. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_clipboard_feedback',
    problemMessage:
        '[prefer_clipboard_feedback] Clipboard.setData should provide user feedback. Clipboard operations should provide user feedback (SnackBar, Toast, etc.) to confirm the action was successful. Without feedback, users won\'t know if the copy succeeded. {v2}',
    correctionMessage:
        'Add SnackBar or Toast to confirm clipboard operation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

// =============================================================================
// Part 5 Rules: cached_network_image Rules
// =============================================================================

/// Warns when CachedNetworkImage is used without memory cache dimensions.
///
/// Since: v4.9.0 | Updated: v4.13.0 | Rule version: v4
///
/// Large images without cache dimensions cause OOM errors. Always specify
/// memCacheWidth or memCacheHeight.
///
/// **BAD:**
/// ```dart
/// CachedNetworkImage(imageUrl: url)
/// ```
///
/// **GOOD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   memCacheWidth: 300,
///   memCacheHeight: 300,
/// )
/// ```
class RequireCachedImageDimensionsRule extends SaropaLintRule {
  const RequireCachedImageDimensionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_cached_image_dimensions',
    problemMessage:
        '[require_cached_image_dimensions] CachedNetworkImage without cache dimensions loads full-resolution images into memory, causing out-of-memory errors and app crashes on devices with limited RAM. Large images (such as high-resolution photos from modern cameras) can consume hundreds of megabytes when decoded, quickly exhausting available memory. {v4}',
    correctionMessage:
        'Add memCacheWidth/memCacheHeight to limit decoded image size. This reduces memory usage and prevents crashes.',
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
      if (typeName != 'CachedNetworkImage') return;

      bool hasMemCacheWidth = false;
      bool hasMemCacheHeight = false;
      bool hasMaxWidthDiskCache = false;
      bool hasMaxHeightDiskCache = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'memCacheWidth') hasMemCacheWidth = true;
          if (name == 'memCacheHeight') hasMemCacheHeight = true;
          if (name == 'maxWidthDiskCache') hasMaxWidthDiskCache = true;
          if (name == 'maxHeightDiskCache') hasMaxHeightDiskCache = true;
        }
      }

      // Need at least memory cache dimensions
      if (!hasMemCacheWidth &&
          !hasMemCacheHeight &&
          !hasMaxWidthDiskCache &&
          !hasMaxHeightDiskCache) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RequireCachedImageDimensionsFix()];
}

class _RequireCachedImageDimensionsFix extends DartFix {
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
        message: 'Add memCacheWidth and memCacheHeight',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList;
        builder.addSimpleInsertion(
          args.arguments.last.end,
          ', memCacheWidth: 300, memCacheHeight: 300',
        );
      });
    });
  }
}

/// Warns when CachedNetworkImage is used without placeholder.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Placeholders provide visual feedback while the image loads.
///
/// **BAD:**
/// ```dart
/// CachedNetworkImage(imageUrl: url)
/// ```
///
/// **GOOD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   placeholder: (context, url) => CircularProgressIndicator(),
/// )
/// ```
class RequireCachedImagePlaceholderRule extends SaropaLintRule {
  const RequireCachedImagePlaceholderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_cached_image_placeholder',
    problemMessage:
        '[require_cached_image_placeholder] CachedNetworkImage without placeholder. User sees blank during load. Placeholders provide visual feedback while the image loads. This image handling causes excessive memory usage, visual artifacts, or slow load times. {v2}',
    correctionMessage:
        'Add placeholder parameter for loading state. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      if (typeName != 'CachedNetworkImage') return;

      bool hasPlaceholder = false;
      bool hasProgressIndicator = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'placeholder') hasPlaceholder = true;
          if (name == 'progressIndicatorBuilder') hasProgressIndicator = true;
        }
      }

      if (!hasPlaceholder && !hasProgressIndicator) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when CachedNetworkImage is used without error widget.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Network images can fail. Always provide fallback for broken images.
///
/// **BAD:**
/// ```dart
/// CachedNetworkImage(imageUrl: url)
/// ```
///
/// **GOOD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   errorWidget: (context, url, error) => Icon(Icons.error),
/// )
/// ```
class RequireCachedImageErrorWidgetRule extends SaropaLintRule {
  const RequireCachedImageErrorWidgetRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_cached_image_error_widget',
    problemMessage:
        '[require_cached_image_error_widget] CachedNetworkImage without errorWidget. Broken images show nothing. Network images can fail. Always provide fallback for broken images. CachedNetworkImage is used without error widget. {v2}',
    correctionMessage:
        'Add errorWidget parameter to handle failed loads. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      if (typeName != 'CachedNetworkImage') return;

      bool hasErrorWidget = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'errorWidget') {
          hasErrorWidget = true;
          break;
        }
      }

      if (!hasErrorWidget) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Image.file is used without EXIF orientation handling.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Photos from cameras often have EXIF orientation metadata.
/// Without handling, images may appear rotated incorrectly.
///
/// **BAD:**
/// ```dart
/// Image.file(File(photoPath));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use a package that handles EXIF
/// Image(image: ImageUtils.loadWithExif(photoPath));
/// ```
///
/// **ALSO GOOD:**
/// ```dart
/// // Or use flutter_image_compress/image package
/// final fixed = await FlutterImageCompress.compressAndGetFile(
///   photoPath, outputPath,
///   keepExif: false, // This auto-rotates
/// );
/// Image.file(fixed!);
/// ```
class RequireExifHandlingRule extends SaropaLintRule {
  const RequireExifHandlingRule() : super(code: _code);

  /// Visual issue - images may display rotated.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_exif_handling',
    problemMessage:
        '[require_exif_handling] Image.file may show photos rotated. Prefer EXIF handling. Photos from cameras often have EXIF orientation metadata. Without handling, images may appear rotated incorrectly. {v2}',
    correctionMessage:
        'Use flutter_image_compress or similar to auto-rotate camera photos. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      final constructorName = node.constructorName.name?.name;

      // Check Image.file
      if (typeName != 'Image' || constructorName != 'file') {
        return;
      }

      // Check if the file reference suggests camera/photo origin
      final argSource = node.argumentList.arguments.isNotEmpty
          ? node.argumentList.arguments.first.toSource().toLowerCase()
          : '';

      final isCameraRelated = argSource.contains('photo') ||
          argSource.contains('camera') ||
          argSource.contains('image') ||
          argSource.contains('picture');

      if (isCameraRelated) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Suggests explicitly setting fadeInDuration on CachedNetworkImage.
///
/// Since: v2.3.2 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: cached_image_fade, smooth_image_loading
///
/// ## Why This Rule Exists
///
/// CachedNetworkImage has a default fadeInDuration of 500ms, which works well
/// for most cases. However, explicitly setting this value signals intentional
/// UX design and allows customization for different contexts:
/// - **Fast transitions**: 150-200ms for thumbnail grids
/// - **Smooth transitions**: 300-400ms for hero images
/// - **No transition**: Duration.zero for instant display
///
/// ## Severity: INFO
///
/// This is a style suggestion, not a bug. The default 500ms fade is reasonable,
/// but explicit configuration documents your UX intent.
///
/// ## Example
///
/// ### Without explicit duration (uses 500ms default):
/// ```dart
/// CachedNetworkImage(
///   imageUrl: 'https://example.com/image.jpg',
///   placeholder: (context, url) => CircularProgressIndicator(),
/// )
/// ```
///
/// ### With explicit duration:
/// ```dart
/// CachedNetworkImage(
///   imageUrl: 'https://example.com/image.jpg',
///   placeholder: (context, url) => CircularProgressIndicator(),
///   fadeInDuration: Duration(milliseconds: 300), // Intentional UX choice
/// )
/// ```
class PreferCachedImageFadeAnimationRule extends SaropaLintRule {
  const PreferCachedImageFadeAnimationRule() : super(code: _code);

  /// Low impact - style suggestion, not a bug.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_cached_image_fade_animation',
    problemMessage:
        '[prefer_cached_image_fade_animation] CachedNetworkImage without fadeInDuration causes abrupt image pop-in. CachedNetworkImage has a default fadeInDuration of 500ms, which works well for most cases. However, explicitly setting this value signals intentional UX design and allows customization for different contexts: - Fast transitions: 150-200ms for thumbnail grids - Smooth transitions: 300-400ms for hero images - No transition: Duration.zero for instant display. {v3}',
    correctionMessage:
        'Add fadeInDuration for a smoother loading experience. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'CachedNetworkImage') return;

      // Check if fadeInDuration is specified
      bool hasFadeInDuration = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'fadeInDuration') {
          hasFadeInDuration = true;
          break;
        }
      }

      if (!hasFadeInDuration) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferCachedImageFadeAnimationFix()];
}

class _PreferCachedImageFadeAnimationFix extends DartFix {
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
        message: 'Add fadeInDuration',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList;
        builder.addSimpleInsertion(
          args.arguments.last.end,
          ', fadeInDuration: const Duration(milliseconds: 300)',
        );
      });
    });
  }
}

// =============================================================================
// ImageStream Disposal Rules
// =============================================================================

/// Warns when ImageStream is used without removeListener cleanup.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: image_stream_dispose, image_stream_listener, image_listener_leak
///
/// ImageStream listeners must be removed when the widget is disposed to
/// prevent memory leaks. This is particularly important when using
/// ImageProvider.resolve() directly for advanced image handling.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   ImageStream? _imageStream;
///   late ImageStreamListener _listener;
///
///   @override
///   void initState() {
///     super.initState();
///     _listener = ImageStreamListener((image, sync) {
///       // Handle image
///     });
///     _imageStream = ImageProvider.resolve(configuration);
///     _imageStream?.addListener(_listener);
///   }
///   // Missing removeListener in dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   ImageStream? _imageStream;
///   late ImageStreamListener _listener;
///
///   @override
///   void initState() {
///     super.initState();
///     _listener = ImageStreamListener((image, sync) {
///       // Handle image
///     });
///     _imageStream = ImageProvider.resolve(configuration);
///     _imageStream?.addListener(_listener);
///   }
///
///   @override
///   void dispose() {
///     _imageStream?.removeListener(_listener);
///     super.dispose();
///   }
/// }
/// ```
class RequireImageStreamDisposeRule extends SaropaLintRule {
  const RequireImageStreamDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_image_stream_dispose',
    problemMessage:
        '[require_image_stream_dispose] ImageStream listener is not removed in the dispose() method. The listener retains a reference to the widget State object, preventing garbage collection after the widget is removed from the tree. This creates a memory leak where decoded image data and the entire widget state remain allocated indefinitely, consuming device memory. {v2}',
    correctionMessage:
        'Add _imageStream?.removeListener(_listener) in the dispose() method before calling super.dispose() to release the ImageStream reference and prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.WARNING,
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

      // Find ImageStream fields
      final List<String> imageStreamFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null &&
              (typeName == 'ImageStream' || typeName == 'ImageStream?')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              imageStreamFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (imageStreamFields.isEmpty) return;

      // Check if addListener is called (to confirm ImageStream is actively used)
      final String classSource = node.toSource();
      final bool hasAddListener = classSource.contains('.addListener(');

      if (!hasAddListener) return;

      // Find dispose method and check for removeListener calls
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Report ImageStreams without removeListener in dispose
      for (final String fieldName in imageStreamFields) {
        final bool hasRemoveListener = disposeBody != null &&
            (disposeBody.contains('$fieldName.removeListener(') ||
                disposeBody.contains('$fieldName?.removeListener('));

        if (!hasRemoveListener) {
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
// image_picker Package Rules
// =============================================================================

/// Warns when pickImage is called without requestFullMetadata: false.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// By default, image_picker includes full EXIF metadata (GPS location, camera
/// info, timestamps). If your app doesn't need this metadata, set
/// requestFullMetadata: false to improve privacy and reduce permissions needed.
///
/// **BAD:**
/// ```dart
/// final image = await ImagePicker().pickImage(source: ImageSource.gallery);
/// // Includes GPS, camera info, timestamps - may not be needed
/// ```
///
/// **GOOD:**
/// ```dart
/// // When EXIF metadata is not needed:
/// final image = await ImagePicker().pickImage(
///   source: ImageSource.gallery,
///   requestFullMetadata: false, // Skip EXIF for privacy
/// );
///
/// // When EXIF is needed, be explicit:
/// final image = await ImagePicker().pickImage(
///   source: ImageSource.gallery,
///   requestFullMetadata: true, // Need GPS for geotagging feature
/// );
/// ```
class PreferImagePickerRequestFullMetadataRule extends SaropaLintRule {
  const PreferImagePickerRequestFullMetadataRule() : super(code: _code);

  /// Privacy consideration - unnecessary metadata collection.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_image_picker_request_full_metadata',
    problemMessage:
        '[prefer_image_picker_request_full_metadata] pickImage collects EXIF metadata (GPS, timestamps) by default. By default, image_picker includes full EXIF metadata (GPS location, camera info, timestamps). If your app doesn\'t need this metadata, set requestFullMetadata: false to improve privacy and reduce permissions needed. {v3}',
    correctionMessage:
        'Add requestFullMetadata: false if EXIF data (GPS, timestamps) not needed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for pickImage, pickVideo, pickMultiImage
      if (methodName != 'pickImage' &&
          methodName != 'pickVideo' &&
          methodName != 'pickMultiImage') {
        return;
      }

      // Check if called on ImagePicker
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource();
        if (!targetSource.contains('ImagePicker') &&
            !targetSource.contains('picker') &&
            !targetSource.contains('imagePicker')) {
          return;
        }
      }

      // Check for requestFullMetadata parameter
      bool hasRequestFullMetadata = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'requestFullMetadata') {
            hasRequestFullMetadata = true;
            break;
          }
        }
      }

      if (!hasRequestFullMetadata) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferImagePickerRequestFullMetadataFix()];
}

class _PreferImagePickerRequestFullMetadataFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add requestFullMetadata: false',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList;
        if (args.arguments.isEmpty) {
          builder.addSimpleInsertion(
            args.leftParenthesis.end,
            'requestFullMetadata: false',
          );
        } else {
          builder.addSimpleInsertion(
            args.arguments.last.end,
            ', requestFullMetadata: false',
          );
        }
      });
    });
  }
}

/// Warns when pickImage is called without imageQuality for compression.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v5
///
/// Photos from modern cameras can be 5-20+ MB. Without compression, apps waste
/// bandwidth, storage, and memory. Use imageQuality to reduce file size for
/// typical use cases like profile pictures, thumbnails, or uploads.
///
/// **BAD:**
/// ```dart
/// final image = await ImagePicker().pickImage(source: ImageSource.camera);
/// // May be 10+ MB raw from camera!
///
/// await uploadProfilePicture(image); // Wastes bandwidth
/// ```
///
/// **GOOD:**
/// ```dart
/// // For profile pictures (80-85% quality is usually indistinguishable):
/// final image = await ImagePicker().pickImage(
///   source: ImageSource.camera,
///   imageQuality: 85,
/// );
///
/// // For thumbnails or previews:
/// final thumbnail = await ImagePicker().pickImage(
///   source: ImageSource.gallery,
///   imageQuality: 50, // Smaller for previews
///   maxWidth: 300,
///   maxHeight: 300,
/// );
/// ```
class AvoidImagePickerLargeFilesRule extends SaropaLintRule {
  const AvoidImagePickerLargeFilesRule() : super(code: _code);

  /// Performance issue - large files waste bandwidth and memory.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_image_picker_large_files',
    problemMessage:
        '[avoid_image_picker_large_files] pickImage without imageQuality allows raw photos that can be 10+ MB in size, creating slow uploads and wasteful bandwidth consumption. Large image files cause network timeouts, drain battery, consume expensive mobile data, and may trigger out-of-memory errors when the app attempts to process them. {v5}',
    correctionMessage:
        'Add imageQuality (e.g., 85) to compress images and reduce file size. This improves performance and reliability.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for pickImage (not pickVideo - video has different compression)
      if (methodName != 'pickImage' && methodName != 'pickMultiImage') {
        return;
      }

      // Check if called on ImagePicker
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource();
        if (!targetSource.contains('ImagePicker') &&
            !targetSource.contains('picker') &&
            !targetSource.contains('imagePicker')) {
          return;
        }
      }

      // Check for imageQuality or size constraint parameters
      bool hasCompression = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'imageQuality' ||
              paramName == 'maxWidth' ||
              paramName == 'maxHeight') {
            hasCompression = true;
            break;
          }
        }
      }

      if (!hasCompression) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AvoidImagePickerLargeFilesFix()];
}

class _AvoidImagePickerLargeFilesFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add imageQuality: 85',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList;
        if (args.arguments.isEmpty) {
          builder.addSimpleInsertion(
            args.leftParenthesis.end,
            'imageQuality: 85',
          );
        } else {
          builder.addSimpleInsertion(
            args.arguments.last.end,
            ', imageQuality: 85',
          );
        }
      });
    });
  }
}

/// Warns when CachedNetworkImage doesn't use a custom CacheManager.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: network_image_cache, custom_cache_manager
///
/// Without a custom CacheManager, cached images can grow unbounded and
/// consume excessive storage. Configure limits for production apps.
///
/// **BAD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: 'https://example.com/image.jpg',
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: 'https://example.com/image.jpg',
///   cacheManager: CacheManager(
///     Config(
///       'imageCache',
///       maxNrOfCacheObjects: 100,
///       stalePeriod: Duration(days: 7),
///     ),
///   ),
/// )
/// ```
class PreferCachedImageCacheManagerRule extends SaropaLintRule {
  const PreferCachedImageCacheManagerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_cached_image_cache_manager',
    problemMessage:
        '[prefer_cached_image_cache_manager] CachedNetworkImage without CacheManager. Cache may grow unbounded. Without a custom CacheManager, cached images can grow unbounded and consume excessive storage. Configure limits for production apps. {v2}',
    correctionMessage:
        'Add cacheManager parameter to limit cache size and stale period. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      if (typeName != 'CachedNetworkImage') return;

      // Check for cacheManager parameter
      bool hasCacheManager = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'cacheManager') {
          hasCacheManager = true;
          break;
        }
      }

      if (!hasCacheManager) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Image.network is used without a cacheWidth/cacheHeight.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: image_cache_dimensions, network_image_size
///
/// Without cacheWidth/cacheHeight, images are decoded at full resolution,
/// consuming excessive memory. Always specify cache dimensions for memory efficiency.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/large-image.jpg')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/large-image.jpg',
///   cacheWidth: 400,
///   cacheHeight: 400,
/// )
/// ```
class RequireImageCacheDimensionsRule extends SaropaLintRule {
  const RequireImageCacheDimensionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_image_cache_dimensions',
    problemMessage:
        '[require_image_cache_dimensions] Image.network loads the full-resolution image into memory without cacheWidth or cacheHeight constraints. A 4000x3000 pixel photo decodes to approximately 48MB of uncompressed bitmap data in memory. Without cache dimensions, displaying multiple images causes excessive memory consumption that leads to out-of-memory crashes on lower-end devices. {v6}',
    correctionMessage:
        'Add cacheWidth and cacheHeight parameters matching the display dimensions to limit the decoded image size in memory and reduce overall memory consumption.',
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
      final String constructorSource = node.constructorName.toSource();
      if (constructorSource != 'Image.network') return;

      // Check for cacheWidth or cacheHeight parameter
      bool hasCacheDimensions = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'cacheWidth' || name == 'cacheHeight') {
            hasCacheDimensions = true;
            break;
          }
        }
      }

      if (!hasCacheDimensions) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RequireImageCacheDimensionsFix()];
}

class _RequireImageCacheDimensionsFix extends DartFix {
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
        message: 'Add cacheWidth and cacheHeight',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList;
        builder.addSimpleInsertion(
          args.arguments.last.end,
          ', cacheWidth: 400, cacheHeight: 400',
        );
      });
    });
  }
}

// =============================================================================
// CACHED IMAGE DEVICE PIXEL RATIO RULES
// =============================================================================

/// Warns when CachedNetworkImage uses fixed width/height without DPR.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Using fixed pixel dimensions for network images ignores device pixel
/// ratio (DPR). A 200px image looks crisp on a 1x screen but blurry on
/// a 3x screen. Multiply dimensions by devicePixelRatio or use
/// MediaQuery-based sizing.
///
/// **BAD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   width: 200,
///   height: 200,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   width: 200 * MediaQuery.of(context).devicePixelRatio,
///   height: 200 * MediaQuery.of(context).devicePixelRatio,
///   memCacheWidth: (200 * dpr).toInt(),
/// )
/// ```
class RequireCachedImageDevicePixelRatioRule extends SaropaLintRule {
  const RequireCachedImageDevicePixelRatioRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_cached_image_device_pixel_ratio',
    problemMessage:
        '[require_cached_image_device_pixel_ratio] CachedNetworkImage has fixed width or height without considering devicePixelRatio. A 200px image looks crisp on a 1x display but blurry on 2x and 3x screens (most modern phones). Without DPR scaling, images appear pixelated on high-density devices or waste bandwidth on low-density ones. Scale dimensions by MediaQuery.of(context).devicePixelRatio or use memCacheWidth/memCacheHeight for memory-efficient DPR-aware sizing. {v1}',
    correctionMessage:
        'Multiply the fixed dimensions by MediaQuery.of(context).devicePixelRatio, or use memCacheWidth/memCacheHeight for cache-level DPR scaling.',
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
      if (typeName != 'CachedNetworkImage') return;

      bool hasFixedSize = false;
      bool hasDprScaling = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final String name = arg.name.label.name;

        // Check for fixed width/height
        if (name == 'width' || name == 'height') {
          if (arg.expression is IntegerLiteral ||
              arg.expression is DoubleLiteral) {
            hasFixedSize = true;
          }
        }

        // Check for DPR-aware parameters
        if (name == 'memCacheWidth' || name == 'memCacheHeight') {
          hasDprScaling = true;
        }
      }

      // Check if the size expressions reference devicePixelRatio
      if (hasFixedSize) {
        final String source = node.toSource();
        if (source.contains('devicePixelRatio') ||
            source.contains('dpr') ||
            source.contains('DPR')) {
          hasDprScaling = true;
        }
      }

      if (hasFixedSize && !hasDprScaling) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}
