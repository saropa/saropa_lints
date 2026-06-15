/// HTML/CSS/JS template for the Saropa Project Map report. Theme-aware (light /
/// dark via CSS vars, falls back to system colors), sticky brand banner with
/// inline KPI chips, continuous orange ramp on the treemap with a legend bar,
/// staggered card reveal, hover lift on cards / panels, skeleton shimmer on the
/// charts until they mount, table zebra + sticky header, and a relative-time
/// "scanned X ago" chip that refreshes every 30 s. Motion respects
/// `prefers-reduced-motion`. The only Dart interpolation is the embedded JSON.
library;

/// Wraps the embedded [json] payload in the full HTML document.
String renderHealthDocument(String json) =>
    '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Saropa Project Map</title>
<script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script>
<style>
  /* Brand-anchored palette = the SAROPA_DASHBOARD_STYLE_GUIDE standalone fallback
     (§3.6). This is what a browser/CI export with no host theme renders. CSS vars so
     light and dark share the same rules; the dark override below flips surfaces / text
     without rewriting components. In the VS Code webview these same token NAMES are
     rebound to the host theme by projectMapView.ts (webviewThemeOverride) — keep the
     names stable so that override keeps matching. */
  :root {
    color-scheme: light dark;
    --brand: #f97316;
    --brand-2: #ea580c;
    --brand-glow: rgba(249,115,22,.18);
    --bg: #fafaf9;
    --surface: #ffffff;
    --surface-2: #f5f5f4;
    --text: #0f172a;
    --muted: #64748b;
    --border: #e5e7eb;
    --hover: rgba(15,23,42,.05);
    --zebra: rgba(15,23,42,.025);
    --shadow: 0 1px 2px rgba(15,23,42,.04), 0 1px 3px rgba(15,23,42,.06);
    --shadow-lg: 0 4px 12px rgba(15,23,42,.08), 0 10px 30px -8px rgba(15,23,42,.16);
    --radius: 12px;
    --ring: 0 0 0 3px rgba(249,115,22,.32);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0a0f1c;
      --surface: #0f172a;
      --surface-2: #1e293b;
      --text: #f1f5f9;
      --muted: #94a3b8;
      --border: rgba(148,163,184,.18);
      --hover: rgba(241,245,249,.06);
      --zebra: rgba(241,245,249,.025);
      --shadow: 0 1px 3px rgba(0,0,0,.4);
      --shadow-lg: 0 8px 24px rgba(0,0,0,.45), 0 20px 50px -12px rgba(0,0,0,.6);
      --brand-glow: rgba(249,115,22,.28);
    }
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui,
      "Helvetica Neue", Arial, sans-serif;
    margin: 0; padding: 0;
    background: var(--bg); color: var(--text);
    line-height: 1.45;
    -webkit-font-smoothing: antialiased;
  }
  .page { padding: 0 24px 32px; max-width: 1400px; margin: 0 auto; }

  /* Sticky brand banner. The 3px gradient strip on top is the brand mark;
     the soft blur keeps content underneath legible when scrolled. */
  .banner {
    position: sticky; top: 0; z-index: 50;
    margin: 0 -24px 22px;
    padding: 18px 24px 16px;
    background: linear-gradient(180deg, var(--surface) 0%,
      color-mix(in oklab, var(--surface) 92%, transparent) 100%);
    -webkit-backdrop-filter: blur(10px);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid var(--border);
    box-shadow: var(--shadow);
  }
  .banner::before {
    content: ""; position: absolute; inset: 0 0 auto 0; height: 3px;
    background: linear-gradient(90deg, var(--brand) 0%, var(--brand-2) 55%, #0f172a 100%);
  }
  .eyebrow {
    font-size: 11px; font-weight: 700;
    letter-spacing: .14em; text-transform: uppercase;
    color: var(--brand);
    margin: 4px 0 6px;
  }
  .banner h1 {
    font-size: 30px; font-weight: 700; letter-spacing: -.025em;
    margin: 0; line-height: 1.1;
    display: flex; align-items: center; gap: 10px;
  }
  .banner h1 .flame { filter: drop-shadow(0 1px 4px var(--brand-glow)); }
  .banner h1 .title-text {
    background: linear-gradient(135deg, var(--text) 0%, var(--muted) 130%);
    -webkit-background-clip: text; background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  .meta {
    display: flex; gap: 12px; align-items: center; flex-wrap: wrap;
    margin-top: 10px; font-size: 12.5px; color: var(--muted);
  }
  #sub { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
         font-size: 12px; }
  .chip {
    display: inline-flex; gap: 6px; align-items: center;
    padding: 3px 10px; border-radius: 999px;
    background: var(--brand-glow); color: var(--brand-2);
    font-weight: 600; font-size: 11px;
  }
  @media (prefers-color-scheme: dark) {
    .chip { color: #fdba74; }
  }
  .chip::before {
    content: ""; width: 6px; height: 6px; border-radius: 50%;
    background: var(--brand);
    box-shadow: 0 0 0 3px var(--brand-glow);
  }

  /* KPI chips — five inline cards inside the banner so the strip and the
     numbers read as one banner instead of two stacked rows. */
  .kpis {
    display: grid; grid-template-columns: repeat(5, minmax(0, 1fr));
    gap: 10px; margin-top: 14px;
  }
  @media (max-width: 720px) { .kpis { grid-template-columns: repeat(2, 1fr); } }
  .kpi {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); padding: 12px 14px 11px;
    box-shadow: var(--shadow);
    transition: transform .18s ease, box-shadow .18s ease;
    position: relative; overflow: hidden;
    animation: rise .45s ease both;
  }
  .kpi:hover { transform: translateY(-2px); box-shadow: var(--shadow-lg); }
  .kpi::after {
    content: ""; position: absolute; left: 0; right: 0; bottom: 0; height: 2px;
    background: var(--brand);
    transform: scaleX(0); transform-origin: left;
    transition: transform .3s ease;
  }
  .kpi:hover::after { transform: scaleX(1); }
  .kpi.heat::after { transform: scaleX(1); opacity: .55; }
  .kpi .num {
    font-size: 24px; font-weight: 700; letter-spacing: -.02em;
    font-variant-numeric: tabular-nums;
  }
  .kpi.heat .num { color: var(--brand); }
  .kpi .lbl {
    font-size: 10px; font-weight: 700; text-transform: uppercase;
    letter-spacing: .08em; color: var(--muted); margin-top: 2px;
  }
  /* Staggered reveal — feels alive on first paint without being theatrical. */
  .kpi:nth-child(1){animation-delay:0ms}
  .kpi:nth-child(2){animation-delay:55ms}
  .kpi:nth-child(3){animation-delay:110ms}
  .kpi:nth-child(4){animation-delay:165ms}
  .kpi:nth-child(5){animation-delay:220ms}
  @keyframes rise {
    from { opacity: 0; transform: translateY(8px); }
    to   { opacity: 1; transform: none; }
  }

  /* Panels — soft elevation, brand-colored chevron, hover lift. */
  .panel {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); margin-bottom: 16px;
    box-shadow: var(--shadow); overflow: hidden;
    transition: box-shadow .2s ease, transform .2s ease;
    animation: rise .5s ease both;
  }
  .panel:nth-of-type(1){animation-delay:280ms}
  .panel:nth-of-type(2){animation-delay:340ms}
  .panel:nth-of-type(3){animation-delay:400ms}
  .panel:hover { box-shadow: var(--shadow-lg); }
  .panel > summary {
    cursor: pointer; padding: 14px 18px;
    font-size: 14px; font-weight: 600;
    list-style: none; user-select: none;
    display: flex; align-items: center; gap: 10px;
  }
  .panel > summary::-webkit-details-marker { display: none; }
  .panel > summary::before {
    content: ""; width: 7px; height: 7px;
    border-right: 2px solid var(--brand);
    border-bottom: 2px solid var(--brand);
    transform: rotate(-45deg);
    transition: transform .2s ease;
    flex: 0 0 auto;
  }
  .panel[open] > summary::before { transform: rotate(45deg); }
  .pbody { padding: 0 18px 18px; }
  .chart { width: 100%; height: 420px; }

  /* Skeleton shimmer — visible while the JSON is parsing and ECharts mounts.
     Removed by JS after each setOption returns. */
  .skeleton {
    background: linear-gradient(90deg,
      var(--surface-2) 0%, var(--hover) 50%, var(--surface-2) 100%);
    background-size: 200% 100%; border-radius: 8px;
    animation: shimmer 1.4s linear infinite;
  }
  @keyframes shimmer {
    0%   { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }

  /* Treemap legend — a thin 4-stop gradient bar with labels at each end.
     Mirrors the per-leaf orange ramp applied in JS so colors are legible. */
  .legend {
    display: flex; align-items: center; gap: 10px;
    margin-top: 10px; font-size: 11px; color: var(--muted);
  }
  .legend-bar {
    flex: 1; height: 6px; border-radius: 999px;
    background: linear-gradient(90deg,
      rgb(254,243,199) 0%, rgb(253,186,116) 33%,
      rgb(249,115,22) 66%, rgb(194,65,12) 100%);
    box-shadow: inset 0 0 0 1px var(--border);
  }

  /* Hot-spot filter + table. Sticky head + tabular-figures numerics +
     monospace path column = readable scanning of a long list. */
  .filter {
    width: 100%; padding: 10px 12px;
    border: 1px solid var(--border); border-radius: 8px;
    background: var(--surface-2); color: var(--text);
    font-size: 13px; margin-bottom: 12px;
    transition: border-color .15s ease, box-shadow .15s ease;
  }
  .filter:focus {
    outline: none; border-color: var(--brand); box-shadow: var(--ring);
  }
  .filter::placeholder { color: var(--muted); }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  thead th {
    position: sticky; top: 0;
    background: var(--surface);
    text-align: left; padding: 10px 12px;
    border-bottom: 2px solid var(--border);
    font-weight: 600; font-size: 10.5px;
    text-transform: uppercase; letter-spacing: .07em;
    color: var(--muted); cursor: pointer; user-select: none;
    transition: color .15s ease;
  }
  thead th:hover { color: var(--brand); }
  thead th.sort-active { color: var(--brand); }
  thead th.sort-active::after { content: " ▾"; font-size: 9px; }
  tbody tr {
    cursor: pointer;
    transition: background .12s ease;
  }
  tbody tr:nth-child(even) td { background: var(--zebra); }
  tbody tr:hover td { background: var(--brand-glow); }
  td {
    padding: 9px 12px; border-bottom: 1px solid var(--border);
    white-space: nowrap;
  }
  /* Numeric columns share a single tabular figure stack so they line up. */
  td.n { font-variant-numeric: tabular-nums; text-align: right; }
  td.fire { font-size: 14px; letter-spacing: -.06em; }
  td.path {
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 12px; color: var(--text);
  }

  /* Keyboard a11y — orange focus ring is the brand color, so focus reads as
     intentional product polish instead of the default browser blue. */
  :focus-visible {
    outline: none; box-shadow: var(--ring); border-radius: 6px;
  }

  /* Reduced motion — kill animations and hover transforms wholesale. */
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: .001ms !important;
      animation-iteration-count: 1 !important;
      transition: none !important;
    }
  }
</style>
</head>
<body>
<div class="page">
<header class="banner">
  <div class="eyebrow">Saropa Lints · Code Health</div>
  <h1><span class="flame">🔥</span><span class="title-text">Saropa Project Map</span></h1>
  <div class="meta">
    <span id="sub"></span>
    <span class="chip" id="scanChip" title="">just now</span>
  </div>
  <div class="kpis" id="kpis"></div>
</header>

<details class="panel" open><summary>Size map — largest files by lines</summary>
  <div class="pbody">
    <div id="treemap" class="chart skeleton"></div>
    <div class="legend">
      <span>fewer lines</span>
      <span class="legend-bar"></span>
      <span>more lines</span>
    </div>
  </div></details>

<details class="panel" open id="scatterPanel"><summary>Churn × complexity — top-right = refactor first</summary>
  <div class="pbody"><div id="scatter" class="chart skeleton"></div></div></details>

<details class="panel" open><summary>Hot spots — click a column to sort, type to filter</summary>
  <div class="pbody">
    <input id="filter" class="filter" type="search" placeholder="Filter by file or reason…">
    <table id="hot"><thead><tr>
      <th>Fire</th><th>File</th><th>LOC</th><th>Cognitive</th><th>Maint.</th><th>Churn</th><th>Why</th>
    </tr></thead><tbody></tbody></table>
  </div></details>

<details class="panel" open id="gravityPanel"><summary>Performance gravity — features carrying the most performance risk</summary>
  <div class="pbody">
    <table id="gravity"><thead><tr>
      <th>Gravity</th><th>Level</th><th>Feature</th><th>Patterns</th><th>Files</th>
    </tr></thead><tbody></tbody></table>
  </div></details>
</div>
<script>
const DATA = $json;
const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
const fg = dark ? "#e2e8f0" : "#0f172a";
const muted = dark ? "#94a3b8" : "#64748b";

function humanBytes(b){
  if (b < 1024) return b + " B";
  if (b < 1048576) return (b/1024).toFixed(1) + " KB";
  return (b/1048576).toFixed(1) + " MB";
}

// Relative-time chip — refreshes every 30s so an open dashboard stays accurate.
function fmtAgo(iso){
  const ms = Date.now() - new Date(iso).getTime();
  const s = Math.max(0, Math.floor(ms / 1000));
  if (s < 45) return "just now";
  if (s < 3600) return Math.floor(s/60) + "m ago";
  if (s < 86400) return Math.floor(s/3600) + "h ago";
  return Math.floor(s/86400) + "d ago";
}

const t = DATA.totals;
// Each entry: [label, value, isHeat] — heat tints the number orange to draw
// attention to the metrics that actually need action.
const kpis = [
  ["Files",      t.fileCount.toLocaleString(),  false],
  ["Lines",      t.loc.toLocaleString(),        false],
  ["Size",       humanBytes(t.bytes),           false],
  ["Dead files", String(t.deadFiles),           t.deadFiles > 0],
  ["Hot spots",  String(t.hotspots),            t.hotspots > 0]
];
document.getElementById("kpis").innerHTML = kpis.map(function(c){
  const cls = "kpi" + (c[2] ? " heat" : "");
  return '<div class="' + cls + '"><div class="num">' + c[1] +
         '</div><div class="lbl">' + c[0] + '</div></div>';
}).join("");
document.getElementById("sub").textContent = DATA.projectPath;
const chip = document.getElementById("scanChip");
function refreshChip(){
  chip.textContent = "Scanned " + fmtAgo(DATA.generatedAt);
  chip.title = "Scan completed at " + new Date(DATA.generatedAt).toLocaleString();
}
refreshChip();
setInterval(refreshChip, 30000);

// Treemap recolor — walk the tree, paint each LEAF with a continuous orange
// ramp keyed to its LOC. Folders inherit color from their largest leaf via
// ECharts' default rollup, so the heat of a folder reads correctly without us
// having to compute per-folder aggregates here. (Folder-level cognitive heat
// requires data-layer changes; tracked as a follow-up.)
const RAMP = [[254,243,199],[253,186,116],[249,115,22],[194,65,12]];
function rampRgb(t){
  const last = RAMP.length - 1;
  const i = Math.min(last - 1, Math.max(0, Math.floor(t * last)));
  const f = t * last - i;
  const a = RAMP[i], b = RAMP[i+1];
  return [
    Math.round(a[0] + (b[0]-a[0])*f),
    Math.round(a[1] + (b[1]-a[1])*f),
    Math.round(a[2] + (b[2]-a[2])*f)
  ];
}
function rgbCss(c){ return "rgb(" + c[0] + "," + c[1] + "," + c[2] + ")"; }
// Pick near-black or near-white label text from the TILE'S OWN fill, not the
// page's dark/light mode. The treemap fill is the same orange ramp in both
// modes, so a mode-keyed text color goes invisible: the old labels rendered
// light `fg` on cream tiles (white-on-white headings) in dark mode and a fixed
// dark slate that vanished on the darkest brown tiles. Rec. 709 luma; the .58
// cutoff keeps the mid-orange tiles legible with dark text.
function contrastText(rgb){
  const luma = (0.2126*rgb[0] + 0.7152*rgb[1] + 0.0722*rgb[2]) / 255;
  return luma > 0.58 ? "#0f172a" : "#f8fafc";
}
function maxLeaf(node, m){
  if (!node.children || node.children.length === 0) return Math.max(m, node.value || 0);
  let cur = m;
  for (const c of node.children) cur = maxLeaf(c, cur);
  return cur;
}
// Paint each node's fill from its LOC, and set the label/upperLabel text color
// from that fill so headings stay legible regardless of page mode. Returns the
// node's [fillRgb, ratio] so a folder can adopt its hottest leaf's color — the
// header band the user sees — and contrast its title against it.
function paint(node, max){
  if (!node.children || node.children.length === 0) {
    const ratio = max > 0 ? (node.value || 0) / max : 0;
    const rgb = rampRgb(ratio);
    node.itemStyle = {
      color: rgbCss(rgb),
      borderRadius: 4,
      borderColor: dark ? "rgba(0,0,0,.45)" : "rgba(255,255,255,.7)",
      borderWidth: 1,
      gapWidth: 2
    };
    node.label = { color: contrastText(rgb) };
    return [rgb, ratio];
  }
  let hotRatio = -1, hotRgb = RAMP[0];
  for (const c of node.children) {
    const r = paint(c, max);
    if (r[1] > hotRatio) { hotRatio = r[1]; hotRgb = r[0]; }
  }
  // Folder header band adopts the hottest descendant's color (mirrors ECharts'
  // rollup) so its title contrasts against the band actually rendered.
  node.itemStyle = { color: rgbCss(hotRgb), gapWidth: 2, borderRadius: 6 };
  node.upperLabel = { color: contrastText(hotRgb) };
  return [hotRgb, hotRatio];
}

const treeRoot = DATA.folderTree || { name: "(root)", children: [] };
const max = maxLeaf(treeRoot, 0);
(treeRoot.children || []).forEach(function(c){ paint(c, max); });

const treemapEl = document.getElementById("treemap");
echarts.init(treemapEl).setOption({
  textStyle: { color: fg },
  tooltip: {
    backgroundColor: dark ? "#0f172a" : "#ffffff",
    borderColor: "#f97316",
    borderWidth: 1,
    textStyle: { color: fg, fontSize: 12 },
    formatter: function(p){
      return '<b>' + p.name + '</b><br/>' + (p.value || 0).toLocaleString() + " LOC";
    }
  },
  series: [{
    type: "treemap",
    name: treeRoot.name,
    data: treeRoot.children || [],
    leafDepth: 2,
    roam: false,
    breadcrumb: {
      show: true,
      itemStyle: { color: "transparent", borderColor: muted, textStyle: { color: fg } }
    },
    label: {
      show: true, formatter: "{b}",
      color: "#0f172a", fontSize: 11, fontWeight: 600
    },
    upperLabel: {
      show: true, height: 20,
      color: fg, fontSize: 11, fontWeight: 600
    },
    levels: [
      { itemStyle: { borderColor: muted, borderWidth: 0, gapWidth: 2 } },
      { itemStyle: { gapWidth: 2, borderRadius: 6 },
        upperLabel: { show: true, color: fg, backgroundColor: "rgba(0,0,0,.04)" } }
    ]
  }]
});
treemapEl.classList.remove("skeleton");

if (DATA.scatter.length) {
  const scatterEl = document.getElementById("scatter");
  echarts.init(scatterEl).setOption({
    textStyle: { color: fg },
    grid: { left: 50, right: 24, top: 24, bottom: 44, containLabel: true },
    tooltip: {
      backgroundColor: dark ? "#0f172a" : "#ffffff",
      borderColor: "#f97316",
      borderWidth: 1,
      textStyle: { color: fg, fontSize: 12 },
      formatter: function(p){
        return '<b>' + p.data[2] + '</b><br/>' +
               'churn: ' + p.data[0] + '<br/>cognitive: ' + p.data[1];
      }
    },
    xAxis: {
      name: "churn",
      nameTextStyle: { color: muted, fontSize: 11 },
      axisLabel: { color: muted },
      axisLine: { lineStyle: { color: muted } },
      splitLine: { lineStyle: { color: dark ? "rgba(148,163,184,.12)" : "rgba(15,23,42,.06)" } }
    },
    yAxis: {
      name: "cognitive",
      nameTextStyle: { color: muted, fontSize: 11 },
      axisLabel: { color: muted },
      axisLine: { lineStyle: { color: muted } },
      splitLine: { lineStyle: { color: dark ? "rgba(148,163,184,.12)" : "rgba(15,23,42,.06)" } }
    },
    series: [{
      type: "scatter",
      symbolSize: function(d){ return 6 + Math.sqrt((d[3]||0)) / 2; },
      itemStyle: {
        color: "#f97316",
        borderColor: dark ? "rgba(255,255,255,.2)" : "rgba(15,23,42,.18)",
        borderWidth: 1,
        shadowColor: "rgba(249,115,22,.4)", shadowBlur: 6
      },
      data: DATA.scatter.map(function(d){
        return [d.churn, d.cognitive, d.name, d.loc || 0];
      })
    }]
  });
  scatterEl.classList.remove("skeleton");
} else {
  document.getElementById("scatterPanel").style.display = "none";
}

// In a VS Code webview this lets a row click jump to the file; in a plain
// browser acquireVsCodeApi is absent, so clicks are simply inert.
const vscodeApi = (typeof acquireVsCodeApi === "function") ? acquireVsCodeApi() : null;
const tb = document.querySelector("#hot tbody");
function fillRows(rows){
  tb.innerHTML = "";
  rows.forEach(function(h){
    const tr = document.createElement("tr");
    tr.dataset.file = h.path;
    tr.title = "Click to open " + h.path;
    const cells = [
      ["fire", "🔥".repeat(h.fire)],
      ["path", h.path],
      ["n",    h.loc],
      ["n",    h.cognitive == null ? "" : h.cognitive],
      ["n",    h.mi == null ? "" : h.mi.toFixed(0)],
      ["n",    h.churn == null ? "" : h.churn],
      ["why",  h.reasons.join(", ")]
    ];
    cells.forEach(function(c){
      const td = document.createElement("td");
      td.className = c[0];
      td.textContent = c[1];
      tr.appendChild(td);
    });
    tb.appendChild(tr);
  });
}
// Render applies the current filter then the current sort, so the two compose.
const keys = ["fire","path","loc","cognitive","mi","churn","reasons"];
let filterText = "";
let sortKey = null;
const ths = document.querySelectorAll("#hot th");
function render(){
  let rows = DATA.hotspots;
  if (filterText){
    const q = filterText.toLowerCase();
    rows = rows.filter(function(h){
      return h.path.toLowerCase().indexOf(q) >= 0 ||
             h.reasons.join(" ").toLowerCase().indexOf(q) >= 0;
    });
  }
  if (sortKey){
    rows = rows.slice().sort(function(a, b){
      let av = a[sortKey], bv = b[sortKey];
      if (sortKey === "reasons"){ av = (av||[]).length; bv = (bv||[]).length; }
      if (av == null || typeof av === "number"){ return (bv||0) - (av||0); }
      return String(av).localeCompare(String(bv));
    });
  }
  fillRows(rows);
  // Visually pin the active sort column so the user can see what's sorted.
  ths.forEach(function(th, idx){
    th.classList.toggle("sort-active", keys[idx] === sortKey);
  });
}
render();
document.getElementById("filter").addEventListener("input", function(e){
  filterText = e.target.value; render();
});
tb.addEventListener("click", function(e){
  const tr = e.target.closest("tr");
  if (tr && tr.dataset.file && vscodeApi) {
    vscodeApi.postMessage({ type: "openFile", file: tr.dataset.file });
  }
});
ths.forEach(function(th, idx){
  th.addEventListener("click", function(){ sortKey = keys[idx]; render(); });
});

// Performance gravity table. Already sorted worst-first by the Dart side; the
// panel hides entirely when no feature carries a compound pattern (no false
// "all clear" table). Color keys the level so the eye lands on CRITICAL first.
(function(){
  const gravity = DATA.featureGravity || [];
  const panel = document.getElementById("gravityPanel");
  if (!gravity.length){ if (panel) panel.style.display = "none"; return; }
  const colors = { low: "#16a34a", medium: "#d97706", high: "#ea580c", critical: "#dc2626" };
  const gb = document.querySelector("#gravity tbody");
  gravity.forEach(function(f){
    const tr = document.createElement("tr");
    const color = colors[f.level] || muted;
    const cells = [
      ["n", f.gravityScore + "%"],
      ["why", f.level.toUpperCase()],
      ["path", f.feature],
      ["n", f.patternCount],
      ["n", f.fileCount]
    ];
    cells.forEach(function(c, i){
      const td = document.createElement("td");
      td.className = c[0];
      td.textContent = c[1];
      // Tint the gravity % and level cells by band.
      if (i < 2){ td.style.color = color; td.style.fontWeight = "600"; }
      tr.appendChild(td);
    });
    gb.appendChild(tr);
  });
})();
</script>
</body>
</html>
''';
