// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_mixed_environments` lint rule.

// NOTE: avoid_mixed_environments fires when kDebugMode/kProfileMode
// are used in conditional assignments that mix env configs.
//
// BAD:
// final url = kDebugMode ? 'http://localhost' : prodUrl;
//
// GOOD:
// final url = AppConfig.current.apiUrl; // config-driven

void main() {}

// NO LINT: `release_notes` contains "release" and `latest` contains "test",
// but neither is a standalone environment token. Word-boundary regex must
// not flag these substrings.
abstract final class ReleaseNotesConfig {
  const ReleaseNotesConfig._();

  static const String assetPath =
      'assets/data/release_notes/release_notes.json';

  static const int expectedLatestBuildNumber = 2026020101;
  static const int expectedLatestBuildItemCount = 25;
}

// NO LINT: `latestVersion` (test ⊂ latest) and `releaseDate` (release ⊂
// releaseDate, followed by an alpha "D") — both are substrings butting up
// against other letters, so the word-boundary lookarounds reject both.
abstract final class AppVersionConfig {
  const AppVersionConfig._();

  static const String latestVersion = '1.2.3';
  static const String releaseDate = '2026-02-01';
}

// NO LINT: `dev` ⊂ developer and `live` ⊂ delivery — both are substrings,
// not standalone environment tokens.
abstract final class ContactSettings {
  const ContactSettings._();

  static const String developerName = 'Saropa';
  static const String liveDelivery = 'standard';
}

// LINT: `apiUrlProd` (standalone "prod" token) + `debugFlag` (standalone
// "debug" token) genuinely mix production and development configuration.
abstract final class MixedEnvironmentConfig {
  const MixedEnvironmentConfig._();

  static const String apiUrlProd = 'https://api.example.com';
  static const bool debugFlag = true;
}
