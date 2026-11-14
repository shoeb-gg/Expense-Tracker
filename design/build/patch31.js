// 1. The selected category tile glows as well as being ringed.
// 2. With nothing typed and no category chosen, a card above the typing bar says what to do ("Select a category").
// 3. NewAdd becomes the screen as it first opens; the keypad state moves to NewAddKeypad.
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
const GUIDE = [
  '<sc-if value="{{qv.guide}}" hint-placeholder-val="{{ false }}">',
  '          <div style="display: flex; align-items: center; gap: 12px; padding: 12px 16px; border-radius: 20px; background: {{t.surface}}">',
  '            <span aria-hidden="true" style="width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px; background: {{t.tile}}; color: {{t.accent}}; display: flex; align-items: center; justify-content: center">',
  '              <span class="ms" style="font-size: 24px; width: 24px; height: 24px">{{qv.guideIcon}}</span>',
  '            </span>',
  '            <span style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">',
  '              <span style="font-size: 15px; line-height: 20px; font-weight: 800">{{qv.guideTitle}}</span>',
  '              <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{qv.guideSub}}</span>',
  '            </span>',
  '          </div>',
  '        </sc-if>'
].join('\n');
const PAIRS = [
  ['cookie,directions_bus', 'cookie,dialpad,directions_bus'],
  ['subscriptions,wifi', 'subscriptions,touch_app,wifi'],
  // The glow: a soft halo of the accent colour outside the ring.
  ["ring: on ? '0 0 0 3px ' + t.bg + ', 0 0 0 5px ' + t.accent : 'none',", "ring: on ? '0 0 0 3px ' + t.bg + ', 0 0 0 5px ' + t.accent + ', 0 0 18px 7px ' + t.accent + '73' : 'none',"],
  ["c.ring = '0 0 0 3px ' + v.t.bg + ', 0 0 0 5px ' + v.t.accent;", "c.ring = '0 0 0 3px ' + v.t.bg + ', 0 0 0 5px ' + v.t.accent + ', 0 0 18px 7px ' + v.t.accent + '73';"],
  [/<sc-if value="\{\{hasHint\}\}"[^>]*>\s*<p [^>]*>\{\{hint\}\}<\/p>\s*<\/sc-if>/, () => GUIDE],
  ['    v.qv = this.quickVals(v.t);\n', '    v.qv = this.quickVals(v.t);\n    // Whenever the keypad is not up, the typing bar is, with a card above it that says what to do next.\n    if (!v.showPanel) v.showQuick = true;\n'],
  ['      show,\n      known,', [
    '      show,',
    '      // Before there is an amount, the card above the bar is a guide: pick a category, or finish typing.',
    '      guide: !show,',
    "      guideIcon: typed ? 'dialpad' : 'touch_app',",
    "      guideTitle: typed ? 'Now add the amount' : 'Select a category',",
    "      guideSub: typed ? 'like \u201C' + typed + ' 120\u201D' : 'Tap one above, or type it below',",
    '      known,'
  ].join('\n')],
  ['    const q = this.parseQuick(K, st.typed);\n    const show = !!(q && q.amount);', "    const q = this.parseQuick(K, st.typed);\n    const typed = (st.typed || '').trim();\n    const show = !!(q && q.amount);"],
  [/'Tap a category above\. Next time it.s automatic\.'/, () => "'Select a category above. Next time it\u2019s automatic.'"]
];
['NewAdd', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), PAIRS));

// The keypad state keeps its own board; NewAdd (the file every "+" button opens) is now the screen as it first opens.
if (!fs.existsSync(path.join(proj, 'NewAddKeypad.dc.html')) || true) {
  let s = fs.readFileSync(path.join(proj, 'NewAdd.dc.html'), 'utf8');
  const D = "return { picked: 'snacks', expr: '120', note: 'Coffee', typed: '' };";
  if (s.split(D).length === 2) {
    fs.writeFileSync(path.join(proj, 'NewAddKeypad.dc.html'), s);
    s = s.split(D).join("return { picked: null, expr: '', note: '', typed: '' };").replace(/<title>[^<]*<\/title>/, '<title>Add expense, as it opens</title>');
    fs.writeFileSync(path.join(proj, 'NewAdd.dc.html'), s);
    console.log('NewAddKeypad written; NewAdd is now the opening state');
  } else if (s.indexOf("return { picked: null, expr: '', note: '', typed: '' };") > 0 && fs.existsSync(path.join(proj, 'NewAddKeypad.dc.html'))) console.log('NewAdd already the opening state');
  else { problems++; console.log('PROBLEM: NewAdd defaults not found'); }
}
patch(path.join(__dirname, 'pop', 'PopDate.pop.html'), [['"host":"NewAdd"', '"host":"NewAddKeypad"']]);
{
  const f = path.join(__dirname, 'pop', 'PopDate.pop.html');
  let s = fs.readFileSync(f, 'utf8');
  const n = s.split('href="NewAdd.dc.html"').length - 1;
  s = s.split('href="NewAdd.dc.html"').join('href="NewAddKeypad.dc.html"');
  fs.writeFileSync(f, s);
  console.log('PopDate links repointed: ' + n);
}
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
