// Version 35 groundwork: import headers, Settings links to Export and Import, and the type-to-add preview states.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
let problems = 0;
const say = (ok, msg) => { if (!ok) problems++; console.log((ok ? 'ok       ' : 'PROBLEM  ') + msg); };
const read = (f) => fs.readFileSync(f, 'utf8').replace(/\r\n/g, '\n');
const count = (s, re) => (s.match(new RegExp(re.source, 'g')) || []).length;

// 1. Import screens: the step sits under the title, and the side columns only need to hold the back button.
['NewImport', 'NewImportMatch', 'NewImportReview'].forEach((name) => {
  const f = path.join(__dirname, name + '.part.html');
  let s = read(f);
  const re = /<h1 style="margin: 0; text-align: center;[^"]*">([^<]*)<\/h1>\s*<span style="justify-self: end;[^"]*">(Step \d of 3)<\/span>/;
  if (count(s, re) === 1) {
    s = s.replace(re, (all, title, step) => '<div style="display: flex; flex-direction: column; align-items: center">\n      <h1 style="margin: 0; font-size: 17px; line-height: 22px; font-weight: 800; letter-spacing: -0.2px; white-space: nowrap">' + (title === 'Check columns' ? 'Check the columns' : title) + '</h1>\n      <span style="font-size: 12.5px; line-height: 16px; font-weight: 600; color: {{t.text3}}">' + step + '</span>\n    </div>\n    <span aria-hidden="true"></span>');
    const g = 'grid-template-columns: 88px minmax(0, 1fr) 88px';
    say(s.split(g).length === 2, name + ' header columns');
    s = s.split(g).join('grid-template-columns: 48px minmax(0, 1fr) 48px');
    fs.writeFileSync(f, s);
    say(true, name + ' header step line');
  } else say(s.indexOf('>Step ') > 0 && s.indexOf('justify-self: end; height: 32px') < 0, name + ' header already patched');
});

// 2. Settings: the Export and Import rows open their screens.
{
  const f = path.join(__dirname, 'NewSettings.part.html');
  let s = read(f);
  [['Export', 'NewExport'], ['Import', 'NewImport']].forEach(([label, target]) => {
    const re = new RegExp('<button type="button" style="(margin: 0 16px; height: 68px;[^"]*)">(\\s*<span[^>]*>\\s*<span[^>]*>' + label + '</span>[\\s\\S]*?)</button>');
    if (count(s, re) === 1) {
      s = s.replace(re, (all, style, inner) => '<a href="' + target + '.dc.html" style="' + style + '; text-decoration: none">' + inner + '</a>');
      say(true, 'Settings row ' + label + ' is a link');
    } else say(s.indexOf('<a href="' + target + '.dc.html"') > 0, 'Settings row ' + label + ' already a link');
  });
  fs.writeFileSync(f, s);
}

// 3. Type to add: the preview shows as soon as there is an amount, the category is a button, and an unknown word asks for a category.
const PREVIEW = [
  '<sc-if value="{{qv.show}}" hint-placeholder-val="{{ true }}">',
  '        <div style="display: flex; align-items: center; gap: 12px; padding: 12px 16px; border-radius: 20px; background: {{t.surface}}">',
  '          <a href="PopQuickCat.dc.html" aria-label="{{qv.aria}}" style="flex: 1; min-width: 0; display: flex; align-items: center; gap: 12px; text-decoration: none; color: inherit">',
  '            <span style="width: 44px; height: 44px; flex-shrink: 0; box-sizing: border-box; border-radius: 14px; background: {{qv.tile}}; border: {{qv.tileLine}}; display: flex; align-items: center; justify-content: center">',
  '              <sc-if value="{{qv.known}}" hint-placeholder-val="{{ true }}">',
  '                <span class="em" aria-hidden="true" style="font-size: 22px">{{qv.emoji}}</span>',
  '              </sc-if>',
  '              <sc-if value="{{qv.unknown}}" hint-placeholder-val="{{ false }}">',
  '                <span aria-hidden="true" style="font-size: 20px; line-height: 24px; font-weight: 800; color: {{t.accent}}">?</span>',
  '              </sc-if>',
  '            </span>',
  '            <span style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">',
  '              <span style="display: flex; align-items: center; font-size: 15px; line-height: 20px; font-weight: {{qv.nameFw}}; color: {{qv.nameFg}}; white-space: nowrap">',
  '                <span style="min-width: 0; overflow: hidden; text-overflow: ellipsis">{{qv.name}}</span>',
  '                <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; color: {{t.accent}}">expand_more</span>',
  '              </span>',
  '              <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{qv.sub}}</span>',
  '            </span>',
  '          </a>',
  '          <span style="font-size: 17px; line-height: 24px; font-weight: 800; font-variant-numeric: tabular-nums">{{qv.amount}}</span>',
  '          <a href="MoodAqua.dc.html" aria-disabled="{{qv.unknown}}" style="height: 40px; flex-shrink: 0; padding: 0 18px; border-radius: 20px; background: {{qv.addBg}}; color: {{qv.addFg}}; pointer-events: {{qv.addPe}}; font-size: 14.5px; line-height: 20px; font-weight: 800; display: flex; align-items: center; text-decoration: none">Add</a>',
  '        </div>',
  '      </sc-if>'
].join('\n');
const QUICK = [
  '  renderVals() {',
  '    const v = this.quickHostVals();',
  '    v.qv = this.quickVals(v.t);',
  "    if (v.qv.hint && 'hint' in v) v.hint = v.qv.hint;",
  '    return v;',
  '  }',
  '',
  '  // Type to add: the preview shows as soon as there is an amount. A word the app has not seen asks for a category once.',
  '  // Tapping a category tile, or the category on the preview, overrides the guess.',
  '  quickVals(t) {',
  '    const K = this.kit();',
  '    const st = Object.assign(this.defaults(), this.state || {});',
  '    const q = this.parseQuick(K, st.typed);',
  '    const show = !!(q && q.amount);',
  '    const cat = show ? (st.picked ? K.CAT[st.picked] : q.cat) : null;',
  '    const known = !!cat;',
  '    return {',
  '      show,',
  '      known,',
  '      unknown: show && !known,',
  "      emoji: known ? cat.emoji : '',",
  "      name: known ? cat.name : 'Category',",
  "      aria: known ? 'Category: ' + cat.name + '. Tap to change' : 'Pick a category',",
  "      tile: known ? t.tile : 'transparent',",
  "      tileLine: known ? '0 solid transparent' : '1.5px dashed ' + t.accent,",
  '      nameFg: known ? t.text : t.accent,',
  "      nameFw: known ? '600' : '800',",
  "      sub: show ? (q.note ? q.note + ' \\u00B7 ' : '') + 'Today' : '',",
  "      amount: show ? this.pretty(String(q.amount)) : '',",
  '      addBg: known ? t.accent : t.surface2,',
  '      addFg: known ? t.onAccent : t.text3,',
  "      addPe: known ? 'auto' : 'none',",
  "      hint: show && !known ? 'New word. Pick its category once.' : ''",
  '    };',
  '  }',
  '',
  '  quickHostVals() {',
  ''
].join('\n');
['NewAdd', 'NewAddQuick', 'NewEdit'].forEach((name) => {
  const f = path.join(proj, name + '.dc.html');
  let s = read(f);
  if (s.indexOf('quickHostVals') > 0) { say(true, name + ' already has the new preview'); return; }
  const block = /<sc-if value="\{\{hasPreview\}\}"[^>]*>[\s\S]*?<\/sc-if>/;
  const fn = /\n  renderVals\(\) \{\n/;
  const a = count(s, block);
  const b = count(s, fn);
  if (a !== 1 || b !== 1) { say(false, name + ': preview block x' + a + ', renderVals x' + b); return; }
  s = s.replace(block, () => PREVIEW).replace(fn, () => '\n' + QUICK);
  fs.writeFileSync(f, s);
  say(true, name + ' preview and logic replaced');
});

// 4. The "new word" state is the type-to-add board opened on a word the app has not seen.
{
  let s = read(path.join(proj, 'NewAddQuick.dc.html'));
  const a = "typed: 'coffee 120'";
  say(s.split(a).length === 2, 'NewAddQuick default text found once');
  s = s.split(a).join("typed: 'saree 12000'").replace(/<title>[^<]*<\/title>/, '<title>Add expense, type to add, new word</title>');
  fs.writeFileSync(path.join(proj, 'NewAddQuickNew.dc.html'), s);
  say(true, 'NewAddQuickNew written');
}
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
