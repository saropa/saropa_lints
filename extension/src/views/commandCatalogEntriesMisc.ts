/**
 * Command catalog entries: TODOs & Hacks, Drift Advisor, and views / navigation.
 *
 * Part of the command catalog registry, split out of commandCatalogRegistry.ts
 * so the large entry literal is not one 1300-line file. The registry composes
 * this array into `catalogEntries`. Each entry's `category` field (not its file
 * or array position) drives grouping in the catalog UI.
 */

import { CatalogEntry } from './commandCatalogTypes';

export const miscCatalogEntries: readonly CatalogEntry[] = [

  // ── TODOs & Hacks ────────────────────────────────────────────────────────

  {
    command: 'saropaLints.todosAndHacks.refresh',
    title: 'Refresh TODOs & Hacks',
    description: 'Re-scan the workspace for TODO, HACK, and FIXME comments.',
    category: 'TODOs & Hacks',
    icon: 'refresh',
  },
  {
    command: 'saropaLints.todosAndHacks.toggleGroupByTag',
    title: 'Toggle Group by Tag / Folder',
    description: 'Switch between grouping TODOs by tag type or by folder.',
    category: 'TODOs & Hacks',
    icon: 'list-tree',
  },
  {
    command: 'saropaLints.todosAndHacks.enableWorkspaceScan',
    title: 'Enable Workspace Scan',
    description: 'Enable workspace-wide scanning for TODO and HACK comments.',
    category: 'TODOs & Hacks',
    icon: 'search',
  },

  // ── Drift Advisor ────────────────────────────────────────────────────────

  {
    command: 'saropaLints.driftAdvisor.enableIntegration',
    title: 'Enable Drift Advisor',
    description: 'Turn on the Drift Advisor integration for this workspace.',
    category: 'Drift Advisor',
    icon: 'plug',
  },
  {
    command: 'saropaLints.driftAdvisor.disableIntegration',
    title: 'Disable Drift Advisor',
    description: 'Turn off the Drift Advisor integration for this workspace.',
    category: 'Drift Advisor',
    icon: 'circle-slash',
  },
  {
    command: 'saropaLints.driftAdvisor.refresh',
    title: 'Refresh Drift Advisor',
    description: 'Re-fetch drift data from the Drift Advisor service.',
    category: 'Drift Advisor',
    icon: 'refresh',
  },
  {
    command: 'saropaLints.driftAdvisor.openInBrowser',
    title: 'Open in Browser',
    description: 'Open the Drift Advisor dashboard in the default browser.',
    category: 'Drift Advisor',
    icon: 'link-external',
  },

  // ── Views & Navigation ───────────────────────────────────────────────────

  {
    command: 'saropaLints.showCommandCatalog',
    title: 'Browse All Commands',
    description: 'Open this searchable catalog of every extension command.',
    category: 'Views & Navigation',
    icon: 'list-flat',
  },
  {
    command: 'saropaLints.openWalkthrough',
    title: 'Getting Started',
    description: 'Open the guided walkthrough for Saropa Lints features.',
    category: 'Views & Navigation',
    icon: 'mortar-board',
  },
  {
    command: 'saropaLints.showAbout',
    title: 'About',
    description: 'Open the About Saropa Lints panel with version and product information.',
    category: 'Views & Navigation',
    icon: 'info',
  },
  {
    command: 'saropaLints.openHelpHub',
    title: 'Help',
    description:
      'Open walkthrough, About, command catalog, and pub.dev from one quick pick (same as sidebar Help rows).',
    category: 'Views & Navigation',
    icon: 'question',
  },
  {
    command: 'saropaLints.openPubDevSaropaLints',
    title: 'Open Package on pub.dev',
    description: 'Open the saropa_lints package page on pub.dev.',
    category: 'Views & Navigation',
    icon: 'link-external',
  },
  {
    command: 'saropaLints.toggleSidebarSection',
    title: 'Toggle Activity Bar Section',
    description: 'Show or hide a section in the Saropa Lints activity bar.',
    category: 'Views & Navigation',
    icon: 'layout',
    internal: true,
  },
];
