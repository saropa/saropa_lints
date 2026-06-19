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
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2) ?? '0');
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
}

/// Section headers whose 2-space-indented children are version dependencies.
final RegExp _depSectionHeader = RegExp(
  r'^(dependencies|dev_dependencies):\s*$',
);

/// A 2-space-indented `name: value` entry. `value` may be empty (block follows).
final RegExp _depEntry = RegExp(r'^  ([a-zA-Z0-9_][a-zA-Z0-9_-]*):(.*)$');

/// `publish_to: none` at column 0 marks an application, not a published package.
final RegExp _publishToNone = RegExp(
  r'''^publish_to:\s*['"]?none['"]?\s*(#.*)?$''',
  multiLine: true,
);

/// Parses a `pubspec.yaml` body into the [ParsedPubspec] the rules consume.
ParsedPubspec parsePubspecConstraints(String content) {
  final lines = content.split(RegExp(r'\r\n?|\n'));
  final isApp = _publishToNone.hasMatch(content);
  ParsedConstraint? sdkConstraint;
  final dependencies = <PubspecDependency>[];

  // Track which top-level block we are inside. Only `environment` and the two
  // dependency sections matter; anything else (flutter:, dev tooling) is skipped.
  bool inDepSection = false;
  bool inEnvironment = false;

  for (final line in lines) {
    // A non-indented, non-blank line starts a new top-level block.
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
      inDepSection = _depSectionHeader.hasMatch(line);
      inEnvironment = line.trimRight() == 'environment:';
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
  );
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
