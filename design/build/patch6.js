// Review fixes for Reports and Settings (part files) and two shared theme tokens. Each replacement must match exactly once.
const fs = require('fs');
const path = require('path');
let n = 0, miss = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [a, b] of pairs) {
    const c = s.split(a).length - 1;
    if (c !== 1) { console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 80)); miss++; continue; }
    s = s.replace(a, () => b); n++;
  }
  fs.writeFileSync(file, s);
}

// Shared tokens: a selection tint that is clearly different from the header bands, and a danger red that is not the Coral accent.
patch(path.join(__dirname, '..', 'mockup', 'project', 'NewCharts.dc.html'), [
  ["t.wash = t.accent + '14';", "t.wash = t.accent + '29';"],
  ["t.bad = '#FF9A8F';", "t.bad = '#FF8C9A';"]
]);

patch(path.join(__dirname, 'NewReports.part.html'), [
  // "so far" chip stays visible on a selected row.
  ['border-radius: 10px; background: {{t.surface2}}; color: {{t.text2}}; font-size: 11.5px; line-height: 20px; font-weight: 600">so far</span>', 'border-radius: 10px; background: {{t.bg}}; color: {{t.text2}}; font-size: 11.5px; line-height: 20px; font-weight: 600">so far</span>'],
  // Arrow and number travel together, so the gap between them is the same on every row.
  ['<span style="width: 32px; text-align: right">{{r.delta}}</span>', '<span>{{r.delta}}</span>'],
  // The three statistics sit left, centre and right, so the gaps between them are even.
  ['<span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Daily average</span>', '<span style="justify-self: center; font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Daily average</span>'],
  ['<span style="font-size: 18px; line-height: 24px; font-weight: 800">{{mAvg}}</span>', '<span style="justify-self: center; font-size: 18px; line-height: 24px; font-weight: 800">{{mAvg}}</span>'],
  // The comparison says "more" or "less" in words, like the Charts screen.
  ['<span style="justify-self: end; display: inline-flex; align-items: center; gap: 4px; font-size: 18px; line-height: 24px; font-weight: 800; color: {{mCmpFg}}">\n          <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px">{{mCmpIcon}}</span>\n          {{mCmpText}}\n        </span>', '<span style="justify-self: end; font-size: 18px; line-height: 24px; font-weight: 800; white-space: nowrap; color: {{mCmpFg}}">{{mCmpText}}</span>'],
  ["mCmpText: mCmp ? mCmp.abs + '%' : '\\u2014',", "mCmpText: mCmp ? (mCmp.flat ? 'Same' : mCmp.abs + '% ' + (mCmp.less ? 'less' : 'more')) : '\\u2014',"],
  // The selected month's letter sits on a small accent chip.
  ['<span style="position: absolute; left: 0; right: 0; bottom: 4px; text-align: center; font-size: 10.5px; line-height: 14px; font-weight: {{b.fw}}; color: {{b.labelFg}}">{{b.label}}</span>', '<span style="position: absolute; left: 0; right: 0; bottom: 3px; display: flex; justify-content: center"><span style="min-width: 16px; height: 16px; border-radius: 6px; background: {{b.labelBg}}; color: {{b.labelFg}}; font-size: 10.5px; line-height: 16px; font-weight: {{b.fw}}; text-align: center">{{b.label}}</span></span>'],
  ["labelFg: x.future ? t.dim : (on ? t.text : t.text3),", "labelBg: on ? t.accent : 'transparent',\n        labelFg: x.future ? t.dim : (on ? t.onAccent : t.text3),"],
  // Legend wording.
  ['              Month in progress\n', '              In progress\n'],
  ["avgText: year + ' average ' + K.fmt(avgV),", "avgText: year + ' monthly average ' + K.fmt(avgV),"]
]);

patch(path.join(__dirname, 'NewSettings.part.html'), [
  ['<!--@HELMET calculate,calendar_month,category,check,chevron_right,folder,palette-->', '<!--@HELMET calculate,calendar_month,category,check,chevron_right,delete,folder,palette-->'],
  // Theme tiles preview the theme with a tiny chart instead of grey bars.
  ['                <span aria-hidden="true" style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px">\n                  <span style="height: 6px; border-radius: 3px; background: {{m.bar1}}"></span>\n                  <span style="width: 62%; height: 6px; border-radius: 3px; background: {{m.bar2}}"></span>\n                </span>', '                <span aria-hidden="true" style="margin-left: auto; height: 24px; display: flex; align-items: flex-end; gap: 3px">\n                  <span style="width: 6px; height: 10px; border-radius: 2px 2px 0 0; background: {{m.soft}}"></span>\n                  <span style="width: 6px; height: 24px; border-radius: 2px 2px 0 0; background: {{m.accent}}"></span>\n                  <span style="width: 6px; height: 16px; border-radius: 2px 2px 0 0; background: {{m.soft}}"></span>\n                  <span style="width: 6px; height: 20px; border-radius: 2px 2px 0 0; background: {{m.soft}}"></span>\n                </span>'],
  ['        bg: m.bg,\n', '        bg: m.surface2,\n'],
  ['        bar1: m.surface2,\n        bar2: m.line,\n', '        soft: m.barSoft,\n'],
  // Slider letters sit exactly on the two gutters.
  ['<span aria-hidden="true" style="width: 14px; text-align: center; font-size: 12px; line-height: 16px; font-weight: 700; color: {{t.text3}}">A</span>', '<span aria-hidden="true" style="width: 14px; text-align: left; font-size: 12px; line-height: 16px; font-weight: 700; color: {{t.text3}}">A</span>'],
  ['<span aria-hidden="true" style="width: 14px; text-align: center; font-size: 19px; line-height: 24px; font-weight: 700; color: {{t.text3}}">A</span>', '<span aria-hidden="true" style="width: 14px; text-align: right; font-size: 19px; line-height: 24px; font-weight: 700; color: {{t.text3}}">A</span>'],
  // The preview says what the slider changes.
  ['          <span style="font-weight: 800">{{previewAmount}}</span>\n        </div>\n', '          <span style="font-weight: 800">{{previewAmount}}</span>\n        </div>\n        <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Preview. The whole app uses this size.</span>\n'],
  // A switch that is off keeps a clearly visible track.
  ['        track: on ? t.accent : t.line,\n        knob: on ? t.onAccent : t.text3,', '        track: on ? t.accent : t.mix(t.text3, t.surface, 0.4),\n        knob: on ? t.onAccent : t.text,'],
  // "Manage categories" shows a peek of the category tiles.
  ['          <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">15 categories. Add, edit, delete, reorder.</span>\n        </span>\n        <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; margin-right: -6px; color: {{t.text3}}">chevron_right</span>', '          <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Add, edit, delete, reorder</span>\n        </span>\n        <span style="flex-shrink: 0; display: flex; align-items: center; gap: 6px">\n          <span aria-hidden="true" style="display: flex; align-items: center">\n            <sc-for list="{{catPeek}}" as="p" hint-placeholder-count="3">\n              <span style="width: 28px; height: 28px; margin-right: -8px; border-radius: 9px; background: {{t.tile}}; box-shadow: 0 0 0 2px {{t.surface}}; display: flex; align-items: center; justify-content: center"><span class="em" style="font-size: 15px">{{p.emoji}}</span></span>\n            </sc-for>\n            <span style="width: 28px; height: 28px; border-radius: 9px; background: {{t.tile}}; box-shadow: 0 0 0 2px {{t.surface}}; display: flex; align-items: center; justify-content: center; font-size: 10.5px; line-height: 14px; font-weight: 800; color: {{t.text2}}">+12</span>\n          </span>\n          <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; margin-right: -6px; color: {{t.text3}}">chevron_right</span>\n        </span>'],
  ["      numToggles: [tg('sep', 'Thousands separator', '', true)],", "      numToggles: [tg('sep', 'Thousands separator', '', true)],\n      catPeek: [{ emoji: '\\uD83E\\uDD66' }, { emoji: '\\uD83C\\uDF57' }, { emoji: '\\uD83D\\uDE8D' }],"],
  // "Clear cache" and "Delete all data" say what they do; the delete row is marked by an icon as well as colour.
  ['<button type="button" style="margin: 0 16px; height: 56px; border: 0; padding: 0; background: transparent; box-shadow: inset 0 -1px 0 {{t.line}}; color: {{t.text}}; font-size: 15px; line-height: 20px; font-weight: 600; text-align: left; cursor: pointer">Clear cache</button>', '<button type="button" style="margin: 0 16px; height: 68px; border: 0; padding: 0; background: transparent; box-shadow: inset 0 -1px 0 {{t.line}}; color: {{t.text}}; display: flex; flex-direction: column; justify-content: center; gap: 2px; text-align: left; cursor: pointer">\n        <span style="font-size: 15px; line-height: 20px; font-weight: 600">Clear cache</span>\n        <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Frees up space. Your expenses stay.</span>\n      </button>'],
  ['<button type="button" style="margin: 0 16px; height: 56px; border: 0; padding: 0; background: transparent; color: {{t.bad}}; font-size: 15px; line-height: 20px; font-weight: 700; text-align: left; cursor: pointer">Delete all data</button>', '<button type="button" style="margin: 0 16px; height: 68px; border: 0; padding: 0; background: transparent; color: {{t.bad}}; display: flex; align-items: center; justify-content: space-between; gap: 12px; text-align: left; cursor: pointer">\n        <span style="min-width: 0; display: flex; flex-direction: column; gap: 2px">\n          <span style="font-size: 15px; line-height: 20px; font-weight: 700">Delete all data</span>\n          <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">This cannot be undone</span>\n        </span>\n        <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; margin-right: -2px">delete</span>\n      </button>']
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
