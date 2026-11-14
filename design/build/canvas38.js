// Adds the "Pockets" row to the canvas, starting from the copy that is live now. Safe to run again.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
const c = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fresh', 'project', 'canvas.json'), 'utf8'));
const Y = -5320;
const ROW = [
  ['PocketHome', 'Home: the pocket switch'],
  ['PocketSwitch', 'Home: switch pocket'],
  ['PocketAddExpense', 'Add expense: which pocket'],
  ['PocketPick', 'Add expense: choose the pocket'],
  ['PocketEditExpense', 'Edit expense: which pocket'],
  ['PocketMove', 'Edit expense: move to another pocket'],
  ['PocketList', 'Pockets'],
  ['PocketAdd', 'Add pocket'],
  ['PocketEdit', 'Edit pocket'],
  ['PocketDelete', 'Pockets: delete a pocket'],
  ['PocketSettings', 'Settings: the Pockets row']
];
const mine = new Set(ROW.map(([n]) => n + '.dc.html'));
Object.keys(c.boards).forEach((k) => { if (mine.has(k)) delete c.boards[k]; });
c.order = c.order.filter((k) => !mine.has(k));
const missing = [];
ROW.forEach(([name, title], i) => {
  if (!fs.existsSync(path.join(proj, name + '.dc.html'))) { missing.push(name); return; }
  c.boards[name + '.dc.html'] = { h: 780, is_interactive: true, title, w: 360, x: i * 440, y: Y };
  c.order.push(name + '.dc.html');
});
c.notes.rowK = { kind: 'title1', maxW: (ROW.length - 1) * 440 + 360, text: 'Pockets', w: 240, x: 0, y: Y - 300 };
if (c.noteOrder && c.noteOrder.indexOf('rowK') < 0) c.noteOrder.push('rowK');
fs.writeFileSync(path.join(proj, 'canvas.json'), JSON.stringify(c, null, 2) + '\n');
console.log('Pockets row: ' + (ROW.length - missing.length) + ' boards' + (missing.length ? ', missing: ' + missing.join(', ') : ''));
