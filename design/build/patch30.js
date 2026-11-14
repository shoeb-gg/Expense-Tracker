// Type-to-add card: no stale line under the card once a category is chosen; the note inside the card confirms what will be remembered.
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
const PAIRS = [
  ['    // The note for a new word is inside the preview card, so the line under it is not needed then.\n    if (v.qv.unknown) v.hasHint = false;', '    // Whatever needs saying about a typed expense is said inside the preview card, so the line under it is not shown then.\n    if (v.qv.show) v.hasHint = false;'],
  [/<sc-if value="\{\{qv\.unknown\}\}" hint-placeholder-val="\{\{ false \}\}">(\s*<span style="margin: 0 16px; padding: 9px 0 11px;)/, (all, rest) => '<sc-if value="{{qv.hasNote}}" hint-placeholder-val="{{ false }}">' + rest],
  ["      hint: show && !known ? 'Tap a category above. The app remembers it.' : ''", "      // A new word asks for a category. Once the user has chosen one by hand, the note says what will happen next time.\n      hasNote: show && (!known || (!!st.picked && !!q.note)),\n      hint: !show ? '' : (!known ? 'Tap a category above. Next time it\u2019s automatic.' : (st.picked && q.note ? 'Next time, \u201C' + q.note.toLowerCase() + '\u201D goes to ' + cat.name + '.' : ''))"]
];
['NewAdd', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), PAIRS));
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
