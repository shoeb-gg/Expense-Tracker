// Builds pop-up boards: takes a finished host board, lays a scrim and a pop-up over it, and adds the pop-up's logic.
// Usage: node build/overlay.js PopDate PopMonth ...   (reads build/pop/<Name>.pop.html, writes mockup/project/<Name>.dc.html)
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
const popDir = path.join(__dirname, 'pop');

// Shared by every pop-up: dates, colour mixes, and the few colours the older boards do not define.
const KIT = [
  '  popKit(t) {',
  "    const mix = (a, b, w) => '#' + [1, 3, 5].map((i) => Math.round(parseInt(a.slice(i, i + 2), 16) * w + parseInt(b.slice(i, i + 2), 16) * (1 - w)).toString(16).padStart(2, '0')).join('');",
  '    const dn = (y, m, d) => Math.round(Date.UTC(y, m, d) / 86400000);',
  '    const dt = (n) => new Date(n * 86400000);',
  "    const MS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];",
  "    const ML = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];",
  "    const WS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];",
  "    const WD = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];",
  "    const full = (n) => { const d = dt(n); return MS[d.getUTCMonth()] + ' ' + d.getUTCDate() + ', ' + d.getUTCFullYear(); };",
  "    const soft = t.accent + '2E';",
  '    const stub = mix(t.text3, t.surface2, 0.45);',
  '    // One choice in a list: the current one is tinted, ringed and ticked.',
  "    const opt = (on) => ({ on, bg: on ? soft : t.tile, ring: on ? 'inset 0 0 0 2px ' + t.accent : 'none', fw: on ? '800' : '600', dotBg: on ? t.accent : 'transparent', dotRing: on ? 'none' : 'inset 0 0 0 2px ' + stub });",
  '    return {',
  '      mix, dn, dt, MS, ML, WS, WD, full, opt, soft, stub,',
  '      TODAY: dn(2026, 9, 18),',
  "      bad: '#FF8C9A',",
  "      onBad: '#2A0B12',",
  '      dim: mix(t.text3, t.surface2, 0.5),',
  '      grab: mix(t.text3, t.surface2, 0.4),',
  '      off: mix(t.tile, t.surface2, 0.5)',
  '    };',
  '  }',
  '',
  '  // Swiping pulls the neighbouring page into view. Dragging the finger left-to-right or top-to-bottom reveals what is',
  '  // on the left or above (the previous one); dragging right-to-left or bottom-to-top reveals the next one.',
  '  popSwipe(back, forward) {',
  '    return {',
  '      down: (e) => { this._sw = { x: e.clientX, y: e.clientY }; },',
  '      up: (e) => {',
  '        const s = this._sw;',
  '        this._sw = null;',
  '        if (!s) return;',
  '        const dx = e.clientX - s.x;',
  '        const dy = e.clientY - s.y;',
  '        const far = Math.abs(dx) > Math.abs(dy) ? dx : dy;',
  '        if (Math.abs(far) < 24) return;',
  '        this._swiped = Date.now();',
  '        if (far > 0) back(); else forward();',
  '      }',
  '    };',
  '  }',
  '',
  '  // A tap that ends a swipe is not a tap.',
  '  popTap(fn) {',
  '    return () => { if (Date.now() - (this._swiped || 0) > 350) fn(); };',
  '  }'
].join('\n');

function build(name) {
  const src = fs.readFileSync(path.join(popDir, name + '.pop.html'), 'utf8').replace(/\r\n/g, '\n');
  const m = src.match(/^<!--@POP (\{.*\})-->\n([\s\S]*?)\n<!--@LOGIC-->\n([\s\S]*)$/);
  if (!m) throw new Error(name + ': pop file needs <!--@POP {...}--> on line 1 and a <!--@LOGIC--> line');
  const cfg = JSON.parse(m[1]);
  const markup = m[2].replace(/\s+$/, '');
  const logic = m[3].replace(/\s+$/, '');
  let s = fs.readFileSync(path.join(proj, cfg.host + '.dc.html'), 'utf8').replace(/\r\n/g, '\n');
  const once = (re, to, what) => {
    const c = (s.match(new RegExp(re.source, 'g')) || []).length;
    if (c !== 1) throw new Error(name + ': ' + what + ' matched ' + c + ' times in ' + cfg.host);
    s = s.replace(re, to);
  };
  once(/<title>[^<]*<\/title>/, () => '<title>' + cfg.title + '</title>', 'title');
  once(/icon_names=([a-z0-9_,]*)&amp;display=block/, (all, list) => 'icon_names=' + Array.from(new Set(list.split(',').concat((cfg.icons || '').split(',')).map((x) => x.trim()).filter(Boolean))).sort().join(',') + '&amp;display=block', 'icon list');
  if (cfg.height) {
    once(/height: \d+px; position: relative; overflow: hidden/, () => 'height: ' + cfg.height + 'px; position: relative; overflow: hidden', 'board height');
    once(/"\$preview":\{"width":360,"height":\d+\}/, () => '"$preview":{"width":360,"height":' + cfg.height + '}', 'preview height');
  }
  // Shows the host as if it had been scrolled down by this much.
  if (cfg.scroll) once(/<\/style>\n<\/helmet>/, () => 'main>:first-child{margin-top:-' + cfg.scroll + 'px}\n</style>\n</helmet>', 'helmet style');
  (cfg.replace || []).forEach(([a, b]) => {
    const c = s.split(a).length - 1;
    if (c !== 1) throw new Error(name + ': replace text matched ' + c + ' times: ' + a.slice(0, 60));
    s = s.split(a).join(b);
  });
  once(/\n<\/div>\n<\/x-dc>/, () => '\n' + markup + '\n</div>\n</x-dc>', 'board end');
  once(/\n  renderVals\(\) \{\n/, () => '\n  renderVals() {\n    const v = this.popHostVals();\n    v.pop = this.popVals(v.t, v);\n    return v;\n  }\n\n' + KIT + '\n\n' + logic + '\n\n  popHostVals() {\n', 'renderVals');
  fs.writeFileSync(path.join(proj, name + '.dc.html'), s);
  console.log('built ' + name + '.dc.html on ' + cfg.host + '  ' + s.length + ' bytes');
}

const names = process.argv.slice(2);
names.forEach(build);

// The year grid is the month pop-up opened on its other view.
if (names.includes('PopMonth')) {
  let s = fs.readFileSync(path.join(proj, 'PopMonth.dc.html'), 'utf8');
  const a = "const POP_VIEW = 'months';";
  if (s.split(a).length !== 2) throw new Error('PopYear: view marker not found once');
  s = s.split(a).join("const POP_VIEW = 'years';").replace(/<title>[^<]*<\/title>/, '<title>Home, pick a year</title>');
  fs.writeFileSync(path.join(proj, 'PopYear.dc.html'), s);
  console.log('built PopYear.dc.html from PopMonth');
}
