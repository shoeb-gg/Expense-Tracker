// Static renderer for a .dc.html board: runs its renderVals() and expands the template (sc-for, sc-if, {{holes}})
// in headless Chrome, so layout can be measured and screenshotted without the canvas runtime.
// Usage: node render.js <board.dc.html> <out.html> [stateJson] [probeJsFile]
const fs = require('fs');
const [src, out, stateJson, probeFile, propsJson] = process.argv.slice(2);
const html = fs.readFileSync(src, 'utf8');
const xdc = html.split('<x-dc>')[1].split('</x-dc>')[0];
const helmet = (xdc.match(/<helmet>([\s\S]*?)<\/helmet>/) || [, ''])[1];
const tpl = xdc.replace(/<helmet>[\s\S]*?<\/helmet>/, '');
const script = html.split('data-dc-script')[1].split('>').slice(1).join('>').split('</script>')[0];
const probe = probeFile ? fs.readFileSync(probeFile, 'utf8') : '';
// Optional: RENDER_SHIM=<file.js> injects test-only code after the board script and before renderVals() runs.
const shim = process.env.RENDER_SHIM ? fs.readFileSync(process.env.RENDER_SHIM, 'utf8') + '\n' : '';
const page = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>render</title>
${helmet}
</head><body style="margin:0;background:#000">
<template id="tpl">${tpl}</template>
<div id="mount"></div>
<pre id="out" style="display:none">PENDING</pre>
<script>
class DCLogic { constructor() { this.props = {}; this.state = null; } setState(p) { this.state = Object.assign({}, this.state || {}, p); } }
${script}
${shim}const comp = new Component();
comp.state = ${stateJson || 'null'};
comp.props = ${propsJson || '{}'};
const vals = comp.renderVals();
function get(scope, path) { path = path.trim(); if (path === 'true') return true; if (path === 'false') return false; return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), scope); }
function fill(str, scope) { return str.replace(/\\{\\{([^}]+)\\}\\}/g, (_, p) => { const v = get(scope, p); return v == null ? '' : String(v); }); }
function build(node, scope, outEl) {
  if (node.nodeType === 3) { outEl.appendChild(document.createTextNode(fill(node.nodeValue, scope))); return; }
  if (node.nodeType !== 1) return;
  const tag = node.tagName.toLowerCase();
  if (tag === 'sc-for') { const list = get(scope, node.getAttribute('list').replace(/[{}]/g, '')) || []; const as = node.getAttribute('as'); list.forEach((item, i) => { const s = Object.assign({}, scope, { [as]: item, $index: i }); node.childNodes.forEach((c) => build(c, s, outEl)); }); return; }
  if (tag === 'sc-if') { if (get(scope, node.getAttribute('value').replace(/[{}]/g, ''))) node.childNodes.forEach((c) => build(c, scope, outEl)); return; }
  const el = node.namespaceURI === 'http://www.w3.org/2000/svg' ? document.createElementNS(node.namespaceURI, node.tagName) : document.createElement(tag);
  for (const a of node.attributes) {
    if (/^on/i.test(a.name)) continue;
    const whole = a.value.match(/^\\{\\{([^}]+)\\}\\}$/);
    if (whole) { const v = get(scope, whole[1]); if (v === false || v == null) { if (a.name.indexOf('aria-') === 0) el.setAttribute(a.name, 'false'); continue; } el.setAttribute(a.name, v === true ? (a.name.indexOf('aria-') === 0 ? 'true' : '') : String(v)); }
    else el.setAttribute(a.name, fill(a.value, scope));
  }
  node.childNodes.forEach((c) => build(c, scope, el));
  outEl.appendChild(el);
}
document.getElementById('tpl').content.childNodes.forEach((c) => build(c, vals, document.getElementById('mount')));
${probe}
</script>
</body></html>`;
fs.writeFileSync(out, page);
console.log('wrote', out);
