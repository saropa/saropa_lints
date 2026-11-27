/// The accepted-findings list: a committed, hand-maintained record of
/// reviewed findings (`rule` + `file` + `reason`, no line numbers).
///
/// An optional `max:` caps how many findings an entry hides: the first `max`
/// by source position stay hidden and the rest report again.
///
/// Lives at `<project root>/saropa_accepted.yaml`. Its presence is the
/// opt-in; there is no config key or env var. An entry hides every finding
/// of its rule in its file, from the Problems panel and from exports. It
/// exists because the baseline (`saropa_baseline.json`) is line-keyed and
/// regenerated, so it cannot hold a durable "reviewed, and why" record.
///
/// This file holds only parsing, validation and matching. Filtering scan
/// output and judging staleness live in `accepted_findings_report.dart`; the
/// in-editor plugin hook lives in `accepted_findings_runtime.dart`.
library;

import 'dart:io' show File, FileSystemEntity, Platform;

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' show YamlList, YamlMap, YamlNode, loadYamlNode;

import '../rule_name_utils.dart' show allSaropaRuleNames;

/// File name of the list, at the project root. One literal, used by the CLI,
/// the plugin hook and (mirrored) the VS Code extension.
const String kAcceptedFindingsFileName = 'saropa_accepted.yaml';

/// The only schema version this build understands.
const int kAcceptedFindingsVersion = 1;

/// Allowed values for an entry's optional `kind`.
const Set<String> kAcceptedKinds = {'accepted', 'false_positive'};

/// Keys an entry may carry. Anything else invalidates the entry, so a key
/// from a newer schema (or a mistaken `line:`) never silently widens what
/// the entry hides.
const Set<String> _allowedEntryKeys = {'rule', 'file', 'kind', 'reason', 'max'};

/// One valid entry.
class AcceptedEntry {
  const AcceptedEntry({
    required this.rule,
    required this.file,
    required this.reason,
    required this.line,
    this.kind,
    this.max,
  });

  final String rule;

  /// Project-relative path with forward slashes, no leading `./`.
  final String file;
  final String reason;

  /// `accepted`, `false_positive`, or null when omitted.
  final String? kind;

  /// Most findings the entry hides, always positive; null means unlimited.
  final int? max;

  /// 1-based line of the entry in the list file, for stale/invalid reports
  /// and the Problems diagnostic the extension places on the list file.
  final int line;

  /// Lookup key shared by matching and per-entry hidden counts.
  String get key => accKey(file, rule);
}

/// Builds the (file, rule) lookup key. NUL cannot appear in either part.
String accKey(String file, String rule) => '$file\u0000$rule';

/// A problem with the list: a parse failure or an invalid entry. Invalid
/// entries hide nothing.
class AcceptedProblem {
  const AcceptedProblem({required this.line, required this.message});

  /// 1-based line in the list file (1 when the whole file is unusable).
  final int line;
  final String message;
}

/// The parsed list. [entries] holds valid entries only.
class AcceptedFindingsList {
  AcceptedFindingsList._(this.path, this.exists, this.entries, this.problems)
    : _byKey = {for (final e in entries) e.key: e};

  /// An absent list: hides nothing, reports nothing.
  AcceptedFindingsList.absent(String path)
    : this._(path, false, const [], const []);

  /// Absolute path of the list file (whether or not it exists).
  final String path;
  final bool exists;
  final List<AcceptedEntry> entries;
  final List<AcceptedProblem> problems;
  final Map<String, AcceptedEntry> _byKey;

  bool get isEmpty => entries.isEmpty;

  /// The entry covering [rule] in project-relative [relFile], if any.
  /// Exact match on the path; no suffix or glob matching.
  AcceptedEntry? entryFor(String relFile, String rule) =>
      _byKey[accKey(relFile, rule)];

  /// Loads `<projectRoot>/saropa_accepted.yaml`. Never throws: an unreadable
  /// file becomes a problem rather than an empty list, so a broken list is
  /// always reported instead of looking like "nothing accepted".
  static AcceptedFindingsList load(String projectRoot, {Set<String>? known}) {
    // Normalized so a `.` scan target does not put `/./` into the list path.
    final root = _trimSlash(_slashes(p.normalize(projectRoot)));
    final path = '$root/$kAcceptedFindingsFileName';
    if (!FileSystemEntity.isFileSync(path)) {
      return AcceptedFindingsList.absent(path);
    }
    try {
      return parse(File(path).readAsStringSync(), path: path, known: known);
    } on Object catch (e) {
      return AcceptedFindingsList._(path, true, const [], [
        AcceptedProblem(line: 1, message: 'Cannot read file: $e'),
      ]);
    }
  }

  /// Parses list [content]. [known] defaults to every saropa_lints rule
  /// name; injectable so tests do not depend on the live registry.
  static AcceptedFindingsList parse(
    String content, {
    required String path,
    Set<String>? known,
  }) {
    final problems = <AcceptedProblem>[];
    final entries = <AcceptedEntry>[];
    YamlNode root;
    try {
      root = loadYamlNode(content);
    } on Object catch (e) {
      // Whole-file failure: hide nothing, report once.
      return AcceptedFindingsList._(path, true, const [], [
        AcceptedProblem(line: 1, message: 'Cannot parse YAML: $e'),
      ]);
    }
    // An empty file is a valid, empty list (nothing to hide, nothing wrong).
    if (root.value == null) return AcceptedFindingsList._(path, true, [], []);
    if (root is! YamlMap) {
      return AcceptedFindingsList._(path, true, const [], [
        _problemAt(root, 'Top level must be a map with `accepted:`.'),
      ]);
    }
    final version = root['version'];
    // An unknown version hides nothing: its entries may mean something this
    // build does not implement.
    if (version != null && version != kAcceptedFindingsVersion) {
      return AcceptedFindingsList._(path, true, const [], [
        _problemAt(root, 'Unsupported version $version (expected 1).'),
      ]);
    }
    final list = root.nodes['accepted'];
    if (list == null || list.value == null) {
      return AcceptedFindingsList._(path, true, [], []);
    }
    if (list is! YamlList) {
      return AcceptedFindingsList._(path, true, const [], [
        _problemAt(list, '`accepted:` must be a list.'),
      ]);
    }
    final seen = <String>{};
    for (final node in list.nodes) {
      final entry = _parseEntry(node, known ?? allSaropaRuleNames, problems);
      if (entry == null) continue;
      // A duplicate hides nothing extra; flag it so the list stays tidy.
      if (!seen.add(entry.key)) {
        problems.add(
          AcceptedProblem(
            line: entry.line,
            message: 'Duplicate entry for ${entry.rule} in ${entry.file}.',
          ),
        );
        continue;
      }
      entries.add(entry);
    }
    return AcceptedFindingsList._(path, true, entries, problems);
  }
}

/// Validates one list item. Returns null (and records why) when invalid.
AcceptedEntry? _parseEntry(
  YamlNode node,
  Set<String> known,
  List<AcceptedProblem> problems,
) {
  final line = node.span.start.line + 1;
  void bad(String m) => problems.add(AcceptedProblem(line: line, message: m));
  if (node is! YamlMap) {
    bad('Entry must be a map with rule, file and reason.');
    return null;
  }
  final extra = node.keys.where((k) => !_allowedEntryKeys.contains(k));
  if (extra.isNotEmpty) {
    bad(
      'Unknown key(s): ${extra.join(', ')}. Allowed: rule, file, kind, reason, max.',
    );
    return null;
  }
  final rule = _str(node['rule']);
  final rawFile = _str(node['file']);
  final reason = _str(node['reason']);
  final kind = _str(node['kind']);
  final file = rawFile == null ? null : normalizeAcceptedFile(rawFile);
  // Presence is checked, not just the value: an empty `max:` must not fall
  // back to unlimited, which would hide more than the author asked for.
  final hasMax = node.containsKey('max');
  final rawMax = node['max'];
  final max = rawMax is int && rawMax > 0 ? rawMax : null;
  // First failing check wins; one message per entry keeps the report short.
  final String? error;
  if (rule == null) {
    error = 'Missing `rule`.';
  } else if (rawFile == null) {
    error = 'Missing `file`.';
  } else if (reason == null) {
    // A reason is the point of the list: without one the entry is just an
    // unexplained suppression, so it hides nothing.
    error = 'Missing or empty `reason`.';
  } else if (!known.contains(rule)) {
    // Covers typos and renamed rules: an entry that can never match must
    // not sit in the list looking like it does something.
    error = 'Unknown rule `$rule`.';
  } else if (kind != null && !kAcceptedKinds.contains(kind)) {
    error = '`kind` must be accepted or false_positive.';
  } else if (hasMax && max == null) {
    error = '`max` must be a positive whole number.';
  } else if (file == null) {
    error = '`file` must be a project-relative path without globs or "..".';
  } else {
    error = null;
  }
  if (error != null || rule == null || file == null || reason == null) {
    bad(error ?? 'Invalid entry.');
    return null;
  }
  return AcceptedEntry(
    rule: rule,
    file: file,
    reason: reason,
    kind: kind,
    max: max,
    line: line,
  );
}

/// Normalizes an entry's `file` to the matching form, or null when it is not
/// a plain project-relative path. Backslashes become slashes so a path typed
/// on Windows still matches; absolute paths, `..` and glob characters are
/// rejected because matching is exact on the project-relative path.
String? normalizeAcceptedFile(String raw) {
  var f = _slashes(raw.trim());
  while (f.startsWith('./')) {
    f = f.substring(2);
  }
  if (f.isEmpty || f.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(f)) {
    return null;
  }
  if (f.split('/').contains('..') || RegExp(r'[*?\[\]{}]').hasMatch(f)) {
    return null;
  }
  return f;
}

/// Converts an absolute [path] to the project-relative form entries use, or
/// null when it is outside [projectRoot]. Both sides are normalized first: a
/// `.` scan target yields `<root>/./lib/a.dart`, which otherwise matches no
/// entry, so nothing was hidden or checked. Both are also made absolute: a
/// producer given a relative root (`scan_daemon .`) reports absolute finding
/// paths, which a bare `.` prefix would never match. The root prefix is compared
/// case-insensitively on Windows (drive-letter casing differs between
/// tools); the remainder is compared exactly by the caller.
String? relativeToProject(String path, String projectRoot) {
  final f = _slashes(p.normalize(p.absolute(path)));
  final root = _slashes(p.normalize(p.absolute(projectRoot)));
  final r = '${_trimSlash(root)}/';
  final matches = Platform.isWindows
      ? f.toLowerCase().startsWith(r.toLowerCase())
      : f.startsWith(r);
  return matches ? f.substring(r.length) : null;
}

String _slashes(String s) => s.replaceAll('\\', '/');

String _trimSlash(String s) =>
    s.endsWith('/') ? s.substring(0, s.length - 1) : s;

/// Trimmed non-empty string value, or null.
String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

AcceptedProblem _problemAt(YamlNode node, String message) =>
    AcceptedProblem(line: node.span.start.line + 1, message: message);
