// Second-round review fixes: calendar selection ring, Category spacing and touch highlight,
// a softer bar groove, and a "Still to come" note that never sits level with the average line.
const fs = require('fs');
const path = require('path');
let n = 0, miss = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [a, b] of pairs) {
    const c = s.split(a).length - 1;
    if (c !== 1) { console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 80)); miss++; continue; }
    s = s.replace(a, () => b); n++;
  }
  fs.writeFileSync(file, s);
}
const LATER_CALC = "\n    // The note sits just above the faint marks, unless the average line is at that height; then it moves above the line.\n    const avgY = Y(avgV);\n    let laterTop = padT + ph - 21;\n    if (Math.abs(avgY - (laterTop + 7)) < 12) laterTop = avgY - 22;";

patch(path.join(__dirname, '..', 'mockup', 'project', 'NewCharts.dc.html'), [
  ['    t.track = t.bg;', '    t.track = mix(t.bg, t.surface, 0.5);'],
  ['top: 191px; width: {{laterW}};', 'top: {{laterTop}}; width: {{laterW}};'],
  ['    const laterW = firstFuture >= 0 ? X(n - 1) + bw / 2 - laterLeft : 0;', '    const laterW = firstFuture >= 0 ? X(n - 1) + bw / 2 - laterLeft : 0;' + LATER_CALC],
  ["      laterW: laterW.toFixed(1) + 'px',", "      laterW: laterW.toFixed(1) + 'px',\n      laterTop: laterTop.toFixed(1) + 'px',"]
]);

patch(path.join(__dirname, 'NewCalendar.part.html'), [
  // The ring sits just outside the selected cell, so the cell's contents keep their normal spacing.
  ["ring: on ? 'inset 0 0 0 2px ' + t.text + ', inset 0 0 0 4px ' + t.bg : 'none',", "ring: on ? '0 0 0 2px ' + t.text + ', inset 0 0 0 1px ' + t.bg : 'none',"]
]);

patch(path.join(__dirname, 'NewCategory.part.html'), [
  // First card sits 12px under the header buttons, like the other screens.
  ['padding: 12px 16px 24px; display: flex; flex-direction: column; gap: 12px">', 'padding: 2px 16px 24px; display: flex; flex-direction: column; gap: 12px">'],
  ['width: 360px; height: 798px;', 'width: 360px; height: 788px;'],
  ['"height":798}', '"height":788}'],
  // While a column is touched, the others step back so the touched one is obvious.
  ['const soft = t.mix(c.color, t.surface, 0.8);', 'const soft = t.mix(c.color, t.surface, hover !== null ? 0.5 : 0.8);'],
  ['top: 139px; width: {{laterW}};', 'top: {{laterTop}}; width: {{laterW}};'],
  ['    const laterW = firstFuture >= 0 ? X(n - 1) + bw / 2 - laterLeft : 0;', '    const laterW = firstFuture >= 0 ? X(n - 1) + bw / 2 - laterLeft : 0;' + LATER_CALC],
  ["      laterW: laterW.toFixed(1) + 'px',", "      laterW: laterW.toFixed(1) + 'px',\n      laterTop: laterTop.toFixed(1) + 'px',"]
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
