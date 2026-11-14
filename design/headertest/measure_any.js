// node measure_any.js <Board> <name> [stateJson] [propsJson]
// Renders a new-look board, measures it with probe_generic.js in headless Chrome, prints a compact report,
// and saves a 2x screenshot as g_<Board>_<name>.png (SHOT=0 skips it; ITEMS=1 lists every text run).
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const here = __dirname;
const [boardName, name = 'default', state = '{}', props = '{}'] = process.argv.slice(2);
const board = path.join(here, '..', 'mockup', 'project', boardName + '.dc.html');
const stem = path.join(here, 'g_' + boardName + '_' + name);
const log = execFileSync('node', [path.join(here, 'render.js'), board, stem + '.html', state, path.join(here, 'probe_generic.js'), props], { encoding: 'utf8' });
const chrome = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const url = 'file:///' + (stem + '.html').replace(/\\/g, '/');
const H = (/height: (\d+)px; position: relative; overflow: hidden/.exec(fs.readFileSync(board, 'utf8')) || [0, '800'])[1];
const common = ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--window-size=360,' + H, '--virtual-time-budget=9000'];
const dom = execFileSync(chrome, common.concat(['--dump-dom', url]), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const m = /<pre id="out"[^>]*>([\s\S]*?)<\/pre>/.exec(dom);
if (!m) { console.log('NO OUT ELEMENT; render log: ' + log.trim().slice(0, 300)); process.exit(1); }
const txt = m[1].replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
fs.writeFileSync(stem + '.json', txt);
const o = JSON.parse(txt);
if (o.error) { console.log('PROBE ERROR ' + o.error.slice(0, 800)); process.exit(1); }
console.log('## ' + boardName + ' / ' + name + '  board ' + o.root + '  main ' + o.main.clientH + '/' + o.main.scrollH + '  fonts ' + JSON.stringify(o.fonts));
console.log(' top: ' + o.top.join(' | '));
console.log(' blocks: ' + o.blocks.join(' | '));
console.log(' gaps: ' + o.gaps.join(',') + ' first ' + o.firstGap + ' | ' + JSON.stringify(o.nav || o.bottom));
console.log(' text lefts: ' + o.textLefts);
console.log(' text rights: ' + o.textRights);
console.log(' flags: ' + (o.flags.length ? '\n   ' + o.flags.join('\n   ') : 'none'));
if (process.env.ITEMS === '1') console.log(' items:\n   ' + o.items.join('\n   '));
if (process.env.SHOT !== '0') { execFileSync(chrome, common.concat(['--force-device-scale-factor=2', '--screenshot=' + stem + '.png', url]), { encoding: 'utf8' }); }
