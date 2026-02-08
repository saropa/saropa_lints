// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Permission handling lint rules for Flutter applications.
///
/// These rules help ensure proper permission handling including rationale
/// display, camera permission checks, and image picker best practices.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// require_location_permission_rationale
// =============================================================================

/// Warns when location permission is requested without showing rationale.
///
/// Alias: location_rationale, permission_explanation
///
/// Explain why you need location before requesting. "Weather app needs location
/// for local forecast." This improves grant rate and user trust.
///
/// **BAD:**
/// ```dart
/// onTap: () async {
///   await Permission.location.request(); // No explanation!
///   // User has no idea why location is needed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onTap: () async {
///   final status = await Permission.location.status;
///   if (status.isDenied) {
///     // Show rationale first
///     await showDialog(
///       context: context,
///       builder: (_) => AlertDialog(
///         title: Text('Location Access'),
///         content: Text('We need your location to show nearby restaurants.'),
///         actions: [
///           TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
///         ],
///       ),
///     );
///   }
///   await Permission.location.request();
/// }
/// ```
class RequireLocationPermissionRationaleRule extends SaropaLintRule {
  const RequireLocationPermissionRationaleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_location_permission_rationale',
    problemMessage:
        '[require_location_permission_rationale] Location permission requested '
        'without showing rationale. Users may deny without understanding why.',
    correctionMessage:
        'Show a dialog explaining why location is needed before requesting.',
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

      // Check for permission request
      if (methodName != 'request') return;

      // Check if this is a location permission request
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      // Match specific permission enum values, not any class with "location"
      if (targetSource != 'Permission.location' &&
          targetSource != 'Permission.locationAlways' &&
          targetSource != 'Permission.locationWhenInUse') {
        return;
      }

      // Check for rationale dialog before request
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();

      // Check for rationale patterns using specific function/class names
      if (bodySource.contains('showDialog') ||
          bodySource.contains('AlertDialog') ||
          bodySource.contains('showModalBottomSheet') ||
          bodySource.contains('SnackBar') ||
          bodySource.contains('shouldShowRationale') ||
          bodySource.contains('shouldShowRequestRationale')) {
        return; // Has rationale
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// require_camera_permission_check
// =============================================================================

/// Warns when camera is accessed without permission check.
///
/// Alias: camera_permission, check_camera_access
///
/// Camera access without permission crashes on iOS, throws on Android. Always
/// check and request permission before initializing CameraController.
///
/// **BAD:**
/// ```dart
/// late CameraController _controller;
///
/// void initState() {
///   super.initState();
///   _controller = CameraController(camera, ResolutionPreset.high);
///   _controller.initialize(); // Crashes without permission!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late CameraController _controller;
///
/// void initState() {
///   super.initState();
///   _initCamera();
/// }
///
/// Future<void> _initCamera() async {
///   final status = await Permission.camera.request();
///   if (status.isGranted) {
///     _controller = CameraController(camera, ResolutionPreset.high);
///     await _controller.initialize();
///   }
/// }
/// ```
class RequireCameraPermissionCheckRule extends SaropaLintRule {
  const RequireCameraPermissionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_camera_permission_check',
    problemMessage:
        '[require_camera_permission_check] Camera initialized without permission '
        'check. This crashes on iOS and throws on Android.',
    correctionMessage:
        'Request Permission.camera before creating CameraController.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'CameraController') return;

      // Check for permission request in surrounding context
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        if (current is ClassDeclaration) {
          // Check the entire class for permission handling
          final String classSource = current.toSource();
          if (classSource.contains('Permission.camera') ||
              classSource.contains('.camera.request') ||
              classSource.contains('.camera.status') ||
              classSource.contains('requestCameraPermission') ||
              classSource.contains('checkCameraPermission')) {
            return; // Class handles permissions somewhere
          }
        }
        current = current.parent;
      }

      if (functionBody != null) {
        final String bodySource = functionBody.toSource();

        if (bodySource.contains('Permission.camera') ||
            bodySource.contains('.camera.request') ||
            bodySource.contains('.camera.status') ||
            bodySource.contains('isGranted')) {
          return; // Has permission check
        }
      }

      reporter.atNode(node, code);
    });

    // Also check for availableCameras and camera initialization
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'availableCameras' && methodName != 'initialize') {
        return;
      }

      // For initialize, check if target is CameraController (not just by name)
      if (methodName == 'initialize') {
        final Expression? target = node.target;
        if (target == null) return;

        // Use staticType to check for CameraController
        final staticType =
            target.staticType?.getDisplayString(withNullability: false) ?? '';
        if (staticType != 'CameraController') {
          return;
        }
      }

      // Check for permission handling
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();

      if (!bodySource.contains('Permission.camera') &&
          !bodySource.contains('.camera.request') &&
          !bodySource.contains('.camera.status') &&
          !bodySource.contains('checkCameraPermission') &&
          !bodySource.contains('requestCameraPermission')) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// prefer_image_cropping
// =============================================================================

/// Warns when image picker is used for profile photos without cropping.
///
/// Alias: crop_profile_image, image_cropping
///
/// Profile photos should be cropped to square. Offer cropping UI after
/// selection rather than forcing users to pre-crop externally.
///
/// **BAD:**
/// ```dart
/// onTap: () async {
///   final image = await ImagePicker().pickImage(source: ImageSource.gallery);
///   // Using raw image for profile - may have wrong aspect ratio
///   updateProfilePhoto(image);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onTap: () async {
///   final image = await ImagePicker().pickImage(source: ImageSource.gallery);
///   if (image != null) {
///     // Crop to square for profile
///     final croppedFile = await ImageCropper().cropImage(
///       sourcePath: image.path,
///       aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
///     );
///     if (croppedFile != null) updateProfilePhoto(croppedFile);
///   }
/// }
/// ```
class PreferImageCroppingRule extends SaropaLintRule {
  const PreferImageCroppingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_image_cropping',
    problemMessage:
        '[prefer_image_cropping] Profile/avatar image picked without cropping. '
        'Raw photos may have wrong aspect ratio for profile display.',
    correctionMessage:
        'Use ImageCropper to let users crop the image to the correct aspect ratio.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Keywords suggesting profile/avatar context
  static const Set<String> _profileContextKeywords = <String>{
    'profile',
    'avatar',
    'photo',
    'picture',
    'headshot',
    'user_image',
    'userimage',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for image picker methods
      if (methodName != 'pickImage' && methodName != 'pickMultiImage') return;

      // Check if this is in a profile/avatar context
      AstNode? functionBody;
      MethodDeclaration? methodDeclaration;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
        }
        if (current is MethodDeclaration) {
          methodDeclaration = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource().toLowerCase();
      final String methodNameLower =
          methodDeclaration?.name.lexeme.toLowerCase() ?? '';

      // Check if this is profile/avatar context
      bool isProfileContext = false;
      for (final String keyword in _profileContextKeywords) {
        if (bodySource.contains(keyword) || methodNameLower.contains(keyword)) {
          isProfileContext = true;
          break;
        }
      }

      if (!isProfileContext) return;

      // Check for cropping
      if (bodySource.contains('cropper') ||
          bodySource.contains('crop') ||
          bodySource.contains('ImageCropper') ||
          bodySource.contains('cropImage')) {
        return; // Has cropping
      }

      reporter.atNode(node, code);
    });
  }
}
