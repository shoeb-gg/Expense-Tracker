// The category sheet is gone (it repeated the grid already on the screen). While a typed expense is on show,
// tapping a category tile in the grid sets that expense's category; tapping the category on the card hides the keyboard
// so the whole grid can be seen. The arrow beside the name now points up, towards the grid.
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
  ['edit,expand_more,', 'edit,expand_less,expand_more,'],
  ['<a href="PopQuickCat.dc.html" aria-label="{{qv.aria}}" style="flex: 1; min-width: 0; display: flex; align-items: center; gap: 12px; text-decoration: none; color: inherit">', '<button type="button" aria-label="{{qv.aria}}" style="flex: 1; min-width: 0; display: flex; align-items: center; gap: 12px; border: 0; padding: 0; background: transparent; color: inherit; font: inherit; text-align: left; cursor: pointer">'],
  [/<\/a>(\s*<span style="font-size: 17px; line-height: 24px; font-weight: 800; font-variant-numeric: tabular-nums">\{\{qv\.amount\}\}<\/span>)/, (all, rest) => '</button>' + rest],
  ['<span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; color: {{t.accent}}">expand_more</span>', '<span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; color: {{t.accent}}">expand_less</span>'],
  ['<a href="{{qv.addHref}}" style="height: 40px; flex-shrink: 0; padding: 0 14px; border-radius: 20px; background: {{qv.addBg}}; color: {{qv.addFg}};', '<a href="MoodAqua.dc.html" aria-disabled="{{qv.unknown}}" style="height: 40px; flex-shrink: 0; padding: 0 14px; border-radius: 20px; background: {{qv.addBg}}; color: {{qv.addFg}}; pointer-events: {{qv.addPe}};'],
  ["addHref: known ? 'MoodAqua.dc.html' : 'PopQuickCat.dc.html',", "addPe: known ? 'auto' : 'none',"],
  ["'Pick a category once. The app remembers it.'", "'Tap a category above. The app remembers it.'"],
  ["aria: known ? 'Category: ' + cat.name + '. Tap to change' : 'Pick a category',", "aria: known ? 'Category: ' + cat.name + '. Tap, then pick another one from the grid above' : 'Pick a category from the grid above',"],
  ['    if (v.qv.unknown) v.hasHint = false;\n    return v;', [
    '    if (v.qv.unknown) v.hasHint = false;',
    '    // While a typed expense is on show, the screen stays in type-to-add mode: tapping a category tile sets the category',
    '    // of that expense instead of opening the keypad. The tile of the category in use is ringed, whether guessed or chosen.',
    '    if (v.qv.show) {',
    '      v.showPanel = false;',
    '      v.showQuick = true;',
    '      v.tiles.forEach((c) => {',
    '        if (!v.qv.known || c.name !== v.qv.name) return;',
    '        c.on = true;',
    "        c.ring = '0 0 0 3px ' + v.t.bg + ', 0 0 0 5px ' + v.t.accent;",
    '        c.labelColor = v.t.accent;',
    "        c.fw = '800';",
    '      });',
    '    }',
    '    return v;'
  ].join('\n')]
];
['NewAdd', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), PAIRS));

// Canvas: start from the copy that is live now, drop the sheet's board and close the gap it leaves.
const fresh = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fresh', 'project', 'canvas.json'), 'utf8'));
const gone = 'PopQuickCat.dc.html';
if (fresh.boards[gone]) {
  const hole = fresh.boards[gone];
  delete fresh.boards[gone];
  fresh.order = fresh.order.filter((k) => k !== gone);
  let right = 0;
  Object.values(fresh.boards).forEach((b) => {
    if (b.y !== hole.y) return;
    if (b.x > hole.x) b.x -= 440;
    right = Math.max(right, b.x + b.w);
  });
  fresh.notes.rowP.maxW = right;
  console.log('canvas: sheet board removed, row now ends at ' + right);
} else console.log('canvas: sheet board was already gone');
fs.writeFileSync(path.join(proj, 'canvas.json'), JSON.stringify(fresh, null, 2) + '\n');
if (fs.existsSync(path.join(proj, gone))) fs.unlinkSync(path.join(proj, gone));
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
