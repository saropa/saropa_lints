/**
 * Guards the Phase 4 design requirement (PLAN_extension_ui_redesign.md §1 principle 4: "every
 * `analysis_options_custom.yaml` key... gets a visible surface") against silent regression: every
 * key in `customConfigYaml.ts`'s `CUSTOM_YAML_TOP_LEVEL_KEYS` — the single source of truth for
 * "which top-level custom-yaml keys does the extension know about" — must map, via
 * `rulePacksWebviewProvider.ts`'s `CONFIG_FILE_KEY_TO_CARD`, to a card id that is actually
 * rendered (`CONFIG_FILE_CARD_IDS`). A 9th key added to the array without also wiring a card
 * mapping fails THIS test instead of shipping with no UI, the exact failure mode Phase 4 exists
 * to close off.
 */
import * as assert from 'assert';
import { CUSTOM_YAML_TOP_LEVEL_KEYS } from '../../rulePacks/customConfigYaml';
import {
  CONFIG_FILE_CARD_IDS,
  CONFIG_FILE_KEY_TO_CARD,
} from '../../rulePacks/rulePacksWebviewProvider';

describe('Config file tab coverage guard', () => {
  it('maps every CUSTOM_YAML_TOP_LEVEL_KEYS entry to a rendered card id', () => {
    for (const key of CUSTOM_YAML_TOP_LEVEL_KEYS) {
      const cardId = CONFIG_FILE_KEY_TO_CARD[key];
      assert.ok(
        cardId !== undefined,
        `analysis_options_custom.yaml key "${key}" has no entry in CONFIG_FILE_KEY_TO_CARD — ` +
          'add one mapping it to an existing (or new) Config file tab card.',
      );
      assert.ok(
        (CONFIG_FILE_CARD_IDS as readonly string[]).includes(cardId),
        `CONFIG_FILE_KEY_TO_CARD["${key}"] = "${cardId}", but that id is not in CONFIG_FILE_CARD_IDS ` +
          '— the card it points to is not actually rendered by _buildConfigFileTab.',
      );
    }
  });

  it('has no CONFIG_FILE_KEY_TO_CARD entries for keys no longer in CUSTOM_YAML_TOP_LEVEL_KEYS', () => {
    // Guards the inverse drift direction: a key removed from the yaml module should also have its
    // mapping removed, so the mapping never silently outlives the key it describes.
    const known = new Set<string>(CUSTOM_YAML_TOP_LEVEL_KEYS);
    for (const key of Object.keys(CONFIG_FILE_KEY_TO_CARD)) {
      assert.ok(known.has(key), `CONFIG_FILE_KEY_TO_CARD has a stale entry for "${key}", which is no longer in CUSTOM_YAML_TOP_LEVEL_KEYS.`);
    }
  });

  it('every rendered card id is reachable from at least one yaml key', () => {
    // A card id that maps from nothing is dead code the coverage guard should also catch.
    const reachable = new Set(Object.values(CONFIG_FILE_KEY_TO_CARD));
    for (const id of CONFIG_FILE_CARD_IDS) {
      assert.ok(reachable.has(id), `Card id "${id}" is in CONFIG_FILE_CARD_IDS but no CUSTOM_YAML_TOP_LEVEL_KEYS entry maps to it.`);
    }
  });
});
