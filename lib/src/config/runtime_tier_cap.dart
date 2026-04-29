/// Optional runtime cap on rule strictness (Discussion #61).
///
/// When active, rules above the cap are treated as disabled for execution and
/// for [SaropaLintRule.enabledRules] counts, even if `analysis_options.yaml`
/// lists them as enabled.
///
/// **Sources (precedence):** non-empty `SAROPA_TIER` environment variable wins;
/// otherwise `saropa_tier:` in `analysis_options_custom.yaml`; otherwise
/// `runtime_tier:` or `saropa_tier:` under `plugins.saropa_lints` in
/// `analysis_options.yaml`.
///
/// **Semantics:** Cumulative strictness — `recommended` runs essential and
/// recommended rules only. [RuleTier.stylistic] rules are not capped (they are
/// opt-in via config only).
library;

import 'dart:io' show File, Platform;

import 'package:saropa_lints/src/native/plugin_logger.dart' show PluginLogger;
import 'package:saropa_lints/src/saropa_lint_rule.dart'
    show RuleTier, SaropaLintRule;
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Rule tier for a name — mirrors [getTierFromSets] in `init/rule_metadata.dart`.
RuleTier _lookupRuleTier(String ruleName) {
  if (tiers.stylisticRules.contains(ruleName)) return RuleTier.stylistic;
  if (tiers.essentialRules.contains(ruleName)) return RuleTier.essential;
  if (tiers.pedanticOnlyRules.contains(ruleName)) return RuleTier.pedantic;
  if (tiers.comprehensiveOnlyRules.contains(ruleName)) {
    return RuleTier.comprehensive;
  }
  if (tiers.professionalOnlyRules.contains(ruleName)) {
    return RuleTier.professional;
  }
  if (tiers.recommendedOnlyRules.contains(ruleName)) {
    return RuleTier.recommended;
  }
  return RuleTier.professional;
}

/// Order for cumulative cap (lower = stricter band). Stylistic is excluded.
int _strictnessIndex(RuleTier tier) {
  return switch (tier) {
    RuleTier.essential => 0,
    RuleTier.recommended => 1,
    RuleTier.professional => 2,
    RuleTier.comprehensive => 3,
    RuleTier.pedantic => 4,
    RuleTier.stylistic => -1,
  };
}

RuleTier? _parseTierLabel(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  return switch (s) {
    'essential' => RuleTier.essential,
    'recommended' => RuleTier.recommended,
    'professional' => RuleTier.professional,
    'comprehensive' => RuleTier.comprehensive,
    'pedantic' => RuleTier.pedantic,
    _ => null,
  };
}

int _leadingSpaces(String value) {
  var count = 0;
  while (count < value.length && value.codeUnitAt(count) == 32) {
    count++;
  }
  return count;
}

String _stripYamlScalarQuotes(String raw) {
  if (raw.length < 2) return raw;
  final first = raw[0];
  final last = raw[raw.length - 1];
  if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
    return String.fromCharCodes(raw.codeUnits, 1, raw.length - 1);
  }
  return raw;
}

/// `saropa_tier: recommended` at top level of custom options.
String? parseSaropaTierFromCustomYaml(String? content) {
  if (content == null || content.isEmpty) return null;
  final m = RegExp(
    r'^saropa_tier:\s*([^\s#]+)\s*(?:#.*)?$',
    multiLine: true,
  ).firstMatch(content);
  final raw = m?.group(1)?.trim();
  if (raw == null || raw.isEmpty) return null;
  return _stripYamlScalarQuotes(raw).toLowerCase();
}

/// `runtime_tier` / `saropa_tier` under `plugins.saropa_lints`.
String? parseSaropaTierFromPluginBlock(String? content) {
  if (content == null || content.isEmpty) return null;
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimRight();
    if (!RegExp(r'^\s+saropa_lints:\s*(?:#.*)?$').hasMatch(trimmed)) continue;
    final baseIndent = _leadingSpaces(lines[i]);
    for (var j = i + 1; j < lines.length; j++) {
      final inner = lines[j];
      final t = inner.trimLeft();
      if (t.isEmpty || t.startsWith('#')) continue;
      final ind = _leadingSpaces(inner);
      if (ind <= baseIndent) break;
      final m = RegExp(
        r'^\s*(runtime_tier|saropa_tier):\s*([^\s#]+)',
      ).firstMatch(inner);
      if (m != null) {
        final v = m.group(2)?.trim();
        if (v == null || v.isEmpty) continue;
        return _stripYamlScalarQuotes(v).toLowerCase();
      }
    }
  }
  return null;
}

/// Reloads cap from [projectRoot] (both yaml files) and environment.
///
/// [environmentOverride] is for tests only; when null, uses
/// [Platform.environment] (so `SAROPA_TIER` is read from the real process).
void reloadRuntimeTierCapFromProject(
  String? projectRoot, [
  Map<String, String>? environmentOverride,
]) {
  RuntimeTierCap._reload(projectRoot, environmentOverride);
}

/// Mutable runtime tier cap state and rule checks.
abstract final class RuntimeTierCap {
  static RuleTier? _cap;
  static String? _capLabel;
  static final Map<String, bool> _allowedCache = {};

  static RuleTier? get activeCap => _cap;

  /// Human-readable label for reports (e.g. `recommended`, or null).
  static String? get activeCapLabel => _capLabel;

  static void _reload(
    String? projectRoot, [
    Map<String, String>? environmentOverride,
  ]) {
    _cap = null;
    _capLabel = null;
    _allowedCache.clear();

    final envMap = environmentOverride ?? Platform.environment;
    final envRaw = envMap['SAROPA_TIER']?.trim();
    RuleTier? resolved;
    String? source;

    if (envRaw != null && envRaw.isNotEmpty) {
      resolved = _parseTierLabel(envRaw);
      source = 'SAROPA_TIER';
      if (resolved == null) {
        PluginLogger.log(
          'Ignoring invalid SAROPA_TIER="$envRaw" '
          '(use essential, recommended, professional, comprehensive, pedantic).',
        );
      }
    }

    String? readFile(String name) {
      if (projectRoot == null || projectRoot.isEmpty) return null;
      try {
        final sep = Platform.pathSeparator;
        final path = '$projectRoot$sep$name';
        final f = File(path);
        if (!f.existsSync()) return null;
        return f.readAsStringSync();
      } on Object catch (e, st) {
        PluginLogger.log(
          'RuntimeTierCap: read $name failed',
          error: e,
          stackTrace: st,
        );
        return null;
      }
    }

    if (resolved == null) {
      final custom = readFile('analysis_options_custom.yaml');
      final fromCustom = _parseTierLabel(parseSaropaTierFromCustomYaml(custom));
      if (fromCustom != null) {
        resolved = fromCustom;
        source = 'analysis_options_custom.yaml saropa_tier';
      }
    }

    if (resolved == null) {
      final main = readFile('analysis_options.yaml');
      final fromPlugin = _parseTierLabel(parseSaropaTierFromPluginBlock(main));
      if (fromPlugin != null) {
        resolved = fromPlugin;
        source = 'analysis_options.yaml (plugins.saropa_lints)';
      }
    }

    if (resolved == null) return;

    final tier = resolved;
    _cap = tier;
    final label = switch (tier) {
      RuleTier.essential => 'essential',
      RuleTier.recommended => 'recommended',
      RuleTier.professional => 'professional',
      RuleTier.comprehensive => 'comprehensive',
      RuleTier.pedantic => 'pedantic',
      RuleTier.stylistic => 'stylistic',
    };
    _capLabel = label;
    final src = source ?? 'config';
    PluginLogger.log(
      'Runtime tier cap: $label (from $src) — rules above this '
      'strictness band are skipped.',
    );
  }

  /// Removes rules above the active cap from [enabled] (mutates copy).
  static void applyCapToEnabledRuleSet() {
    final enabled = SaropaLintRule.enabledRules;
    if (_cap == null || enabled == null || enabled.isEmpty) return;

    final before = enabled.length;
    final filtered = enabled.where(ruleAllowedByCap).toSet();
    SaropaLintRule.enabledRules = filtered.isEmpty ? null : filtered;
    final after = filtered.length;
    if (after != before) {
      PluginLogger.log(
        'Runtime tier cap applied: enabled rule count $before → $after.',
      );
    }
  }

  /// Intersection of [rules] with the active cap (no mutation of statics).
  static Set<String> filterRuleSet(Set<String> rules) {
    if (_cap == null || rules.isEmpty) return rules;
    return rules.where(ruleAllowedByCap).toSet();
  }

  /// Whether [ruleName] may run under the active cap.
  static bool ruleAllowedByCap(String ruleName) {
    if (_cap == null) return true;
    return _allowedCache.putIfAbsent(ruleName, () {
      final rt = _lookupRuleTier(ruleName);
      if (rt == RuleTier.stylistic) return true;
      final ri = _strictnessIndex(rt);
      final ci = _strictnessIndex(_cap!);
      if (ri < 0 || ci < 0) return true;
      return ri <= ci;
    });
  }
}
