# False positive: `avoid_bluetooth_scan_without_timeout` fires on any `scan(...).listen` regardless of receiver

Status: Fixed
Filed: 2026-08-03, from `d:\src\contacts`

## Symptom

The rule flags a contact-deduplication scanner as an infinite Bluetooth scan:

```dart
// lib/views/contact/contact_duplicates_screen.dart:292 (saropa contacts app)
_scanSubscription = DuplicatesScanRunner.scan(threshold: _sensitivity.threshold).listen(
  (DuplicatesScanProgress progress) => setStateSafe(() => _scan = progress),
  onDone: _onScanDone,
  ...
);
```

`DuplicatesScanRunner` is a pure-Dart duplicate-contact matcher streaming scan
progress — no Bluetooth, no platform channel, no radio. The diagnostic
("Infinite Bluetooth scan drains battery") is unrelated to the code.

## Likely cause

The rule appears to match on the METHOD NAME `scan(...)` followed by
`.listen(...)` without verifying the receiver's type comes from a Bluetooth
package (`flutter_blue_plus`, `flutter_reactive_ble`, etc.). Any domain object
with a streaming `scan()` API (virus scan, dedup scan, barcode scan, port
scan) will trip it.

## Suggested fix

Gate the rule on the receiver's package/type resolving to a known Bluetooth
API surface, or at minimum require the enclosing library to import a
Bluetooth package. Fixture: a non-Bluetooth `scan().listen()` (as above) must
NOT be flagged; a `FlutterBluePlus.scan(...)` without timeout still must.

## Downstream suppression

`d:\src\contacts\lib\views\contact\contact_duplicates_screen.dart:292` carries
`// ignore: avoid_bluetooth_scan_without_timeout` with a rationale referencing
this report; remove it when the rule lands a receiver-type check.

## Finish Report (2026-08-03)

`AvoidBluetoothScanWithoutTimeoutRule` matched any method named `scan()` regardless of receiver type, producing false positives on non-Bluetooth APIs (contact dedup scanners, port scanners, barcode scanners).

### Changes

- **`lib/src/rules/hardware/bluetooth_hardware_rules.dart`**: Added `_isBluetoothReceiver()` gate for `scan()` calls. Three-tier check: static type resolution → syntactic target-name match via `isExactTarget` → file-level Bluetooth package import fallback. `startScan`/`startBluetoothScan` remain ungated (Bluetooth-specific names with negligible collision risk). Target set: `FlutterBluePlus`, `FlutterBlue`, `FlutterReactiveBle`, `CentralManager`, `PeripheralManager`. Updated DartDoc BAD/GOOD examples.
- **`lib/src/import_utils.dart`**: Added `PackageImports.bluetooth` covering `flutter_blue_plus`, `flutter_reactive_ble`, `flutter_blue`, `bluetooth_low_energy`.
- **`example/lib/flutter_mocks.dart`**: Added `FlutterBluePlus` and `FlutterBlue` mock classes with `scan`/`startScan`/`stopScan` members.
- **`example/lib/bluetooth_hardware/avoid_bluetooth_scan_without_timeout_fixture.dart`**: Added BAD case (`FlutterBluePlus.scan()` without timeout) and GOOD false-positive guards (`DuplicatesScanRunner.scan()`, `_PortScanner().scan()`).

### Known residual

Files that import a Bluetooth package but also contain non-Bluetooth `scan()` calls will still false-positive on those calls (the file-import fallback is a last-resort heuristic). This matches the gating pattern used elsewhere in the codebase (Dio, Geolocator).

### Hardening (post-review)

- Corrected `_bluetoothTargets` entry from `BluetoothLowEnergy` (non-existent class) to `CentralManager`/`PeripheralManager` (actual `bluetooth_low_energy` API surface).
- Extended `RequireBluetoothStateCheckRule._bleTypeNames` with `FlutterReactiveBle`, `CentralManager`, `PeripheralManager` — previously only recognized `flutter_blue_plus` types.
- Added comments documenting: why `startScan`/`startBluetoothScan` are ungated (Bluetooth-specific names), and the known residual FP surface of the file-import fallback.

### Additional hardening (post-reflection)

- Added `QuickBlue` and `UniversalBle` to `_bluetoothTargets` and `_bleTypeNames` — discovered via pub.dev search as additional popular Flutter BLE packages with `startScan()` methods.
- Added `package:quick_blue/` and `package:universal_ble/` to `PackageImports.bluetooth`.
- Added `requiredPatterns` override (`{'startScan', 'startBluetoothScan', 'scan'}`) to `AvoidBluetoothScanWithoutTimeoutRule` — files without these strings skip AST traversal entirely.
- Confirmed `flutter_reactive_ble` uses `scanForDevices()` not `scan()` — no collision risk, but keeping `FlutterReactiveBle` in the target set is correct for the state-check rule's `startScan`/`connect`/`discoverServices` detection.

### Downstream action

Remove `// ignore: avoid_bluetooth_scan_without_timeout` from `d:\src\contacts\lib\views\contact\contact_duplicates_screen.dart:292` after upgrading saropa_lints.
