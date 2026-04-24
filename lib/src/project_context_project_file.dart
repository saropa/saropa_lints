part of 'project_context.dart';

class ProjectContext {
  ProjectContext._();

  // =========================================================================
  // Project Type Cache
  // =========================================================================

  static final Map<String, _ProjectInfo> _projectCache = {};

  /// Get project info for the given file path.
  ///
  /// Finds the project root (directory containing pubspec.yaml) and caches
  /// the parsed project information for subsequent calls.
  /// Returns null if [filePath] is null/empty or no project root is found.
  static _ProjectInfo? getProjectInfo(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    final projectRoot = findProjectRoot(filePath);
    if (projectRoot == null || projectRoot.isEmpty) return null;

    return _projectCache.putIfAbsent(projectRoot, () {
      return _ProjectInfo._fromProjectRoot(projectRoot);
    });
  }

  /// Get the package name for the project at [projectRoot].
  ///
  /// Returns the `name:` field from `pubspec.yaml`, or an empty string
  /// if not found. Result is cached.
  /// Returns empty string if [projectRoot] is null or empty.
  static String getPackageName(String? projectRoot) {
    if (projectRoot == null || projectRoot.isEmpty) return '';
    final info = _projectCache.putIfAbsent(projectRoot, () {
      return _ProjectInfo._fromProjectRoot(projectRoot);
    });
    return info.packageName;
  }

  /// Find the project root directory (contains pubspec.yaml).
  ///
  /// Walks up the directory tree from [filePath] looking for pubspec.yaml.
  /// Returns `null` if no project root is found or [filePath] is null/empty.
  static String? findProjectRoot(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    final normalized = normalizePath(filePath);
    if (normalized.isEmpty) return null;
    try {
      var dir = Directory(normalized).parent;

      // Walk up the directory tree looking for pubspec.yaml
      while (dir.path.length > 1) {
        final pubspec = File('${dir.path}/pubspec.yaml');
        if (pubspec.existsSync()) {
          return dir.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      return null;
    } on OSError {
      return null;
    }
  }

  /// Check if the project containing [filePath] has a specific dependency.
  /// Returns false if [filePath] or [packageName] is null/empty.
  static bool hasDependency(String? filePath, String? packageName) {
    if (filePath == null || filePath.isEmpty) return false;
    if (packageName == null || packageName.isEmpty) return false;
    return getProjectInfo(filePath)?.hasDependency(packageName) ?? false;
  }

  /// Returns `true` when the project containing [filePath] could produce a
  /// web build — i.e. when rules whose failure mode is "breaks on web"
  /// should fire.
  ///
  /// **Signals used (any one is sufficient):**
  /// - A `web/` directory exists at the project root. `flutter create
  ///   --platforms=web` creates this directory and it's the required root
  ///   for `index.html`; its absence on a Flutter project is a strong
  ///   signal that the project cannot produce a web build.
  /// - The project is not a Flutter project at all (no `flutter:` / `sdk:
  ///   flutter` in pubspec). Pure Dart libraries run on any platform
  ///   including the browser, so web-compat warnings still apply — a
  ///   library author can't know their caller's platform targets.
  ///
  /// **Defaults to `true` (assume web) when unknown** (no path, no
  /// pubspec, unparseable): same philosophy as [flutterSdkAtLeast] —
  /// prefer to warn on the cautious side rather than silently skip a
  /// real cross-platform issue.
  ///
  /// **Why this exists:** `avoid_platform_specific_imports` justifies
  /// itself with "dart:io breaks web builds". In a mobile-only Flutter
  /// app (android/ios/macos only, no `web/`) that failure mode is
  /// structurally impossible, and every `dart:io` diagnostic is pure
  /// noise. See `bugs/avoid_platform_specific_imports_false_positive_non_web_project.md`.
  static bool hasWebSupport(String? filePath) {
    return getProjectInfo(filePath)?.hasWebSupport ?? true;
  }

  /// Returns `true` when the project containing [filePath] targets any
  /// non-web platform (android, ios, macos, windows, linux) OR is a pure
  /// Dart library — i.e. when rules whose failure mode is "breaks on
  /// non-web platforms" should fire.
  ///
  /// **Signals used (any one is sufficient):**
  /// - Any of `android/`, `ios/`, `macos/`, `windows/`, `linux/` exists
  ///   at the project root (the standard Flutter platform-directory
  ///   layout emitted by `flutter create --platforms=...`).
  /// - The project is not a Flutter project at all. Pure Dart libraries
  ///   are consumed by arbitrary clients — including VM, AOT-compiled,
  ///   and browser targets — so warnings about "won't work on X" still
  ///   apply since the library author can't know the consumer's target.
  ///
  /// **Defaults to `true` (assume yes) when unknown** (no path, no
  /// pubspec, unparseable): unknown → assume strict, same philosophy as
  /// [hasWebSupport] and [flutterSdkAtLeast].
  ///
  /// **Why this exists:** `avoid_web_only_dependencies` justifies
  /// itself with "dart:html crashes at startup on mobile/desktop". In a
  /// web-only Flutter app (no android/ios/macos/windows/linux
  /// directories at root) that failure mode is structurally impossible
  /// and every diagnostic raised is noise. Companion to [hasWebSupport].
  /// See `bugs/platform_gate_missing_from_sibling_rules.md`.
  static bool hasNonWebPlatform(String? filePath) {
    return getProjectInfo(filePath)?.hasNonWebPlatform ?? true;
  }

  /// Returns `true` when the project containing [filePath] targets a
  /// platform where end users interact via a pointer device (mouse /
  /// trackpad / external stylus): web, macos, windows, or linux. Pure
  /// Dart libraries default to `true`.
  ///
  /// **Why this is distinct from [hasNonWebPlatform]:** Android and iOS
  /// apps technically *can* receive pointer input (ChromeOS / iPad
  /// Magic Keyboard / external mice), but by default they render no
  /// cursor — so rules like `prefer_cursor_for_buttons` that suggest
  /// `mouseCursor: SystemMouseCursors.click` deliver near-zero value
  /// on a pure-mobile project and should be suppressed there. Desktop
  /// and web always render a cursor; those are the platforms the rule
  /// is written for.
  ///
  /// **Defaults to `true` when unknown** (same philosophy as siblings).
  static bool hasPointerPlatform(String? filePath) {
    return getProjectInfo(filePath)?.hasPointerPlatform ?? true;
  }

  /// Returns `true` when the project containing [filePath] declares a
  /// Flutter SDK constraint whose **lower bound** is ≥ `major.minor.patch`.
  ///
  /// **Defaults to `true` (assume modern)** when the constraint is missing
  /// or unparseable — rules should emit migration hints by default and let
  /// users silence false positives, rather than silently skip real
  /// violations on projects with non-standard pubspec formats.
  ///
  /// Used by SDK-migration rules (e.g. `prefer_listenable_builder`, which
  /// requires Flutter 3.13.0+) to suppress reports on projects that are
  /// legitimately pinned below the feature's availability window.
  static bool flutterSdkAtLeast(
    String? filePath,
    int major,
    int minor,
    int patch,
  ) {
    final info = getProjectInfo(filePath);
    final current = info?.flutterSdkMinVersion;
    if (current == null) return true; // unknown → assume modern
    return current.isAtLeast(_FlutterSdkVersion(major, minor, patch));
  }

  /// Clear the project cache (useful for testing).
  static void clearCache() {
    _projectCache.clear();
  }
}

/// Semver-like triple for Flutter SDK version comparisons.
///
/// Only major/minor/patch are compared; pre-release / build metadata
/// (e.g. `3.13.0-0.0.pre`) is stripped during parsing because Flutter SDK
/// gates are always expressed in terms of stable releases.
class _FlutterSdkVersion {
  const _FlutterSdkVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// `true` when `this` ≥ [other] in standard semver lexicographic order
  /// over (major, minor, patch).
  bool isAtLeast(_FlutterSdkVersion other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    return patch >= other.patch;
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// Parses the lower bound of a `flutter:` version constraint from a
/// pubspec `environment:` block. Returns `null` when the constraint is
/// absent, `"any"`, or otherwise unparseable.
///
/// Recognized forms (the ones Flutter templates and pub.dev emit):
/// - `"3.13.0"`            → 3.13.0 (exact)
/// - `"^3.13.0"`           → 3.13.0 (caret: compatible range)
/// - `">=3.13.0"`          → 3.13.0 (open upper bound)
/// - `">=3.13.0 <4.0.0"`   → 3.13.0 (ranged)
/// - `"3.13.0-0.0.pre"`    → 3.13.0 (pre-release suffix stripped)
/// - `"any"`               → null (no minimum declared)
_FlutterSdkVersion? _parseFlutterConstraint(String pubspecContent) {
  // Match the `environment:` block and capture its indented children only.
  // pubspec is flat YAML here — no nesting beyond one level — so the
  // `^[ \t]+.*` continuation pattern is sufficient.
  final envMatch = RegExp(
    r'^environment:\s*\n((?:[ \t]+.*\n)+)',
    multiLine: true,
  ).firstMatch(pubspecContent);
  if (envMatch == null) return null;
  final envBlock = envMatch.group(1) ?? '';

  // Extract the right-hand side of the `flutter:` key (optionally quoted).
  final flutterMatch = RegExp(
    '''^\\s+flutter:\\s*['"]?([^'"\\n]+?)['"]?\\s*\$''',
    multiLine: true,
  ).firstMatch(envBlock);
  if (flutterMatch == null) return null;

  final constraint = (flutterMatch.group(1) ?? '').trim();
  if (constraint.isEmpty || constraint == 'any') return null;

  return _parseFlutterLowerBound(constraint);
}

/// Extracts the `major.minor.patch` lower bound from a version constraint
/// string. Returns `null` when the string does not contain a parseable
/// triple.
_FlutterSdkVersion? _parseFlutterLowerBound(String constraint) {
  // Prefer an explicit `>= X.Y.Z` token when present; otherwise fall back
  // to a caret or bare version. Any of these yield the same lower bound.
  String lower = constraint;
  final geMatch = RegExp(r'>=\s*(\d+\.\d+\.\d+[^\s]*)').firstMatch(constraint);
  if (geMatch != null) {
    lower = geMatch.group(1) ?? '';
  } else if (constraint.startsWith('^')) {
    lower = constraint.afterIndex(1).trim();
  }

  final parts = lower.split('.');
  if (parts.length < 3) return null;
  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  // Strip pre-release / build metadata from patch (e.g. "0-0.0.pre" → "0").
  final patchStr = parts[2].split(RegExp(r'[-+]')).first;
  final patch = int.tryParse(patchStr);
  if (major == null || minor == null || patch == null) return null;
  return _FlutterSdkVersion(major, minor, patch);
}

/// Cached information about a project.
class _ProjectInfo {
  _ProjectInfo._({
    required this.isFlutterProject,
    required this.dependencies,
    required this.packageName,
    required this.flutterSdkMinVersion,
    required this.hasWebSupport,
    required this.hasNonWebPlatform,
    required this.hasPointerPlatform,
  });

  factory _ProjectInfo._fromProjectRoot(String projectRoot) {
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      // No pubspec: we can't tell anything about this tree. Assume every
      // platform-target flag is set so rules that warn about
      // cross-platform hazards still fire — matches the
      // unknown-defaults-to-true philosophy below.
      return _ProjectInfo._(
        isFlutterProject: false,
        dependencies: {},
        packageName: '',
        flutterSdkMinVersion: null,
        hasWebSupport: true,
        hasNonWebPlatform: true,
        hasPointerPlatform: true,
      );
    }

    try {
      final content = pubspecFile.readAsStringSync();
      final isFlutter =
          content.contains('flutter:') ||
          content.contains('flutter_test:') ||
          content.contains('sdk: flutter');

      // Parse package name from top-level `name:` field (valid Dart pkg names)
      final nameMatch = RegExp(
        r'^name:\s+([a-z][a-z0-9_]*)',
        multiLine: true,
      ).firstMatch(content);
      final packageName = nameMatch?.group(1) ?? '';

      // Parse dependencies (simple regex-based parsing).
      //
      // CRITICAL: `multiLine: true` is required. Without it `^` anchors only
      // at position 0 of the string, so `allMatches` returns at most one hit —
      // and since pubspec.yaml always starts with `name:` (no leading
      // whitespace), the match set was silently empty. That meant
      // `hasDependency(..., <anything>)` returned `false` for every project,
      // so every rule that gates on "skip when the pubspec declares the
      // package" lost its guard. For `saropa_depend_on_referenced_packages`
      // (formerly `depend_on_referenced_packages`) this flagged every single
      // `package:` import as undeclared — 22,695 false positives on
      // saropa-contacts. See
      // bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md
      // §"Secondary — possible over-firing on the saropa side".
      //
      // The parser is intentionally over-inclusive (it also collects nested
      // keys like `sdk:` under `flutter:`) — false negatives in the skip set
      // are the safe failure mode here, since they only prevent the rule
      // from firing, not cause spurious fires.
      final deps = <String>{};
      final depMatches = RegExp(r'^\s+(\w+):', multiLine: true).allMatches(content);
      for (final match in depMatches) {
        final dep = match.group(1);
        if (dep != null) deps.add(dep);
      }

      // Project-root directory probes. Each is one syscall and only runs
      // once per project (cached via `_projectCache.putIfAbsent`), so the
      // full set is still cheaper than the existing pubspec read above.
      //
      // Standard Flutter project layout: `flutter create --platforms=<X>`
      // emits one directory per enabled platform. The presence of a
      // directory is the canonical signal that the project can produce
      // a build for that target.
      //
      // We intentionally don't try to parse `flutter.plugin.platforms`
      // in pubspec — the directory checks catch apps, and the
      // `!isFlutter` branches below catch pure Dart libraries. Plugin
      // packages that declare a platform but have no matching directory
      // are rare enough to leave to a future refinement.
      final bool hasWebDir = Directory('$projectRoot/web').existsSync();
      final bool hasAndroidDir =
          Directory('$projectRoot/android').existsSync();
      final bool hasIosDir = Directory('$projectRoot/ios').existsSync();
      final bool hasMacosDir = Directory('$projectRoot/macos').existsSync();
      final bool hasWindowsDir =
          Directory('$projectRoot/windows').existsSync();
      final bool hasLinuxDir = Directory('$projectRoot/linux').existsSync();

      return _ProjectInfo._(
        isFlutterProject: isFlutter,
        dependencies: deps,
        packageName: packageName,
        flutterSdkMinVersion: _parseFlutterConstraint(content),
        // Web rules should fire when the project has a `web/` dir, or
        // when it's a pure Dart library (libraries are consumed by
        // arbitrary clients including browsers).
        hasWebSupport: hasWebDir || !isFlutter,
        // Inverse of `hasWebSupport`: web-only rules should NOT fire
        // when the project has any non-web platform directory. Pure
        // Dart libraries default true — the library author can't
        // know the consumer's target platform.
        hasNonWebPlatform: hasAndroidDir ||
            hasIosDir ||
            hasMacosDir ||
            hasWindowsDir ||
            hasLinuxDir ||
            !isFlutter,
        // Cursor / hover-UX rules apply on platforms that render a
        // pointer by default: web + desktop (macos/windows/linux).
        // Pure mobile (android/ios only) gets zero value from these
        // rules because the cursor is never visible. Pure Dart
        // libraries default true.
        hasPointerPlatform:
            hasWebDir || hasMacosDir || hasWindowsDir || hasLinuxDir ||
                !isFlutter,
      );
    } on FormatException {
      return _ProjectInfo._(
        isFlutterProject: false,
        dependencies: {},
        packageName: '',
        flutterSdkMinVersion: null,
        hasWebSupport: true,
        hasNonWebPlatform: true,
        hasPointerPlatform: true,
      );
    } on IOException {
      return _ProjectInfo._(
        isFlutterProject: false,
        dependencies: {},
        packageName: '',
        flutterSdkMinVersion: null,
        hasWebSupport: true,
        hasNonWebPlatform: true,
        hasPointerPlatform: true,
      );
    }
  }

  /// Whether this is a Flutter project (has flutter SDK dependency).
  final bool isFlutterProject;

  /// The package name from `pubspec.yaml` (`name:` field).
  final String packageName;

  /// Set of dependency names in the project.
  final Set<String> dependencies;

  /// Lower bound of the project's Flutter SDK constraint (from
  /// `environment.flutter` in pubspec.yaml). `null` when missing, `"any"`,
  /// or unparseable — callers should treat null as "assume modern".
  final _FlutterSdkVersion? flutterSdkMinVersion;

  /// Whether the project could produce a web build. See
  /// [ProjectContext.hasWebSupport] for the full rationale; briefly, this
  /// is `true` when the project has a `web/` directory OR is a pure Dart
  /// (non-Flutter) package.
  final bool hasWebSupport;

  /// Whether the project targets at least one non-web platform
  /// (android, ios, macos, windows, linux). See
  /// [ProjectContext.hasNonWebPlatform] for the full rationale; briefly,
  /// this is `true` when any of the five platform directories exists OR
  /// the project is a pure Dart (non-Flutter) package.
  final bool hasNonWebPlatform;

  /// Whether the project targets at least one platform that renders a
  /// pointer cursor by default (web, macos, windows, linux). See
  /// [ProjectContext.hasPointerPlatform] for why mobile is excluded
  /// despite technically supporting external pointer devices.
  final bool hasPointerPlatform;

  /// Check if the project has a specific dependency.
  bool hasDependency(String name) => dependencies.contains(name);
}

// =============================================================================
// FILE CONTENT CACHE (Performance Optimization)
// =============================================================================
//
// Tracks file content hashes to detect unchanged files between analysis runs.
// When a file hasn't changed, we can skip re-running rules that already passed.
// =============================================================================

/// Caches file content hashes to detect unchanged files.
///
/// Usage:
/// ```dart
/// // Check if file changed since last analysis
/// if (!FileContentCache.hasChanged(path, content)) {
///   return; // Skip - file unchanged
/// }
/// ```
class FileContentCache {
  FileContentCache._();

  // Map of file path -> content hash
  static final Map<String, int> _contentHashes = {};

  // Map of file path -> set of rules that passed on this file
  static final Map<String, Set<String>> _passedRules = {};

  /// Check if file content has changed since last analysis.
  ///
  /// Returns `true` if the file is new or has changed.
  /// Returns `false` if the file content is identical to the cached version.
  static bool hasChanged(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);
    final newHash = content.hashCode;
    final oldHash = _contentHashes[normalizedPath];

    if (oldHash == null || oldHash != newHash) {
      // File is new or changed - update cache and clear passed rules
      _contentHashes[normalizedPath] = newHash;
      _passedRules.remove(normalizedPath);
      return true;
    }

    return false;
  }

  /// Record that a rule passed (no violations) on a file.
  ///
  /// Call this after a rule completes with no violations.
  static void recordRulePassed(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    _passedRules.putIfAbsent(normalizedPath, () => {}).add(ruleName);
  }

  /// Check if a rule previously passed on an unchanged file.
  ///
  /// Returns `true` if the file is unchanged AND the rule passed before.
  static bool rulePreviouslyPassed(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    return _passedRules[normalizedPath]?.contains(ruleName) ?? false;
  }

  /// Clear cache for a specific file.
  static void invalidate(String filePath) {
    final normalizedPath = normalizePath(filePath);
    _contentHashes.remove(normalizedPath);
    _passedRules.remove(normalizedPath);
  }

  /// Clear all cached data (useful for testing).
  static void clearCache() {
    _contentHashes.clear();
    _passedRules.clear();
  }
}

// =============================================================================
// FILE TYPE CLASSIFICATION (Performance Optimization)
// =============================================================================
//
// Classifies files by type to enable early rule skipping. Rules that only
// apply to specific file types can check this once instead of analyzing
// the entire file.
// =============================================================================

/// Classification of a Dart file for rule filtering.
enum FileType {
  /// A widget file (contains StatelessWidget, StatefulWidget, etc.)
  widget,

  /// A test file (*_test.dart, in test/ directory)
  test,

  /// A Bloc/Cubit file (contains Bloc, Cubit classes)
  bloc,

  /// A Provider/Riverpod file (contains providers)
  provider,

  /// A model/entity file (data classes, entities)
  model,

  /// A service/repository file
  service,

  /// Unknown or general Dart file
  general,
}

/// Fast file type detection based on file path and content.
class FileTypeDetector {
  FileTypeDetector._();

  static final Map<String, Set<FileType>> _cache = {};

  /// Detect file types for the given file.
  ///
  /// Returns a set of applicable file types (a file can be multiple types).
  /// Results are cached per file path.
  static Set<FileType> detect(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);

    // Check cache first
    final cached = _cache[normalizedPath];
    if (cached != null) return cached;

    final types = <FileType>{};

    // Path-based detection (fast)
    if (isTestPath(normalizedPath)) {
      types.add(FileType.test);
    }

    // Content-based detection (only if needed)
    if (content.contains('extends StatelessWidget') ||
        content.contains('extends StatefulWidget') ||
        content.contains('extends State<')) {
      types.add(FileType.widget);
    }

    if (content.contains('extends Bloc<') ||
        content.contains('extends Cubit<')) {
      types.add(FileType.bloc);
    }

    // Provider/Riverpod detection - use specific patterns to avoid false positives
    if (content.contains('@riverpod') ||
        content.contains('ConsumerWidget') ||
        content.contains('ConsumerStatefulWidget') ||
        content.contains('ProviderScope') ||
        content.contains('ref.watch(') ||
        content.contains('ref.read(') ||
        content.contains('ChangeNotifierProvider') ||
        content.contains('StateNotifierProvider')) {
      types.add(FileType.provider);
    }

    if (types.isEmpty) {
      types.add(FileType.general);
    }

    _cache[normalizedPath] = types;
    return types;
  }

  /// Fast path-only check for test files.
  ///
  /// Expects a normalized path (forward slashes). Matches:
  /// - `*_test.dart` files
  /// - Files in `/test/`, `/test_driver/`, or `/integration_test/` directories
  static bool isTestPath(String normalizedPath) {
    return normalizedPath.endsWith('_test.dart') ||
        normalizedPath.contains('/test/') ||
        normalizedPath.contains('/test_driver/') ||
        normalizedPath.contains('/integration_test/');
  }

  /// Check if file is a specific type.
  static bool isType(String filePath, String content, FileType type) {
    return detect(filePath, content).contains(type);
  }

  /// Clear the cache (useful for testing).
  static void clearCache() {
    _cache.clear();
  }
}
