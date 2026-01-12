import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when Bluetooth scan is started without timeout parameter.
///
/// BLE scanning drains battery quickly. Without a timeout, scans run
/// indefinitely, causing excessive battery drain and degraded user experience.
///
/// **BAD:**
/// ```dart
/// FlutterBluePlus.startScan(); // No timeout - drains battery!
/// flutterBlue.startScan(); // Legacy API, same issue
/// ```
///
/// **GOOD:**
/// ```dart
/// FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
/// ```
class AvoidBluetoothScanWithoutTimeoutRule extends SaropaLintRule {
  const AvoidBluetoothScanWithoutTimeoutRule() : super(code: _code);

  /// Significant issue for battery life.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_bluetooth_scan_without_timeout',
    problemMessage:
        'Bluetooth scan should have a timeout to prevent battery drain.',
    correctionMessage:
        'Add timeout parameter: startScan(timeout: Duration(seconds: 10))',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scanMethods = <String>{
    'startScan',
    'startBluetoothScan',
    'scan',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_scanMethods.contains(methodName)) return;

      // Check for timeout parameter
      bool hasTimeout = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'timeout') {
          hasTimeout = true;
          break;
        }
      }

      if (!hasTimeout) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when Bluetooth operations start without checking adapter state.
///
/// BLE operations fail silently or throw if Bluetooth is disabled. Always
/// check adapter state before starting scans or connections.
///
/// **BAD:**
/// ```dart
/// void connect() {
///   device.connect(); // May fail if Bluetooth is off!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void connect() async {
///   final state = await FlutterBluePlus.adapterState.first;
///   if (state != BluetoothAdapterState.on) {
///     showError('Please enable Bluetooth');
///     return;
///   }
///   device.connect();
/// }
/// ```
class RequireBluetoothStateCheckRule extends SaropaLintRule {
  const RequireBluetoothStateCheckRule() : super(code: _code);

  /// Critical for robust Bluetooth apps.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_bluetooth_state_check',
    problemMessage: 'BLE operations should check adapter state first.',
    correctionMessage:
        'Check FlutterBluePlus.adapterState before BLE operations.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// BLE type names from flutter_blue_plus and similar packages.
  static const Set<String> _bleTypeNames = <String>{
    'BluetoothDevice',
    'FlutterBluePlus',
    'FlutterBlue',
    'BluetoothCharacteristic',
    'BluetoothService',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check BLE-specific methods
      if (methodName != 'connect' &&
          methodName != 'discoverServices' &&
          methodName != 'startScan') {
        return;
      }

      // Use type resolution to verify this is a BLE type
      final Expression? target = node.target;
      if (target == null) {
        // Static call like FlutterBluePlus.startScan()
        final String? targetName = node.realTarget?.toSource();
        if (targetName != 'FlutterBluePlus' && targetName != 'FlutterBlue') {
          return;
        }
      } else {
        // Instance call - check the static type
        final String? typeName = target.staticType?.element?.name;
        if (typeName == null || !_bleTypeNames.contains(typeName)) {
          return;
        }
      }

      // Check if this is inside a method that checks adapter state
      bool hasStateCheck = false;
      AstNode? current = node.parent;
      BlockFunctionBody? enclosingBody;

      while (current != null) {
        if (current is BlockFunctionBody) {
          enclosingBody = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBody != null) {
        final String bodySource = enclosingBody.toSource();
        if (bodySource.contains('adapterState') ||
            bodySource.contains('isAvailable') ||
            bodySource.contains('BluetoothAdapterState')) {
          hasStateCheck = true;
        }
      }

      if (!hasStateCheck) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when BLE device connection lacks disconnect state listener.
///
/// BLE devices disconnect unexpectedly (out of range, battery, interference).
/// Without disconnect handling, the app shows stale state or crashes.
///
/// **BAD:**
/// ```dart
/// await device.connect();
/// // No disconnect handling - app breaks when device goes out of range
/// ```
///
/// **GOOD:**
/// ```dart
/// await device.connect();
/// device.connectionState.listen((state) {
///   if (state == BluetoothConnectionState.disconnected) {
///     showError('Device disconnected');
///     cleanup();
///   }
/// });
/// ```
class RequireBleDisconnectHandlingRule extends SaropaLintRule {
  const RequireBleDisconnectHandlingRule() : super(code: _code);

  /// Critical for robust Bluetooth apps.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_ble_disconnect_handling',
    problemMessage: 'BLE connection should handle disconnect state.',
    correctionMessage:
        'Listen to device.connectionState for disconnect events.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// BLE device type names from flutter_blue_plus and similar packages.
  static const Set<String> _bleDeviceTypes = <String>{
    'BluetoothDevice',
    'BleDevice',
    'Peripheral',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'connect') return;

      // Check if this is a BLE device connect using type resolution
      final Expression? target = node.target;
      if (target == null) return;

      // Use static type to verify this is a BLE device
      final String? typeName = target.staticType?.element?.name;
      if (typeName == null || !_bleDeviceTypes.contains(typeName)) {
        return;
      }

      // Look for connectionState listener in same class
      bool hasDisconnectHandler = false;
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass != null) {
        final String classSource = enclosingClass.toSource();
        if (classSource.contains('connectionState.listen') ||
            classSource.contains('connectionState.stream') ||
            classSource.contains('onDisconnected') ||
            classSource.contains('BluetoothConnectionState.disconnected')) {
          hasDisconnectHandler = true;
        }
      }

      if (!hasDisconnectHandler) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when audio playback lacks AudioSession configuration.
///
/// Without proper audio session handling, your app may conflict with other
/// audio sources (music apps, calls, navigation). Use audio_session package
/// to configure proper audio focus behavior.
///
/// **BAD:**
/// ```dart
/// final player = AudioPlayer();
/// player.play(); // May interrupt or be interrupted by other audio
/// ```
///
/// **GOOD:**
/// ```dart
/// final session = await AudioSession.instance;
/// await session.configure(AudioSessionConfiguration.music());
/// final player = AudioPlayer();
/// player.play();
/// ```
class RequireAudioFocusHandlingRule extends SaropaLintRule {
  const RequireAudioFocusHandlingRule() : super(code: _code);

  /// Important for proper audio behavior.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_audio_focus_handling',
    problemMessage:
        'Audio playback should configure AudioSession for proper focus handling.',
    correctionMessage: 'Use AudioSession.instance to configure audio behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Audio player type names from just_audio, audioplayers, and similar packages.
  static const Set<String> _audioPlayerTypes = <String>{
    'AudioPlayer',
    'AssetsAudioPlayer',
    'JustAudioPlayer',
    'AudioCache',
    'AudioPlayerHandler',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'play') return;

      // Check if this is an audio player play call using type resolution
      final Expression? target = node.target;
      if (target == null) return;

      // Use static type to verify this is an audio player
      final String? typeName = target.staticType?.element?.name;
      if (typeName == null || !_audioPlayerTypes.contains(typeName)) {
        return;
      }

      // Check if AudioSession is configured in same class
      bool hasAudioSession = false;
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass != null) {
        final String classSource = enclosingClass.toSource();
        if (classSource.contains('AudioSession') ||
            classSource.contains('audioSession') ||
            classSource.contains('audio_session')) {
          hasAudioSession = true;
        }
      }

      if (!hasAudioSession) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when QR scanner is used without checking camera permission.
///
/// QR scanning requires camera access. Using scanner widgets without
/// permission handling causes crashes on iOS or exceptions on Android.
/// This is also an App Store compliance requirement.
///
/// **BAD:**
/// ```dart
/// Widget build(context) {
///   return QRView(onQRViewCreated: _onCreated); // May crash!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(context) {
///   return FutureBuilder(
///     future: Permission.camera.request(),
///     builder: (context, snapshot) {
///       if (snapshot.data?.isGranted ?? false) {
///         return QRView(onQRViewCreated: _onCreated);
///       }
///       return Text('Camera permission required');
///     },
///   );
/// }
/// ```
class RequireQrPermissionCheckRule extends SaropaLintRule {
  const RequireQrPermissionCheckRule() : super(code: _code);

  /// Critical for app store compliance.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_qr_permission_check',
    problemMessage: 'QR scanner requires camera permission check.',
    correctionMessage: 'Request Permission.camera before showing QR scanner.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _qrWidgets = <String>{
    'QRView',
    'MobileScanner',
    'QrScannerOverlay',
    'BarcodeScanner',
    'QRCodeScanner',
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
      if (!_qrWidgets.contains(typeName)) return;

      // Check if permission handling exists in same class
      bool hasPermissionCheck = false;
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass != null) {
        final String classSource = enclosingClass.toSource();
        if (classSource.contains('Permission.camera') ||
            classSource.contains('CameraPermission') ||
            classSource.contains('permission_handler') ||
            classSource.contains('requestCameraPermission') ||
            classSource.contains('cameraPermission')) {
          hasPermissionCheck = true;
        }
      }

      if (!hasPermissionCheck) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// Part 5 Rules: Geolocator Rules
// =============================================================================

/// Warns when Geolocator is used without permission check.
///
/// Location access without permission check crashes on iOS and throws on Android.
///
/// **BAD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition();
/// ```
///
/// **GOOD:**
/// ```dart
/// final permission = await Geolocator.checkPermission();
/// if (permission == LocationPermission.denied) {
///   permission = await Geolocator.requestPermission();
/// }
/// if (permission == LocationPermission.deniedForever) {
///   return; // Handle denial
/// }
/// final position = await Geolocator.getCurrentPosition();
/// ```
class RequireGeolocatorPermissionCheckRule extends SaropaLintRule {
  const RequireGeolocatorPermissionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_geolocator_permission_check',
    problemMessage: 'Location access without permission check. Crashes on iOS.',
    correctionMessage:
        'Call Geolocator.checkPermission() before getCurrentPosition().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'getCurrentPosition' &&
          methodName != 'getPositionStream') {
        return;
      }

      // Check if target is Geolocator
      final Expression? target = node.target;
      if (target == null) return;

      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check if there's a permission check in the enclosing function
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
      if (!bodySource.contains('checkPermission') &&
          !bodySource.contains('requestPermission')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Geolocator is used without checking if service is enabled.
///
/// Location service can be disabled. Check before requesting position.
///
/// **BAD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition();
/// ```
///
/// **GOOD:**
/// ```dart
/// final serviceEnabled = await Geolocator.isLocationServiceEnabled();
/// if (!serviceEnabled) {
///   return; // Handle disabled service
/// }
/// final position = await Geolocator.getCurrentPosition();
/// ```
class RequireGeolocatorServiceEnabledRule extends SaropaLintRule {
  const RequireGeolocatorServiceEnabledRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_geolocator_service_enabled',
    problemMessage:
        'Location request without service check. May fail if GPS is off.',
    correctionMessage: 'Call Geolocator.isLocationServiceEnabled() first.',
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
      if (methodName != 'getCurrentPosition') return;

      final Expression? target = node.target;
      if (target == null) return;

      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check for service enabled check
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
      if (!bodySource.contains('isLocationServiceEnabled')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when getPositionStream subscription is not cancelled.
///
/// Stream subscriptions must be cancelled to stop location updates.
///
/// **BAD:**
/// ```dart
/// Geolocator.getPositionStream().listen((position) {...});
/// ```
///
/// **GOOD:**
/// ```dart
/// late StreamSubscription<Position> _subscription;
///
/// void initState() {
///   _subscription = Geolocator.getPositionStream().listen(...);
/// }
///
/// void dispose() {
///   _subscription.cancel();
///   super.dispose();
/// }
/// ```
class RequireGeolocatorStreamCancelRule extends SaropaLintRule {
  const RequireGeolocatorStreamCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_geolocator_stream_cancel',
    problemMessage:
        'Position stream subscription without cancel. Battery drain.',
    correctionMessage: 'Store subscription and call cancel() in dispose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if target is getPositionStream
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;

      if (target.methodName.name != 'getPositionStream') return;

      // Check if target is Geolocator
      final Expression? geoTarget = target.target;
      if (geoTarget is! SimpleIdentifier || geoTarget.name != 'Geolocator') {
        return;
      }

      // Check if result is assigned to a variable
      AstNode? parent = node.parent;
      if (parent is! VariableDeclaration && parent is! AssignmentExpression) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Geolocator requests are made without error handling.
///
/// Location requests can fail. Always handle errors gracefully.
///
/// **BAD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition();
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final position = await Geolocator.getCurrentPosition();
/// } catch (e) {
///   handleLocationError(e);
/// }
/// ```
class RequireGeolocatorErrorHandlingRule extends SaropaLintRule {
  const RequireGeolocatorErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_geolocator_error_handling',
    problemMessage:
        'Location request without error handling. May crash on failure.',
    correctionMessage: 'Wrap in try-catch to handle location errors.',
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
      if (methodName != 'getCurrentPosition' &&
          methodName != 'getLastKnownPosition') {
        return;
      }

      final Expression? target = node.target;
      if (target == null) return;

      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check if inside try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return;
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when BLE data transfer occurs without MTU negotiation.
///
/// BLE default MTU is only 23 bytes (20 bytes payload). Without negotiating
/// a larger MTU, data transfers are fragmented into many small packets,
/// causing poor throughput and increased latency. Always request MTU
/// negotiation before transferring data.
///
/// **BAD:**
/// ```dart
/// await device.connect();
/// final services = await device.discoverServices();
/// final characteristic = services.first.characteristics.first;
/// await characteristic.write(largeData); // Slow, fragmented transfer!
/// ```
///
/// **GOOD:**
/// ```dart
/// await device.connect();
/// await device.requestMtu(512); // Request larger MTU
/// final services = await device.discoverServices();
/// final characteristic = services.first.characteristics.first;
/// await characteristic.write(largeData); // Faster transfer
/// ```
class PreferBleMtuNegotiationRule extends SaropaLintRule {
  const PreferBleMtuNegotiationRule() : super(code: _code);

  /// Important for BLE performance.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_ble_mtu_negotiation',
    problemMessage:
        'BLE data transfer without MTU negotiation causes slow, fragmented transfers.',
    correctionMessage:
        'Call device.requestMtu(512) after connect() and before write operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Methods that transfer data over BLE.
  static const Set<String> _dataTransferMethods = <String>{
    'write',
    'writeCharacteristic',
    'setNotifyValue',
    'read',
    'readCharacteristic',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_dataTransferMethods.contains(methodName)) return;

      // Check if target is a BLE characteristic or device using type resolution
      final Expression? target = node.target;
      if (target == null) return;

      // Check the target's static type
      final String? typeName = target.staticType?.element?.name;
      final bool isBleCharacteristic = typeName == 'BluetoothCharacteristic' ||
          typeName == 'BleCharacteristic' ||
          typeName == 'Characteristic';

      if (!isBleCharacteristic) return;

      // Look for requestMtu call in same class
      bool hasMtuNegotiation = false;
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass != null) {
        final String classSource = enclosingClass.toSource();
        if (classSource.contains('requestMtu') ||
            classSource.contains('mtuRequest') ||
            classSource.contains('negotiateMtu') ||
            classSource.contains('setMtu')) {
          hasMtuNegotiation = true;
        }
      }

      // Also check enclosing method for MTU negotiation
      if (!hasMtuNegotiation) {
        current = node.parent;
        while (current != null) {
          if (current is MethodDeclaration) {
            final String methodSource = current.toSource();
            if (methodSource.contains('requestMtu') ||
                methodSource.contains('mtuRequest')) {
              hasMtuNegotiation = true;
            }
            break;
          }
          current = current.parent;
        }
      }

      if (!hasMtuNegotiation) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}
