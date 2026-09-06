/// Pure parser for `pubspec.yaml` version-constraint hygiene rules.
///
/// Shared by the five constraint-reviewer rules in
/// `lib/src/rules/config/pubspec_constraint_rules.dart`. Kept dependency-free
/// and side-effect-free so it can be unit-tested directly on string samples
/// (the lint rules themselves can only be verified through the scan CLI, since
/// `custom_lint` analyzes `.dart` files, not `.yaml`).
library;

/// A semantic version reduced to the parts the constraint rules reason about.
///
/// Pre-release and build metadata are intentionally dropped: every rule here
/// reasons about major/minor spans, never about pre-release ordering.
class SemverParts {
  const SemverParts(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Matches `1`, `1.2`, or `1.2.3` with optional `-pre`/`+build` suffix.
  /// Missing minor/patch default to 0, mirroring how pub treats `>=1` as
  /// `>=1.0.0`.
  static final RegExp _pattern = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?');

  /// Returns the parsed parts, or null when [text] does not begin with a
  /// numeric version (e.g. `any`, a git ref, an empty string).
  static SemverParts? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    // Verified false positive: `_pattern`'s capture groups are `(\d+)`, so
    // every non-null group is digit-only by construction — int.parse cannot
    // throw here. tryParse would only hide an unreachable null branch.
    // ignore: saropa_lints/prefer_try_parse_for_dynamic_data
    final major = int.parse(match.group(1)!);
    // Same regex guarantee as above: group 2 is `(?:\.(\d+))?`, digit-only.
    // ignore: saropa_lints/prefer_try_parse_for_dynamic_data
    final minor = int.parse(match.group(2) ?? '0');
    // Same regex guarantee as above: group 3 is `(?:\.(\d+))?`, digit-only.
    // ignore: saropa_lints/prefer_try_parse_for_dynamic_data
    final patch = int.parse(match.group(3) ?? '0');
    return SemverParts(major, minor, patch);
  }
}

/// The shape of a single dependency or `environment` version constraint, with
/// just enough structure for the five constraint rules to make a decision.
class ParsedConstraint {
  ParsedConstraint({
    required this.raw,
    required this.isBlock,
    required this.isAny,
    required this.isCaret,
    required this.hasLower,
    required this.hasUpper,
    this.lower,
    this.upper,
  });

  /// The constraint text as written (trimmed, comment/quotes removed).
  final String raw;

  /// True when the entry is a sub-map (`git:`, `path:`, `sdk:`, `hosted:`)
  /// rather than an inline version string. These carry no comparable version
  /// range, so the range rules skip them.
  final bool isBlock;

  /// `any` or an empty constraint — resolves to every published version.
  final bool isAny;

  /// Written with caret syntax (`^1.2.3`).
  final bool isCaret;

  /// Has a lower bound (`>=`, `^`, or an exact pin).
  final bool hasLower;

  /// Has an upper bound (`<`, caret-implied, or an exact pin).
  final bool hasUpper;

  /// Lower-bound version, when one is present and numeric.
  final SemverParts? lower;

  /// Upper-bound version. For caret constraints this is the synthesized
  /// exclusive bound (`^1.2.3` → `2.0.0`, `^0.2.3` → `0.3.0`).
  final SemverParts? upper;

  /// Number of major versions the allowed range spans. `>=1.0.0 <2.0.0` and
  /// `^1.2.3` span 1; `>=1.0.0 <4.0.0` spans 3. Null when either bound is
  /// missing or non-numeric (span is undefined without both ends).
  int? get majorSpan {
    final lowerParts = lower;
    final upperParts = upper;
    if (lowerParts == null || upperParts == null) return null;
    return upperParts.major - lowerParts.major;
  }

  /// True when this `>=A.B.C <D.E.F` range is exactly what `^A.B.C` would mean,
  /// so a caret would be tighter and clearer. Caret-equivalence: the upper
  /// bound is the next breaking version per pub's caret semantics — next major
  /// for `>=1.x`, next minor for `>=0.x`.
  bool get isCaretEquivalentRange {
    if (isCaret || !hasLower || !hasUpper) return false;
    final lowerParts = lower;
    final upperParts = upper;
    if (lowerParts == null || upperParts == null) return false;
    // For 1.x and up, caret stops at the next major (patch/minor become 0).
    if (lowerParts.major >= 1) {
      return upperParts.major == lowerParts.major + 1 &&
          upperParts.minor == 0 &&
          upperParts.patch == 0;
    }
    // For 0.x, caret stops at the next minor.
    return upperParts.major == 0 &&
        upperParts.minor == lowerParts.minor + 1 &&
        upperParts.patch == 0;
  }
}

/// Parses one constraint string (the value after `name:`), e.g. `^1.2.3`,
/// `>=1.0.0 <2.0.0`, `any`, or `''` (empty inline = block follows).
ParsedConstraint parseConstraint(String rawValue) {
  final value = _stripComment(rawValue).trim();
  final unquoted = _stripQuotes(value);

  // Empty inline value means a sub-map (git/path/sdk/hosted) follows on the
  // next lines — there is no comparable version range here.
  if (unquoted.isEmpty) {
    return ParsedConstraint(
      raw: unquoted,
      isBlock: true,
      isAny: false,
      isCaret: false,
      hasLower: false,
      hasUpper: false,
    );
  }

  if (unquoted == 'any') {
    return ParsedConstraint(
      raw: unquoted,
      isBlock: false,
      isAny: true,
      isCaret: false,
      hasLower: false,
      hasUpper: false,
    );
  }

  // Caret: lower bound explicit, upper bound synthesized from caret semantics.
  if (unquoted.startsWith('^')) {
    final lower = SemverParts.tryParse(unquoted.substring(1));
    return ParsedConstraint(
      raw: unquoted,
      isBlock: false,
      isAny: false,
      isCaret: true,
      hasLower: lower != null,
      hasUpper: lower != null,
      lower: lower,
      upper: lower == null ? null : _caretUpperBound(lower),
    );
  }

  return _parseRange(unquoted);
}

/// Parses a comparator range like `>=1.0.0 <2.0.0`, `>=1.0.0`, `<2.0.0`, or an
/// exact pin like `1.2.3` (treated as both bounds at the same version).
ParsedConstraint _parseRange(String value) {
  final lowerMatch = RegExp(r'>=?\s*([0-9][^\s,]*)').firstMatch(value);
  final upperMatch = RegExp(r'<=?\s*([0-9][^\s,]*)').firstMatch(value);

  SemverParts? lower = lowerMatch == null
      ? null
      : SemverParts.tryParse(lowerMatch.group(1)!);
  SemverParts? upper = upperMatch == null
      ? null
      : SemverParts.tryParse(upperMatch.group(1)!);
  bool hasLower = lowerMatch != null;
  bool hasUpper = upperMatch != null;

  // An exact pin (`1.2.3`, no comparators) bounds both ends at one version.
  if (!hasLower && !hasUpper) {
    final exact = SemverParts.tryParse(value);
    if (exact != null) {
      lower = exact;
      upper = exact;
      hasLower = true;
      hasUpper = true;
    }
  }

  return ParsedConstraint(
    raw: value,
    isBlock: false,
    isAny: false,
    isCaret: false,
    hasLower: hasLower,
    hasUpper: hasUpper,
    lower: lower,
    upper: upper,
  );
}

/// Pub caret upper bound: next major for `>=1.x`, next minor for `0.x`.
SemverParts _caretUpperBound(SemverParts lower) {
  if (lower.major >= 1) return SemverParts(lower.major + 1, 0, 0);
  return SemverParts(0, lower.minor + 1, 0);
}

/// One dependency line parsed from a pubspec section.
class PubspecDependency {
  const PubspecDependency(this.name, this.constraint);

  final String name;
  final ParsedConstraint constraint;
}

/// The parts of a `pubspec.yaml` the constraint rules inspect.
class ParsedPubspec {
  ParsedPubspec({
    required this.isApp,
    required this.sdkConstraint,
    required this.dependencies,
    required this.hasDependencyOverrides,
    required this.hasPublishTo,
    required this.hasHomepage,
    required this.hasRepository,
  });

  /// True when the package is an application (`publish_to: none`), false when
  /// it is a publishable package. Audience-gated rules use this: apps want
  /// tight constraints, published packages want wide ones.
  final bool isApp;

  /// The `environment: sdk:` constraint, when present.
  final ParsedConstraint? sdkConstraint;

  /// Regular and dev dependencies that carry an inline version string. Block
  /// entries (git/path/sdk) and the bare `flutter:`/`sdk: flutter` markers are
  /// excluded — they have no comparable version range.
  final List<PubspecDependency> dependencies;

  /// True when the pubspec has a non-empty `dependency_overrides:` section —
  /// i.e. the header is present AND at least one 2-space-indented child entry
  /// follows it. An empty section (`dependency_overrides:` with no children,
  /// or `dependency_overrides: {}`) is not a violation: nothing is actually
  /// being overridden.
  final bool hasDependencyOverrides;

  /// True when a `publish_to:` key exists at all, regardless of its value
  /// (`none` or a custom hosted-package server URL). Distinct from [isApp],
  /// which only matches the `none` value — `prefer_publish_to_none` needs to
  /// know "was this key considered at all" so a package that intentionally
  /// publishes to a private server is not flagged for missing `none`.
  final bool hasPublishTo;

  /// True when a non-empty `homepage:` field is present. Used, together with
  /// [hasRepository], as a heuristic signal that this pubspec describes a
  /// publishable library rather than an application — pub.dev expects both
  /// fields on a published package, so their presence suggests intent to
  /// publish even without an explicit `publish_to:`.
  final bool hasHomepage;

  /// True when a non-empty `repository:` field is present. See [hasHomepage].
  final bool hasRepository;
}

/// Section headers whose 2-space-indented children are version dependencies.
final RegExp _depSectionHeader = RegExp(
  r'^(dependencies|dev_dependencies):\s*$',
);

/// The `dependency_overrides:` block header. Matched only when nothing
/// follows the colon on the same line — `dependency_overrides: {}` (an
/// explicit empty flow-map) intentionally does NOT match, so it is treated
/// the same as "no overrides" rather than needing a separate empty-map check.
final RegExp _dependencyOverridesHeader = RegExp(
  r'^dependency_overrides:\s*$',
);

/// A 2-space-indented `name: value` entry. `value` may be empty (block follows).
final RegExp _depEntry = RegExp(r'^  ([a-zA-Z0-9_][a-zA-Z0-9_-]*):(.*)$');

/// `publish_to: none` at column 0 marks an application, not a published
/// package. Uses `[ \t]*` (not `\s*`) around the value: `\s` matches `\n`,
/// so `\s*` here would let the match skip past an empty rest-of-line and
/// bleed onto the START OF THE NEXT LINE looking for `none` — a bug found in
/// review (confirmed by a failing test with `publish_to:` on its own line
/// followed by an unrelated `none`-shaped value further down).
final RegExp _publishToNone = RegExp(
  r'''^publish_to:[ \t]*['"]?none['"]?[ \t]*(#.*)?$''',
  multiLine: true,
);

/// Any `publish_to:` key at column 0, whatever its value — `none` or a
/// custom hosted-package server URL. Broader than [_publishToNone] because
/// `prefer_publish_to_none` must not flag a pubspec that already made a
/// deliberate publish-target decision of either kind. The first
/// non-whitespace character must not be `#`: `publish_to: # decide later` has
/// no actual value, only a comment, so it must NOT count as a deliberate
/// decision — bug found in review, previously `\S` matched the `#` itself and
/// silently suppressed the lint on a pubspec that still needs publish_to set.
/// Uses `[ \t]*` rather than `\s*` for the same line-bleed reason as
/// [_publishToNone]: `\s` matches `\n`, so a bare `publish_to:` with nothing
/// on its line would otherwise match the first non-whitespace character of
/// the FOLLOWING line and be misread as a value.
final RegExp _publishToAny = RegExp(
  r'''^publish_to:[ \t]*[^\s#]''',
  multiLine: true,
);

/// A non-empty `homepage:` field at column 0. Requires at least one non-space,
/// non-`#` character after the colon so `homepage:` with nothing following
/// (or only trailing whitespace, or only a trailing comment like
/// `homepage: # TODO`) does not count as "present" — same reasoning as
/// [_publishToAny]. `[ \t]*` (not `\s*`) keeps the match on one line — see
/// [_publishToAny] for why `\s*` is unsafe here.
final RegExp _homepageField = RegExp(
  r'''^homepage:[ \t]*[^\s#]''',
  multiLine: true,
);

/// A non-empty `repository:` field at column 0. Same non-empty, non-comment,
/// single-line rule as [_homepageField].
final RegExp _repositoryField = RegExp(
  r'''^repository:[ \t]*[^\s#]''',
  multiLine: true,
);

/// Parses a `pubspec.yaml` body into the [ParsedPubspec] the rules consume.
ParsedPubspec parsePubspecConstraints(String content) {
  final lines = content.split(RegExp(r'\r\n?|\n'));
  final isApp = _publishToNone.hasMatch(content);
  // Publish-metadata signals for prefer_publish_to_none: whether the pubspec
  // already made an explicit publish_to decision, and whether it carries the
  // homepage/repository fields pub.dev expects on a publishable package.
  final hasPublishTo = _publishToAny.hasMatch(content);
  final hasHomepage = _homepageField.hasMatch(content);
  final hasRepository = _repositoryField.hasMatch(content);
  ParsedConstraint? sdkConstraint;
  final dependencies = <PubspecDependency>[];
  // True once a `dependency_overrides:` header AND at least one indented
  // child entry under it have both been seen.
  var hasDependencyOverrides = false;

  // Track which top-level block we are inside. Only `environment` and the two
  // dependency sections matter; anything else (flutter:, dev tooling) is skipped.
  bool inDepSection = false;
  bool inEnvironment = false;
  // Tracked separately from inDepSection: override entries must NOT be added
  // to `dependencies` (they are not the package's own declared constraints,
  // and folding them in would make the range-hygiene rules reason about
  // versions the pubspec doesn't actually declare).
  bool inDependencyOverrides = false;

  for (final line in lines) {
    // A non-indented, non-blank line starts a new top-level block.
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
      inDepSection = _depSectionHeader.hasMatch(line);
      inEnvironment = line.trimRight() == 'environment:';
      inDependencyOverrides = _dependencyOverridesHeader.hasMatch(line);
      continue;
    }

    if (inDependencyOverrides) {
      // Any 2-space-indented child line under the header means the section
      // is non-empty — a real override is being forced.
      if (_depEntry.hasMatch(line)) {
        hasDependencyOverrides = true;
      }
      continue;
    }

    if (inEnvironment) {
      final sdkMatch = RegExp(r'^  sdk:\s*(.+)$').firstMatch(line);
      if (sdkMatch != null) {
        final parsed = parseConstraint(sdkMatch.group(1)!);
        // Keep only real version ranges. `sdk: flutter` is a keyword, not a
        // version, and parses to a constraint with no bounds — skip it.
        if (parsed.lower != null || parsed.upper != null || parsed.isAny) {
          sdkConstraint = parsed;
        }
      }
      continue;
    }

    if (inDepSection) {
      final match = _depEntry.firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)!;
      final constraint = parseConstraint(match.group(2)!);
      // Skip block entries and the SDK-sourced `flutter`/`flutter_test` markers.
      if (constraint.isBlock) continue;
      dependencies.add(PubspecDependency(name, constraint));
    }
  }

  return ParsedPubspec(
    isApp: isApp,
    sdkConstraint: sdkConstraint,
    dependencies: dependencies,
    hasDependencyOverrides: hasDependencyOverrides,
    hasPublishTo: hasPublishTo,
    hasHomepage: hasHomepage,
    hasRepository: hasRepository,
  );
}

/// Returns true when the pubspec has a non-empty dependency_overrides
/// section. Exists as a thin, named wrapper around [ParsedPubspec] so the
/// unit tests can assert on the same public surface the rule reads from,
/// without depending on field access syntax staying stable.
bool hasDependencyOverridesEntries(ParsedPubspec parsed) {
  return parsed.hasDependencyOverrides;
}

/// Returns true when [parsed] looks like an application pubspec that is
/// missing `publish_to: none`.
///
/// Extracted as a pure function (rather than inlined in the rule) so it can
/// be unit-tested directly on parser output, the same way every other
/// decision in this file is tested. The heuristic is intentionally simple
/// for v1: a package that already made a publish_to decision, or that
/// carries both of the fields pub.dev requires for a published package
/// (`homepage` and `repository`), is assumed to be a library and is not
/// flagged — everything else is treated as an app missing the guard.
bool shouldFlagMissingPublishToNone(ParsedPubspec parsed) {
  // Already has publish_to: (whether "none" or a custom server URL) — the
  // author already made a deliberate choice, so there is nothing to flag.
  if (parsed.hasPublishTo) return false;
  // Has both homepage and repository — looks like a publishable package
  // deliberately prepared for pub.dev, not an app that forgot the guard.
  if (parsed.hasHomepage && parsed.hasRepository) return false;
  // No publish_to AND missing (or incomplete) publish metadata — flag it as
  // an app that should set publish_to: none to prevent accidental publishing.
  return true;
}

/// Returns true when an app pubspec (`publish_to: none`) has any caret-syntax
/// dependencies that could be pinned to exact versions for reproducible
/// builds. Published packages are exempt: they need caret ranges so
/// consumers can resolve compatible versions, which is the opposite goal of
/// `PreferCaretConstraintInAppRule` — the two rules form a deliberate
/// conflicting stylistic pair, gated apart by [ParsedPubspec.isApp].
bool hasCaretDependenciesInApp(ParsedPubspec parsed) {
  // Only fire for apps — a publishable package should keep caret ranges.
  if (!parsed.isApp) return false;
  // `parsed.dependencies` intentionally includes BOTH `dependencies:` and
  // `dev_dependencies:` (see `_depSectionHeader`, which matches both
  // headers into the same list). Reproducible builds care about dev
  // tooling too — a caret-pinned build_runner/test package can drift a CI
  // build the same way a caret-pinned runtime dependency can — so dev deps
  // are not excluded here.
  //
  // A single caret dependency is enough to report: the rule flags the
  // pubspec once, not once per offending line.
  return parsed.dependencies.any((dep) => dep.constraint.isCaret);
}

/// Finds dependencies that carry more than one distinct constraint string
/// across a set of workspace member pubspecs.
///
/// Extracted from `WorkspaceDependencyVersionSyncRule` (in
/// `lib/src/rules/config/pubspec_constraint_rules.dart`) so the actual
/// decision logic — "do any two members disagree on a dependency's version
/// range" — is a pure function over strings and can be unit-tested directly,
/// the same way every other constraint rule in this file is tested. The rule
/// itself only adds file I/O (reading each member's pubspec.yaml) and the
/// diagnostic report; it delegates the comparison to this function.
///
/// [memberPubspecContents] is the raw text of each workspace member's
/// pubspec.yaml. Order does not matter — every distinct raw constraint string
/// seen for a dependency name is collected regardless of which member wrote
/// it.
///
/// Returns a map of dependency name to the set of distinct constraint strings
/// found for it, containing ONLY dependencies with 2+ distinct strings (a
/// dependency used by just one member, or used identically by all members
/// that declare it, has nothing to diverge from and is omitted).
///
/// Block dependencies (`git:`, `path:`, `sdk:`) are never included: they have
/// no comparable version string, and `parsePubspecConstraints` already
/// excludes them from `dependencies` before this function ever sees them —
/// there is no separate block check needed here.
Map<String, Set<String>> findDivergentDependencyConstraints(
  Iterable<String> memberPubspecContents,
) {
  // Key = dependency name, Value = every distinct raw constraint string seen
  // for it across all members.
  final constraintsByDependency = <String, Set<String>>{};
  for (final content in memberPubspecContents) {
    final parsed = parsePubspecConstraints(content);
    for (final dep in parsed.dependencies) {
      constraintsByDependency
          .putIfAbsent(dep.name, () => {})
          .add(dep.constraint.raw);
    }
  }

  // A dependency only "diverges" once two members disagree on its constraint
  // string — a single distinct value (whether from one member or from many
  // members that all agree) is not a finding.
  constraintsByDependency.removeWhere((_, versions) => versions.length <= 1);
  return constraintsByDependency;
}

/// Drops a trailing `# comment` that is not inside quotes. Constraint values
/// never contain `#`, so a plain split on the first `#` is safe here.
String _stripComment(String value) {
  final hashIndex = value.indexOf('#');
  if (hashIndex < 0) return value;
  return value.substring(0, hashIndex);
}

/// Removes a single pair of surrounding single or double quotes.
String _stripQuotes(String value) {
  if (value.length < 2) return value;
  final first = value[0];
  final last = value[value.length - 1];
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1);
  }
  return value;
}
