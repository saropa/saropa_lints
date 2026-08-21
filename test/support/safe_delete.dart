import 'dart:io';

/// Retry-tolerant directory cleanup for Windows file-lock races.
///
/// On Windows, antivirus / indexer / test-runner handles can linger on temp
/// files after a test completes, causing `deleteSync` to throw a
/// [PathAccessException] (errno 32). This helper retries with a short delay
/// before giving up silently — a stale temp dir is harmless, but a thrown
/// exception fails the test and forces a full-suite retry.
void safeDeleteDir(Directory dir, {int retries = 3}) {
  for (var i = 0; i <= retries; i++) {
    try {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      // ignore: avoid_returning_null_for_void
      return;
    } on FileSystemException {
      // Last attempt — give up silently rather than fail the test
      if (i == retries) return;
      // Brief pause to let the handle release
      sleep(const Duration(milliseconds: 100));
    }
  }
}
