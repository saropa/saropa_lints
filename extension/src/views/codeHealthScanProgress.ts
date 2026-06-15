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
import { getDashboardChromeStyles } from './dashboardChromeStyles';
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
<style nonce="${nonce}">${getDashboardChromeStyles()}${scanStyles()}</style>
</head>
<body>
<header class="dash-hero">
  <div class="hero-text">
    <h1>${escapeHtml(l10n('codeHealth.scan.title'))} <span class="spinner" aria-hidden="true"></span></h1>
    <p class="status-line"><span>${escapeHtml(l10n('codeHealth.scan.subtitle'))}</span></p>
  </div>
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

/**
 * Scan-specific styles layered over the shared dashboard chrome
 * (SAROPA_DASHBOARD_STYLE_GUIDE). The chrome owns body/base, the `.dash-hero`,
 * `.status-line`, the `.btn`/`.btn.danger` tiers, tokens, a11y, and reduced-motion;
 * this only styles the scanning-specific components (stepper, progress bar, counter
 * cards, current-file, preview list, footer), every value drawn from a chrome token
 * so the panel matches the finished Code Health report. All class/id names that the
 * inline script and the unit test reference are preserved unchanged; selectors are
 * scoped under scan-specific ancestors to avoid colliding with chrome classes
 * (`.dot`, `.bar-fill`, `.pill`). Per the webview-template-literal trap, no regex
 * backslashes appear in this string.
 */
function scanStyles(): string {
  return `
.spinner{width:16px;height:16px;border:2px solid var(--vscode-progressBar-background,#0e70c0);border-right-color:transparent;border-radius:50%;display:inline-block;vertical-align:middle;margin-inline-start:var(--space-2);animation:scanspin 0.8s linear infinite;}
@keyframes scanspin{to{transform:rotate(360deg);}}
@media (prefers-reduced-motion:reduce){.spinner{animation:none;}}
.stepper{list-style:none;display:flex;flex-wrap:wrap;gap:var(--space-1) var(--space-5);padding:0;margin:0 0 var(--space-5);}
.step{display:flex;align-items:center;gap:7px;color:var(--muted);font-size:var(--text-caption);}
.step .dot{width:9px;height:9px;border-radius:var(--radius-pill);background:var(--border);}
.step.active{color:var(--vscode-foreground);font-weight:600;}
.step.active .dot{background:var(--accent-info);box-shadow:0 0 0 3px color-mix(in srgb,var(--accent-info) 30%,transparent);}
.step.done{color:var(--vscode-foreground);}
.step.done .dot{background:var(--status-good);}
.bar-block{margin-bottom:var(--space-4);}
.bar-head{display:flex;justify-content:space-between;font-size:var(--text-body);margin-bottom:var(--space-1);}
.bar-head #phaseLabel{font-weight:600;}
.head-right{display:flex;gap:var(--space-2);align-items:baseline;}
.eta{font-size:var(--text-caption);color:var(--accent-info);font-variant-numeric:tabular-nums;}
.pct{font-variant-numeric:tabular-nums;font-weight:600;color:var(--vscode-foreground);}
.bar-track{height:12px;border-radius:var(--radius);background:var(--inset);overflow:hidden;box-shadow:inset 0 0 0 1px var(--border);}
.bar-track .bar-fill{height:100%;width:0;border-radius:var(--radius);background:linear-gradient(90deg,var(--accent-info),var(--vscode-progressBar-background,#0e70c0));transition:width var(--dur) var(--ease);}
/* Indeterminate: a sliding chunk shown while the scan is starting/compiling and
   no done/total has arrived yet, so the bar is never a dead "0%". */
.bar-track.indeterminate .bar-fill{width:35%;animation:scanindeterminate 1.1s ease-in-out infinite;}
@keyframes scanindeterminate{0%{margin-left:-35%;}100%{margin-left:100%;}}
@media (prefers-reduced-motion:reduce){.bar-track.indeterminate .bar-fill{animation:none;width:100%;opacity:.4;}}
.scan-hint{margin:var(--space-2) 0 0;font-size:var(--text-caption);color:var(--muted);}
.current-file{margin:var(--space-2) 0 0;font-family:var(--vscode-editor-font-family,monospace);font-size:var(--text-caption);color:var(--muted);min-height:1.2em;display:flex;min-width:0;}
/* File paths collapse the DIRECTORY (the truncatable part) and keep the basename
   fully visible: cropping the end with a plain ellipsis used to eat the filename,
   which is the one piece a reader needs to identify the file. The dir shrinks
   first (flex:0 1), the basename never shrinks (flex:0 0). */
.current-file .path-dir,.prob-file .path-dir{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:0 1 auto;min-width:0;}
.current-file .path-base,.prob-file .path-base{white-space:nowrap;flex:0 0 auto;}
/* Counter cards mirror the chrome KPI cards (surface, border, radius) with a
   per-metric colored top edge so the strip reads at a glance — re-tokened. */
.counters{display:flex;flex-wrap:wrap;gap:var(--space-3);margin-bottom:var(--space-5);}
.counter{flex:1 1 90px;background:var(--surface-2);border:1px solid var(--border);border-top-width:3px;border-radius:var(--radius);padding:var(--space-3);display:flex;flex-direction:column;gap:2px;}
.counter .n{font-size:var(--text-kpi);font-weight:700;font-variant-numeric:tabular-nums;line-height:1.1;}
.counter .k{font-size:var(--text-caption);color:var(--muted);text-transform:uppercase;letter-spacing:.04em;}
.c-files{border-top-color:var(--accent-info);}
.c-files .n{color:var(--accent-info);}
.c-fns{border-top-color:var(--accent-opinionated);}
.c-fns .n{color:var(--vscode-foreground);}
.c-prob{border-top-color:var(--accent-critical);}
.counter .n.bad{color:var(--accent-critical);}
.c-time{border-top-color:var(--status-good);}
.c-time .n{color:var(--status-good);}
.controls{display:flex;gap:var(--space-2);margin-bottom:var(--space-6);}
.preview h2{font-size:var(--text-h3);margin:0 0 var(--space-2);}
.prob-list{list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:var(--space-1);max-height:340px;overflow:auto;}
/* Fixed three-column grid (grade | function | path) so the columns line up at the
   same x on every row. */
.prob-list li{display:grid;grid-template-columns:1.6em minmax(0,1fr) minmax(0,42%);align-items:center;column-gap:var(--space-3);padding:var(--space-1) var(--space-2);border-radius:var(--radius);background:var(--surface-2);font-size:var(--text-caption);}
.prob-list li.empty{display:block;background:transparent;color:var(--muted);font-style:italic;}
.prob-list li.clickable{cursor:pointer;}
.prob-list li.clickable:hover{background:var(--vscode-list-hoverBackground);}
.prob-list li.clickable:focus-visible{outline:2px solid var(--vscode-focusBorder);outline-offset:1px;}
.grade{font-weight:700;text-align:center;border-radius:var(--radius-sm);padding:1px 0;}
/* Shared grade ramp (guide §5.8) — same hues as the finished Code Health report. */
.grade-D{color:var(--grade-d);}
.grade-E{color:var(--grade-e);}
.grade-F{color:var(--grade-f);}
.prob-name{font-family:var(--vscode-editor-font-family,monospace);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.prob-file{display:flex;min-width:0;color:var(--muted);font-size:var(--text-caption);}
.ver-foot{margin-top:var(--space-6);padding-top:var(--space-3);border-top:1px solid var(--border);font-size:var(--text-caption);color:var(--muted);display:flex;gap:var(--space-2);align-items:center;}
.ver-brand{font-weight:600;}
.ver-tag{font-family:var(--vscode-editor-font-family,monospace);color:var(--accent-info);opacity:.85;}
.ver-sep{opacity:.5;}
#engineVer.ok{color:var(--status-good);font-weight:600;}
#engineVer.legacy{color:var(--accent-medium);font-weight:600;}
body.paused .bar-track .bar-fill{background:var(--accent-warning);}
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
  // Human-friendly elapsed/remaining: seconds under a minute, m+s under an hour,
  // h+m above it (seconds are dropped past an hour — noise at that scale). A raw
  // "6762s" is unreadable; "1h 52m" is not.
  function fmtDuration(s){
    if (s < 60) return s + 's';
    if (s < 3600){
      var m = Math.floor(s / 60);
      var rs = s % 60;
      return rs === 0 ? m + 'm' : m + 'm ' + rs + 's';
    }
    var h = Math.floor(s / 3600);
    var rm = Math.floor((s % 3600) / 60);
    return rm === 0 ? h + 'h' : h + 'h ' + rm + 'm';
  }
  // Thousands separators so six-figure file/function counts stay readable.
  // en-US locale forces comma grouping regardless of the host's locale; a regex
  // can't be used here because this whole script lives inside a template literal,
  // where \\d / \\B in a regex would collapse to plain d / B.
  function fmtNum(n){
    return Number(n || 0).toLocaleString('en-US');
  }

  setInterval(function(){
    var s = Math.floor((Date.now()-started)/1000);
    document.getElementById('cElapsed').textContent = fmtDuration(s);
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
        // One decimal: on a multi-thousand-file phase a whole-number percent sits
        // on the same value for dozens of ticks and reads as stalled; the decimal
        // keeps visibly moving. clamp to 100 so float drift can't print 100.1.
        var pct = Math.min(100, (ev.done/ev.total)*100);
        document.getElementById('barFill').style.width = pct + '%';
        document.getElementById('phasePct').textContent = pct.toFixed(1) + '%';
        updateEta(ev.done, ev.total);
      }
      if (ev.phase === 'parse'){
        document.getElementById('cFiles').textContent = fmtNum(ev.done || 0);
        if (typeof ev.functions === 'number') document.getElementById('cFns').textContent = fmtNum(ev.functions);
      }
      if (ev.file){
        applyPath(document.getElementById('currentFile'), ev.file);
      }
    } else if (ev.event === 'row'){
      addProblem(ev);
    }
  }

  // Render a path into the element as a truncatable directory span + an
  // always-visible basename span, so the filename is never the part that gets
  // cropped. The CLI already emits posix-separated paths (forward slashes), so
  // no backslash normalization is needed here.
  function applyPath(el, path){
    if (!el) return;
    var p = path || '';
    el.textContent = '';
    el.title = p;
    var cut = p.lastIndexOf('/');
    if (cut >= 0){
      var dir = document.createElement('span');
      dir.className = 'path-dir';
      dir.textContent = p.slice(0, cut + 1);
      el.appendChild(dir);
    }
    var base = document.createElement('span');
    base.className = 'path-base';
    base.textContent = cut >= 0 ? p.slice(cut + 1) : p;
    el.appendChild(base);
  }

  // Dart reports operator overrides by their symbol (==, <, []). Shown bare in a
  // "worst functions" list they read as nonsense, so label them as operators.
  function displayName(n){
    if (!n) return '';
    return /^[A-Za-z_$]/.test(n) ? n : 'operator ' + n;
  }

  function addProblem(ev){
    if (probEmpty){ probEmpty.remove(); probEmpty = null; }
    problems++;
    document.getElementById('cProb').textContent = fmtNum(problems);
    var label = displayName(ev.name);
    var li = document.createElement('li');
    var g = document.createElement('span');
    g.className = 'grade grade-' + (ev.grade||'F');
    g.textContent = ev.grade || 'F';
    var name = document.createElement('span');
    name.className = 'prob-name';
    name.textContent = label;
    var file = document.createElement('span');
    file.className = 'prob-file';
    applyPath(file, ev.file || '');
    li.appendChild(g); li.appendChild(name); li.appendChild(file);
    // Clicking the row opens the function at its line (host handles 'openFile').
    if (ev.file){
      li.className = 'clickable';
      li.setAttribute('role', 'button');
      li.setAttribute('tabindex', '0');
      li.title = label + ' — ' + ev.file;
      var open = function(){ vscode.postMessage({type:'openFile', file: ev.file, line: ev.line || 1}); };
      li.addEventListener('click', open);
      li.addEventListener('keydown', function(e){ if (e.key === 'Enter' || e.key === ' '){ e.preventDefault(); open(); } });
    }
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
  // Restart and Cancel act immediately — no Y/N confirmation. A scan is cheap to
  // re-run and easy to restart, so a confirmation dialog is friction, not safety.
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
