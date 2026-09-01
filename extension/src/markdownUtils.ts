/**
 * Shared Markdown escaping and structured builder for vscode.MarkdownString.
 *
 * Use escapeMarkdown() for untrusted text that must render literally.
 * Use buildMarkdownString() for constructing complex tooltips with mixed
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
 *
 * Use this on any string that originates outside our own code — package
 * names, rule messages, user file paths, API responses.  Never on
 * structural Markdown you control (bold wrappers, table markup, links).
 */
export function escapeMarkdown(text: string): string {
  return text.replace(MD_SPECIAL, '\\$&');
}

/**
 * One segment of a structured MarkdownString.
 *
 * By default every segment is treated as untrusted and escaped.
 * Set `raw: true` ONLY for markup you wrote yourself — never for
 * values that come from package metadata, user files, or APIs.
 */
export interface MdSegment {
  /** The text content to render. */
  text: string;
  /**
   * Pass-through without escaping.  ONLY for trusted structural
   * Markdown (bold wrappers, table headers, separator lines).
   * Using raw:true on user-supplied text is a Markdown injection bug.
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
