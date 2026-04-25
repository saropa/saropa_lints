import 'package:window_manager/window_manager.dart';

Future<void> badDesktopWindowApiWithoutRunnerSetup() async {
  // LINT: Uses desktop window API without guaranteed desktop runner setup.
  await windowManager.ensureInitialized();
}

Future<void> badDesktopWindowSizeWithoutSetup() async {
  // LINT: Desktop APIs need desktop platform runner files in project.
  await windowManager.setTitle('Desktop App');
}

Future<void> okDesktopProjectConfigured() async {
  // OK: In a properly configured desktop Flutter project this is expected.
  await windowManager.waitUntilReadyToShow();
}
