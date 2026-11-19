# BUG: `require_qr_permission_check` — flags `MobileScanner`, which requests camera permission itself

**Status: Open**

Created: 2026-10-29
Rule: `require_qr_permission_check`
File: `lib/src/rules/hardware/bluetooth_hardware_rules.dart` (line ~487-560)
Severity: False positive
Rule version: v2 | Since: v2.1.0 | Updated: 17.0.1-beta.3 (project pins 17.0.1-beta.2)

---

## Summary

The rule requires the text `Permission.camera` (or similar) in the enclosing class for every `MobileScanner` widget. The `mobile_scanner` package starts the camera through its controller, which asks the OS for camera permission and reports a denial as `MobileScannerErrorCode.permissionDenied`. The widget renders a default error view or the caller's `errorBuilder`. The "black screen / crash" the message describes does not occur.

---

## Attribution Evidence

```bash
grep -rn "'require_qr_permission_check'" lib/src/rules/
# lib/src/rules/hardware/bluetooth_hardware_rules.dart:507:    'require_qr_permission_check',
```

**Emitter registration:** `lib/saropa_lints.dart:1489` (`RequireQrPermissionCheckRule.new`)
**Rule class:** `RequireQrPermissionCheckRule` (`bluetooth_hardware_rules.dart:487`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Copied in shape from `/Users/craighathaway/Documents/src/contacts/lib/components/contact/detail_panels/social_media/qr_messaging_handle_scanner.dart:258-278`. Needs `mobile_scanner: ^7.4.2`:

```dart
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint: MobileScanner requests permission itself.
    return MobileScanner(controller: _controller, onDetect: (BarcodeCapture c) {});
  }
}
```

**Frequency:** Always for `MobileScanner` without the listed permission text in the class.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for `MobileScanner` |
| **Actual** | `[require_qr_permission_check] If you open the QR scanner without first requesting camera permission, your app will show a black screen on iOS or crash on some Android devices. ... {v2}` at `qr_messaging_handle_scanner.dart` 271:13-271:26 |

---

## AST Context

```
ClassDeclaration (_QrMessagingHandleScannerScreenState)
  └─ MethodDeclaration (build)
      └─ BlockFunctionBody
          └─ TryStatement
              └─ ReturnStatement
                  └─ InstanceCreationExpression (CommonScaffold)
                      └─ ... Stack children
                          └─ InstanceCreationExpression (MobileScanner)   <- constructorName reported here
```

---

## Root Cause

`bluetooth_hardware_rules.dart`:

- Line 529: `_qrWidgets` (line ~516) includes `'MobileScanner'`; the node passes the filter.
- Line 546-552: `hasPermissionCheck` is true only if the class source contains `Permission.camera`, `CameraPermission`, `permission_handler`, `requestCameraPermission` or `cameraPermission`.
- Line 556: otherwise reports.

The rule treats all listed widgets alike. `QRView` (qr_code_scanner) needs a manual request. `MobileScanner` does not.

---

## Why the code is correct

In `mobile_scanner-7.4.2`:

- `lib/src/enums/mobile_scanner_error_code.dart:27` defines `permissionDenied`.
- `lib/src/mobile_scanner.dart:53` exposes `errorBuilder`; line 347 falls back to a default error widget.

The project declares `NSCameraUsageDescription` in `ios/Runner/Info.plist` and the `CAMERA` permission in `android/app/src/main/AndroidManifest.xml`. Adding a separate permission request would duplicate the package's own prompt and add UI states.

---

## All affected project locations

- `lib/components/contact/detail_panels/social_media/qr_messaging_handle_scanner.dart:271`

---

## Suggested Fix

Remove `'MobileScanner'` from `_qrWidgets` (bluetooth_hardware_rules.dart ~line 516), or exempt it when the import resolves to `package:mobile_scanner`.

---

## Fixture Gap

The fixture should include:

1. `QRView(...)` with no permission text in the class — expect LINT
2. `MobileScanner(controller: c, onDetect: f)` — expect NO lint
3. `MobileScanner` in a class that mentions `Permission.camera` — expect NO lint

---

## Environment

- saropa_lints: 17.0.1-beta.2 (project pubspec.lock); rule source read at 17.0.1-beta.3
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Project: contacts (Flutter), mobile_scanner 7.4.2

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
