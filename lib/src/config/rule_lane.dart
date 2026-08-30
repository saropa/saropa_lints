/// Two-lane execution split: which rules may run **in-process** (inside the
/// Dart analysis server) versus which are left to the out-of-process scan
/// daemon.
///
/// **Why this exists.** The in-process choice used to be binary and both ends
/// were bad: with the plugin OFF (today's default) the editor shows no
/// in-editor squiggles at all, and with it fully ON the analysis server was measured at
/// 7.8–13.6 GB RSS on a ~3,900-file project (vs ~3 GB with no plugin) and OOM
/// crashed. The cause is not rule count per se — it is that any rule touching
/// resolved types forces the analyzer's *lazy cross-library* element
/// resolution, and the analyzer then retains that model for the whole project.
/// See `plans/PLAN_scan_only_diagnostics.md` for the measurement table and
/// `plans/PLAN_two_lane_daemon_architecture.md` for this design.
///
/// **The light lane** is the missing middle configuration: run only rules that
/// are severe enough to be worth an in-editor squiggle AND cheap enough AND — the
/// load-bearing part — never touch the element model, so they cannot trigger
/// the cross-library cascade that costs the gigabytes. Everything else is
/// delivered on save by the scan daemon, exactly as it is today.
///
/// **Membership is derived, never hand-listed.** [isLightLaneRule] is the
/// single source of truth and is evaluated against real rule instances during
/// the registry build (see `_buildRuleFactoriesMap` in `lib/saropa_lints.dart`),
/// which already instantiates every rule to harvest its name — so lane
/// membership costs nothing extra and can never drift from the rules that
/// actually ship. Both the in-process gate and the daemon's de-duplication
/// exclusion read the same computed set.
library;

import 'package:analyzer/error/error.dart' show DiagnosticSeverity;

import 'package:saropa_lints/src/native/plugin_logger.dart' show PluginLogger;
// RuleCost is declared in a part of saropa_lint_rule.dart, so it must be
// imported through the owning library, not the part file.
import 'package:saropa_lints/src/saropa_lint_rule.dart'
    show RuleCost, SaropaLintRule;

/// Which execution lane the in-process plugin is configured to run.
enum RuleLane {
  /// Only [isLightLaneRule] rules run in-process; the rest are the scan
  /// daemon's job. In-editor squiggles for severe issues at near-baseline
  /// memory. The default when no `lane:` key is configured — RSS-measured at
  /// +0.6% over the plugin-off baseline (vs +77.2% for [full]) on a
  /// ~3,900-file project, see `plans/PLAN_two_lane_daemon_architecture.md`
  /// acceptance criterion 1 for the measurement.
  light,

  /// Every enabled rule runs in-process — the historical behavior, still
  /// available via an explicit `lane: full`. Retained for anyone who
  /// deliberately wants full in-process coverage and has verified their
  /// project's memory footprint at that cost.
  full,
}

/// Config key name — used in warning messages. Parsed as a top-level key
/// in `analysis_options_custom.yaml` by `_parseTopLevelScalar` in
/// `config_loader.dart`.
const String kLaneConfigKey = 'lane';

/// Highest [RuleCost] admitted to the light lane.
///
/// Deliberately conservative: `trivial` and `low` only (~200 rules). The
/// `medium` band would roughly double the lane (~415 rules) and is an
/// explicit follow-up decision to be made only AFTER the memory acceptance
/// criterion passes at this size — widening first would confound the
/// measurement that tells us whether the lane works at all.
final Set<RuleCost> kLightLaneCosts = <RuleCost>{
  RuleCost.trivial,
  RuleCost.low,
};

/// Severities admitted to the light lane.
///
/// INFO-level findings are the bulk of the catalog and the least urgent; they
/// are exactly what "arrives a few seconds later, on save" suits. Reserving
/// the in-process budget for errors and warnings is what keeps the lane small.
/// Not `const`: [DiagnosticSeverity] overrides `==`, which Dart forbids in a
/// constant set literal.
final Set<DiagnosticSeverity> kLightLaneSeverities = <DiagnosticSeverity>{
  DiagnosticSeverity.ERROR,
  DiagnosticSeverity.WARNING,
};

/// Whether [rule] belongs to the light (in-process) lane.
///
/// Three conditions, all required:
///
/// 1. **Severity** is ERROR or WARNING ([kLightLaneSeverities]). Uses the
///    rule's *declared* `code.severity`, NOT [SaropaLintRule.effectiveSeverity]
///    — lane membership must be a stable property of the rule itself. If it
///    honored user severity overrides, a consumer bumping one INFO rule to
///    WARNING would silently pull it into the in-process lane and change the
///    memory profile the lane exists to protect.
/// 2. **Cost** is trivial or low ([kLightLaneCosts]).
/// 3. **Does not use type resolution** — the memory-critical condition.
///
/// Condition 3 rests on the rule's own [SaropaLintRule.usesTypeResolution]
/// declaration, which defaults to `false` and is not enforced by the compiler.
/// A rule that touches the element model while declaring `false` would defeat
/// the entire lane, so that declaration is audited against actual element-API
/// usage by `test/integrity/rule_lane_test.dart`. A mis-declaration found
/// there is a defect in the RULE (fix the override), never a reason to special
/// -case it here.
bool isLightLaneRule(SaropaLintRule rule) {
  if (rule.usesTypeResolution) return false;
  if (!kLightLaneSeverities.contains(rule.code.severity)) return false;

  return kLightLaneCosts.contains(rule.cost);
}

/// Names of every rule satisfying [isLightLaneRule], published once by the
/// registry build. Empty until then — see [setLightLaneRuleNames].
Set<String> _lightLaneRuleNames = const <String>{};

/// The active lane. Defaults to [RuleLane.light] — see [RuleLane.light] for
/// the RSS measurement backing this default.
RuleLane _activeLane = RuleLane.light;

/// Read-only view of the computed light-lane membership.
Set<String> get lightLaneRuleNames => _lightLaneRuleNames;

/// The lane currently in force.
RuleLane get activeRuleLane => _activeLane;

/// Publishes the computed light-lane membership.
///
/// Called from the lazy registry build in `lib/saropa_lints.dart`, which is
/// the one place where every rule is instantiated and its metadata is already
/// being read — so this adds no instantiation cost. Both the plugin path and
/// the scan CLI path flow through that build, so both see the same set.
void setLightLaneRuleNames(Set<String> names) {
  _lightLaneRuleNames = Set<String>.unmodifiable(names);
}

/// Sets the active lane from parsed configuration.
///
/// Separate from the yaml parsing so tests can drive lane behavior directly
/// without writing config files.
void setActiveRuleLane(RuleLane lane) {
  _activeLane = lane;
}

/// Parses a `lane:` config value.
///
/// Absent/empty (the key was never written, e.g. an uncommented `plugins:`
/// block with no explicit `lane:`) falls back to [RuleLane.light] — the
/// RSS-measured default, see [RuleLane.light]. An unrecognized non-empty
/// value (a typo) falls back to [RuleLane.full] instead: that is the more
/// conservative read of a value that was clearly meant to say *something*,
/// and matches the historical, fully-covered behavior rather than silently
/// narrowing coverage on a typo.
RuleLane parseRuleLane(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return RuleLane.light;
  if (value == 'light') return RuleLane.light;
  if (value == 'full') return RuleLane.full;

  PluginLogger.log(
    'Unknown `$kLaneConfigKey: $raw` in analysis_options_custom.yaml — expected '
    '"light" or "full". Falling back to "full" (all enabled rules run '
    'in-process).',
  );

  return RuleLane.full;
}

/// Whether a rule may execute in the current lane.
///
/// The per-node gate. Mirrors `RuntimeTierCap.ruleAllowedByCap`: a plain set
/// lookup, cheap enough for the `_wrapCallback` hot path, and returning `true`
/// unconditionally in [RuleLane.full] so the historical path pays nothing but
/// one enum comparison.
///
/// Fails **open** when membership has not been published yet
/// ([_lightLaneRuleNames] still empty): a lane that silenced every rule
/// because a set was not populated in time would repeat the register-time
/// gating incident that killed all rules for file-picker users.
bool ruleAllowedByLane(String ruleName) {
  if (_activeLane == RuleLane.full) return true;
  if (_lightLaneRuleNames.isEmpty) return true;

  return _lightLaneRuleNames.contains(ruleName);
}

/// Restricts [enabled] to the active lane.
///
/// Applied once at config-load time, after the tier cap, so that reported
/// rule counts and the report header's CONFIGURATION block reflect what will
/// actually run rather than what was requested. Returns [enabled] untouched in
/// [RuleLane.full] or before membership is known.
Set<String> applyLaneToEnabledRuleSet(Set<String> enabled) {
  if (_activeLane == RuleLane.full) return enabled;
  if (_lightLaneRuleNames.isEmpty) return enabled;

  final filtered = enabled.where(_lightLaneRuleNames.contains).toSet();
  if (filtered.length != enabled.length) {
    PluginLogger.log(
      'Light lane applied: enabled rule count ${enabled.length} → '
      '${filtered.length}. The remaining rules still run on save via the '
      'saropa_lints scan daemon.',
    );
  }

  return filtered;
}

/// Removes light-lane rules from [ruleNames].
///
/// The de-duplication half of the split: when the plugin is running the light
/// lane in-process, the daemon must NOT also report those findings or every
/// severe issue would appear twice in the Problems panel (once as an analyzer
/// diagnostic, once from the extension's own `DiagnosticCollection`).
Set<String> excludeLightLaneRules(Set<String> ruleNames) {
  if (_lightLaneRuleNames.isEmpty) return ruleNames;

  return ruleNames.where((name) => !_lightLaneRuleNames.contains(name)).toSet();
}

/// Resets the active lane to the default. Test-only hook — the statics are
/// process-global, so a test that sets a lane would otherwise leak into the
/// next one.
///
/// Deliberately does NOT clear [_lightLaneRuleNames]. Membership is derived
/// from the rule registry, which is a lazy `final` that initializes exactly
/// once per process — clearing it would be unrecoverable for every later test
/// in the same file, and it is not per-test state in the first place. A test
/// that needs empty membership sets it explicitly via [setLightLaneRuleNames]
/// and restores it afterwards.
void resetRuleLaneForTest() {
  _activeLane = RuleLane.light;
}
