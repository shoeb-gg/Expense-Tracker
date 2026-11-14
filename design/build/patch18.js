// Review fixes for the expense-details, categories and category-form boards.
const fs = require('fs');
const path = require('path');
let n = 0, miss = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [a, b, count] of pairs) {
    if (a instanceof RegExp) { const m = s.match(a); if (!m) { console.log('PROBLEM (regex) in ' + path.basename(file) + ': ' + String(a).slice(0, 90)); miss++; continue; } s = s.replace(a, typeof b === 'function' ? b : () => b); n++; continue; }
    const c = s.split(a).length - 1;
    if (c !== (count || 1)) { console.log('PROBLEM (' + c + ' matches, wanted ' + (count || 1) + ') in ' + path.basename(file) + ': ' + a.slice(0, 80)); miss++; continue; }
    s = s.split(a).join(b); n++;
  }
  fs.writeFileSync(file, s);
}
// An emoji may be stored either as a real character or as its \u escape text; match both.
const esc = (ch) => Array.from(ch).map((c) => { const cp = c.codePointAt(0); if (cp > 0xFFFF) { const v = cp - 0x10000; return '\\\\u' + (0xD800 + (v >> 10)).toString(16).toUpperCase() + '\\\\u' + (0xDC00 + (v & 0x3FF)).toString(16).toUpperCase(); } return '\\\\u' + cp.toString(16).toUpperCase().padStart(4, '0'); }).join('');
const lit = (ch) => esc(ch).replace(/\\\\/g, '\\');
const swap = (from, to) => [new RegExp("'(" + esc(from) + '|' + from + ")'"), "'" + lit(to) + "'"];

const PHOTO = '<span role="img" aria-label="Receipt photo" style="width: 44px; height: 44px; flex-shrink: 0; border-radius: 12px; overflow: hidden; background: linear-gradient(135deg, #6A5747, #3F332A); display: flex; align-items: center; justify-content: center"><span style="width: 22px; height: 31px; box-sizing: border-box; border-radius: 2.5px; background: #F4F1EA; transform: rotate(-8deg); box-shadow: 0 2px 5px rgba(0, 0, 0, 0.4); display: flex; flex-direction: column; justify-content: center; gap: 3px; padding: 0 4px"><span style="height: 2px; border-radius: 1px; background: #B9B2A2"></span><span style="width: 70%; height: 2px; border-radius: 1px; background: #CFC9BA"></span><span style="height: 2px; border-radius: 1px; background: #CFC9BA"></span><span style="width: 50%; height: 2px; border-radius: 1px; background: #B9B2A2"></span></span></span>';
const DOT = (size) => '<span aria-hidden="true" style="position: absolute; right: -3px; bottom: -3px; width: ' + size + 'px; height: ' + size + 'px; border-radius: ' + size / 2 + 'px; background: {{COLOR}}; box-shadow: 0 0 0 2.5px {{t.surface}}"></span>';

patch(path.join(__dirname, 'NewExpense.part.html'), [
  // Buttons sit in a docked bar, so the space above them reads as the end of the page.
  ['    <div style="margin-top: auto; flex-shrink: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px">', '  </main>\n\n  <div style="flex-shrink: 0; padding: 12px 16px 16px; background: {{t.nav}}; box-shadow: inset 0 1px 0 {{t.line}}; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px">'],
  ['        Delete\n      </button>\n    </div>\n  </main>', '        Delete\n      </button>\n  </div>'],
  // The link row reads as a link and no longer repeats the amount.
  ['<span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">{{monthLabel}}</span>\n          <span style="font-size: 15px; line-height: 20px; font-weight: 600">{{monthText}}</span>', '<span style="font-size: 15px; line-height: 20px; font-weight: 600">{{monthLabel}}</span>\n          <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">{{monthText}}</span>'],
  ["monthLabel: c.name + ' in ' + K.ML[d.getUTCMonth()],\n      monthText: K.fmt(monthSum) + (monthCount === 1 ? ' in 1 expense' : ' across ' + monthCount + ' expenses'),", "monthLabel: 'See all ' + c.name + ' in ' + K.ML[d.getUTCMonth()],\n      monthText: monthCount === 1 ? '1 expense this month' : monthCount + ' expenses this month',"],
  // The receipt thumbnail looks like a photo, and the row says what tapping does.
  [/<span role="img" aria-label="Receipt photo"[\s\S]*?<span style="width: 50%; height: 3px; border-radius: 2px; background: #B9B2A2"><\/span>\s*<\/span>/, PHOTO],
  ['<span style="font-size: 15px; line-height: 20px; font-weight: 600">Receipt attached</span>', '<span style="font-size: 15px; line-height: 20px; font-weight: 600">Receipt, tap to view</span>'],
  // Dialog: wider, darker backdrop, and the expense named on its own line.
  ['width: 360px; height: 780px; background: rgba(4, 10, 11, 0.68); display: flex;', 'width: 360px; height: 780px; background: rgba(4, 10, 11, 0.78); display: flex;'],
  ['style="width: 296px; box-sizing: border-box; padding: 20px; border-radius: 24px;', 'style="width: 312px; box-sizing: border-box; padding: 20px; border-radius: 24px;'],
  ['<span style="margin-top: 6px; font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">{{confirmText}}</span>', '<span style="margin-top: 8px; font-size: 14px; line-height: 20px; font-weight: 700">{{confirmWhat}}</span>\n        <span style="font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">This can\'t be undone.</span>'],
  ["confirmText: (x.note || c.name) + ', ' + amount + '. This cannot be undone.',", "confirmWhat: (x.note || c.name) + ' \\u00B7 ' + amount,"]
]);

patch(path.join(__dirname, 'NewCategories.part.html'), [
  ['<!--@HELMET add,arrow_back,delete,drag_indicator,edit-->', '<!--@HELMET add,arrow_back,delete,drag_indicator,edit,lock-->'],
  // Each tile carries a dot in the category's chart colour.
  ['<span style="width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px; background: {{t.tile}}; display: flex; align-items: center; justify-content: center">\n              <span class="em" aria-hidden="true" style="font-size: 22px">{{r.emoji}}</span>\n            </span>', '<span style="position: relative; width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px; background: {{t.tile}}; display: flex; align-items: center; justify-content: center">\n              <span class="em" aria-hidden="true" style="font-size: 22px">{{r.emoji}}</span>\n              ' + DOT(12).replace('{{COLOR}}', '{{r.color}}') + '\n            </span>'],
  // Miscellaneous says why it has no bin.
  ['<span style="flex: 1; min-width: 0; font-size: 15px; line-height: 20px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{r.name}}</span>', '<span style="flex: 1; min-width: 0; display: flex; flex-direction: column">\n                <span style="font-size: 15px; line-height: 20px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{r.name}}</span>\n                <sc-if value="{{r.locked}}" hint-placeholder-val="{{ false }}">\n                  <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">Can\'t be deleted</span>\n                </sc-if>\n              </span>'],
  ['<span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px">delete</span>', '<span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px">{{r.delIcon}}</span>'],
  // Slimmer controls leave more room between a long name and the bin.
  ['width: 32px; height: 36px;', 'width: 30px; height: 36px;', 3],
  ['margin-right: -11px; color: {{t.text3}};', 'margin-right: -10px; color: {{t.text3}};'],
  ["        delOp: locked ? 0.3 : 1,", "        color: c.color,\n        delIcon: locked ? 'lock' : 'delete',\n        delOp: locked ? 0.6 : 1,"],
  // Dialog: wider, darker backdrop, clearer wording.
  ['height: 1114px; background: rgba(4, 10, 11, 0.68)', 'height: 1114px; background: rgba(4, 10, 11, 0.78)'],
  ['style="position: absolute; left: 32px; top: 300px; width: 296px;', 'style="position: absolute; left: 24px; top: 300px; width: 312px;'],
  ['<span style="margin-top: 6px; font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">{{confirmText}}</span>', '<span style="margin-top: 8px; font-size: 14px; line-height: 20px; font-weight: 700">{{confirmWhat}}</span>\n        <span style="font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">{{confirmNote}}</span>'],
  ["      confirmText: target ? (n === 0 ? 'It has no expenses.' : (n === 1 ? 'Its 1 expense' : 'Its ' + K.fmt(n) + ' expenses') + ' will move to Miscellaneous. Nothing is lost.') : '',", "      confirmWhat: target ? (n === 0 ? target.name + ' has no expenses.' : target.name + '\\u2019s ' + (n === 1 ? '1 expense moves' : K.fmt(n) + ' expenses move') + ' to Miscellaneous.') : '',\n      confirmNote: n === 0 ? 'It will simply be removed.' : 'Nothing is lost.',"]
]);

patch(path.join(__dirname, 'NewCategoryEdit.part.html'), [
  // Preview tile: the same colour dot as on the list, instead of a band.
  ['<span style="width: 56px; height: 56px; flex-shrink: 0; border-radius: 18px; background: {{t.tile}}; box-shadow: inset 0 -4px 0 {{color}}; display: flex; align-items: center; justify-content: center">\n        <span class="em" aria-hidden="true" style="font-size: 28px">{{emoji}}</span>\n      </span>', '<span style="position: relative; width: 56px; height: 56px; flex-shrink: 0; border-radius: 18px; background: {{t.tile}}; display: flex; align-items: center; justify-content: center">\n        <span class="em" aria-hidden="true" style="font-size: 28px">{{emoji}}</span>\n        ' + DOT(16).replace('{{COLOR}}', '{{color}}') + '\n      </span>'],
  // Cancel and Save are the same width; Save is dim until there is a name.
  ['style="justify-self: start; height: 40px; padding: 0 16px; border-radius: 20px; background: {{t.surface}}; color: {{t.text}}; font-size: 14px; line-height: 20px; font-weight: 700; display: flex; align-items: center; text-decoration: none">Cancel</a>', 'style="justify-self: start; width: 80px; height: 40px; border-radius: 20px; background: {{t.surface}}; color: {{t.text}}; font-size: 14px; line-height: 20px; font-weight: 700; display: flex; align-items: center; justify-content: center; text-decoration: none">Cancel</a>'],
  ['style="justify-self: end; height: 40px; padding: 0 18px; border-radius: 20px; background: {{t.accent}}; color: {{t.onAccent}}; font-size: 14px; line-height: 20px; font-weight: 800; display: flex; align-items: center; text-decoration: none">Save</a>', 'style="justify-self: end; width: 80px; height: 40px; border-radius: 20px; background: {{t.accent}}; color: {{t.onAccent}}; opacity: {{saveOp}}; pointer-events: {{savePe}}; font-size: 14px; line-height: 20px; font-weight: 800; display: flex; align-items: center; justify-content: center; text-decoration: none">Save</a>'],
  ["      onName: (ev) => this.setState({ name: ev.target.value })", "      saveOp: name.trim() ? 1 : 0.4,\n      savePe: name.trim() ? 'auto' : 'none',\n      onName: (ev) => this.setState({ name: ev.target.value })"],
  // The selected colour is marked inside its own circle, so it never crowds its neighbours.
  ["ring: c === color ? '0 0 0 2px ' + t.surface + ', 0 0 0 4px ' + c : 'none',", "ring: c === color ? 'inset 0 0 0 2px ' + c + ', inset 0 0 0 4.5px ' + t.surface : 'none',"],
  ['<span class="ms" aria-hidden="true" style="font-size: 18px; width: 18px; height: 18px">check</span>', '<span class="ms" aria-hidden="true" style="font-size: 16px; width: 16px; height: 16px">check</span>'],
  // One spelling across the app.
  ['<section aria-label="Colour on charts"', '<section aria-label="Color on charts"'],
  ['font-weight: 800">Colour on charts</h2>', 'font-weight: 800">Color on charts</h2>'],
  ['<div role="group" aria-label="Colour"', '<div role="group" aria-label="Color"'],
  // The keyboard button is quieter than the section titles.
  ['background: {{t.surface2}}; color: {{t.text}}; font-size: 13.5px; line-height: 20px; font-weight: 700; display: flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer">', 'background: {{t.surface2}}; color: {{t.text2}}; font-size: 13.5px; line-height: 20px; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer">'],
  // Stronger emoji in place of four faint ones.
  swap('🚲', '🛵'),
  swap('👓', '🩺'),
  swap('🎮', '🎉'),
  swap('🎬', '🍿'),
  // A new category starts with a tag emoji and a colour that is not the first in the list.
  [/: \{ name: '', emoji: '[^']*', color: '#3987E5' \};/, ": { name: '', emoji: '" + lit('🏷️') + "', color: '#C98500' };"]
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
