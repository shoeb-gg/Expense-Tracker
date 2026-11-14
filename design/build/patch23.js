// Type-to-add preview: the "new word" note lives inside the card, a grey Add opens the category sheet instead of doing nothing.
// Also finishes the calculator-keys sheet (all four keys shown in both rows).
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
      s = s.replace(a, () => b);
      continue;
    }
    const c = s.split(a).length - 1;
    if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 70)); continue; }
    s = s.split(a).join(b);
  }
  fs.writeFileSync(file, s);
}
const QUICK = [
  ['<div style="display: flex; align-items: center; gap: 12px; padding: 12px 16px; border-radius: 20px; background: {{t.surface}}">', '<div style="border-radius: 20px; background: {{t.surface}}; display: flex; flex-direction: column">\n          <div style="display: flex; align-items: center; gap: 12px; padding: 12px 16px">'],
  [/<a href="MoodAqua\.dc\.html" aria-disabled="\{\{qv\.unknown\}\}"[^>]*>Add<\/a>\s*<\/div>/, '<a href="{{qv.addHref}}" style="height: 40px; flex-shrink: 0; padding: 0 18px; border-radius: 20px; background: {{qv.addBg}}; color: {{qv.addFg}}; font-size: 14.5px; line-height: 20px; font-weight: 800; display: flex; align-items: center; text-decoration: none">Add</a>\n          </div>\n          <sc-if value="{{qv.unknown}}" hint-placeholder-val="{{ false }}">\n            <span style="margin: 0 16px; padding: 9px 0 11px; box-shadow: inset 0 1px 0 {{t.line}}; font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">{{qv.hint}}</span>\n          </sc-if>\n        </div>'],
  ["if (v.qv.hint && 'hint' in v) v.hint = v.qv.hint;", '// The note for a new word is inside the preview card, so the line under it is not needed then.\n    if (v.qv.unknown) v.hasHint = false;'],
  ["addPe: known ? 'auto' : 'none',", "addHref: known ? 'MoodAqua.dc.html' : 'PopQuickCat.dc.html',"],
  ["'New word. Pick its category once.'", "'Pick a category once. The app remembers it.'"]
];
['NewAdd', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), QUICK));

patch(path.join(__dirname, 'pop', 'PopCalc.pop.html'), [
  [/const LIST = \[\['Plus and minus', \[[^\n]*\]\]\];/, "// Both rows show all four keys in the same places; the ones a choice leaves out are faded.\n    const KEYS = ['+', '\\u2212', '\\u00D7', '\\u00F7'];\n    const LIST = [['Plus and minus', 2], ['All four keys', 4]];"]
]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
