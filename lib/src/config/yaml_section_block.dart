/// Bounds a hand-rolled, line-based YAML section parse to one section.
///
/// The config loaders in this package (`banned_usage:`,
/// `always_specify_parameter_names:`, `avoid_ignoring_return_values:`) are
/// deliberately line-based and do not support full YAML. Each one finds its
/// top-level header with a regex, then looks for an indented sub-key in
/// everything that follows. Without a bound, that search — and the list-item
/// loop after it — runs to end-of-file and silently adopts configuration that
/// belongs to an unrelated top-level section further down the file.
/// [yamlSectionBlock] supplies the bound.
library;

/// The indented body of a top-level YAML section, given everything that
/// follows the section's own header line (i.e. `content.substring(match.end)`
/// for a header regex anchored with `\s*$`).
///
/// Keeps indented lines, blank lines, and full-line `#` comments; stops at the
/// first line that begins a new top-level key — any line starting in column 0
/// with a non-whitespace, non-`#` character — so a sibling section's sub-keys
/// and list items are never mistaken for this section's.
///
/// The result is prefixed with a newline so the first kept line still has a
/// line start for a caller's `^\s+sub_key:` pattern to anchor against. The
/// first element of the split is empty for that call shape — the header regex
/// ends its match at a line end, so nothing of the header line survives into
/// the substring — and is skipped rather than kept. A body passed in directly,
/// without a leading line break, keeps its first line.
///
/// Line endings are normalised first, matching the sibling config readers
/// (`runtime_tier_cap.dart`, `analysis_options_rule_packs.dart`,
/// `config_loader.dart`), which all accept a Windows-authored
/// `analysis_options_custom.yaml`. Without it a CRLF blank line arrives here
/// as a bare `\r` — neither empty nor indented nor a comment — and would end
/// the block early, silently discarding the rest of the section.
String yamlSectionBlock(String afterSectionHeader) {
  final lines = afterSectionHeader
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final kept = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // Element 0 is the remainder of the header line itself, and is empty: the
    // caller's header regex ends its match at a line end, so nothing of that
    // line survives into the substring. Drop it rather than treat it as a body
    // line — but only when it is in fact empty, so a body handed over directly
    // (no leading line break) is bounded instead of losing its first line,
    // which would usually be the sub-key the caller is about to search for.
    if (i == 0 && line.isEmpty) continue;
    if (line.isEmpty) {
      kept.add(line);
      continue;
    }
    final first = line.codeUnitAt(0);
    final startsIndented = first == 0x20 || first == 0x09; // space or tab
    if (!startsIndented && !line.startsWith('#')) break;
    kept.add(line);
  }
  return '\n${kept.join('\n')}';
}
