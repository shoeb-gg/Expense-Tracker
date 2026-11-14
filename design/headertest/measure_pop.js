// node measure_pop.js <Board> <name> [stateJson] [propsJson]
// Renders a pop-up board with probe_pop.js in headless Chrome, prints a compact report and flags, writes
// p_<Board>_<name>.html/.json and a 2x screenshot p_<Board>_<name>.png.
// Env: SHOT=0 skips the png, ITEMS=1 lists every text run and control, HEIGHT=<px> overrides the board height,
//      RENDER_SHIM=<file.js> is passed on to render.js (test-only code run before renderVals).
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const here = __dirname;
const [boardName, name = 'default', state = '{}', props = '{}'] = process.argv.slice(2);
const board = path.join(here, '..', 'mockup', 'project', boardName + '.dc.html');
const stem = path.join(here, 'p_' + boardName + '_' + name);
const log = execFileSync('node', [path.join(here, 'render.js'), board, stem + '.html', state, path.join(here, 'probe_pop.js'), props], { encoding: 'utf8' });
const chrome = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const url = 'file:///' + (stem + '.html').replace(/\\/g, '/');
const H = process.env.HEIGHT || (/height: (\d+)px; position: relative; overflow: hidden/.exec(fs.readFileSync(board, 'utf8')) || [0, '780'])[1];
const common = ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--window-size=360,' + H, '--virtual-time-budget=9000'];
const dom = execFileSync(chrome, common.concat(['--dump-dom', url]), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const m = /<pre id="out"[^>]*>([\s\S]*?)<\/pre>/.exec(dom);
if (!m || m[1] === 'PENDING') { console.log('## ' + boardName + ' / ' + name + '  NO PROBE OUTPUT (page script probably threw; try: render and open ' + stem + '.html)'); process.exit(1); }
const txt = m[1].replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
fs.writeFileSync(stem + '.json', txt);
const o = JSON.parse(txt);
if (o.error) { console.log('## ' + boardName + ' / ' + name + '  PROBE ERROR ' + o.error.slice(0, 800)); process.exit(1); }
const bx = (b) => 'x' + b.l + '-' + b.r + ' y' + b.t + '-' + b.b + ' (' + b.w + 'x' + b.h + ')';
if (o.nopop) {
  console.log('## ' + boardName + ' / ' + name + '  board ' + o.board.w + 'x' + o.board.h + '  NO [data-pop] IN THIS STATE');
} else {
  const p = o.pop;
  console.log('## ' + boardName + ' / ' + name + '  board ' + o.board.w + 'x' + o.board.h + '  ' + p.kind + ' panel "' + p.label + '" ' + bx(p.panel) + '  centre dx ' + p.centre.dx + ' dy ' + p.centre.dy + '  scrim above ' + p.scrimAbove + ' below ' + p.scrimBelow + '  fonts ' + JSON.stringify(o.fonts));
  const g = o.gaps;
  console.log(' padding L' + p.padL + ' R' + p.padR + ' | min gap to panel edge: L' + g.toPanelEdgeL + ' (' + g.byL + ') R' + g.toPanelEdgeR + ' (' + g.byR + ') | to content edge: L' + g.toContentEdgeL + ' R' + g.toContentEdgeR + ' | text only L' + g.textMinL + ' R' + g.textMinR + (g.ctrlMinL !== undefined ? ' | controls only L' + g.ctrlMinL + ' R' + g.ctrlMinR : ''));
  console.log(' rows (direct blocks; box l-r, controls l-r, ink l-r) modes box ' + o.rowModes.boxL + '-' + o.rowModes.boxR + ' controls ' + o.rowModes.ctrlL + '-' + o.rowModes.ctrlR + ':');
  o.rows.forEach((r) => console.log('   ' + (r.label + '                        ').slice(0, 24) + ' x' + r.l + '-' + r.r + ' y' + r.t + '-' + r.b + (r.nCtrl ? ' ctrl(' + r.nCtrl + ') ' + r.ctrlL + '-' + r.ctrlR : '') + (r.inkL !== null ? ' ink ' + r.inkL + '-' + r.inkR : '') + (r.decor ? ' [decor]' : '')));
  console.log(' counts: ' + o.items.length + ' text runs, ' + o.controls.length + ' controls');
  console.log(' flags: ' + (o.flags.length ? '\n   ' + o.flags.join('\n   ') : 'none'));
  if (o.notes.length) console.log(' notes:\n   ' + o.notes.join('\n   '));
  if (process.env.ITEMS === '1') {
    console.log(' text runs:\n   ' + o.items.map((i) => (i.kind === 'text' ? '' : i.kind + ' ') + '"' + i.text + '" ' + i.fs + 'px w' + i.fw + ' x' + i.l + '-' + i.r + ' y' + i.t + '-' + i.b + (i.lines > 1 ? ' lines' + i.lines : '')).join('\n   '));
    console.log(' controls:\n   ' + o.controls.map((c) => c.tag + ' [' + c.label + '] x' + c.l + '-' + c.r + ' y' + c.t + '-' + c.b + ' ' + c.w + 'x' + c.h).join('\n   '));
  }
}
if (process.env.SHOT !== '0') { execFileSync(chrome, common.concat(['--force-device-scale-factor=2', '--screenshot=' + stem + '.png', url]), { encoding: 'utf8' }); console.log(' screenshot: ' + stem + '.png'); }
