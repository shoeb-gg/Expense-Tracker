// Pocket screens, fixes from the first Opus review: nothing said twice, "Add pocket" everywhere,
// the default pocket says "Can't be deleted", a stronger and tidier delete warning, a fresh starter emoji.
const fs = require('fs');
const path = require('path');
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
const part = (n) => path.join(__dirname, n + '.part.html');

patch(part('PocketList'), [
  ['<!--@HELMET add,arrow_back,check,delete,edit,lock-->', '<!--@HELMET add,arrow_back,check,chevron_right,delete,edit,lock-->'],
  // The band only counts the pockets; the card below explains them once.
  ['          <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">Each one is a separate book</span>\n', ''],
  // The default pocket says in words why it has a lock, like Miscellaneous does on Categories.
  ['{{r.sub}}</span>\n              </span>', '{{r.sub}}</span>\n                <sc-if value="{{r.locked}}" hint-placeholder-val="{{ false }}">\n                  <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">Can’t be deleted</span>\n                </sc-if>\n              </span>'],
  [/sub: count\(p\.n\) \+ \(p\.locked \? '[^']*' : ''\),/, () => 'sub: count(p.n),'],
  ['<section aria-label="What a pocket is"', '<section aria-label="How pockets work"'],
  ['font-weight: 800">What is a pocket?</h2>', 'font-weight: 800">How pockets work</h2>'],
  ['        <span style="font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">A pocket is a separate book of expenses, like one for home and one for a business.</span>\n        <span style="font-size: 12.5px; line-height: 18px; font-weight: 500; color: {{t.text3}}">Home, Calendar, Charts and Reports show the pocket you are in. Categories and settings are the same in every pocket.</span>',
    '        <span style="font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">Each pocket keeps its own expenses. Home, Calendar, Charts and Reports show the pocket you are in.</span>\n        <span style="font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">Categories and settings are the same in every pocket.</span>'],
  ['      New pocket\n    </a>', '      Add pocket\n    </a>'],
  // Delete warning: the emoji ties the title to the row, the lost expenses are counted, and a copy can be saved first.
  ['<span style="font-size: 17px; line-height: 24px; font-weight: 800; letter-spacing: -0.2px">{{confirmTitle}}</span>', '<span style="font-size: 17px; line-height: 24px; font-weight: 800; letter-spacing: -0.2px; display: flex; align-items: center; gap: 6px">Delete<span class="em" aria-hidden="true" style="font-size: 17px">{{confirmEmoji}}</span>{{confirmName}}?</span>'],
  ['        <sc-if value="{{needsTick}}" hint-placeholder-val="{{ true }}">\n          <button type="button" role="checkbox" aria-checked="{{ok}}" onClick="{{flip}}" style="margin-top: 16px; height: 48px;', '        <sc-if value="{{needsTick}}" hint-placeholder-val="{{ true }}">\n          <div style="display: flex; flex-direction: column">\n          <a href="NewExport.dc.html" style="margin-top: 16px; height: 48px; box-sizing: border-box; border-radius: 16px; padding: 0 10px 0 16px; background: {{t.tile}}; color: {{t.text}}; text-decoration: none; display: flex; align-items: center; justify-content: space-between; gap: 12px; font-size: 14px; line-height: 20px; font-weight: 600">\n            Save a copy first\n            <span style="display: flex; align-items: center; gap: 2px; font-size: 13.5px; font-weight: 700; color: {{t.accent}}">\n              Export\n              <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px">chevron_right</span>\n            </span>\n          </a>\n          <button type="button" role="checkbox" aria-checked="{{ok}}" onClick="{{flip}}" style="margin-top: 16px; height: 48px;'],
  ['            Yes, delete these expenses too\n          </button>\n        </sc-if>', '            {{tickLabel}}\n          </button>\n          </div>\n        </sc-if>'],
  [/confirmNote: n \? '[^']*' : 'It will simply be removed\.',/, () => "confirmNote: n ? 'This can\\u2019t be undone.' : 'It will simply be removed.',\n      confirmEmoji: target ? target.emoji : '',\n      confirmName: target ? target.name : '',\n      tickLabel: 'Yes, delete ' + count(n),"]
]);

patch(part('PocketEdit'), [
  ["screenTitle: mode === 'edit' ? 'Edit pocket' : 'New pocket',", "screenTitle: mode === 'edit' ? 'Edit pocket' : 'Add pocket',"],
  // A new pocket starts with an emoji no other pocket is using, so it never looks like an existing one.
  ["{ name: '', emoji: '👛' }", "{ name: '', emoji: '💰' }"],
  ["'🐾'", "'🐶'"],
  ['// Edit opens with the pocket\'s current name and emoji; New opens empty with a starter emoji.', '// Edit opens with the pocket\'s current name and emoji; Add opens empty with a starter emoji no pocket uses yet.']
]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
