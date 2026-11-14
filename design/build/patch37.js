// Pocket list, second-pass fixes: the default pocket's row is taller so its three lines breathe,
// "How pockets work" is two sentences, and the delete warning says what else is deleted.
const fs = require('fs');
const path = require('path');
let problems = 0;
const f = path.join(__dirname, 'PocketList.part.html');
let s = fs.readFileSync(f, 'utf8').replace(/\r\n/g, '\n');
const PAIRS = [
  ['<span style="flex: 1; min-width: 0; height: 68px; margin-right: 16px; box-shadow: {{r.divider}}; display: flex; align-items: center">', '<span style="flex: 1; min-width: 0; height: {{r.h}}; margin-right: 16px; box-shadow: {{r.divider}}; display: flex; align-items: center">'],
  ['      locked: !!p.locked,\n', "      locked: !!p.locked,\n      h: p.locked ? '80px' : '68px',\n"],
  ['\n        <span style="font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">Categories and settings are the same in every pocket.</span>', ''],
  ["confirmWhat: n ? count(n) + ' and their photos' : 'This pocket is empty.',", "confirmWhat: n ? 'Also deletes ' + count(n) + ' and photos' : 'This pocket is empty.',"]
];
for (const [a, b] of PAIRS) {
  const c = s.split(a).length - 1;
  if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches): ' + a.slice(0, 70)); continue; }
  s = s.split(a).join(b);
}
fs.writeFileSync(f, s);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
