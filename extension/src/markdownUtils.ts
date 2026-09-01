/**
 * Shared Markdown escaping and structured builder for vscode.MarkdownString.
 *
 * Use escapeMarkdown() for untrusted text that must render literally.
 * Use MarkdownBuilder for constructing complex tooltips with mixed
 * safe-markup and untrusted-text segments.
 */

import * as vscode from 'vscode';

/**
 * Characters that have special meaning in CommonMark and must be
 * backslash-escaped when rendering untrusted text literally.
 */
const MD_SPECIAL = /[\\`*_{}[\]()#+\-.!|~]/g;

/**
 * Escape all Markdown special characters so untrusted text renders as
 * literal content inside a vscode.MarkdownString.  Covers: \ ` * _ { }
 * [ ] ( ) # + - . ! | ~
 */
export function escapeMarkdown(text: string): string {
  return text.replace(MD_SPECIAL, '\\$&');
}

/** One segment of a structured MarkdownString. */
export interface MdSegment {
  /** The text content to render. */
  text: string;
  /**
   * Whether the text is raw (trusted) Markdown or should be escaped.
   * Default false = the text is untrusted and will be escaped.
   */
  raw?: boolean;
  /** Wrap the (escaped) text in backtick code spans. */
  code?: boolean;
  /** Wrap the (escaped) text in bold markers. */
  bold?: boolean;
}

/**
 * Build a vscode.MarkdownString from mixed safe/unsafe segments.
 * Eliminates the error-prone manual dance of knowing which parts to
 * escape and which to leave as markup.
 *
 * Example:
 *   buildMarkdownString([
 *     { text: '**Rule:** ', raw: true },
 *     { text: ruleName, code: true },
 *   ])
 */
export function buildMarkdownString(segments: MdSegment[]): vscode.MarkdownString {
  const md = new vscode.MarkdownString();
  for (const seg of segments) {
    // Raw segments pass through as trusted Markdown
    if (seg.raw) {
      md.appendMarkdown(seg.text);
      continue;
    }
    // Untrusted segments get escaped, then optionally wrapped
    let escaped = escapeMarkdown(seg.text);
    if (seg.code) { escaped = '`' + escaped + '`'; }
    if (seg.bold) { escaped = '**' + escaped + '**'; }
    md.appendMarkdown(escaped);
  }
  return md;
}
