/**
 * Scanning-state view for the Code Health Dashboard.
 *
 * Before the scan finishes, the panel shows this live progress surface instead
 * of a frozen "scanning…" notification: a phase stepper, a per-phase progress
 * bar, the file currently being processed, running counters, a streaming preview
 * of the worst functions found so far, and Pause / Resume / Restart / Cancel
 * controls. The host streams `VibrancyScanEvent`s in via `postMessage`; the
 * inline script below patches the DOM. When the scan completes the host replaces
 * `webview.html` with the full report (see projectVibrancyReportView).
 */
import { createWebviewCspNonce, escapeHtml, jsonForScriptBlock } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';

// Injected by esbuild at build time (see esbuild.js `define`). Falls back to
// 'dev' under the test compiler (tsc, no define), so importing this module in a
// unit test never throws on an undefined global.
declare const __BUILD_TAG__: string;
const BUILD_TAG = typeof __BUILD_TAG__ !== 'undefined' ? __BUILD_TAG__ : 'dev';

/** Ordered phases the dart scan reports, with human labels for the stepper. */
function phaseLabels(): Record<string, string> {
  return {
    parse: l10n('codeHealth.scan.phase.parse'),
    history: l10n('codeHealth.scan.phase.history'),
    blame: l10n('codeHealth.scan.phase.blame'),
    usage: l10n('codeHealth.scan.phase.usage'),
    score: l10n('codeHealth.scan.phase.score'),
  };
}

/** Strings the inline client script needs (resolved host-side for i18n). */
function scanStrings(): Record<string, string> {
  return {
    ...phaseLabels(),
    files: l10n('codeHealth.scan.counter.files'),
    functions: l10n('codeHealth.scan.counter.functions'),
    problems: l10n('codeHealth.scan.counter.problems'),
    elapsed: l10n('codeHealth.scan.elapsed'),
    paused: l10n('codeHealth.scan.paused'),
    stopped: l10n('codeHealth.scan.stopped'),
    waiting: l10n('codeHealth.scan.waiting'),
    launching: l10n('codeHealth.scan.launching'),
    collect: l10n('codeHealth.scan.collect'),
    previewEmpty: l10n('codeHealth.scan.preview.empty'),
    pause: l10n('codeHealth.scan.btn.pause'),
    resume: l10n('codeHealth.scan.btn.resume'),
    legacyEngine: l10n('codeHealth.scan.version.legacy'),
  };
}

/** Full scanning-state HTML document set as the panel's initial `webview.html`. */
export function buildCodeHealthScanningHtml(extensionVersion = 'dev'): string {
  const nonce = createWebviewCspNonce();
  const labels = phaseLabels();
  const stepper = Object.entries(labels)
    .map(
      ([key, label]) =>
        `<li class="step" data-phase="${key}"><span class="dot"></span>${escapeHtml(label)}</li>`,
    )
    .join('');
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>${escapeHtml(l10n('codeHealth.scan.title'))}</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
<style nonce="${nonce}">${scanStyles()}</style>
</head>
<body>
<header class="scan-hero">
  <h1>${escapeHtml(l10n('codeHealth.scan.title'))} <span class="spinner" aria-hidden="true"></span></h1>
  <p class="sub">${escapeHtml(l10n('codeHealth.scan.subtitle'))}</p>
</header>

<ol class="stepper" id="stepper">${stepper}</ol>

<section class="bar-block">
  <div class="bar-head">
    <span id="phaseLabel">${escapeHtml(l10n('codeHealth.scan.launching'))}</span>
    <span class="head-right"><span id="eta" class="eta"></span><span id="phasePct" class="pct"></span></span>
  </div>
  <div class="bar-track indeterminate" id="barTrack"><div class="bar-fill" id="barFill"></div></div>
  <p class="scan-hint" id="scanHint">${escapeHtml(l10n('codeHealth.scan.firstRunHint'))}</p>
  <p class="current-file" id="currentFile" title=""></p>
</section>

<section class="counters" aria-label="${escapeHtml(l10n('codeHealth.scan.counters.aria'))}">
  <div class="counter c-files"><span class="n" id="cFiles">0</span><span class="k">${escapeHtml(l10n('codeHealth.scan.counter.files'))}</span></div>
  <div class="counter c-fns"><span class="n" id="cFns">0</span><span class="k">${escapeHtml(l10n('codeHealth.scan.counter.functions'))}</span></div>
  <div class="counter c-prob"><span class="n bad" id="cProb">0</span><span class="k">${escapeHtml(l10n('codeHealth.scan.counter.problems'))}</span></div>
  <div class="counter c-time"><span class="n" id="cElapsed">0s</span><span class="k">${escapeHtml(l10n('codeHealth.scan.elapsed'))}</span></div>
</section>

<section class="controls" role="toolbar" aria-label="${escapeHtml(l10n('codeHealth.scan.controls.aria'))}">
  <button class="btn" id="btnPause" type="button">${escapeHtml(l10n('codeHealth.scan.btn.pause'))}</button>
  <button class="btn" id="btnRestart" type="button">${escapeHtml(l10n('codeHealth.scan.btn.restart'))}</button>
  <button class="btn danger" id="btnCancel" type="button">${escapeHtml(l10n('codeHealth.scan.btn.cancel'))}</button>
</section>

<section class="preview">
  <h2>${escapeHtml(l10n('codeHealth.scan.preview.heading'))}</h2>
  <ul class="prob-list" id="probList"><li class="empty" id="probEmpty">${escapeHtml(l10n('codeHealth.scan.preview.empty'))}</li></ul>
</section>

<footer class="ver-foot">
  <span class="ver-brand">Saropa Lints v${escapeHtml(extensionVersion)} <span class="ver-tag">#${escapeHtml(BUILD_TAG)}</span></span>
  <span class="ver-sep">·</span>
  <span>${escapeHtml(l10n('codeHealth.scan.version.engine'))}: <span id="engineVer">${escapeHtml(l10n('codeHealth.scan.version.detecting'))}</span></span>
</footer>

<script nonce="${nonce}">${scanScript()}</script>
</body>
</html>`;
}

/** Styles: theme-aware via VS Code webview CSS variables; no external assets. */
function scanStyles(): string {
  return `
:root{color-scheme:light dark;}
body{font-family:var(--vscode-font-family);color:var(--vscode-foreground);background:var(--vscode-editor-background);margin:0;padding:24px;line-height:1.5;}
.scan-hero h1{font-size:1.5rem;margin:0 0 4px;display:flex;align-items:center;gap:10px;}
.sub{margin:0 0 20px;color:var(--vscode-descriptionForeground);}
.spinner{width:16px;height:16px;border:2px solid var(--vscode-progressBar-background,#0e70c0);border-right-color:transparent;border-radius:50%;display:inline-block;animation:spin 0.8s linear infinite;}
@keyframes spin{to{transform:rotate(360deg);}}
@media (prefers-reduced-motion:reduce){.spinner{animation:none;}}
.stepper{list-style:none;display:flex;flex-wrap:wrap;gap:6px 18px;padding:0;margin:0 0 20px;}
.step{display:flex;align-items:center;gap:7px;color:var(--vscode-descriptionForeground);font-size:.85rem;}
.step .dot{width:9px;height:9px;border-radius:50%;background:var(--vscode-input-border,#5557);}
.step.active{color:var(--vscode-foreground);font-weight:600;}
.step.active .dot{background:var(--vscode-progressBar-background,#0e70c0);box-shadow:0 0 0 3px color-mix(in srgb,var(--vscode-progressBar-background,#0e70c0) 30%,transparent);}
.step.done{color:var(--vscode-foreground);}
.step.done .dot{background:var(--vscode-charts-green,#2ea043);}
.bar-block{margin-bottom:18px;}
.bar-head{display:flex;justify-content:space-between;font-size:.9rem;margin-bottom:6px;}
.bar-head #phaseLabel{font-weight:600;}
.head-right{display:flex;gap:10px;align-items:baseline;}
.eta{font-size:.8rem;color:var(--vscode-charts-blue,#3794ff);font-variant-numeric:tabular-nums;}
.pct{font-variant-numeric:tabular-nums;font-weight:600;color:var(--vscode-foreground);}
.bar-track{height:12px;border-radius:7px;background:var(--vscode-input-background,#8881);overflow:hidden;box-shadow:inset 0 0 0 1px var(--vscode-widget-border,#8883);}
.bar-fill{height:100%;width:0;border-radius:7px;background:linear-gradient(90deg,var(--vscode-charts-blue,#3794ff),var(--vscode-progressBar-background,#0e70c0));transition:width .2s ease;}
/* Indeterminate: a sliding chunk shown while the scan is starting/compiling and
   no done/total has arrived yet, so the bar is never a dead "0%". */
.bar-track.indeterminate .bar-fill{width:35%;animation:indeterminate 1.1s ease-in-out infinite;}
@keyframes indeterminate{0%{margin-left:-35%;}100%{margin-left:100%;}}
@media (prefers-reduced-motion:reduce){.bar-track.indeterminate .bar-fill{animation:none;width:100%;opacity:.4;}}
.scan-hint{margin:8px 0 0;font-size:.8rem;color:var(--vscode-descriptionForeground);}
.current-file{margin:8px 0 0;font-family:var(--vscode-editor-font-family,monospace);font-size:.8rem;color:var(--vscode-descriptionForeground);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-height:1.2em;}
.counters{display:flex;flex-wrap:wrap;gap:14px;margin-bottom:20px;}
.counter{flex:1 1 90px;background:var(--vscode-editorWidget-background,#8881);border:1px solid var(--vscode-widget-border,#8883);border-top-width:3px;border-radius:8px;padding:10px 12px;display:flex;flex-direction:column;gap:2px;}
.counter .n{font-size:1.5rem;font-weight:700;font-variant-numeric:tabular-nums;}
.counter .k{font-size:.75rem;color:var(--vscode-descriptionForeground);text-transform:uppercase;letter-spacing:.04em;}
/* Each counter gets its own hue so the strip reads at a glance. */
.c-files{border-top-color:var(--vscode-charts-blue,#3794ff);}
.c-files .n{color:var(--vscode-charts-blue,#3794ff);}
.c-fns{border-top-color:var(--vscode-charts-purple,#b180d7);}
.c-fns .n{color:var(--vscode-charts-purple,#b180d7);}
.c-prob{border-top-color:var(--vscode-charts-red,#f14c4c);}
.counter .n.bad{color:var(--vscode-charts-red,#f14c4c);}
.c-time{border-top-color:var(--vscode-charts-green,#2ea043);}
.c-time .n{color:var(--vscode-charts-green,#2ea043);}
.controls{display:flex;gap:8px;margin-bottom:24px;}
.btn{font:inherit;padding:6px 16px;border-radius:6px;border:1px solid var(--vscode-button-border,transparent);background:var(--vscode-button-secondaryBackground,#3a3d41);color:var(--vscode-button-secondaryForeground,#fff);cursor:pointer;}
.btn:hover{background:var(--vscode-button-secondaryHoverBackground,#45494e);}
.btn.danger{background:var(--vscode-inputValidation-errorBackground,#5a1d1d);color:var(--vscode-foreground);}
.btn[disabled]{opacity:.5;cursor:default;}
.preview h2{font-size:1rem;margin:0 0 8px;}
.prob-list{list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:4px;max-height:340px;overflow:auto;}
.prob-list li{display:flex;align-items:center;gap:10px;padding:6px 10px;border-radius:6px;background:var(--vscode-editorWidget-background,#8881);font-size:.85rem;}
.prob-list li.empty{background:transparent;color:var(--vscode-descriptionForeground);font-style:italic;}
.grade{font-weight:700;width:1.4em;text-align:center;border-radius:4px;padding:1px 0;}
.grade-D,.grade-E{color:var(--vscode-charts-orange,#e2a03f);}
.grade-F{color:var(--vscode-charts-red,#f14c4c);}
.prob-name{font-family:var(--vscode-editor-font-family,monospace);}
.prob-file{margin-left:auto;color:var(--vscode-descriptionForeground);font-size:.78rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:45%;}
.ver-foot{margin-top:28px;padding-top:12px;border-top:1px solid var(--vscode-widget-border,#8883);font-size:.78rem;color:var(--vscode-descriptionForeground);display:flex;gap:8px;align-items:center;}
.ver-brand{font-weight:600;}
.ver-tag{font-family:var(--vscode-editor-font-family,monospace);color:var(--vscode-charts-blue,#3794ff);opacity:.85;}
.ver-sep{opacity:.5;}
#engineVer.ok{color:var(--vscode-charts-green,#2ea043);font-weight:600;}
#engineVer.legacy{color:var(--vscode-charts-orange,#e2a03f);font-weight:600;}
body.paused .bar-fill{background:var(--vscode-charts-yellow,#cca700);}
body.paused .spinner{animation-play-state:paused;}
`;
}

/** Inline client script: applies streamed events + wires the control buttons. */
function scanScript(): string {
  const strings = jsonForScriptBlock(scanStrings());
  return `
(function(){
  var S = ${strings};
  var vscode = acquireVsCodeApi();
  var started = Date.now();
  var phaseStart = Date.now();
  var paused = false;
  var problems = 0;
  var btnPause = document.getElementById('btnPause');
  var probEmpty = document.getElementById('probEmpty');

  // Estimate remaining time for the current phase from its observed rate so the
  // user gets a real "this isn't stalled, ~N left" signal. Throttled-feeling by
  // nature: it only refines as ticks arrive.
  function updateEta(done, total){
    var el = document.getElementById('eta');
    if (!el) return;
    var elapsed = (Date.now() - phaseStart) / 1000;
    if (done <= 0 || elapsed < 1){ el.textContent = ''; return; }
    var remaining = Math.round((total - done) / (done / elapsed));
    if (remaining <= 0){ el.textContent = ''; return; }
    el.textContent = '~' + fmtDuration(remaining) + ' left';
  }
  function fmtDuration(s){
    if (s < 60) return s + 's';
    var m = Math.floor(s / 60);
    var r = s % 60;
    return r === 0 ? m + 'm' : m + 'm ' + r + 's';
  }

  setInterval(function(){
    var s = Math.floor((Date.now()-started)/1000);
    document.getElementById('cElapsed').textContent = s + 's';
  }, 1000);

  // If no 'meta' event has arrived after a generous window (covers a cold
  // dart-run compile), the scanned project is almost certainly running an older
  // saropa_lints CLI that cannot report progress — say so explicitly so a stuck
  // 0% is explained rather than mysterious. A late meta still overrides this
  // back to the green version.
  setTimeout(function(){
    if (sawMeta) return;
    var ve = document.getElementById('engineVer');
    if (ve){ ve.textContent = S.legacyEngine; ve.className = 'legacy'; }
  }, 40000);

  function setActive(phase){
    var steps = document.querySelectorAll('.step');
    var passed = true;
    steps.forEach(function(el){
      var p = el.getAttribute('data-phase');
      if (p === phase){ el.classList.add('active'); el.classList.remove('done'); passed = false; }
      else if (passed){ el.classList.add('done'); el.classList.remove('active'); }
      else { el.classList.remove('active','done'); }
    });
  }

  function goDeterminate(){
    var hint = document.getElementById('scanHint');
    if (hint){ hint.style.display = 'none'; }
    document.getElementById('barTrack').classList.remove('indeterminate');
  }

  var sawMeta = false;
  function onEvent(ev){
    if (ev.event === 'meta'){
      sawMeta = true;
      var ve = document.getElementById('engineVer');
      if (ve){ ve.textContent = 'saropa_lints v' + (ev.version || '?'); ve.className = 'ok'; }
      return;
    }
    if (ev.event === 'phase'){
      // 'collect' precedes file enumeration — keep the bar indeterminate, just
      // confirm the scanner is alive. Real phases reset to 0% on first tick.
      if (ev.phase === 'collect'){
        document.getElementById('phaseLabel').textContent = S.collect;
        return;
      }
      setActive(ev.phase);
      // Reset the per-phase rate window so the ETA reflects THIS phase's speed.
      phaseStart = Date.now();
      document.getElementById('eta').textContent = '';
      document.getElementById('phaseLabel').textContent = S[ev.phase] || ev.phase;
    } else if (ev.event === 'tick'){
      if (typeof ev.total === 'number' && ev.total > 0){
        goDeterminate();
        var pct = Math.min(100, Math.round((ev.done/ev.total)*100));
        document.getElementById('barFill').style.width = pct + '%';
        document.getElementById('phasePct').textContent = pct + '%';
        updateEta(ev.done, ev.total);
      }
      if (ev.phase === 'parse'){
        document.getElementById('cFiles').textContent = ev.done || 0;
        if (typeof ev.functions === 'number') document.getElementById('cFns').textContent = ev.functions;
      }
      if (ev.file){
        var cf = document.getElementById('currentFile');
        cf.textContent = ev.file; cf.title = ev.file;
      }
    } else if (ev.event === 'row'){
      addProblem(ev);
    }
  }

  function addProblem(ev){
    if (probEmpty){ probEmpty.remove(); probEmpty = null; }
    problems++;
    document.getElementById('cProb').textContent = problems;
    var li = document.createElement('li');
    var g = document.createElement('span');
    g.className = 'grade grade-' + (ev.grade||'F');
    g.textContent = ev.grade || 'F';
    var name = document.createElement('span');
    name.className = 'prob-name';
    name.textContent = ev.name || '';
    var file = document.createElement('span');
    file.className = 'prob-file';
    file.textContent = ev.file || '';
    li.appendChild(g); li.appendChild(name); li.appendChild(file);
    var list = document.getElementById('probList');
    list.appendChild(li);
    list.scrollTop = list.scrollHeight;
  }

  function setPaused(v){
    paused = v;
    document.body.classList.toggle('paused', v);
    btnPause.textContent = v ? S.resume : S.pause;
    if (v){
      document.getElementById('phaseLabel').textContent = S.paused;
    }
  }

  btnPause.addEventListener('click', function(){
    if (paused){ vscode.postMessage({type:'resume'}); setPaused(false); }
    else { vscode.postMessage({type:'pause'}); setPaused(true); }
  });
  document.getElementById('btnRestart').addEventListener('click', function(){
    setPaused(false); problems = 0; vscode.postMessage({type:'restart'});
  });
  document.getElementById('btnCancel').addEventListener('click', function(){
    vscode.postMessage({type:'cancel'});
  });

  function setStopped(){
    document.body.classList.add('stopped');
    document.getElementById('phaseLabel').textContent = S.stopped;
    var sp = document.querySelector('.spinner');
    if (sp){ sp.style.display = 'none'; }
    btnPause.setAttribute('disabled','');
  }

  window.addEventListener('message', function(e){
    var msg = e.data || {};
    if (msg.type === 'event' && msg.event){ onEvent(msg.event); }
    else if (msg.type === 'paused'){ setPaused(!!msg.value); }
    else if (msg.type === 'stopped'){ setStopped(); }
  });
})();
`;
}
