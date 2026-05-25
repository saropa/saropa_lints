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
    previewEmpty: l10n('codeHealth.scan.preview.empty'),
    pause: l10n('codeHealth.scan.btn.pause'),
    resume: l10n('codeHealth.scan.btn.resume'),
  };
}

/** Full scanning-state HTML document set as the panel's initial `webview.html`. */
export function buildCodeHealthScanningHtml(): string {
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
    <span id="phaseLabel">${escapeHtml(l10n('codeHealth.scan.waiting'))}</span>
    <span id="phasePct" class="pct">0%</span>
  </div>
  <div class="bar-track"><div class="bar-fill" id="barFill"></div></div>
  <p class="current-file" id="currentFile" title=""></p>
</section>

<section class="counters" aria-label="${escapeHtml(l10n('codeHealth.scan.counters.aria'))}">
  <div class="counter"><span class="n" id="cFiles">0</span><span class="k">${escapeHtml(l10n('codeHealth.scan.counter.files'))}</span></div>
  <div class="counter"><span class="n" id="cFns">0</span><span class="k">${escapeHtml(l10n('codeHealth.scan.counter.functions'))}</span></div>
  <div class="counter"><span class="n bad" id="cProb">0</span><span class="k">${escapeHtml(l10n('codeHealth.scan.counter.problems'))}</span></div>
  <div class="counter"><span class="n" id="cElapsed">0s</span><span class="k">${escapeHtml(l10n('codeHealth.scan.elapsed'))}</span></div>
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
.pct{font-variant-numeric:tabular-nums;color:var(--vscode-descriptionForeground);}
.bar-track{height:10px;border-radius:6px;background:var(--vscode-input-background,#8881);overflow:hidden;}
.bar-fill{height:100%;width:0;border-radius:6px;background:var(--vscode-progressBar-background,#0e70c0);transition:width .15s ease;}
.current-file{margin:8px 0 0;font-family:var(--vscode-editor-font-family,monospace);font-size:.8rem;color:var(--vscode-descriptionForeground);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-height:1.2em;}
.counters{display:flex;flex-wrap:wrap;gap:14px;margin-bottom:20px;}
.counter{flex:1 1 90px;background:var(--vscode-editorWidget-background,#8881);border:1px solid var(--vscode-widget-border,#8883);border-radius:8px;padding:10px 12px;display:flex;flex-direction:column;gap:2px;}
.counter .n{font-size:1.4rem;font-weight:700;font-variant-numeric:tabular-nums;}
.counter .n.bad{color:var(--vscode-charts-red,#f14c4c);}
.counter .k{font-size:.75rem;color:var(--vscode-descriptionForeground);text-transform:uppercase;letter-spacing:.04em;}
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
  var paused = false;
  var problems = 0;
  var btnPause = document.getElementById('btnPause');
  var probEmpty = document.getElementById('probEmpty');

  setInterval(function(){
    var s = Math.floor((Date.now()-started)/1000);
    document.getElementById('cElapsed').textContent = s + 's';
  }, 1000);

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

  function onEvent(ev){
    if (ev.event === 'phase'){
      setActive(ev.phase);
      document.getElementById('phaseLabel').textContent = S[ev.phase] || ev.phase;
      document.getElementById('barFill').style.width = '0%';
      document.getElementById('phasePct').textContent = '0%';
    } else if (ev.event === 'tick'){
      if (typeof ev.total === 'number' && ev.total > 0){
        var pct = Math.min(100, Math.round((ev.done/ev.total)*100));
        document.getElementById('barFill').style.width = pct + '%';
        document.getElementById('phasePct').textContent = pct + '%';
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
