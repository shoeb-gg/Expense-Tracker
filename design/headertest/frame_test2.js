// Scrollbar check for any board: loads it in an iframe 1px smaller than its design size (what a zoomed canvas can produce)
// and reports frame-level scrollbars and inner list scrollbars.
// Usage: node frame_test2.js <dir> Name:w:h [Name:w:h ...]
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const [dir, ...items] = process.argv.slice(2);
const shrink = Number(process.env.SHRINK || 1);
let bad = 0;
for (const item of items) {
  const [name, w, h] = item.split(':');
  const src = path.join(dir, name + '.dc.html');
  const inner = path.join(__dirname, 'ft2_inner_' + name + '.html');
  const probe = path.join(__dirname, 'ft2_probe.js');
  fs.writeFileSync(probe, `
    setTimeout(() => {
      const root = document.querySelector('#mount > div');
      const m = document.querySelector('#mount main');
      parent.postMessage({ viewW: innerWidth, viewH: innerHeight, clientW: document.documentElement.clientWidth, clientH: document.documentElement.clientHeight, rootW: root.offsetWidth, rootH: root.offsetHeight, mainBar: m ? m.offsetWidth - m.clientWidth : 0, mainScrolls: m ? m.scrollHeight - m.clientHeight : 0 }, '*');
    }, 2500);
  `);
  execFileSync('node', [path.join(__dirname, 'render.js'), src, inner, 'null', probe, '{}']);
  const outer = path.join(__dirname, 'ft2_outer_' + name + '.html');
  fs.writeFileSync(outer, `<!doctype html><html><body style="margin:20px;background:#333"><iframe src="${path.basename(inner)}" style="width:${w - shrink}px;height:${h - shrink}px;border:0;display:block"></iframe><pre id="out" style="display:none">PENDING</pre><script>addEventListener('message', (e) => { document.getElementById('out').textContent = JSON.stringify(e.data); });</script></body></html>`);
  const dom = execFileSync(chrome, ['--headless=new', '--disable-gpu', '--allow-file-access-from-files', '--virtual-time-budget=15000', '--window-size=600,' + (Number(h) + 100), '--dump-dom', 'file:///' + outer.replace(/\\/g, '/')], { encoding: 'utf8', maxBuffer: 1 << 26 });
  const mm = dom.match(/<pre id="out"[^>]*>([\s\S]*?)<\/pre>/);
  if (!mm || mm[1] === 'PENDING') { console.log(name.padEnd(12), 'NO DATA'); bad++; continue; }
  const o = JSON.parse(mm[1].replace(/&quot;/g, '"').replace(/&amp;/g, '&'));
  const frameBar = o.clientW < o.viewW || o.clientH < o.viewH;
  if (frameBar || o.mainBar > 0 || o.rootW != w || o.rootH != h) bad++;
  console.log(name.padEnd(12), 'design', o.rootW + 'x' + o.rootH, '| frame', o.viewW + 'x' + o.viewH, '| frame scrollbars:', frameBar ? 'YES' : 'none', '| inner list scrollbar:', o.mainBar > 0 ? 'YES (' + o.mainBar + 'px)' : 'none', '| hidden list content below the fold:', o.mainScrolls > 0 ? o.mainScrolls + 'px' : 'none');
}
console.log(bad ? bad + ' BOARD(S) WITH PROBLEMS' : 'ALL CLEAN');
