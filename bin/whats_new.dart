// ignore_for_file: avoid_print

/// Parses CHANGELOG.md and formats a "what's new" summary for the
/// init process. Individual lines are truncated but all items are shown.
library;

import 'dart:io';

const int _maxLineLength = 78; // chars per bullet before "..."
const String _changelogUrl = 'https://pub.dev/packages/saropa_lints/changelog';

/// ANSI color strings passed from init.dart's private `_Colors` class.
class AnsiColors {
  const AnsiColors({
    required this.bold,
    required this.cyan,
    required this.dim,
    required this.reset,
  });
  final String bold;
  final String cyan;
  final String dim;
  final String reset;
}

/// Parse and format "what's new" from the package's CHANGELOG.md.
///
/// Returns pre-formatted lines (with ANSI codes) ready for `_logTerminal()`,
/// or an empty list if nothing to show. Silently returns empty on any error.
List<String> formatWhatsNew({
  required String packageDir,
  required String version,
  required AnsiColors colors,
}) {
  try {
    final file = File('$packageDir/CHANGELOG.md');
    if (!file.existsSync()) return const [];

    final content = file.readAsStringSync();
    final section = _extractVersionSection(content, version);
    if (section == null) return const [];

    final categories = _parseCategories(section.text);
    if (categories.isEmpty) return const [];

    return _format(categories, section.isUnreleased ? null : version, colors);
  } catch (_) {
    return const [];
  }
}

// ── Section extraction ──────────────────────────────────────────────────────

/// Find the changelog section for [version], falling back to [Unreleased].
({String text, bool isUnreleased})? _extractVersionSection(
  String content,
  String version,
) {
  var isUnreleased = false;
  var match = RegExp(
    r'^## \[' + RegExp.escape(version) + r'\]',
    multiLine: true,
  ).firstMatch(content);

  if (match == null) {
    match = RegExp(r'^## \[Unreleased\]', multiLine: true).firstMatch(content);
    if (match == null) return null;
    isUnreleased = true;
  }

  // Extract text from after the header to the next section boundary
  final startIndex = content.indexOf('\n', match.start);
  if (startIndex == -1) return null;

  final sectionEnd = RegExp(r'^(?:---|## \[)', multiLine: true);
  final endMatch = sectionEnd.firstMatch(content.substring(startIndex + 1));
  final text = endMatch != null
      ? content.substring(startIndex + 1, startIndex + 1 + endMatch.start)
      : content.substring(startIndex + 1);

  return (text: text.trim(), isUnreleased: isUnreleased);
}

// ── Category parsing ────────────────────────────────────────────────────────

final RegExp _categoryPattern = RegExp(r'^### (.+)$');
final RegExp _bulletPattern = RegExp(r'^- (.+)$');

/// Parse `### Category` headers and `- bullet` items from a section.
List<_Cat> _parseCategories(String sectionText) {
  final lines = sectionText.split('\n');
  final categories = <_Cat>[];
  String? currentName;
  var items = <String>[];

  for (final line in lines) {
    final catMatch = _categoryPattern.firstMatch(line);
    if (catMatch != null) {
      if (currentName != null && items.isNotEmpty) {
        categories.add(_Cat(currentName, items));
      }
      currentName = catMatch.group(1)!.trim();
      items = [];
      continue;
    }
    if (currentName == null) continue;

    final bulletMatch = _bulletPattern.firstMatch(line.trim());
    if (bulletMatch != null) items.add(bulletMatch.group(1)!);
  }

  if (currentName != null && items.isNotEmpty) {
    categories.add(_Cat(currentName, items));
  }

  return categories;
}

/// A parsed category with its bullet items.
class _Cat {
  const _Cat(this.name, this.items);
  final String name;
  final List<String> items;
}

// ── Formatting ──────────────────────────────────────────────────────────────

/// Format parsed categories into styled terminal lines.
/// [version] is null when showing the [Unreleased] section.
List<String> _format(List<_Cat> categories, String? version, AnsiColors c) {
  final lines = <String>[];
  final label = version != null
      ? "What's new in $version:"
      : "What's new (unreleased):";
  lines.add('');
  lines.add('  ${c.bold}${c.cyan}$label${c.reset}');

  for (final cat in categories) {
    _renderCategory(lines, cat, c);
  }

  // Footer link
  lines.add('');
  lines.add('  ${c.dim}Full changelog: ${c.cyan}$_changelogUrl${c.reset}');
  return lines;
}

/// Append one category's lines.
void _renderCategory(List<String> lines, _Cat cat, AnsiColors c) {
  lines.add('');
  lines.add('  ${c.bold}${cat.name}${c.reset}');

  for (final item in cat.items) {
    lines.add('    - ${_truncateLine(item)}');
  }
}

/// Truncate a line to [_maxLineLength] characters, appending "..." if needed.
String _truncateLine(String text) {
  if (text.length <= _maxLineLength) return text;
  return '${text.substring(0, _maxLineLength - 3)}...';
}
