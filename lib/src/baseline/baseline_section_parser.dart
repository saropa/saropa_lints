/// Line parser for the top-level `baseline:` section of
/// `analysis_options_custom.yaml`.
///
/// The config loader reads custom options with line regexes rather than a
/// YAML library (it runs on every plugin start and must not pull a parser
/// into the analysis isolate), so this covers exactly the YAML shapes the
/// documented baseline examples use:
///
/// ```yaml
/// baseline:
///   file: "saropa_baseline.json"    # trailing comments are dropped
///   date: 2025-01-15
///   paths:                          # block list
///     - "lib/legacy/"
///   only_impacts: [info, warning]   # flow (inline) list
/// ```
///
/// Why it exists as its own unit: the earlier in-loader parser kept a
/// trailing `# comment` as part of the value and stored `[info]` as the
/// string `"[info]"`. The first made `file:` name a file that does not exist
/// (no baseline loaded) and `date:` unparseable; the second made
/// `only_impacts` read as empty, which baselines every severity, the
/// opposite of what the documented example asks for.
library;

import 'package:saropa_lints/src/string_slice_utils.dart';

/// The top-level `baseline:` header line, with or without a trailing comment.
/// Shared by the loader (which reads the section) and the CLI (which edits
/// it): if they disagreed, `baseline:  # note` would be ignored by one and
/// duplicated by the other.
final RegExp kBaselineSectionHeader = RegExp(
  r'^baseline:[ \t]*(?:#.*)?\r?$',
  multiLine: true,
);

/// Parses the section body that starts at [offset] in [content] (just past
/// the `baseline:` line) into the map shape `BaselineConfig.fromYaml` reads:
/// scalars as `String`, block and flow lists as `List<String>`.
///
/// The section ends at the first non-blank, non-comment line that is not
/// indented. Unknown keys are kept; `BaselineConfig` ignores them.
Map<String, Object> parseBaselineSection(String content, int offset) {
  final Map<String, Object> map = <String, Object>{};
  final List<String> lines = content
      .afterIndex(offset)
      .replaceAll('\r\n', '\n')
      .split('\n');
  List<String>? currentList;

  for (final String line in lines) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    // Not indented: the next top-level key, so the section is over.
    if (!line.startsWith(' ') && !line.startsWith('\t')) break;

    // Block list item ("    - value") under the most recent bare key.
    if (trimmed == '-' || trimmed.startsWith('- ')) {
      final String item = unquoteYamlScalar(
        stripYamlComment(trimmed.substring(1)),
      );
      if (currentList != null && item.isNotEmpty) currentList.add(item);
      continue;
    }

    final RegExpMatch? kv = _keyValue.firstMatch(line);
    final String? key = kv?.group(1);
    if (kv == null || key == null) continue;
    final String value = stripYamlComment(kv.group(2) ?? '');

    if (value.isEmpty) {
      // Bare key: a block list follows. Stored now so an empty list (no
      // items) still reads as an explicit empty list.
      currentList = <String>[];
      map[key] = currentList;
    } else {
      currentList = null;
      map[key] = _isFlowList(value)
          ? _parseFlowList(value)
          : unquoteYamlScalar(value);
    }
  }
  return map;
}

/// `  key: value`; the key is a YAML-style identifier.
final RegExp _keyValue = RegExp(r'^\s+(\w+):\s*(.*)$');

/// Removes a trailing YAML comment from [value] and trims it.
///
/// A `#` starts a comment only outside quotes and only at the start or after
/// whitespace, so `"a#b"`, `'x # y'` and `lib/#legacy` keep their `#`.
String stripYamlComment(String value) {
  String? quote;
  for (int i = 0; i < value.length; i++) {
    final String ch = value[i];
    if (quote != null) {
      if (ch == quote) quote = null;
      continue;
    }
    if (ch == '"' || ch == "'") {
      quote = ch;
    } else if (ch == '#' && (i == 0 || value[i - 1].trim().isEmpty)) {
      return value.substring(0, i).trim();
    }
  }
  return value.trim();
}

/// Strips one pair of matching surrounding quotes from [value].
///
/// Only a matched pair is removed; the old parser deleted every `"` in the
/// value, which also mangled paths that legitimately contain one.
String unquoteYamlScalar(String value) {
  final String v = value.trim();
  if (v.length >= 2) {
    final String first = v[0];
    if ((first == '"' || first == "'") && v.endsWith(first)) {
      return v.substring(1, v.length - 1);
    }
  }
  return v;
}

/// True for a flow sequence such as `[info, warning]` or `[]`.
bool _isFlowList(String value) => value.startsWith('[') && value.endsWith(']');

/// Items of a flow sequence, unquoted, with empty entries dropped. Commas
/// inside quotes are not split on, so `["a,b"]` stays one item.
List<String> _parseFlowList(String value) {
  final String inner = value.substring(1, value.length - 1);
  final List<String> items = <String>[];
  final StringBuffer current = StringBuffer();
  String? quote;
  for (int i = 0; i < inner.length; i++) {
    final String ch = inner[i];
    if (quote == null && ch == ',') {
      _addFlowItem(items, current.toString());
      current.clear();
      continue;
    }
    if (quote == null && (ch == '"' || ch == "'")) {
      quote = ch;
    } else if (ch == quote) {
      quote = null;
    }
    current.write(ch);
  }
  _addFlowItem(items, current.toString());
  return items;
}

/// Adds [raw] to [items] when it is a non-empty scalar after unquoting.
void _addFlowItem(List<String> items, String raw) {
  final String item = unquoteYamlScalar(raw);
  if (item.isNotEmpty) items.add(item);
}
