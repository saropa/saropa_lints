import 'package:saropa_lints/src/config/yaml_section_block.dart';
import 'package:test/test.dart';

/// Unit tests for [yamlSectionBlock], the bound shared by the line-based
/// `analysis_options_custom.yaml` section parsers.
void main() {
  group('yamlSectionBlock', () {
    test('keeps the indented body of the section', () {
      expect(
        yamlSectionBlock('\n  entries:\n    - identifier: a\n'),
        '\n  entries:\n    - identifier: a\n',
      );
    });

    test('stops at the next top-level key', () {
      expect(
        yamlSectionBlock('\n  entries:\n    - a\nother_rule:\n    - b\n'),
        '\n  entries:\n    - a',
      );
    });

    test('keeps blank lines and column-0 comments inside the block', () {
      expect(
        yamlSectionBlock('\n  entries:\n\n# note\n    - a\nother_rule:\n'),
        '\n  entries:\n\n# note\n    - a',
      );
    });

    test('treats a tab-indented line as part of the block', () {
      expect(yamlSectionBlock('\n\tentries:\nother_rule:\n'), '\n\tentries:');
    });

    test('empty body yields a bare line start', () {
      expect(yamlSectionBlock(''), '\n');
      expect(yamlSectionBlock('\nother_rule:\n'), '\n');
    });

    test('a CRLF blank line does not end the block', () {
      // Regression: `split('\n')` leaves a bare `\r` for a blank line in a
      // Windows-authored file. It is not empty, not indented and not a
      // comment, so an un-normalised loop breaks here and truncates the
      // section.
      expect(
        yamlSectionBlock('\r\n  entries:\r\n\r\n    - a\r\nother_rule:\r\n'),
        '\n  entries:\n\n    - a',
      );
    });

    test('CRLF input is normalised to LF in the result', () {
      expect(yamlSectionBlock('\r\n  entries:\r\n'), '\n  entries:\n');
    });

    test('a lone-CR blank line does not end the block', () {
      expect(
        yamlSectionBlock('\r  entries:\r\r    - a\rother_rule:\r'),
        '\n  entries:\n\n    - a',
      );
    });

    test('a list item starting in column 0 ends the block', () {
      // A `- item` at column 0 is a sibling of the section header, not part
      // of its indented body.
      expect(yamlSectionBlock('\n  entries:\n- a\n'), '\n  entries:');
    });
  });
}
