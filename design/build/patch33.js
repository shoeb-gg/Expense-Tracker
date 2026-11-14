// From the Opus check: the selected tile is lit from inside as well, the glow is a little stronger,
// a known word lights its tile as soon as it is typed, and two wording fixes on the guide card.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
let problems = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  for (const [a, b] of pairs) {
    if (a instanceof RegExp) {
      const c = (s.match(new RegExp(a.source, 'g')) || []).length;
      if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.source.slice(0, 70)); continue; }
      s = s.replace(a, b);
      continue;
    }
    const c = s.split(a).length - 1;
    if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 70)); continue; }
    s = s.split(a).join(b);
  }
  fs.writeFileSync(file, s);
}
const BLOCK = [
  '    // While a typed expense is on show, the screen stays in type-to-add mode: tapping a category tile sets the category',
  '    // of that expense instead of opening the keypad.',
  '    if (v.qv.show) {',
  '      v.showPanel = false;',
  '      v.showQuick = true;',
  '    }',
  '    // The tile of the category in use is marked, whether the app guessed it from the typed word or the user chose it.',
  "    const inUse = v.qv.show ? (v.qv.known ? v.qv.name : '') : v.qv.guess;",
  '    v.tiles.forEach((c) => {',
  '      if (!inUse || c.name !== inUse) return;',
  '      c.on = true;',
  "      c.ring = '0 0 0 3px ' + v.t.bg + ', 0 0 0 5px ' + v.t.accent + ', 0 0 18px 7px ' + v.t.accent + '96';",
  '      c.labelColor = v.t.accent;',
  "      c.fw = '800';",
  '    });',
  '    // A selected tile is ringed, glows, and is lit from inside: a little of the accent colour is mixed into its fill.',
  "    const lit = '#' + [1, 3, 5].map((i) => Math.round(parseInt(v.t.accent.slice(i, i + 2), 16) * 0.15 + parseInt(v.t.tile.slice(i, i + 2), 16) * 0.85).toString(16).padStart(2, '0')).join('');",
  '    v.tiles.forEach((c) => { if (c.on) c.tile = lit; });',
  '    return v;'
].join('\n');
const PAIRS = [
  [/    \/\/ While a typed expense is on show, the screen stays in type-to-add mode[\s\S]*?\n    \}\n    return v;/, () => BLOCK],
  ["+ ', 0 0 18px 7px ' + t.accent + '73' : 'none',", "+ ', 0 0 18px 7px ' + t.accent + '96' : 'none',"],
  ['      guide: !show,\n', "      guide: !show,\n      guess: !show && !st.picked && q && q.cat ? q.cat.name : '',\n"],
  ["guideSub: typed ? 'like ", "guideSub: typed ? 'Like "],
  ["'Tap one above, or type it below'", "'Tap one above, or just type below'"]
];
['NewAdd', 'NewAddKeypad', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), PAIRS));
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
