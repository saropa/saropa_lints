/// Curated knowledge base of Flutter plugin platform support.
///
/// Maps a package name to the set of platforms it does NOT support, so a rule
/// can warn when a project that targets platform X imports a package with no
/// implementation for X (the build links, but the plugin throws
/// `MissingPluginException` / `UnsupportedError` at runtime on that platform).
///
/// **Why a curated list and not pub.dev at analysis time:** the analyzer runs
/// offline and per-keystroke; it cannot fetch pub.dev. The alternative — type
/// or API inspection — cannot tell you a plugin lacks a platform implementation,
/// because the Dart API is identical across platforms; only the native side is
/// missing. So a hand-verified list is the only mechanism available.
///
/// **Accuracy policy (this is shipped data with no compile-time check, so it is
/// held to the "verified safe to ship" bar):** every entry below was confirmed
/// against the package's official pub.dev platform tags on the date in the
/// `Verified:` comment. Plugin platform support changes between releases — an
/// entry that lists a platform as unsupported can become wrong when the plugin
/// adds support. Keep entries CONSERVATIVE: include a package only when its
/// lack of support for the listed platform is long-standing and unambiguous,
/// and re-verify on update. A wrong entry here is a false positive in every
/// consumer's editor, so when in doubt, leave the package out.
///
/// Platform identifiers match the directory names emitted by
/// `flutter create --platforms=...` and the values returned by
/// [ProjectContext.targetsPlatform]: `web`, `windows`, `macos`, `linux`.
/// Android and iOS are intentionally absent: the plugins tracked here all
/// support both, and mobile-incompatible plugins are rare enough to leave to a
/// future refinement rather than risk an unverified entry.
library;

/// Static lookup of package name -> platforms the package does NOT implement.
///
/// Consumed by `avoid_platform_incompatible_dependency`.
abstract final class PluginPlatformSupport {
  /// Platforms (other than Android/iOS) this knowledge base reasons about.
  /// A rule should only consider a project's targets that appear here.
  static const Set<String> trackedPlatforms = <String>{
    'web',
    'windows',
    'macos',
    'linux',
  };

  /// Package name -> set of [trackedPlatforms] the package has no native
  /// implementation for.
  ///
  /// Verified against pub.dev official platform tags on 2026-06-22. A package
  /// listed as supporting a platform is simply absent from its set; a package
  /// that supports every tracked platform (e.g. `geolocator`,
  /// `flutter_local_notifications`) is absent from the map entirely.
  static const Map<String, Set<String>>
  _unsupportedPlatforms = <String, Set<String>>{
    // Core sqflite ships iOS/Android/macOS only; web needs sqflite_common_ffi_web
    // and Windows/Linux need sqflite_common_ffi. Verified: 2026-06-22.
    'sqflite': <String>{'web', 'windows', 'linux'},
    // Biometric auth; no web or Linux implementation. Verified: 2026-06-22.
    'local_auth': <String>{'web', 'linux'},
    // Filesystem path lookup; every directory getter throws UnsupportedError
    // on web (the browser has no filesystem). Verified: 2026-06-22.
    'path_provider': <String>{'web'},
    // FCM has no Windows/Linux native layer. Verified: 2026-06-22.
    'firebase_messaging': <String>{'windows', 'linux'},
    // Camera plugin targets Android/iOS/web only. Verified: 2026-06-22.
    'camera': <String>{'windows', 'macos', 'linux'},
    // Runtime permission gateway; no macOS or Linux implementation.
    // Verified: 2026-06-22.
    'permission_handler': <String>{'macos', 'linux'},
  };

  /// Returns the set of tracked platforms [packageName] does NOT support, or an
  /// empty set when the package supports every tracked platform or is unknown.
  ///
  /// Unknown packages return empty (not "unsupported everywhere") so the rule
  /// stays silent on anything not explicitly verified — the conservative
  /// default that keeps false positives out.
  static Set<String> unsupportedPlatforms(String packageName) {
    return _unsupportedPlatforms[packageName] ?? const <String>{};
  }

  /// Extracts the package name from a `package:<name>/...` import URI, or null
  /// when [uri] is not a package import (e.g. `dart:io`, a relative path).
  static String? packageNameFromUri(String uri) {
    const String prefix = 'package:';
    if (!uri.startsWith(prefix)) return null;
    final int slash = uri.indexOf('/', prefix.length);
    if (slash <= prefix.length) return null;
    return uri.substring(prefix.length, slash);
  }
}
