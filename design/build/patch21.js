// Fixes after the first measuring pass: the Add boards format amounts with pretty() (their kit has no fmt), shorter hint,
// tidier pop-up wording, the category sheet's labels share one slot, and Settings sits scrolled to the right card.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
let problems = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  for (const [a, b] of pairs) {
    const c = s.split(a).length - 1;
    if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 70)); continue; }
    s = s.split(a).join(b);
  }
  fs.writeFileSync(file, s);
}
const QUICK = [
  ["amount: show ? K.fmt(q.amount) : '',", "amount: show ? this.pretty(String(q.amount)) : '',"],
  ["'New word. Pick its category once and the app will remember it.'", "'New word. Pick its category once.'"]
];
['NewAdd', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), QUICK));
patch(path.join(__dirname, 'patch20.js'), [
  ["\"      amount: show ? K.fmt(q.amount) : '',\",", "\"      amount: show ? this.pretty(String(q.amount)) : '',\","],
  ["'New word. Pick its category once and the app will remember it.'", "'New word. Pick its category once.'"]
]);

const pop = (n) => path.join(__dirname, 'pop', n + '.pop.html');
patch(pop('PopRange'), [
  ['<span style="margin: 0 4px; font-size: 17px;', '<span style="font-size: 17px;'],
  ['<span style="margin: 2px 4px 0; font-size: 13.5px;', '<span style="margin-top: 2px; font-size: 13.5px;']
]);
patch(pop('PopWeekStart'), [
  ['The calendar and the weekly chart start on this day.', 'Used by the calendar and the weekly chart.'],
  ['"scroll":440', '"scroll":432']
]);
patch(pop('PopNumber'), [
  ['How amounts are written everywhere in the app.', 'How amounts are written across the app.'],
  ['"scroll":900', '"scroll":948']
]);
patch(pop('PopCalc'), [['"scroll":900', '"scroll":948']]);
patch(pop('PopQuickCat'), [
  // Every label gets a two-line slot and sits in the middle of it, so the emojis line up whether the name is one line or two.
  ['flex-direction: column; align-items: center; justify-content: center; gap: 4px; cursor: pointer">', 'flex-direction: column; align-items: center; justify-content: center; gap: 2px; cursor: pointer">'],
  ['<span style="font-size: 12px; line-height: 14px; font-weight: 600; text-align: center">{{c.name}}</span>', '<span style="height: 28px; display: flex; align-items: center; font-size: 12px; line-height: 14px; font-weight: 600; text-align: center">{{c.name}}</span>']
]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
