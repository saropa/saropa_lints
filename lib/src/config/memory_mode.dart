/// Controls whether type-heavy rules skip unchanged files to reduce
/// analyzer memory retention during incremental analysis.
library;

enum MemoryMode {
  /// Skip type-heavy rules on unchanged files during in-process analysis.
  /// The scan daemon/CLI runs all rules regardless (full coverage).
  /// Reduces in-process analyzer RSS by avoiding lazy cross-library type
  /// resolution on files that haven't changed since the last pass.
  balanced,

  /// Run all rules on all files, regardless of change status.
  /// Both in-process and CLI/daemon scans run every rule on every file.
  full,

  /// Like [balanced], but also applies the unchanged-file skip to
  /// CLI and scan-daemon incremental scans — not just in-process analysis.
  /// Reduces daemon RSS at the cost of potentially missing violations in
  /// unchanged files whose dependencies changed. Use when memory is more
  /// constrained than diagnostic completeness.
  aggressive,
}

/// Static holder for the active [MemoryMode] and CLI override.
class MemoryModeConfig {
  MemoryModeConfig._();

  static MemoryMode _mode = MemoryMode.balanced;
  static bool _isCli = false;

  static MemoryMode get mode => _mode;

  static set mode(MemoryMode value) => _mode = value;

  /// True when the active mode applies balanced filtering.
  static bool get isBalanced =>
      _mode == MemoryMode.balanced || _mode == MemoryMode.aggressive;

  /// Mark this process as a CLI/daemon scan. In [balanced] mode, CLI scans
  /// run full coverage. In [aggressive] mode, CLI scans still apply the
  /// unchanged-file skip to save daemon memory.
  static void markCli() => _isCli = true;

  /// Whether balanced filtering should be applied to rule execution:
  /// - [balanced]: in-process only (not CLI/daemon)
  /// - [aggressive]: in-process AND CLI/daemon
  /// - [full]: never
  static bool get shouldApplyBalancedFiltering {
    if (_mode == MemoryMode.full) return false;
    if (_mode == MemoryMode.aggressive) return true;
    // Balanced: filter in-process, not in CLI/daemon.
    return !_isCli;
  }

  /// Reset to defaults (balanced, not CLI). For test teardown only.
  static void resetForTest() {
    _mode = MemoryMode.balanced;
    _isCli = false;
  }
}
