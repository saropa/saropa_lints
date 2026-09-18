/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Vibrancy UI experiment: scoring, providers, and webview assets. */
import { CiThresholds, CiPlatform } from '../types';

// Stubs for GitHub Actions, GitLab CI, and shell from vibrancy thresholds.
/** Generate CI workflow content for the specified platform. */
export function generateCiWorkflow(
    platform: CiPlatform,
    thresholds: CiThresholds,
): string {
    switch (platform) {
        case 'github-actions':
            return generateGitHubActions(thresholds);
        case 'gitlab-ci':
            return generateGitLabCi(thresholds);
        case 'shell-script':
            return generateShellScript(thresholds);
    }
}

/** Get the default output path for a CI platform. */
export function getDefaultOutputPath(platform: CiPlatform): string {
    switch (platform) {
        case 'github-actions':
            return '.github/workflows/vibrancy-check.yml';
        case 'gitlab-ci':
            return '.gitlab-ci-vibrancy.yml';
        case 'shell-script':
            return 'scripts/vibrancy-check.sh';
    }
}

/**
 * The Dart program every platform runs. One source, so the three generated
 * pipelines cannot drift apart, and so a test can run it with `dart` against
 * real `pub outdated --json` output.
 *
 * Arguments: the `pub outdated --json` file, then optionally a path to write
 * a summary JSON to (the GitHub pull request comment reads it).
 *
 * What it counts, and why:
 * - Outdated = a direct or dev dependency whose `latest` is newer than its
 *   `current`. Transitive packages are left out: they are pinned by the
 *   packages that use them (under Flutter, often by the SDK), so a project
 *   cannot upgrade them and would fail on a threshold it cannot meet. This
 *   is the same measure `suggestThresholds` suggests `maxOutdated` from.
 * - Vulnerable = `isCurrentAffectedByAdvisory`, which `pub outdated` reports
 *   from pub.dev's security advisories. `failOnVulnerability` fails on it.
 * - Abandonment, end-of-life and vibrancy scores come from pub.dev and GitHub
 *   data that `pub outdated` does not carry, so those thresholds are stated
 *   as not enforced rather than faked.
 */
export function buildCheckerScript(thresholds: CiThresholds): string {
    return `import 'dart:convert';
import 'dart:io';

const maxAbandoned = ${thresholds.maxAbandoned};
const maxEol = ${thresholds.maxEndOfLife};
const maxOutdated = ${thresholds.maxOutdated};
const minAvgVibrancy = ${thresholds.minAverageVibrancy};
const failOnVuln = ${thresholds.failOnVulnerability ? 'true' : 'false'};

/// Numeric major.minor.patch; on a tie a release sorts after its pre-releases.
int compareVersions(String a, String b) {
  List<int> core(String v) =>
      v.split(RegExp(r'[-+]'))[0].split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = core(a);
  final y = core(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  final aPre = a.contains('-');
  final bPre = b.contains('-');
  if (aPre == bPre) return 0;
  return aPre ? -1 : 1;
}

/// A breaking update: a new major, or for 0.x a new minor.
bool isBreaking(String current, String latest) {
  int part(String v, int i) {
    final parts = v.split(RegExp(r'[-+]'))[0].split('.');
    return i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0;
  }
  if (part(latest, 0) != part(current, 0)) return true;
  return part(current, 0) == 0 && part(latest, 1) != part(current, 1);
}

String? versionOf(Object? entry) => entry is Map ? entry['version'] as String? : null;

void main(List<String> args) {
  final json = jsonDecode(File(args.isNotEmpty ? args[0] : 'outdated.json').readAsStringSync());
  final packages = (json is Map ? json['packages'] as List? : null) ?? const [];

  final outdated = <String>[];
  var breaking = 0;
  final vulnerable = <String>[];
  final discontinued = <String>[];
  for (final pkg in packages) {
    if (pkg is! Map) continue;
    final kind = pkg['kind'];
    if (kind != 'direct' && kind != 'dev') continue;
    final name = '\${pkg['package']}';
    if (pkg['isCurrentAffectedByAdvisory'] == true) vulnerable.add(name);
    if (pkg['isDiscontinued'] == true) discontinued.add(name);
    final current = versionOf(pkg['current']);
    final latest = versionOf(pkg['latest']);
    if (current != null && latest != null && compareVersions(latest, current) > 0) {
      outdated.add('\$name: \$current → \$latest');
      if (isBreaking(current, latest)) breaking++;
    }
  }

  print('📊 Dependency Health Summary (direct and dev dependencies)');
  print('   Outdated: \${outdated.length} (max \$maxOutdated), breaking updates: \$breaking');
  for (final line in outdated) {
    print('     - \$line');
  }

  var failed = false;
  if (outdated.length > maxOutdated) {
    print('❌ FAIL: \${outdated.length} outdated dependencies exceed the maximum of \$maxOutdated.');
    failed = true;
  } else {
    print('✅ Outdated dependencies are within the threshold.');
  }

  if (vulnerable.isNotEmpty) {
    final names = vulnerable.join(', ');
    if (failOnVuln) {
      print('❌ FAIL: affected by a security advisory: \$names');
      failed = true;
    } else {
      print('⚠️  Affected by a security advisory: \$names');
    }
  } else {
    print('✅ No dependency is affected by a known security advisory.');
  }

  if (discontinued.isNotEmpty) {
    print('ℹ️  Discontinued on pub.dev: \${discontinued.join(', ')}');
  }

  print('ℹ️  Max Abandoned (\$maxAbandoned), Max EOL (\$maxEol) and Min Avg Vibrancy (\$minAvgVibrancy) are scored from pub.dev and GitHub data that pub outdated does not carry, so this check does not enforce them.');

  if (args.length > 1) {
    File(args[1]).writeAsStringSync(jsonEncode({
      'outdated': outdated.length,
      'maxOutdated': maxOutdated,
      'vulnerable': vulnerable,
      'failOnVulnerability': failOnVuln,
      'discontinued': discontinued,
      'failed': failed,
    }));
  }
  exit(failed ? 1 : 0);
}
`;
}

/** `text` with every non-empty line indented by `spaces`. */
function indent(text: string, spaces: number): string {
    const pad = ' '.repeat(spaces);
    return text.split('\n').map((line) => (line ? pad + line : line)).join('\n');
}

/** Generate a GitHub Actions workflow. */
export function generateGitHubActions(thresholds: CiThresholds): string {
    return `# Generated by Package Vibrancy
# Checks dependency health on PRs that modify pubspec files

name: Dependency Health Check

on:
  pull_request:
    paths:
      - 'pubspec.yaml'
      - 'pubspec.lock'

jobs:
  vibrancy-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install dependencies
        run: flutter pub get

      - name: Check dependency health
        id: health-check
        run: |
          flutter pub outdated --json > outdated.json

          # Write the checker to a real file: \`dart run\` cannot read a
          # program from stdin, so a heredoc piped into it silently no-ops.
          cat > vibrancy_check.dart <<'DART_SCRIPT'
${indent(buildCheckerScript(thresholds).trimEnd(), 10)}
          DART_SCRIPT

          dart run vibrancy_check.dart outdated.json vibrancy_summary.json

      - name: Upload dependency report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: dependency-report
          path: |
            outdated.json
            vibrancy_summary.json
          retention-days: 7

      - name: Comment on PR
        if: always() && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');

            let report = '## 📊 Dependency Health Check\\n\\n';

            try {
              // Written by the checker, so the comment reports exactly the
              // verdict the job reached, not a second opinion.
              const s = JSON.parse(fs.readFileSync('vibrancy_summary.json', 'utf8'));
              const mark = (ok) => (ok ? '✅' : '❌');
              report += '| Check | Value | Threshold | Status |\\n';
              report += '|-------|-------|-----------|--------|\\n';
              report += \`| Outdated (direct + dev) | \${s.outdated} | ≤ \${s.maxOutdated} | \${mark(s.outdated <= s.maxOutdated)} |\\n\`;
              report += \`| Security advisories | \${s.vulnerable.length} | \${s.failOnVulnerability ? '0' : 'reported only'} | \${s.failOnVulnerability ? mark(s.vulnerable.length === 0) : 'ℹ️'} |\\n\`;
              report += '| Abandoned, EOL, Avg Vibrancy | — | not enforced | ℹ️ |\\n';
              if (s.vulnerable.length) report += \`\\nAffected by an advisory: \${s.vulnerable.join(', ')}\\n\`;
              report += '\\n*Abandonment, end-of-life and vibrancy scores need full Package Vibrancy data, which pub outdated does not carry.*\\n';
            } catch (e) {
              report += 'The dependency check did not produce a summary. See the job log.\\n';
            }

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: report
            });
`;
}

/** Generate a GitLab CI job configuration. */
export function generateGitLabCi(thresholds: CiThresholds): string {
    return `# Generated by Package Vibrancy
# Add this to your .gitlab-ci.yml or include as a separate file

vibrancy-check:
  stage: test
  image: ghcr.io/cirruslabs/flutter:stable
  rules:
    - changes:
        - pubspec.yaml
        - pubspec.lock
  script:
    - flutter pub get
    - flutter pub outdated --json > outdated.json
    - |
      # Write the checker to a real file: \`dart run\` cannot read a program
      # from stdin, so a heredoc piped into it silently no-ops.
      cat > vibrancy_check.dart <<'DART_SCRIPT'
${indent(buildCheckerScript(thresholds).trimEnd(), 6)}
      DART_SCRIPT

      dart run vibrancy_check.dart outdated.json
  artifacts:
    paths:
      - outdated.json
    expire_in: 1 week
    when: always
`;
}

/** Generate a portable shell script for manual/custom CI. */
export function generateShellScript(thresholds: CiThresholds): string {
    return `#!/bin/bash
# Generated by Package Vibrancy
# Portable dependency health check script

set -e

echo "📊 Dependency Health Check"
echo "=========================="
echo ""

# Ensure Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found in PATH"
    exit 1
fi

# A private directory, not fixed /tmp paths: concurrent runs on one machine
# would overwrite each other's files, and a fixed path in a shared /tmp can
# be pre-created as a symlink by another user.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Installing dependencies..."
flutter pub get

echo "Checking for outdated packages..."
flutter pub outdated --json > "$work/outdated.json"

# \`dart run\` cannot read a program from stdin, so it must be written to a
# real file first — piping a heredoc into it silently does nothing.
cat > "$work/vibrancy_check.dart" <<'DART_SCRIPT'
${buildCheckerScript(thresholds)}DART_SCRIPT

# \`set -e\` means a failing check exits this script with the same code, so
# the caller sees the failure — nothing below runs unless the checks passed.
dart run "$work/vibrancy_check.dart" "$work/outdated.json"

echo ""
echo "✅ Dependency check complete"
`;
}

/** Get platform display name for UI. */
export function getPlatformDisplayName(platform: CiPlatform): string {
    switch (platform) {
        case 'github-actions':
            return 'GitHub Actions';
        case 'gitlab-ci':
            return 'GitLab CI';
        case 'shell-script':
            return 'Shell Script (portable)';
    }
}

/** Get all available platforms for quick-pick. */
export function getAvailablePlatforms(): { id: CiPlatform; label: string; description: string }[] {
    return [
        {
            id: 'github-actions',
            label: '$(github) GitHub Actions',
            description: '.github/workflows/vibrancy-check.yml',
        },
        {
            id: 'gitlab-ci',
            label: '$(git-merge) GitLab CI',
            description: '.gitlab-ci-vibrancy.yml',
        },
        {
            id: 'shell-script',
            label: '$(terminal) Shell Script',
            description: 'scripts/vibrancy-check.sh (portable)',
        },
    ];
}
