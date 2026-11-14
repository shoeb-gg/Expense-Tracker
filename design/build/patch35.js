// The "no category" banner is a tinted panel (not a solid bar that looks like a button), has no notch,
// and every category tile gets a thin turquoise outline while the app is waiting for a choice.
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
  '    <div role="status" style="flex-shrink: 0; margin: 18px 16px 0; height: 64px; box-sizing: border-box; padding: 0 16px; border-radius: 20px; background: {{qv.bannerBg}}; box-shadow: {{qv.bannerLine}}; display: flex; align-items: center; gap: 12px">',
  '      <span aria-hidden="true" style="width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px; background: {{qv.bannerTile}}; color: {{t.accent}}; display: flex; align-items: center; justify-content: center">',
  '        <span class="ms" style="font-size: 26px; width: 26px; height: 26px">arrow_upward</span>',
  '      </span>',
  '      <span style="min-width: 0; display: flex; flex-direction: column; gap: 1px">',
  '        <span style="font-size: 17px; line-height: 22px; font-weight: 800; letter-spacing: -0.2px; color: {{t.accent}}">Select a category above</span>',
  '        <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text2}}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{qv.bannerSub}}</span>',
  '      </span>',
  '    </div>',
  '  </sc-if>'
].join('\n');
const PAIRS = [
  [/  <sc-if value="\{\{qv\.unknown\}\}" hint-placeholder-val="\{\{ false \}\}">\n    <div role="status"[\s\S]*?\n  <\/sc-if>/, () => BANNER],
  ["      bannerDim: t.onAccent + 'D9',\n", "      bannerBg: t.accent + '1F',\n      bannerLine: 'inset 0 0 0 1.5px ' + t.accent + '8C',\n      bannerTile: t.accent + '33',\n"],
  [/      bannerSub: [^\n]*\n/, () => "      bannerSub: q && q.note ? 'So the app knows where \u201C' + q.note.toLowerCase() + '\u201D goes' : 'So the app knows where this goes',\n"],
  ['    v.tiles.forEach((c) => { if (c.on) c.tile = lit; });\n    return v;', "    v.tiles.forEach((c) => { if (c.on) c.tile = lit; });\n    // While the app is waiting for a category, every tile gets a thin outline: the grid itself looks ready to be tapped.\n    if (v.qv.unknown) v.tiles.forEach((c) => { if (!c.on) c.ring = 'inset 0 0 0 1.5px ' + v.t.accent + '73'; });\n    return v;"]
];
['NewAdd', 'NewAddKeypad', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), PAIRS));
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
