// Adds the row of pop-ups and small screens to the canvas. Safe to run again.
const fs = require('fs');
const path = require('path');
const f = path.join(__dirname, '..', 'mockup', 'project', 'canvas.json');
const c = JSON.parse(fs.readFileSync(f, 'utf8'));
const Y = -4040;
const ROW = [
  ['PopDate', 780, 'Add expense: pick a date'],
  ['PopMonth', 780, 'Home: pick a month'],
  ['PopYear', 780, 'Home: pick a year'],
  ['PopRange', 780, 'Charts: custom range'],
  ['NewAddQuickNew', 780, 'Type to add: a new word'],
  ['PopQuickCat', 780, 'Type to add: choose a category'],
  ['PopPhoto', 780, 'Edit expense: receipt photo'],
  ['NewPhoto', 780, 'Receipt photo'],
  ['PopWeekStart', 780, 'Settings: first day of the week'],
  ['PopNumber', 780, 'Settings: number format'],
  ['PopCalc', 780, 'Settings: calculator keys'],
  ['NewAddCalc', 780, 'Add expense: four calculator keys'],
  ['NewExport', 780, 'Export'],
  ['NewImport', 780, 'Import: step 1'],
  ['NewImportMatch', 780, 'Import: step 2'],
  ['NewImportReview', 900, 'Import: step 3'],
  ['PopDeleteAll', 780, 'Settings: delete all data']
];
const have = ROW.filter(([name]) => fs.existsSync(path.join(path.dirname(f), name + '.dc.html')));
const mine = new Set(ROW.map(([name]) => name + '.dc.html'));
Object.keys(c.boards).forEach((k) => { if (mine.has(k)) delete c.boards[k]; });
c.order = c.order.filter((k) => !mine.has(k));
have.forEach(([name, h, title], i) => {
  c.boards[name + '.dc.html'] = { x: i * 440, y: Y, w: 360, h, title, is_interactive: true };
  c.order.push(name + '.dc.html');
});
c.notes.rowP = { x: 0, y: Y - 300, text: 'Pop-ups and small screens', kind: 'title1', maxW: (have.length - 1) * 440 + 360 };
fs.writeFileSync(f, JSON.stringify(c, null, 2) + '\n');
console.log('row has ' + have.length + ' of ' + ROW.length + ' boards; missing: ' + (ROW.filter((r) => !have.includes(r)).map((r) => r[0]).join(', ') || 'none'));
