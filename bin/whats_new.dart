// ignore_for_file: avoid_print

/// Parses CHANGELOG.md and formats a concise "what's new" summary for the
/// init process. Output is capped to avoid terminal spam.
library;

import 'dart:io';

const int _maxItemsPerCategory = 5; // bullets per category before "+N more"
const int _maxLineLength = 78; // chars per bullet before "..."
const int _maxTotalLines = 18; // global output cap across all categories
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
        categories.add(_truncateCategory(currentName, items));
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
    categories.add(_truncateCategory(currentName, items));
  }
  return categories;
}

/// Cap items per category, preserving total count for "+N more" indicator.
_Cat _truncateCategory(String name, List<String> allItems) {
  final kept = allItems.length > _maxItemsPerCategory
      ? allItems.sublist(0, _maxItemsPerCategory)
      : allItems;
  return _Cat(name, kept, allItems.length);
}

/// A parsed category with its (possibly truncated) bullet items.
class _Cat {
  const _Cat(this.name, this.items, this.totalCount);
  final String name;
  final List<String> items;
  final int totalCount;
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

  var used = 2; // lines consumed so far
  for (var i = 0; i < categories.length; i++) {
    // Need room for blank + header + at least 1 bullet
    if (used + 3 > _maxTotalLines) {
      final remaining = categories.length - i;
      lines.add(
        '  ${c.dim}... and $remaining more section'
        '${remaining == 1 ? '' : 's'}${c.reset}',
      );
      break;
    }
    used += _renderCategory(lines, categories[i], c, used);
  }

  // Footer with link (not counted toward cap — always shown)
  lines.add('');
  lines.add('  ${c.dim}Full changelog: ${c.cyan}$_changelogUrl${c.reset}');
  return lines;
}

/// Append one category's lines and return the number of lines added.
int _renderCategory(List<String> lines, _Cat cat, AnsiColors c, int usedSoFar) {
  lines.add('');
  lines.add('  ${c.bold}${cat.name}${c.reset}');
  var added = 2;

  for (final item in cat.items) {
    if (usedSoFar + added >= _maxTotalLines - 1) break;
    lines.add('    - ${_truncateLine(item)}');
    added++;
  }

  if (cat.totalCount > cat.items.length) {
    final more = cat.totalCount - cat.items.length;
    lines.add('    ${c.dim}+$more more${c.reset}');
    added++;
  }
  return added;
}

/// Truncate a line to [_maxLineLength] characters, appending "..." if needed.
String _truncateLine(String text) {
  if (text.length <= _maxLineLength) return text;
  return '${text.substring(0, _maxLineLength - 3)}...';
}
