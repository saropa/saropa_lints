# Cross-file CLI: CI example (GitHub Actions)

Use the cross-file CLI in CI to fail the job when unused files or circular dependencies are found. The CLI exits **0** when there are no issues, **1** when issues are found, and **2** on configuration error — so no extra flag is needed.

## Example workflow

Copy the job below into your `.github/workflows/` (e.g. `cross-file.yml`) and adjust `--path` if your Dart code is not at the repo root.

```yaml
name: Cross-file analysis

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  cross-file:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - name: Install dependencies
        run: dart pub get
      - name: Check unused files and circular deps
        run: dart run saropa_lints:cross_file unused-files
      - name: Check circular dependencies
        run: dart run saropa_lints:cross_file circular-deps
```

- If there are no unused files and no circular imports, both steps exit 0 and the job passes.
- If any are found, the step exits 1 and the job fails.

## Optional: JSON output

Add the following steps to the same job if you want to capture the report as JSON:

```yaml
      - name: Cross-file analysis (JSON)
        run: dart run saropa_lints:cross_file unused-files --output json > cross_file_report.json
      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: cross-file-report
          path: cross_file_report.json
```

## Options

| Option    | Description |
|----------|-------------|
| `--path` | Project directory (default: current). Set to e.g. `./my_package` for monorepos. |
| `--output` | `text` (default) or `json`. |
| `--exclude` | Reserved for future use (repeatable). |

Exit codes: **0** = no issues, **1** = issues found, **2** = configuration error.
