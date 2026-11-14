// Runs the boards' own logic in node and swipes across them, to prove the direction rule.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
function load(name) {
  const s = fs.readFileSync(path.join(proj, name + '.dc.html'), 'utf8');
  const m = s.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/);
  class DCLogic { constructor() { this.state = null; this.props = {}; } setState(p) { this.state = Object.assign({}, this.state || {}, p); } }
  const C = new Function('DCLogic', m[1] + '\nreturn Component;')(DCLogic);
  return new C();
}
const swipe = (c, get, dx, dy) => { const v = c.renderVals(); const h = get(v); h.down({ clientX: 200, clientY: 300 }); h.up({ clientX: 200 + dx, clientY: 300 + dy }); };
const MOVES = [['finger moves left-to-right', 90, 0], ['finger moves right-to-left', -90, 0], ['finger moves top-to-bottom', 0, 90], ['finger moves bottom-to-top', 0, -90], ['tiny move', 10, 5]];
const CASES = [
  ['PopDate', (v) => ({ down: v.pop.swDown, up: v.pop.swUp }), (v) => v.pop.month],
  ['PopMonth', (v) => ({ down: v.pop.swDown, up: v.pop.swUp }), (v) => v.pop.year],
  ['PopYear', (v) => ({ down: v.pop.swDown, up: v.pop.swUp }), (v) => v.pop.year],
  ['NewCalendar', (v) => ({ down: v.swDown, up: v.swUp }), (v) => v.monthLabel]
];
for (const [name, get, label] of CASES) {
  const out = [];
  for (const [what, dx, dy] of MOVES) {
    const c = load(name);
    const before = label(c.renderVals());
    swipe(c, get, dx, dy);
    out.push(what + ': ' + before + ' -> ' + label(c.renderVals()));
  }
  console.log(name + '\n  ' + out.join('\n  '));
}
// A tap straight after a swipe must not pick a day.
{
  const c = load('PopDate');
  swipe(c, (v) => ({ down: v.pop.swDown, up: v.pop.swUp }), -90, 0);
  const v = c.renderVals();
  const head = v.pop.head;
  v.pop.days[10].pick();
  console.log('PopDate tap right after a swipe: ' + (c.renderVals().pop.head === head ? 'ignored (good)' : 'PICKED A DAY (bad)'));
}
