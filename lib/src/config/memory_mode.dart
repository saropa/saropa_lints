/// Controls whether type-heavy rules skip unchanged files to reduce
/// analyzer memory retention during incremental analysis.
library;

enum MemoryMode {
  /// Skip type-heavy rules on unchanged files during incremental analysis.
  /// Reduces analyzer RSS by avoiding lazy cross-library type resolution
  /// on files that haven't changed since the last pass.
  balanced,

  /// Run all rules on all files, regardless of change status.
  full,
}

/// Static holder for the active [MemoryMode] and CLI override.
class MemoryModeConfig {
  MemoryModeConfig._();

  static MemoryMode _mode = MemoryMode.balanced;
  static bool _isCli = false;

  static MemoryMode get mode => _mode;

  static set mode(MemoryMode value) => _mode = value;

  static bool get isBalanced => _mode == MemoryMode.balanced;

  /// Mark this process as a CLI scan (always runs full, ignoring mode).
  static void markCli() => _isCli = true;

  /// Whether balanced filtering should be applied: balanced mode AND
  /// not running in the scan CLI.
  static bool get shouldApplyBalancedFiltering => isBalanced && !_isCli;

  /// Reset to defaults (balanced, not CLI). For test teardown only.
  static void resetForTest() {
    _mode = MemoryMode.balanced;
    _isCli = false;
  }
}
