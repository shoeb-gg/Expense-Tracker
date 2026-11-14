// A typed expense with no category: a solid turquoise banner sits right under the category grid, with a big up arrow,
// and says "Select a category". The arrow beside the category name on the card is gone, and so is the small note.
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
const BANNER = [
  '  <sc-if value="{{qv.unknown}}" hint-placeholder-val="{{ false }}">',
  '    <div role="status" style="position: relative; flex-shrink: 0; margin: 14px 16px 0; height: 64px; box-sizing: border-box; padding: 0 16px 0 10px; border-radius: 20px; background: {{t.accent}}; color: {{t.onAccent}}; display: flex; align-items: center; gap: 12px">',
  '      <span aria-hidden="true" style="position: absolute; left: 25px; top: -6px; width: 14px; height: 14px; border-radius: 3px; background: {{t.accent}}; transform: rotate(45deg)"></span>',
  '      <span aria-hidden="true" style="position: relative; width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px; background: {{t.onAccent}}; color: {{t.accent}}; display: flex; align-items: center; justify-content: center">',
  '        <span class="ms" style="font-size: 28px; width: 28px; height: 28px">arrow_upward</span>',
  '      </span>',
  '      <span style="min-width: 0; display: flex; flex-direction: column; gap: 1px">',
  '        <span style="font-size: 17px; line-height: 22px; font-weight: 800; letter-spacing: -0.2px">Select a category</span>',
  '        <span style="font-size: 12.5px; line-height: 16px; font-weight: 600; color: {{qv.bannerDim}}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{qv.bannerSub}}</span>',
  '      </span>',
  '    </div>',
  '  </sc-if>',
  '',
  ''
].join('\n');
const PAIRS = [
  ['icon_names=backspace,', 'icon_names=arrow_upward,backspace,'],
  [/\s*<span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; color: \{\{t\.accent\}\}">expand_less<\/span>/, () => ''],
  ['  <sc-if value="{{showPanel}}" hint-placeholder-val="{{ true }}">', BANNER + '  <sc-if value="{{showPanel}}" hint-placeholder-val="{{ true }}">'],
  ["name: known ? cat.name : 'Category',", "name: known ? cat.name : 'No category',"],
  ['nameFg: known ? t.text : t.accent,', 'nameFg: known ? t.text : t.text2,'],
  ["nameFw: known ? '600' : '800',", "nameFw: known ? '600' : '700',"],
  ['      hasNote: show && (!known || (!!st.picked && !!q.note)),', '      hasNote: show && known && !!st.picked && !!q.note,'],
  ["(!known ? 'Select a category above.' : (", "(!known ? '' : ("],
  ['      guide: !show,\n', "      guide: !show,\n      // With an amount but no category, a banner under the grid asks for one.\n      bannerDim: t.onAccent + 'D9',\n      bannerSub: q && q.note ? 'Tap one above for \u201C' + q.note.toLowerCase() + '\u201D' : 'Tap one of the tiles above',\n"]
];
['NewAdd', 'NewAddKeypad', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), PAIRS));
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
