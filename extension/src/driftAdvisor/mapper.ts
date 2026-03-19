/**
 * Map Drift Advisor table/column to Dart file and line for editor navigation.
 *
 * Heuristics: table names (snake_case) are converted to Dart class names (PascalCase);
 * column names to getter names (camelCase). We search workspace Dart files for
 * "class TableName extends Table" (or WithClassName<TableName>) and for "get columnName =>"
 * or "get columnName()". First match wins; no ambiguity resolution. Performance:
 * findDartFiles() is called once per mapIssuesToLocations() and table locations are
 * cached per table name. Large workspaces may hit findFiles limit (8000); consider
 * excluding build/ in future if needed.
 */

import * as vscode from 'vscode';
import type { DriftIssueRaw, DriftIssueMapped } from './types';

/** snake_case → PascalCase (e.g. users → Users, user_tasks → UserTasks). */
function toPascalCase(s: string): string {
  return s
    .split('_')
    .map((part) => (part.length > 0 ? part[0].toUpperCase() + part.slice(1).toLowerCase() : ''))
    .join('');
}

/** snake_case → camelCase (e.g. user_id → userId). */
function toCamelCase(s: string): string {
  const pascal = toPascalCase(s);
  return pascal.length > 0 ? pascal[0].toLowerCase() + pascal.slice(1) : s;
}

/** Find Dart files under workspace that might define Drift tables. Excludes build/. */
async function findDartFiles(): Promise<vscode.Uri[]> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) return [];
  const out: vscode.Uri[] = [];
  for (const folder of folders) {
    const uris = await vscode.workspace.findFiles(
      new vscode.RelativePattern(folder, '**/*.dart'),
      '**/build/**',
      8000,
    );
    out.push(...uris);
  }
  return out;
}

/** Regex to find class Foo extends Table (or WithClassName<Foo>, etc.). */
function tableClassRegex(className: string): RegExp {
  const escaped = className.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(
    `\\bclass\\s+${escaped}\\s+extends\\s+(?:Table|\\w+\\s*<\\s*${escaped}\\s*>)`,
    'm',
  );
}

/** Regex to find getter for column (get columnName => or get columnName()). */
function columnGetterRegex(columnNameCamel: string): RegExp {
  const escaped = columnNameCamel.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`\\bget\\s+${escaped}\\s*[=(]`, 'm');
}

/** Find line number (0-based) of first match of regex in text. */
function lineOfMatch(text: string, re: RegExp): number | undefined {
  const m = text.match(re);
  if (!m || m.index === undefined) return undefined;
  let line = 0;
  for (let i = 0; i < m.index && i < text.length; i++) {
    if (text[i] === '\n') line++;
  }
  return line;
}

/**
 * Resolve table name to a Dart file and line (class declaration).
 * When files is provided, uses that list instead of calling findDartFiles() (avoids repeated scans).
 */
async function resolveTableToLocation(
  tableName: string,
  files?: vscode.Uri[],
): Promise<{ uri: vscode.Uri; line: number } | undefined> {
  const className = toPascalCase(tableName);
  const re = tableClassRegex(className);
  const fileList = files ?? (await findDartFiles());
  for (const uri of fileList) {
    try {
      const doc = await vscode.workspace.openTextDocument(uri);
      const line = lineOfMatch(doc.getText(), re);
      if (line !== undefined) return { uri, line };
    } catch {
      // skip unreadable
    }
  }
  return undefined;
}

/**
 * Given a file and line of a table class, find the line of a column getter (optional).
 * If column is null, returns the table class line.
 */
function resolveColumnInDocument(
  doc: vscode.TextDocument,
  columnName: string | null,
  tableLine: number,
): number | undefined {
  if (!columnName || columnName.trim() === '') return tableLine;
  const camel = toCamelCase(columnName.trim());
  const re = columnGetterRegex(camel);
  const text = doc.getText();
  const line = lineOfMatch(text, re);
  return line ?? tableLine;
}

/**
 * Map a single raw issue to file/line when possible. Delegates to mapIssuesToLocations.
 */
export async function mapIssueToLocation(issue: DriftIssueRaw): Promise<DriftIssueMapped> {
  const mapped = await mapIssuesToLocations([issue]);
  return mapped[0] ?? { ...issue };
}

/**
 * Map all issues to locations. Resolves findDartFiles() once and caches table→location
 * so multiple issues for the same table do not re-scan files.
 */
export async function mapIssuesToLocations(issues: DriftIssueRaw[]): Promise<DriftIssueMapped[]> {
  const files = await findDartFiles();
  const tableCache = new Map<string, { uri: vscode.Uri; line: number } | undefined>();
  const resolveTable = async (table: string) => {
    if (!tableCache.has(table)) {
      tableCache.set(table, await resolveTableToLocation(table, files));
    }
    return tableCache.get(table);
  };

  const result: DriftIssueMapped[] = [];
  for (const issue of issues) {
    const loc = await resolveTable(issue.table);
    const mapped: DriftIssueMapped = { ...issue };
    if (loc) {
      mapped.uri = { fsPath: loc.uri.fsPath };
      mapped.line = loc.line;
      if (issue.column) {
        try {
          const doc = await vscode.workspace.openTextDocument(loc.uri);
          const columnLine = resolveColumnInDocument(doc, issue.column, loc.line);
          if (columnLine !== undefined) mapped.line = columnLine;
        } catch {
          // keep table line
        }
      }
    }
    result.push(mapped);
  }
  return result;
}
