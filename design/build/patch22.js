// Fixes from the Opus review of Export, Import, the photo viewer and the Settings sheets.
const fs = require('fs');
const path = require('path');
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
const part = (n) => path.join(__dirname, n + '.part.html');
const pop = (n) => path.join(__dirname, 'pop', n + '.pop.html');

// Export: the note lives inside the File type card, and the CSV line no longer hints that Excel cannot be imported.
patch(part('NewExport'), [
  ["'Can be imported back later'", "'Plain text, opens in almost any app'"],
  [/      <\/div>\n    <\/section>\n\n    <p style="margin: 0 16px;[^>]*>[^<]*<\/p>/, '      </div>\n      <span style="margin: -4px 16px 16px; text-align: center; font-size: 13px; line-height: 20px; font-weight: 500; color: {{t.text3}}">One row per expense. Receipt photos are not included.</span>\n    </section>']
]);

// Import step 1: every icon row starts its text at x=88, only the current step is solid, clearer wording.
patch(part('NewImport'), [
  ['padding: 20px 16px; display: flex; align-items: center; gap: 16px">', 'padding: 16px; display: flex; align-items: center; gap: 12px">'],
  ['width: 56px; height: 56px; flex-shrink: 0; border-radius: 18px; background: {{t.tile}}; color: {{t.accent}};', 'width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px; background: {{t.tile}}; color: {{t.accent}};'],
  ['<span class="ms" style="font-size: 30px; width: 30px; height: 30px">upload_file</span>', '<span class="ms" style="font-size: 24px; width: 24px; height: 24px">upload_file</span>'],
  ['>Import from a file</span>', '>Add expenses from a file</span>'],
  ['>Works with CSV, Excel and JSON files.</span>', '>CSV, Excel or JSON files</span>'],
  ['        <div style="margin: 0 16px; height: 64px; box-shadow: {{s.line}}; display: flex; align-items: center; gap: 12px">\n          <span aria-hidden="true" style="width: 28px; height: 28px; flex-shrink: 0; border-radius: 14px; background: {{t.accent}}; color: {{t.onAccent}}; font-size: 13.5px; line-height: 28px; font-weight: 800; text-align: center">{{s.n}}</span>\n          <span style="min-width: 0; display: flex; flex-direction: column; gap: 2px">',
    '        <div style="margin: 0 16px; height: 64px; display: flex; align-items: center; gap: 12px">\n          <span aria-hidden="true" style="width: 44px; flex-shrink: 0; display: flex; justify-content: center">\n            <span style="width: 28px; height: 28px; border-radius: 14px; background: {{s.bg}}; color: {{s.fg}}; font-size: 13.5px; line-height: 28px; font-weight: 800; text-align: center">{{s.n}}</span>\n          </span>\n          <span style="flex: 1; min-width: 0; align-self: stretch; box-shadow: {{s.line}}; display: flex; flex-direction: column; justify-content: center; gap: 2px">'],
  ['{{s.tag}}</span>\n        </div>\n      </sc-for>', '{{s.tag}}</span>\n        </div>\n      </sc-for>\n      <span style="margin: 0 16px; padding: 10px 0 12px; box-shadow: inset 0 1px 0 {{t.line}}; text-align: center; font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">A file exported from this app works as it is.</span>'],
  ["{ n: '1', title: 'Choose a file', sub: 'From your phone or a cloud drive', line },", "{ n: '1', title: 'Choose a file', sub: 'From your phone or a cloud drive', bg: t.accent, fg: t.onAccent, line },"],
  ["{ n: '2', title: 'Check the columns', sub: 'Say which column is the date, the amount', line },", "{ n: '2', title: 'Check the columns', sub: 'Confirm which column is which', bg: t.accentSoft, fg: t.accent, line },"],
  ["{ n: '3', title: 'Review and import', sub: 'See what will be added before it is saved', line: 'none' }", "{ n: '3', title: 'Review and import', sub: 'See what will be added before it is saved', bg: t.accentSoft, fg: t.accent, line: 'none' }"],
  ["sub: 'Missing ones go to Miscellaneous'", "sub: 'Blank category = Miscellaneous'"]
]);

// Import step 2: column headings say which side is the app and which is the file; Change is a pill; the date result cannot be misread.
patch(part('NewImportMatch'), [
  ['font-weight: 700; color: {{t.accent}}; text-decoration: none">Change</a>', 'font-weight: 700; color: {{t.text}}; text-decoration: none">Change</a>'],
  ['<a href="NewImport.dc.html" style="flex-shrink: 0; font-size: 13.5px; line-height: 20px;', '<a href="NewImport.dc.html" style="flex-shrink: 0; height: 32px; padding: 0 12px; border-radius: 16px; background: {{t.tile}}; font-size: 13px; line-height: 32px;'],
  ['      <sc-for list="{{fields}}" as="f" hint-placeholder-count="4">', '      <div aria-hidden="true" style="margin: 0 16px; padding-top: 12px; display: flex; justify-content: space-between; font-size: 12px; line-height: 16px; font-weight: 600; color: {{t.text3}}">\n        <span>In the app</span>\n        <span style="width: 124px">Column in your file</span>\n      </div>\n      <sc-for list="{{fields}}" as="f" hint-placeholder-count="4">'],
  ['<div style="margin: 0 16px; height: 68px; box-shadow: {{f.line}};', '<div style="margin: 0 16px; height: 64px; box-shadow: {{f.line}};'],
  ['            {{f.column}}\n', '            <span style="min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap">{{f.column}}</span>\n'],
  ['font-variant-numeric: tabular-nums">{{readAs}}</span>', 'font-variant-numeric: tabular-nums">05/03/2025 is read as <span style="font-weight: 800; color: {{t.text}}">{{readAs}}</span></span>'],
  ["readAs: '05/03/2025 is read as ' + (order === 'day' ? 'Mar 5, 2025' : 'May 3, 2025')", "readAs: order === 'day' ? 'March 5, 2025' : 'May 3, 2025'"]
]);

// Import step 3: one text start (x=88) in both cards, lines start at the text, the total sits on the right, failed rows are named.
patch(part('NewImportReview'), [
  ['font-weight: 800; letter-spacing: -0.2px; white-space: nowrap">Review</h1>', 'font-weight: 800; letter-spacing: -0.2px; white-space: nowrap">Review and import</h1>'],
  ['      <span style="margin-top: 2px; font-size: 30px; line-height: 38px; font-weight: 800; letter-spacing: -0.6px; font-variant-numeric: tabular-nums">298 expenses</span>\n      <span style="margin-top: 2px; font-size: 12.5px; line-height: 16px; font-weight: 600; color: {{t.onAccentDim}}; font-variant-numeric: tabular-nums">Mar 2 to Dec 30, 2025 · 412,560 in total</span>',
    '      <div style="margin-top: 2px; display: flex; align-items: flex-end; justify-content: space-between; gap: 12px">\n        <span style="font-size: 30px; line-height: 38px; font-weight: 800; letter-spacing: -0.6px; font-variant-numeric: tabular-nums">298 expenses</span>\n        <span style="padding-bottom: 5px; display: flex; flex-direction: column; align-items: flex-end">\n          <span style="font-size: 17px; line-height: 20px; font-weight: 800; font-variant-numeric: tabular-nums">412,560</span>\n          <span style="font-size: 12px; line-height: 14px; font-weight: 600; color: {{t.onAccentDim}}">in total</span>\n        </span>\n      </div>\n      <span style="margin-top: 2px; font-size: 12.5px; line-height: 16px; font-weight: 600; color: {{t.onAccentDim}}; font-variant-numeric: tabular-nums">Mar 2 to Dec 30, 2025</span>'],
  ['        <div style="margin: 0 16px; height: 64px; box-shadow: {{o.line}}; display: flex; align-items: center; gap: 12px">\n          <span aria-hidden="true" style="width: 36px; height: 36px; flex-shrink: 0; border-radius: 12px;', '        <div style="margin: 0 16px; height: 64px; display: flex; align-items: center; gap: 12px">\n          <span aria-hidden="true" style="width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px;'],
  ['          <span style="min-width: 0; display: flex; flex-direction: column; gap: 2px">\n            <span style="font-size: 15px; line-height: 20px; font-weight: 600; font-variant-numeric: tabular-nums">{{o.title}}</span>', '          <span style="flex: 1; min-width: 0; align-self: stretch; box-shadow: {{o.line}}; display: flex; flex-direction: column; justify-content: center; gap: 2px">\n            <span style="font-size: 15px; line-height: 20px; font-weight: 600; font-variant-numeric: tabular-nums">{{o.title}}</span>'],
  ['          <span style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">\n            <span style="font-size: 15px; line-height: 20px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{x.title}}</span>\n            <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{x.sub}}</span>\n          </span>\n          <span style="font-size: 15px; line-height: 20px; font-weight: 700; font-variant-numeric: tabular-nums">{{x.amount}}</span>',
    '          <span style="flex: 1; min-width: 0; align-self: stretch; box-shadow: {{x.line}}; display: flex; align-items: center; gap: 12px">\n            <span style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">\n              <span style="font-size: 15px; line-height: 20px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{x.title}}</span>\n              <span style="display: flex; align-items: center; gap: 6px; font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">\n                <span>{{x.cat}}</span>\n                <sc-if value="{{x.isNew}}" hint-placeholder-val="{{ false }}">\n                  <span style="height: 16px; padding: 0 6px; border-radius: 8px; background: {{t.surface2}}; color: {{t.accent}}; font-size: 11px; line-height: 16px; font-weight: 800">New</span>\n                </sc-if>\n                <span>{{x.when}}</span>\n              </span>\n            </span>\n            <span style="font-size: 15px; line-height: 20px; font-weight: 700; font-variant-numeric: tabular-nums">{{x.amount}}</span>\n          </span>'],
  ["sub: 'No date or no amount. Skipped', line }", "sub: 'Rows 14, 87, 203 \\u00B7 no date or amount', line }"],
  ["{ emoji: '🥦', title: 'Weekly bazaar', sub: 'Groceries · Mar 2, 2025', amount: '2,450' },", "{ emoji: '🥦', title: 'Weekly bazaar', cat: 'Groceries', isNew: false, when: '\\u00B7 Mar 2, 2025', amount: '2,450', line },"],
  ["{ emoji: '🚍', title: 'Bus pass', sub: 'Transportation · Mar 3, 2025', amount: '600' },", "{ emoji: '🚍', title: 'Bus pass', cat: 'Transportation', isNew: false, when: '\\u00B7 Mar 3, 2025', amount: '600', line },"],
  ["title: 'Cat food', sub: 'Pets (new) · Mar 3, 2025', amount: '890' }", "title: 'Cat food', cat: 'Pets', isNew: true, when: '\\u00B7 Mar 3, 2025', amount: '890', line: 'none' }"],
  ['>They are added to the expenses you already have.</span>', '>Added to your current expenses. Nothing is replaced.</span>']
]);

// Photo viewer: the zoom hint is plain text, and the photo sits midway between the header and the caption.
patch(part('NewPhoto'), [
  ['<footer style="height: 96px; flex-shrink: 0; box-sizing: border-box; padding: 0 16px 12px; display: flex; align-items: center; justify-content: space-between; gap: 12px">', '<footer style="height: 58px; flex-shrink: 0; box-sizing: border-box; padding: 0 16px; display: flex; align-items: flex-start; justify-content: space-between; gap: 12px">'],
  ['<span style="flex-shrink: 0; height: 32px; padding: 0 12px 0 8px; border-radius: 16px; background: rgba(255, 255, 255, 0.12); color: rgba(255, 255, 255, 0.82); font-size: 12.5px; line-height: 16px; font-weight: 600; display: flex; align-items: center; gap: 4px">', '<span style="flex-shrink: 0; height: 20px; color: rgba(255, 255, 255, 0.55); font-size: 12.5px; line-height: 20px; font-weight: 500; display: flex; align-items: center; gap: 4px">'],
  ['<span class="ms" aria-hidden="true" style="font-size: 18px; width: 18px; height: 18px">zoom_in</span>', '<span class="ms" aria-hidden="true" style="font-size: 16px; width: 16px; height: 16px">zoom_in</span>']
]);

// Settings: the Number format row shows a number long enough to tell every style apart.
patch(part('NewSettings'), [["numberSample: sep ? '1,234.56' : '1234.56'", "numberSample: sep ? '1,234,567.89' : '1234567.89'"]]);

// Sheets.
patch(pop('PopNumber'), [['<span style="flex: 1; min-width: 0; font-size: 16px; line-height: 20px;', '<span style="flex: 1; min-width: 0; font-size: 15px; line-height: 20px;']]);
patch(pop('PopCalc'), [
  ['The sum keys on the Add expense keypad.', 'Math keys on the Add expense keypad.'],
  ['onClick="{{o.pick}}" style="height: 60px;', 'onClick="{{o.pick}}" style="height: 56px;'],
  ['<span style="width: 28px; height: 28px; border-radius: 9px; background: {{t.surface}}; color: {{t.accent}};', '<span style="width: 28px; height: 28px; border-radius: 9px; opacity: {{c.op}}; background: {{t.surface}}; color: {{t.accent}};'],
  ['<sc-for list="{{o.keys}}" as="c" hint-placeholder-count="2">', '<sc-for list="{{o.keys}}" as="c" hint-placeholder-count="4">'],
  ["const LIST = [['Plus and minus', ['+', '\\u2212']], ['All four keys', ['+', '\\u2212', '\\u00D7', '\\u00F7']]];", "// Both rows show all four keys in the same places; the ones a choice leaves out are faded.\n    const KEYS = ['+', '\\u2212', '\\u00D7', '\\u00F7'];\n    const LIST = [['Plus and minus', 2], ['All four keys', 4]];"],
  ["opts: LIST.map(([label, keys], i) => Object.assign(k.opt(i === cur), { label, aria: label, keys: keys.map((ch) => ({ ch })), pick: () => this.setState({ popPick: i }) }))", "opts: LIST.map(([label, n], i) => Object.assign(k.opt(i === cur), { label, aria: label, keys: KEYS.map((ch, j) => ({ ch, op: j < n ? 1 : 0.3 })), pick: () => this.setState({ popPick: i }) }))"]
]);
patch(pop('PopPhoto'), [
  ['      <span style="margin: 14px 16px 0; font-size: 17px; line-height: 24px; font-weight: 800; letter-spacing: -0.2px">Receipt photo</span>\n      <span style="margin: 2px 16px 0; font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">One photo is attached to this expense.</span>',
    '      <div style="margin: 14px 16px 0; display: flex; align-items: center; justify-content: space-between; gap: 12px">\n        <span style="min-width: 0; display: flex; flex-direction: column; gap: 2px">\n          <span style="font-size: 17px; line-height: 24px; font-weight: 800; letter-spacing: -0.2px">Receipt photo</span>\n          <span style="font-size: 13.5px; line-height: 20px; font-weight: 500; color: {{t.text2}}">Attached to this expense.</span>\n        </span>\n        <a href="NewPhoto.dc.html" aria-label="View photo" style="position: relative; width: 44px; height: 44px; flex-shrink: 0; border-radius: 12px; overflow: hidden; background: linear-gradient(135deg, #6A5846 0%, #2A221B 100%); display: block">\n          <span aria-hidden="true" style="position: absolute; left: 12px; top: 6px; width: 20px; height: 34px; border-radius: 2px; background-color: #F4F0E6; background-image: repeating-linear-gradient(180deg, transparent 0 5px, #A8A397 5px 6.5px); background-size: 12px 26px; background-position: 4px 2px; background-repeat: no-repeat; transform: rotate(-6deg); box-shadow: 0 2px 4px rgba(0, 0, 0, 0.4)"></span>\n        </a>\n      </div>'],
  ['<button type="button" style="height: 56px; border: 0; border-radius: 16px; padding: 0 16px; background: {{t.tile}}; color: {{pop.bad}};', '<button type="button" style="margin-top: 8px; height: 56px; border: 0; border-radius: 16px; padding: 0 16px; background: {{t.tile}}; color: {{pop.bad}};']
]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
