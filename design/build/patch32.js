// Shorter note for a new word (it wrapped), and the canvas gains the opening-state board.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
let problems = 0;
['NewAdd', 'NewAddKeypad', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => {
  const f = path.join(proj, n + '.dc.html');
  let s = fs.readFileSync(f, 'utf8');
  const re = /'Select a category above\. Next time it.s automatic\.'/g;
  const c = (s.match(re) || []).length;
  if (c !== 1) { problems++; console.log('PROBLEM (' + c + ') in ' + n); return; }
  fs.writeFileSync(f, s.replace(re, "'Select a category above.'"));
});
// Canvas, starting from the copy that is live now.
const c = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fresh', 'project', 'canvas.json'), 'utf8'));
if (!c.boards['NewAddKeypad.dc.html']) {
  const Y = c.boards['NewAdd.dc.html'].y;
  Object.values(c.boards).forEach((b) => { if (b.y === Y && b.x >= 440) b.x += 440; });
  c.boards['NewAdd.dc.html'] = Object.assign(c.boards['NewAdd.dc.html'], { x: 440, title: 'Add expense: when it opens' });
  c.boards['NewAddKeypad.dc.html'] = { h: 780, is_interactive: true, title: 'Add expense: keypad', w: 360, x: 880, y: Y };
  c.order.splice(c.order.indexOf('NewAdd.dc.html') + 1, 0, 'NewAddKeypad.dc.html');
  c.notes.row0.maxW += 440;
  console.log('canvas: opening-state board at x=440, keypad at x=880, row now ' + c.notes.row0.maxW + ' wide');
}
fs.writeFileSync(path.join(proj, 'canvas.json'), JSON.stringify(c, null, 2) + '\n');
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
