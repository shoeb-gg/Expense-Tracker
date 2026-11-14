// Which category tile is marked as in use, in each state of the Add expense boards.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
function load(name, state) {
  const s = fs.readFileSync(path.join(proj, name + '.dc.html'), 'utf8');
  const m = s.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/);
  class DCLogic { constructor() { this.state = state || null; this.props = {}; } setState(p) { this.state = Object.assign({}, this.state || {}, p); } }
  const C = new Function('DCLogic', m[1] + '\nreturn Component;')(DCLogic);
  return new C();
}
const CASES = [['NewAdd', null, 'as it opens'], ['NewAdd', { typed: 'coffee' }, 'typed coffee'], ['NewAddKeypad', null, 'keypad'], ['NewAddQuick', null, 'coffee 120'], ['NewAddQuickNew', null, 'saree 12000'], ['NewAddQuickNew', { picked: 'gifts' }, 'saree 12000 + Gifts'], ['NewEdit', null, 'edit'], ['NewAddCalc', null, 'four keys']];
for (const [name, state, what] of CASES) {
  const v = load(name, state).renderVals();
  const on = v.tiles.filter((c) => c.on);
  console.log((name + ' (' + what + ')').padEnd(38) + ' marked: ' + (on.map((c) => c.name + ' fill ' + c.tile).join(', ') || 'none') + ' | panel ' + !!v.showPanel + ' quick ' + !!v.showQuick + ' | card: ' + (v.qv.show ? v.qv.name + ' / ' + v.qv.amount + (v.qv.hasNote ? ' / note: ' + v.qv.hint : '') : v.qv.guideTitle + ' / ' + v.qv.guideSub));
}
