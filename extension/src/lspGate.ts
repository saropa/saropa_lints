/**
 * Whether the standalone LSP server may run. The `saropaLints.enabled` master
 * switch wins: with it off, `saropaLints.lspServer.enabled` is ignored so no
 * saropa_lints process or Problems entry survives an "Off" toggle.
 */
export function shouldRunLsp(masterEnabled: boolean, lspSettingEnabled: boolean): boolean {
  return masterEnabled && lspSettingEnabled;
}
