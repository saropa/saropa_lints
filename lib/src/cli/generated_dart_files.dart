/// Canonical "is this Dart file machine-generated?" predicate shared by the
/// analysis CLIs (Project Map / `project_health`, Code Health / `project_vibrancy`,
/// and the `cross_file` analyzers).
///
/// **Why this exists:** generated and locale Dart files (a 1 MB
/// `app_localizations_fr.dart`, a `drift_database.g.dart`) are long, mechanical,
/// and never hand-improvable. Left in a health/size report they dominate every
/// hot-spot and size ranking, burying the real issues a developer can act on —
/// exactly the failure the Project Map hot-spot list showed. The suffix/locale
/// knowledge used to be duplicated inline in several walkers; this is the one
/// place to extend it so the CLIs stay in agreement.
library;

import 'package:path/path.dart' as p;

/// Filename suffixes emitted by Dart codegen tools. A suffix match is faster and
/// more deterministic than reading a file header, and every hit avoids opening
/// the file at all. Covers the common build_runner / source_gen family plus the
/// standalone generators teams ship most often.
const Set<String> _generatedSuffixes = {
  '.g.dart', //         build_runner / source_gen (json_serializable, retrofit, riverpod_generator)
  '.freezed.dart', //   freezed
  '.mocks.dart', //     mockito
  '.gr.dart', //        auto_route
  '.config.dart', //    injectable
  '.chopper.dart', //   chopper
  '.gen.dart', //       flutter_gen
  '.drift.dart', //     drift (generated alongside hand-written code)
  '.pb.dart', //        protoc Dart plugin
  '.pbenum.dart',
  '.pbgrpc.dart',
  '.pbjson.dart',
  '.pbserver.dart',
};

/// Returns true when [relPosix] (a project-relative, forward-slash path) is Dart
/// emitted by a generator rather than hand-written. Pass the project-relative
/// path, not an absolute one, so the locale-directory check below is reliable.
bool isGeneratedDartPath(String relPosix) {
  final lower = relPosix.toLowerCase();
  for (final suffix in _generatedSuffixes) {
    if (lower.endsWith(suffix)) return true;
  }
  // A `generated` path segment is the other near-universal codegen convention
  // (`lib/generated/...`, `lib/foo/generated/...`). Match it as a whole segment
  // so an unrelated file like `auto_generated_notes.dart` is not swept up.
  for (final segment in lower.split('/')) {
    if (segment == 'generated') return true;
  }
  // gen-l10n output: `app_localizations*.dart` + `intl_*.dart` under an `l10n/`
  // directory. These are pure ARB-derived translation tables — never hand-
  // written, never improvable by a code-health flag. The `l10n/` gate keeps an
  // unrelated hand-written helper that merely mentions "app_localizations" from
  // being swept up, while still catching wrapper variants like
  // `remote_app_localizations.dart` under `lib/service/l10n/`.
  if (lower.contains('l10n/')) {
    final base = p.basename(lower);
    if (base.contains('app_localizations') || base.startsWith('intl_')) {
      return true;
    }
  }
  return false;
}
