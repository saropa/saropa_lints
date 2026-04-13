// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_hardcoded_config` lint rule.

// NOTE: avoid_hardcoded_config fires on hardcoded URL strings
// and API-like literals in non-const locals/finals — not on top-level
// `const` or class `static const` centralization.

void main() {}

/// Centralized server constants — should NOT trigger (static const).
class ServerConstants {
  ServerConstants._();

  static const String packageVersion = '3.2.0';

  /// jsDelivr CDN base URL for serving web assets.
  static const String cdnBaseUrl =
      'https://cdn.jsdelivr.net/gh/saropa/saropa_drift_advisor';

  static const String queryParamLimit = 'limit';
}

/// Top-level named const — should NOT trigger.
const String kTopLevelApiUrl = 'https://api.example.com/v1/health';

class MutableConfigHolder {
  /// Mutable / rebuildable field — should trigger.
  // expect_lint: avoid_hardcoded_config
  static final String apiUrl = 'https://api.prod.example.com/v1';
}

void _badHardcodedInMethod() {
  // Inline in method body — should trigger.
  // expect_lint: avoid_hardcoded_config
  final apiUrl = 'https://api.staging.example.com/v1';
}
