// Fixes from the Opus review of the dialogs: delete-all wording, a rose-tinted locked button, clearer grouping; Settings wording.
const fs = require('fs');
const path = require('path');
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
patch(path.join(__dirname, 'pop', 'PopDeleteAll.pop.html'), [
  ["They will be erased from this phone. This can't be undone.", "This can't be undone."],
  ['onClick="{{pop.flip}}" style="margin-top: 8px; height: 48px; border: 0; border-radius: 16px; padding: 0 16px; background: transparent;', 'onClick="{{pop.flip}}" style="margin-top: 16px; height: 48px; border: 0; border-radius: 16px; padding: 0 16px; background: {{pop.rowBg}};'],
  ["      delBg: ok ? k.bad : k.off,\n      delFg: ok ? k.onBad : k.dim,", "      // Ticked, the row takes a faint rose tint. Locked, the button is a faded version of the red one, so it is clear what the tick unlocks.\n      rowBg: ok ? k.mix(k.bad, t.surface2, 0.1) : 'transparent',\n      delBg: ok ? k.bad : k.mix(k.bad, t.surface2, 0.14),\n      delFg: ok ? k.onBad : k.mix(k.bad, t.surface2, 0.5),"]
]);
patch(path.join(__dirname, 'NewSettings.part.html'), [['>This cannot be undone</span>', '>This can’t be undone</span>']]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
