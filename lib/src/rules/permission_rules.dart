// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Permission handling lint rules for Flutter applications.
///
/// These rules help ensure proper permission handling including rationale
/// display, camera permission checks, and image picker best practices.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// require_location_permission_rationale
// =============================================================================

/// Warns when location permission is requested without showing rationale.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireLocationPermissionRationaleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_location_permission_rationale',
    '[require_location_permission_rationale] Location permission requested '
        'without showing rationale. Users may deny without understanding why. {v2}',
    correctionMessage:
        'Show a dialog explaining why location is needed before requesting.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// require_camera_permission_check
// =============================================================================

/// Warns when camera is accessed without permission check.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireCameraPermissionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_camera_permission_check',
    '[require_camera_permission_check] Camera initialized without permission '
        'check. This crashes on iOS and throws on Android. {v3}',
    correctionMessage:
        'Request Permission.camera before creating CameraController.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

      reporter.atNode(node);
    });

    // Also check for availableCameras and camera initialization
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_image_cropping
// =============================================================================

/// Warns when image picker is used for profile photos without cropping.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferImageCroppingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_image_cropping',
    '[prefer_image_cropping] Profile/avatar image picked without cropping. '
        'Raw photos may have wrong aspect ratio for profile display. {v2}',
    correctionMessage:
        'Use ImageCropper to let users crop the image to the correct aspect ratio.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_permission_handler_null_safety
// =============================================================================

/// Warns when deprecated permission_handler APIs from pre-null-safety versions
///
/// Since: v4.14.0 | Rule version: v2
///
/// are detected.
///
/// Alias: permission_handler_null_safety, outdated_permission_handler
///
/// Older permission_handler versions (pre-8.0) used deprecated API patterns
/// like `PermissionHandler()` singleton and `checkPermissionStatus` method.
/// These are removed in null-safe versions and cause compile errors.
///
/// **BAD:**
/// ```dart
/// final handler = PermissionHandler();
/// var status = await handler.checkPermissionStatus(PermissionGroup.camera);
/// ```
///
/// **GOOD:**
/// ```dart
/// var status = await Permission.camera.status;
/// if (!status.isGranted) {
///   status = await Permission.camera.request();
/// }
/// ```
class AvoidPermissionHandlerNullSafetyRule extends SaropaLintRule {
  AvoidPermissionHandlerNullSafetyRule() : super(code: _code);

  /// Using deprecated APIs causes compile errors after migration.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_permission_handler_null_safety',
    '[avoid_permission_handler_null_safety] Deprecated pre-null-safety '
        'permission_handler API detected. The PermissionHandler() constructor '
        'and PermissionGroup enum were removed in permission_handler 8.0+. '
        'Using these deprecated APIs prevents migration to null-safe versions '
        'and causes compile errors when updating the package. The modern API '
        'uses Permission.camera.status and Permission.camera.request() instead. {v2}',
    correctionMessage:
        'Migrate to the null-safe permission_handler API: use '
        'Permission.camera.status instead of '
        'PermissionHandler().checkPermissionStatus(PermissionGroup.camera).',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Deprecated class names from pre-null-safety permission_handler
  static const Set<String> _deprecatedClasses = <String>{
    'PermissionHandler',
    'PermissionGroup',
    'ServiceStatus',
  };

  /// Deprecated method names from pre-null-safety permission_handler
  static const Set<String> _deprecatedMethods = <String>{
    'checkPermissionStatus',
    'requestPermissions',
    'checkServiceStatus',
    'shouldShowRequestPermissionRationale',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect deprecated constructor: PermissionHandler()
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (_deprecatedClasses.contains(typeName)) {
        reporter.atNode(node);
      }
    });

    // Detect deprecated method calls on PermissionHandler instances
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_deprecatedMethods.contains(methodName)) return;

      // Check if target is a PermissionHandler identifier or constructor
      final Expression? target = node.target;
      if (target == null) return;

      if (target is SimpleIdentifier &&
          _deprecatedClasses.contains(target.name)) {
        reporter.atNode(node);
      } else if (target is InstanceCreationExpression &&
          _deprecatedClasses.contains(
            target.constructorName.type.name2.lexeme,
          )) {
        reporter.atNode(node);
      }
    });

    // Detect PermissionGroup enum usage
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name == 'PermissionGroup') {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// PERMISSION REQUEST CONTEXT RULES
// =============================================================================

/// Warns when permissions are requested at app startup instead of in context.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Requesting all permissions in main() or initState() confuses users —
/// they see permission dialogs before understanding why the app needs
/// access. Request permissions when the user performs a relevant action
/// (e.g., request camera when they tap "Take Photo"). This increases
/// grant rates and follows platform guidelines.
///
/// **BAD:**
/// ```dart
/// void main() async {
///   await Permission.camera.request();
///   await Permission.location.request();
///   runApp(MyApp());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void onTakePhoto() async {
///   final status = await Permission.camera.request();
///   if (status.isGranted) { /* open camera */ }
/// }
/// ```
class PreferPermissionRequestInContextRule extends SaropaLintRule {
  PreferPermissionRequestInContextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_permission_request_in_context',
    '[prefer_permission_request_in_context] Permission requested at app startup (main or initState) instead of in response to user action. Users see permission dialogs before understanding why the app needs access, leading to higher denial rates and a confusing first-launch experience. Platform guidelines (Apple, Google) recommend requesting permissions just-in-time when the user performs a relevant action. {v1}',
    correctionMessage:
        'Move the permission request to the point where the user performs the action that needs the permission (e.g., request camera when user taps "Take Photo").',
    severity: DiagnosticSeverity.INFO,
  );

  /// Function names that indicate startup context.
  static const Set<String> _startupFunctions = <String>{
    'main',
    'initState',
    'init',
    'initialize',
    'setup',
    'setUp',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check if this is a .request() call
      if (node.methodName.name != 'request') return;

      // Check if target looks like a Permission
      final String? targetSource = node.target?.toSource();
      if (targetSource == null) return;

      final bool isPermission =
          targetSource.contains('Permission') ||
          targetSource.contains('permission');
      if (!isPermission) return;

      // Check if inside a startup function
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionDeclaration) {
          if (_startupFunctions.contains(current.name.lexeme)) {
            reporter.atNode(node);
          }
          return;
        }
        if (current is MethodDeclaration) {
          if (_startupFunctions.contains(current.name.lexeme)) {
            reporter.atNode(node);
          }
          return;
        }
        current = current.parent;
      }
    });
  }
}
