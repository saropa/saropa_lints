# GitHub Issue Form Templates

The project had a detailed issue-reporting guide (`bugs/ISSUE_REPORT_GUIDE.md`) but no mechanism to enforce its structure when someone opened a GitHub issue. Reporters could file blank issues that omitted attribution evidence, reproducers, or severity classification.

## Finish Report (2026-09-02)

### What changed

Three files added under `.github/ISSUE_TEMPLATE/`:

| File | Purpose |
|------|---------|
| `bug_report.yml` | YAML issue form mirroring the Bug Report Template — required fields for severity, rule name, rule source file, attribution grep evidence, reproducer (Dart-rendered code block), frequency, expected-vs-actual, and environment. Optional fields for AST context, root cause hypothesis, and suggested fix. |
| `feature_request.yml` | YAML issue form mirroring the Feature Request Template — required fields for request type, summary, motivation, bad/good code examples (Dart-rendered), and proposed tier. Optional fields for related rules, tier justification, edge cases, and alternatives. |
| `config.yml` | Disables blank issues (`blank_issues_enabled: false`) and adds a contact link to the full guide. |

### Design decisions

- **YAML forms over Markdown templates.** YAML issue forms render as structured input fields with dropdowns, required-field validation, and syntax-highlighted code blocks. Markdown templates are just pre-filled text that reporters can (and do) delete.
- **Required fields match the guide's "must-have" sections.** Attribution evidence, reproducer, and environment are required for bugs. Summary, motivation, and code examples are required for feature requests. Optional sections (AST context, root cause, alternatives) remain optional — they are investigation aids, not filing requirements.
- **Dart-rendered code blocks.** Reproducer and bad/good code fields use `render: dart` for syntax highlighting in the filed issue.
- **Blank issues disabled.** Forces all issues through one of the two templates. A contact link to the full guide is shown below the template chooser.
