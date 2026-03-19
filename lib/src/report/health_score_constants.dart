// Copyright (c) 2025 Saropa Pty Limited. All rights reserved.

/// Canonical health score constants used by the violation export and the VS Code extension.
///
/// The extension's [healthScore.ts] must keep the same values so that
/// [getHealthScoreParams()] and [consumer_contract.json] match.
///
/// Formula: score = 100 * exp(-density * decayRate), where density is
/// weighted violations per file and weights are applied per impact level.
library;

/// Impact-level weights for the health score (critical: 8, high: 3, medium: 1, low: 0.25, opinionated: 0.05).
const Map<String, double> healthScoreImpactWeights = <String, double>{
  'critical': 8,
  'high': 3,
  'medium': 1,
  'low': 0.25,
  'opinionated': 0.05,
};

/// Decay rate for the health score formula (higher = harsher drop as density increases).
const double healthScoreDecayRate = 0.3;
