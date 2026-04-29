import * as vscode from 'vscode';

/** Memento-backed counters for rule-explain / suggestions related-rule usage (local only). */

const TELEMETRY_KEY = 'saropaLints.relatedRuleTelemetry.v1';

export type RelatedRuleTelemetryEvent =
  | 'ruleExplain.open'
  | 'ruleExplain.relatedClick'
  | 'ruleExplain.docClick'
  | 'suggestions.relatedRuleOpen';

export interface RelatedRuleTelemetry {
  track(event: RelatedRuleTelemetryEvent, properties?: Record<string, string>): void;
  snapshot(): TelemetryStore;
  reset(): void;
}

export interface TelemetryStore {
  counters: Record<string, number>;
  lastEventAt?: string;
  lastProperties?: Record<string, string>;
}

function readStore(state: vscode.Memento): TelemetryStore {
  return state.get<TelemetryStore>(TELEMETRY_KEY) ?? { counters: {} };
}

export function createRelatedRuleTelemetry(state: vscode.Memento): RelatedRuleTelemetry {
  return {
    track(event, properties = {}) {
      const prev = readStore(state);
      const counters = { ...prev.counters };
      counters[event] = (counters[event] ?? 0) + 1;

      const next: TelemetryStore = {
        counters,
        lastEventAt: new Date().toISOString(),
        lastProperties: properties,
      };
      void state.update(TELEMETRY_KEY, next);
    },
    snapshot() {
      return readStore(state);
    },
    reset() {
      void state.update(TELEMETRY_KEY, { counters: {} });
    },
  };
}
